import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/thumbnail_provider.dart';
import '../people_providers.dart';

/// Circular avatar for a person: the representative face cropped out of the
/// cached 512px indexing thumbnail (the same size the box was measured against).
/// Falls back to a recessed placeholder circle while loading or if no face.
class FaceAvatar extends ConsumerWidget {
  const FaceAvatar({super.key, required this.personId, this.size = 64});

  final int personId;
  final double size;

  /// The indexing thumbnail edge the stored box coordinates are relative to.
  static const _thumbEdge = 512.0;

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

    final boxW = (cover.right - cover.left).toDouble().clamp(1.0, _thumbEdge);
    final boxH = (cover.bottom - cover.top).toDouble().clamp(1.0, _thumbEdge);
    // Zoom the face box to fill the avatar; center it in the circle.
    final scale = size / (boxW > boxH ? boxW : boxH);
    final scaled = _thumbEdge * scale;
    final cx = (cover.left + cover.right) / 2 * scale;
    final cy = (cover.top + cover.bottom) / 2 * scale;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: size / 2 - cx,
              top: size / 2 - cy,
              width: scaled,
              height: scaled,
              child: Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
            ),
          ],
        ),
      ),
    );
  }
}
