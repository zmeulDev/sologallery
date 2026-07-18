import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/thumbnail_provider.dart';
import '../people_providers.dart';

/// The indexing thumbnail plus its true decoded pixel size. Face boxes are
/// stored in the **512-box** analysis image's coordinate space, and
/// `photo_manager` preserves the asset's aspect ratio (the thumbnail is usually
/// **not** square), so the real width/height are needed to crop without
/// distorting the face.
typedef FaceThumb = ({Uint8List bytes, int width, int height});

/// The edge the stored face-box coordinates were measured against (the ML
/// analysis thumbnail).
const _analysisEdge = 512.0;

/// The edge we fetch for the avatar itself — larger than [_analysisEdge] so the
/// zoomed-in face isn't upscaled to mush. The box is rescaled by the decoded
/// ratio (see [FaceAvatar.build]).
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
/// detected face box sits centered and zoomed to [fill] past just fitting. Pure
/// geometry over the image's real pixel [imageWidth]/[imageHeight] — unit
/// testable without decoding.
({double left, double top, double dispW, double dispH}) faceAvatarPlacement({
  required int boxLeft,
  required int boxTop,
  required int boxRight,
  required int boxBottom,
  required double imageWidth,
  required double imageHeight,
  required double size,
  double fill = 1.3,
}) {
  final boxW = (boxRight - boxLeft).toDouble().clamp(1.0, imageWidth);
  final boxH = (boxBottom - boxTop).toDouble().clamp(1.0, imageHeight);
  // Uniform scale (same on both axes) → no distortion; zoom the box past just
  // fitting so the face hugs the circle.
  final scale = size * fill / (boxW > boxH ? boxW : boxH);
  final cx = (boxLeft + boxRight) / 2 * scale;
  final cy = (boxTop + boxBottom) / 2 * scale;
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
  const FaceAvatar({super.key, required this.personId, this.size = 64});

  final int personId;
  final double size;

  /// Over-zoom past just fitting the box so the face fills the circle. Tunable —
  /// raise to crop closer, lower to show more surround.
  static const _faceFill = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;

    Widget placeholder() => Container(
          width: size,
          height: size,
          decoration:
              BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
        );

    final cover = ref.watch(personCoverProvider(personId)).value;
    if (cover == null) return placeholder();

    final thumb = ref.watch(faceThumbProvider(cover.assetId)).value;
    if (thumb == null) return placeholder();

    // The box was measured on a 512-box thumbnail; this avatar thumbnail is
    // larger (same aspect), so rescale the box into its pixel space by the
    // decoded ratio (robust to originals smaller than [_avatarEdge]).
    final longEdge = thumb.width > thumb.height ? thumb.width : thumb.height;
    final k = longEdge / _analysisEdge;
    final place = faceAvatarPlacement(
      boxLeft: (cover.left * k).round(),
      boxTop: (cover.top * k).round(),
      boxRight: (cover.right * k).round(),
      boxBottom: (cover.bottom * k).round(),
      imageWidth: thumb.width.toDouble(),
      imageHeight: thumb.height.toDouble(),
      size: size,
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
      ),
    );
  }
}
