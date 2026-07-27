import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';
import '../../../services/permission_provider.dart'
    show photoLibraryServiceProvider;
import '../../../services/thumbnail_provider.dart';
import '../../../widgets/asset_thumbnail.dart';
import '../../../widgets/section_header.dart';
import '../../detail/detail_providers.dart' show kDetailImageMaxEdge;
import '../../detail/photo_viewer_args.dart';

/// The Search screen's horizontal "recently viewed" carousel.
///
/// Shows the newest [assetIds] as square r12 thumbnail chips in a two-row
/// horizontal grid; hides itself when empty. Tapping a chip opens the detail
/// viewer for that asset.
class RecentlyViewedRow extends StatelessWidget {
  const RecentlyViewedRow({
    super.key,
    required this.assetIds,
    this.cellSize = 104,
    this.limit = 20,
  });

  final List<String> assetIds;
  final double cellSize;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ids = assetIds.take(limit).toList();
    if (ids.isEmpty) return const SizedBox.shrink();

    final gutter = AppSpace.s4;
    final viewportHeight = cellSize * 2 + gutter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            0,
            AppSpace.s16,
            AppSpace.s12,
          ),
          child: SectionHeader(label: 'Recently viewed'),
        ),
        SizedBox(
          height: viewportHeight,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: gutter,
              crossAxisSpacing: gutter,
              childAspectRatio: 1,
            ),
            itemCount: ids.length,
            itemBuilder: (context, index) => _RecentCell(
              assetId: ids[index],
              size: cellSize,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s20),
      ],
    );
  }
}

class _RecentCell extends ConsumerWidget {
  const _RecentCell({required this.assetId, required this.size});

  final String assetId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Shared target thumbnail pixel size for the tap handler's cache-warming
    // read and the AssetThumbnail below it — they must match or the tap reads
    // a different ThumbnailRequest than the one already resolved for the
    // cell, missing the in-memory cache it's meant to hit.
    final thumbSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return GestureDetector(
      onTap: () {
        final thumb = ref.read(
          thumbnailProvider(
            ThumbnailRequest(assetId, width: thumbSize, height: thumbSize),
          ),
        );
        // Warm the high-res image before the push so the detail page hits the
        // cache.
        ref
            .read(photoLibraryServiceProvider)
            .previewImage(assetId, kDetailImageMaxEdge)
            .ignore();
        context.push(
          '/photo/${Uri.encodeComponent(assetId)}',
          extra: PhotoViewerArgs([assetId], 0, initialBytes: thumb.value),
        );
      },
      child: ClipRRect(
        borderRadius: AppRadius.br12,
        child: SizedBox(
          width: size,
          height: size,
          child: AssetThumbnail(assetId: assetId, size: thumbSize),
        ),
      ),
    );
  }
}
