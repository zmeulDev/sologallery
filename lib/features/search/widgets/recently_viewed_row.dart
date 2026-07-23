import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';
import '../../../widgets/asset_thumbnail.dart';
import '../../../widgets/section_header.dart';
import '../../detail/photo_viewer_args.dart';

/// The Search screen's horizontal "recently viewed" ribbon.
///
/// Shows the newest [assetIds] as square r12 thumbnail chips; hides itself when
/// empty. Tapping a chip opens the detail viewer for that asset.
class RecentlyViewedRow extends StatelessWidget {
  const RecentlyViewedRow({
    super.key,
    required this.assetIds,
    this.cellSize = 72,
    this.limit = 12,
  });

  final List<String> assetIds;
  final double cellSize;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ids = assetIds.take(limit).toList();
    if (ids.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.s16,
            0,
            AppSpace.s16,
            AppSpace.s12,
          ),
          child: SectionHeader(label: 'Recently viewed'),
        ),
        SizedBox(
          height: cellSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s4),
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

class _RecentCell extends StatelessWidget {
  const _RecentCell({required this.assetId, required this.size});

  final String assetId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '/photo/${Uri.encodeComponent(assetId)}',
        extra: PhotoViewerArgs([assetId], 0),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.br12,
        child: SizedBox(
          width: size,
          height: size,
          child: AssetThumbnail(assetId: assetId),
        ),
      ),
    );
  }
}
