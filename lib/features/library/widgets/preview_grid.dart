import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';
import '../../../services/permission_provider.dart';
import '../../../services/thumbnail_provider.dart';
import '../../../widgets/asset_thumbnail.dart';
import '../../detail/detail_providers.dart';
import '../../detail/photo_viewer_args.dart';

/// Up to six previews in a three-column grid. Tapping a cell opens the detail
/// viewer, swiping across this month's previews; the section header opens the
/// full month.
///
/// Implemented with [Wrap] rather than a nested `GridView.count` with
/// `shrinkWrap: true` to avoid the extra intrinsic layout pass a scrollable
/// inside a `ListView` item forces on every frame.
class PreviewGrid extends ConsumerWidget {
  const PreviewGrid({super.key, required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 2 * AppSpace.s4) / 3;
        final thumbSize = (cellWidth * MediaQuery.devicePixelRatioOf(context))
            .ceil();
        return Wrap(
          spacing: AppSpace.s4,
          runSpacing: AppSpace.s4,
          children: [
            for (final (index, id) in assetIds.indexed)
              SizedBox(
                width: cellWidth,
                height: cellWidth,
                child: GestureDetector(
                  onTap: () {
                    final thumb = ref.read(
                      thumbnailProvider(
                        ThumbnailRequest(id, width: thumbSize, height: thumbSize),
                      ),
                    );
                    // Start the high-res fetch before the route push so the
                    // detail page is more likely to hit the in-memory cache.
                    ref
                        .read(photoLibraryServiceProvider)
                        .previewImage(id, kDetailImageMaxEdge)
                        .ignore();
                    context.push(
                      '/photo/${Uri.encodeComponent(id)}',
                      extra: PhotoViewerArgs(
                        assetIds,
                        index,
                        initialBytes: thumb.value,
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: AppRadius.br12,
                    child: AssetThumbnail(
                      assetId: id,
                      size: thumbSize,
                      showVideoBadge: true,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
