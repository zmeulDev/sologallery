import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../services/thumbnail_provider.dart';

/// A single photo thumbnail, resolved by asset id through [thumbnailProvider].
/// Shows a quiet recessed placeholder while loading or if the asset can't be
/// resolved; the photo itself supplies the only color (the chrome is neutral).
///
/// When [showVideoBadge] is set, a [DurationBadge] overlays the bottom-right
/// corner for video assets (watched via [videoDurationProvider]); still images
/// and album covers leave it off.
///
/// Fills its parent — wrap it in a sized/aspect box.
class AssetThumbnail extends ConsumerWidget {
  const AssetThumbnail({
    super.key,
    required this.assetId,
    this.size = 256,
    this.showVideoBadge = false,
  });

  final String assetId;

  /// Requested pixel size of the thumbnail (square). Grid cells pass a size
  /// matched to their on-screen dimensions × devicePixelRatio.
  final int size;

  /// Whether to overlay a duration badge when this asset is a video.
  final bool showVideoBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final async = ref.watch(
      thumbnailProvider(ThumbnailRequest(assetId, width: size, height: size)),
    );
    // Placeholder and image are keyed so the switcher fades exactly once per
    // asset: placeholder → first bytes. A byte refresh for the same asset keeps
    // the same key (no re-fade; gaplessPlayback swaps in place), and an initial
    // build with already-cached bytes shows instantly (AnimatedSwitcher never
    // animates its first child). Pure opacity on the decoded thumbnail — no
    // extra decode, no per-frame allocation.
    final resolved = async.when(
      data: (bytes) => bytes == null
          ? _Placeholder(colors, key: const ValueKey('ph'))
          : Image.memory(
              bytes,
              key: ValueKey(assetId),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              width: double.infinity,
              height: double.infinity,
            ),
      loading: () => _Placeholder(colors, key: const ValueKey('ph')),
      error: (e, st) => _Placeholder(colors, key: const ValueKey('ph')),
    );
    final image = AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.medium),
      layoutBuilder: _fillLayout,
      child: resolved,
    );
    if (!showVideoBadge) return image;

    final duration = ref.watch(videoDurationProvider(assetId)).value;
    if (duration == null) return image;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Positioned(
          right: 4,
          bottom: 4,
          child: DurationBadge(duration: duration),
        ),
      ],
    );
  }

  /// The default switcher layout centers children in a loose [Stack]; this one
  /// keeps the widget's fill-the-cell geometry ([StackFit.expand]) so the
  /// outgoing placeholder and incoming image both cover the cell exactly.
  static Widget _fillLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [...previousChildren, ?currentChild],
    );
  }
}

/// A small "▶ m:ss" pill marking a video and its length. Sits over the photo, so
/// it carries its own contrast (translucent ink + white) rather than theme
/// tokens — legible on any thumbnail in either theme.
class DurationBadge extends StatelessWidget {
  const DurationBadge({super.key, required this.duration});

  final Duration duration;

  static String format(Duration d) {
    final seconds = d.inSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppOverMedia.scrim,
        borderRadius: AppRadius.br12,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              size: 12,
              color: AppOverMedia.glyph,
            ),
            const SizedBox(width: 2),
            Text(
              format(duration),
              style: const TextStyle(
                color: AppOverMedia.glyph,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.colors, {super.key});
  final AppColors colors;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: colors.surface2, child: const SizedBox.expand());
}
