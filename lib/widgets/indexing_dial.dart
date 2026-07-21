import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/count_labels.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_text_styles.dart';
import '../services/indexing_service.dart';

/// Ring geometry: a hairline arc set in from the disc's edge.
const double _ringStroke = 2.5;
const double _ringInset = 3;

/// How far back the track sits from the arc drawn on top of it.
const double _trackOpacity = 0.25;

/// The app-wide "we're still looking at your photos" indicator: a small disc
/// carrying the number of photos left, ringed by an arc of how much of the pass
/// is already done.
///
/// Analysis runs in the background for as long as it takes on a large library,
/// and until it finishes Search, People and Memories are all quietly
/// incomplete. Without this the app just looks like it is missing results.
///
/// Renders nothing at all when the indexer is idle, so callers can mount it
/// unconditionally. Mounted once, as [NavPillBar]'s `trailing` in [AppShell] —
/// that covers the four tabs and every route pushed inside a branch (Settings,
/// the month/older/album/folder grids, People). The full-screen media routes are
/// pushed on the root navigator and cover the shell, so the photo viewer and the
/// memory player stay clean.
///
/// It wears the capsule's own inverted ink and sits on the capsule's baseline:
/// the bottom chrome reads as one family — the sliding knob, escaped and at
/// work — rather than as a second floating object. It is deliberately *beside*
/// the capsule and not a slot inside it, so no destination moves under the
/// thumb when a pass starts or ends.
class IndexingDial extends ConsumerWidget {
  const IndexingDial({super.key});

  /// The disc's diameter, and the space the dial reserves whether or not a pass
  /// is running — so the bar's trailing slot never changes size.
  static const double size = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(indexingStatusProvider).value;
    // A dial that flashed before the first status arrived would claim work that
    // may not exist, so an unresolved stream shows nothing.
    final showing = status != null && status.isIndexing;
    final duration = AppMotion.of(context, AppMotion.medium);

    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: showing ? _Dial(status: status) : const SizedBox.shrink(),
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({required this.status});

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

    return Semantics(
      // The count alone is not a sentence; screen readers get the whole one the
      // app-wide strip used to carry, and hear it again as the pass advances.
      label: 'Analyzing your photos — ${status.remaining} left',
      liveRegion: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: IndexingDial.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.pillActiveBg,
            shape: BoxShape.circle,
          ),
          child: TweenAnimationBuilder<double>(
            // Sweeps to each new fraction rather than stepping, so the ring
            // reads as work in progress and not as a series of redraws.
            tween: Tween<double>(end: done.clamp(0.0, 1.0)),
            duration: AppMotion.of(context, AppMotion.medium),
            curve: AppMotion.curve,
            builder: (context, value, child) => CustomPaint(
              painter: IndexingRingPainter(
                progress: value,
                color: colors.pillActiveText,
              ),
              child: child,
            ),
            child: Center(
              // Compacted: a five-digit library would otherwise overflow the
              // ring it sits inside.
              child: Text(
                compactCount(status.remaining),
                maxLines: 1,
                style: styles.caption.copyWith(
                  color: colors.pillActiveText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the dial's ring: the full track, then the share already done on top.
///
/// Public only so a widget test can read the fraction the ring was actually
/// drawn at — there is no other observable trace of it.
class IndexingRingPainter extends CustomPainter {
  const IndexingRingPainter({required this.progress, required this.color});

  /// Share of the pass already done, `[0, 1]`.
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final arc = (Offset.zero & size).deflate(_ringInset + _ringStroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: _trackOpacity);
    canvas.drawArc(arc, 0, math.pi * 2, false, paint);

    if (progress <= 0) return;
    paint.color = color;
    // From 12 o'clock, clockwise.
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(IndexingRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
