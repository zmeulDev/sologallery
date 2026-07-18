import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/thumbnail_provider.dart';
import '../people_providers.dart';

/// Placement of the face crop inside the avatar circle: the top-left offset and
/// side length of the (square, uniformly-scaled) thumbnail so the detected face
/// box sits centered and zoomed to [fill] past just fitting. Pure geometry —
/// unit-testable without decoding an image. [thumbEdge] is the coordinate space
/// the box was measured in (the 512px indexing thumbnail).
({double left, double top, double side}) faceAvatarPlacement({
  required int boxLeft,
  required int boxTop,
  required int boxRight,
  required int boxBottom,
  required double size,
  double thumbEdge = 512,
  double fill = 1.3,
}) {
  final boxW = (boxRight - boxLeft).toDouble().clamp(1.0, thumbEdge);
  final boxH = (boxBottom - boxTop).toDouble().clamp(1.0, thumbEdge);
  final scale = size * fill / (boxW > boxH ? boxW : boxH);
  final cx = (boxLeft + boxRight) / 2 * scale;
  final cy = (boxTop + boxBottom) / 2 * scale;
  return (left: size / 2 - cx, top: size / 2 - cy, side: thumbEdge * scale);
}

/// Circular avatar for a person: the representative face cropped out of the
/// cached 512px indexing thumbnail (the same size the box was measured against).
/// Falls back to a recessed placeholder circle while loading or if no face.
class FaceAvatar extends ConsumerWidget {
  const FaceAvatar({super.key, required this.personId, this.size = 64});

  final int personId;
  final double size;

  /// The indexing thumbnail edge the stored box coordinates are relative to.
  static const _thumbEdge = 512.0;

  /// How much to zoom the detected face box past just fitting the circle, so the
  /// portrait fills the avatar and hugs the face instead of leaving background in
  /// the corners. 1.0 = box's longer side exactly fills; ~1.3 crops in tighter.
  /// Tunable — raise to crop closer, lower to show more surround.
  static const _faceFill = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final cover = ref.watch(personCoverProvider(personId)).value;

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration:
              BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
        );

    if (cover == null) return placeholder();

    final bytes = ref
        .watch(thumbnailProvider(
          ThumbnailRequest(cover.assetId, width: 512, height: 512),
        ))
        .value;
    if (bytes == null) return placeholder();

    final place = faceAvatarPlacement(
      boxLeft: cover.left,
      boxTop: cover.top,
      boxRight: cover.right,
      boxBottom: cover.bottom,
      size: size,
      thumbEdge: _thumbEdge,
      fill: _faceFill,
    );

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: place.left,
              top: place.top,
              width: place.side,
              height: place.side,
              child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
            ),
          ],
        ),
      ),
    );
  }
}
