import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_space.dart';
import '../features/detail/photo_viewer_args.dart';
import '../services/photo_library_service.dart';
import 'asset_hero_tag.dart';
import 'asset_thumbnail.dart';

/// A paginating three-column grid of asset thumbnails, shared by the full-month
/// grid and the "Older" grid. Tapping a cell opens the detail viewer swiping
/// across [items]; scrolling near the end calls [onLoadMore]. When [hasMore] is
/// true, trailing placeholder cells stand in for the next, still-loading page.
class AssetGrid extends StatelessWidget {
  const AssetGrid({
    super.key,
    required this.items,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<AssetRef> items;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 800) {
          onLoadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpace.s2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.s2,
          crossAxisSpacing: AppSpace.s2,
        ),
        itemCount: items.length + (hasMore ? 3 : 0),
        itemBuilder: (context, i) {
          if (i >= items.length) return const _CellPlaceholder();
          return GestureDetector(
            onTap: () => context.push(
              '/photo/${items[i].id}',
              extra: PhotoViewerArgs([for (final a in items) a.id], i),
            ),
            child: Hero(
              tag: assetHeroTag(items[i].id),
              child: AssetThumbnail(
                assetId: items[i].id,
                size: 400,
                showVideoBadge: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CellPlaceholder extends StatelessWidget {
  const _CellPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return ColoredBox(color: colors.surface2, child: const SizedBox.expand());
  }
}
