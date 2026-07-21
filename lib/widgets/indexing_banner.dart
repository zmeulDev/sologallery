import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';
import '../services/indexing_service.dart';

/// The app-wide "we're still looking at your photos" strip.
///
/// Analysis runs in the background for as long as it takes on a large library,
/// and until it finishes Search, People and Memories are all quietly
/// incomplete. Without this the app just looks like it is missing results.
///
/// Renders nothing at all when the indexer is idle, so callers can mount it
/// unconditionally. Mounted once, in [AppShell], above the shell body — that
/// covers the four tabs and every route pushed inside a branch (Settings, the
/// month/older/album/folder grids, People). The full-screen media routes are
/// pushed on the root navigator and cover the shell, so the photo viewer and
/// the memory player stay clean.
class IndexingBanner extends ConsumerWidget {
  const IndexingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(indexingStatusProvider).value;
    final showing = status != null && status.isIndexing;
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: showing ? _Strip(status: status) : const SizedBox(width: 0),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.status});

  final IndexingStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    // `total` is the size of the current pass, so a pass that is entirely
    // pending reads as 0 done rather than dividing by zero.
    final done = status.total == 0
        ? 0.0
        : (status.total - status.remaining) / status.total;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s8,
              AppSpace.s16,
              AppSpace.s8,
            ),
            child: Text(
              // Same verb as the Settings row, so the app has one word for
              // this rather than two.
              'Analyzing your photos — ${status.remaining} left',
              style: styles.caption.copyWith(color: colors.textSecondary),
            ),
          ),
          // A hairline of real progress along the bottom edge: the strip says
          // work is happening, this says how much is left without a second
          // sentence.
          SizedBox(
            height: AppRadius.r2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: done.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.textMuted,
                    borderRadius: AppRadius.br4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
