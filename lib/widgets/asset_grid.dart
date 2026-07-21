import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
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
        // The bottom inset is the floating nav capsule inside a shell branch
        // (Search) and the system inset on the pushed month/album grids; the
        // last row has to clear whichever it is.
        padding: EdgeInsets.all(
          AppSpace.s4,
        ).copyWith(bottom: AppSpace.s4 + MediaQuery.paddingOf(context).bottom),

        // Cells clip to `br12` like every other thumbnail in the app, so the
        // gutter has to clear the corners — at `s2` adjacent radii nearly
        // touch and the grid reads as damaged rather than tiled.
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.s4,
          crossAxisSpacing: AppSpace.s4,
        ),
        itemCount: items.length + (hasMore ? 3 : 0),
        itemBuilder: (context, i) {
          if (i >= items.length) return const _CellPlaceholder();
          return GestureDetector(
            onTap: () => context.push(
              '/photo/${items[i].id}',
              extra: PhotoViewerArgs([for (final a in items) a.id], i),
            ),
            // The clip sits outside the Hero: inside it, the photo would round
            // itself mid-flight while the detail viewer's destination is
            // full-bleed.
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: Hero(
                tag: assetHeroTag(items[i].id),
                child: AssetThumbnail(
                  assetId: items[i].id,
                  size: 400,
                  showVideoBadge: true,
                ),
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
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(color: colors.surface2, child: const SizedBox.expand()),
    );
  }
}
