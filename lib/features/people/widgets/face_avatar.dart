import 'dart:math' as math;
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

/// The edges we are willing to request, smallest first. Requests snap up to one
/// of these rather than using the exact computed number so that the same face
/// shown at slightly different sizes — the People grid and the People strip —
/// still shares one cache entry and one decode instead of two.
const _avatarEdgeBuckets = [256, 384, 512, 768, 1024];

/// The thumbnail edge needed to fill an [avatarSize]-wide avatar, at device
/// pixels, from a face box covering [boxFraction] of the source image.
///
/// The avatar is a *zoomed crop*, not the whole picture, so the image only has
/// to be large enough that the box itself — [boxFraction] of it — still carries
/// enough pixels once scaled up by [fill]. That makes the honest requirement
/// `avatarSize * dpr * fill / boxFraction`, which for a face filling most of
/// the frame is a few hundred pixels and for a small face in a group shot is
/// more than the 1024 ceiling. Hence the clamp: 1024 stays the maximum (it is
/// what shipped, and lowering it would soften exactly the group-photo avatars
/// that need it most), but a large face no longer pays for it.
///
/// Pure arithmetic, unit tested — no decoding.
int avatarThumbEdge({
  required double avatarSize,
  required double devicePixelRatio,
  required double boxFraction,
  double fill = 1.3,
}) {
  final safeFraction = boxFraction.clamp(0.01, 1.0);
  final needed = avatarSize * devicePixelRatio * fill / safeFraction;
  for (final bucket in _avatarEdgeBuckets) {
    if (bucket >= needed) return bucket;
  }
  return _avatarEdgeBuckets.last;
}

/// Keys [faceThumbProvider]. A record, so it is value-equal and the family
/// caches per asset *and* per requested edge.
typedef FaceThumbRequest = ({String assetId, int edge});

final faceThumbProvider = FutureProvider.autoDispose
    .family<FaceThumb?, FaceThumbRequest>((ref, req) async {
  final bytes = await ref.watch(
    thumbnailProvider(
      ThumbnailRequest(req.assetId, width: req.edge, height: req.edge),
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
    this.cover,
  });

  final int personId;
  final double size;

  /// Rounds the crop to a rectangle instead of a circle. Null — the default —
  /// keeps the circle the People grid and the person screen use; the People
  /// strip passes `AppRadius.br12` so a name can sit on a scrim inside the
  /// tile rather than on a caption line beneath it.
  final BorderRadius? borderRadius;

  /// The cover face, when a caller already resolved it (the People grid and
  /// strip fetch every visible person's cover in one batch via
  /// `personCoversProvider` so N avatars scrolling in don't fan out into N
  /// individual DB queries — see B2). Null falls back to watching
  /// [personCoverProvider] directly, one avatar at a time — the right default
  /// for a caller that only ever renders a single avatar.
  final CoverFace? cover;

  /// Over-zoom past just fitting the box so the face fills the circle. Tunable —
  /// raise to crop closer, lower to show more surround.
  static const _faceFill = 0.5;

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

    final cover = this.cover ?? ref.watch(personCoverProvider(personId)).value;
    if (cover == null) return placeholder();

    // The box is normalized, so its own extent is the fraction of the image the
    // face occupies — which is what decides how big a thumbnail this avatar
    // actually needs.
    final edge = avatarThumbEdge(
      avatarSize: size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      boxFraction: math.max(
        cover.right - cover.left,
        cover.bottom - cover.top,
      ),
      fill: _faceFill,
    );
    final thumb = ref
        .watch(faceThumbProvider((assetId: cover.assetId, edge: edge)))
        .value;
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
