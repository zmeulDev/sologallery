import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/thumbnail_provider.dart';
import '../people_providers.dart';

/// The avatar thumbnail plus its true decoded pixel size. Face boxes are stored
/// as fractions of the image, so the real width/height turn them back into
/// pixels — and `photo_manager` thumbnails are **not** square (a 4:3 photo
/// requested at 1024 comes back 1365×1024), so both axes must come from the
/// decode rather than from the size we asked for.
typedef FaceThumb = ({Uint8List bytes, int width, int height});

/// The edge we request for the avatar thumbnail — larger than the 512 analysis
/// thumbnail so the zoomed-in face isn't upscaled to mush. Nothing depends on
/// the two matching: the stored box is normalized, so it maps onto whatever
/// size actually comes back.
const _avatarEdge = 1024;

final faceThumbProvider =
    FutureProvider.autoDispose.family<FaceThumb?, String>((ref, assetId) async {
  final bytes = await ref.watch(
    thumbnailProvider(
      ThumbnailRequest(assetId, width: _avatarEdge, height: _avatarEdge),
    ).future,
  );
  if (bytes == null) return null;
  // Read the encoded dimensions without a full decode.
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final thumb = (bytes: bytes, width: descriptor.width, height: descriptor.height);
  descriptor.dispose();
  buffer.dispose();
  return thumb;
});

/// Placement of the face crop inside the avatar circle: the top-left offset and
/// display size of the (uniformly-scaled, aspect-preserved) thumbnail so the
/// detected face box sits centered and zoomed to [fill] past just fitting.
///
/// The box arrives **normalized** (`[0, 1]` fractions of the image) and is
/// resolved against the image's real decoded [imageWidth]/[imageHeight] here.
/// Pure geometry — unit testable without decoding.
({double left, double top, double dispW, double dispH}) faceAvatarPlacement({
  required double boxLeft,
  required double boxTop,
  required double boxRight,
  required double boxBottom,
  required double imageWidth,
  required double imageHeight,
  required double size,
  double fill = 1.3,
}) {
  // Fractions → pixels in this image's own space. No scale factor to guess:
  // whatever the thumbnail's dimensions turned out to be, they are the ones the
  // fractions are relative to.
  final l = boxLeft * imageWidth;
  final r = boxRight * imageWidth;
  final t = boxTop * imageHeight;
  final b = boxBottom * imageHeight;

  final boxW = (r - l).clamp(1.0, imageWidth);
  final boxH = (b - t).clamp(1.0, imageHeight);
  // Uniform scale (same on both axes) → no distortion; zoom the box past just
  // fitting so the face hugs the circle.
  final scale = size * fill / (boxW > boxH ? boxW : boxH);
  final cx = (l + r) / 2 * scale;
  final cy = (t + b) / 2 * scale;
  return (
    left: size / 2 - cx,
    top: size / 2 - cy,
    dispW: imageWidth * scale,
    dispH: imageHeight * scale,
  );
}

/// Circular avatar for a person: the representative face cropped out of the
/// cached indexing thumbnail, centered and zoomed. Falls back to a recessed
/// placeholder circle while loading, if there's no cover face, or if the
/// thumbnail can't be decoded.
class FaceAvatar extends ConsumerWidget {
  const FaceAvatar({
    super.key,
    required this.personId,
    this.size = 64,
    this.borderRadius,
  });

  final int personId;
  final double size;

  /// Rounds the crop to a rectangle instead of a circle. Null — the default —
  /// keeps the circle the People grid and the person screen use; the People
  /// strip passes `AppRadius.br12` so a name can sit on a scrim inside the
  /// tile rather than on a caption line beneath it.
  final BorderRadius? borderRadius;

  /// Over-zoom past just fitting the box so the face fills the circle. Tunable —
  /// raise to crop closer, lower to show more surround.
  static const _faceFill = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colors.surface2,
            shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: borderRadius,
          ),
        );

    final cover = ref.watch(personCoverProvider(personId)).value;
    if (cover == null) return placeholder();

    final thumb = ref.watch(faceThumbProvider(cover.assetId)).value;
    if (thumb == null) return placeholder();

    final place = faceAvatarPlacement(
      boxLeft: cover.left,
      boxTop: cover.top,
      boxRight: cover.right,
      boxBottom: cover.bottom,
      imageWidth: thumb.width.toDouble(),
      imageHeight: thumb.height.toDouble(),
      size: size,
      fill: _faceFill,
    );

    final clipped = SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: place.left,
              top: place.top,
              width: place.dispW,
              height: place.dispH,
              child: Image.memory(
                thumb.bytes,
                fit: BoxFit.fill, // dispW/dispH already carry the true aspect
                filterQuality: FilterQuality.medium, // smoother scaling
                gaplessPlayback: true,
              ),
            ),
          ],
        ),
    );
    return borderRadius == null
        ? ClipOval(child: clipped)
        : ClipRRect(borderRadius: borderRadius!, child: clipped);
  }
}
