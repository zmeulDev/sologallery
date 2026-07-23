import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../features/detail/photo_viewer_args.dart';
import '../services/photo_library_service.dart';
import 'asset_thumbnail.dart';

/// How far beyond the viewport a photo scroller pre-builds its children.
///
/// Flutter's default is 250 logical px — under two rows of a three-column grid,
/// which a fling outruns immediately, so cells arrive as empty placeholders and
/// fill in behind the user. One screenful of lead time covers a normal flick,
/// and expressing it as a viewport multiple rather than a pixel count keeps it
/// honest on a tablet, where a fixed 800 would be barely half a screen.
///
/// This is only safe because thumbnail requests are bounded and cancellable
/// (`ThumbnailGate`): pre-building more cells means requesting more thumbnails,
/// so without the cap a larger extent would deepen exactly the queue of
/// scrolled-past decodes it is meant to hide. Raise the two together or not at
/// all.
const ScrollCacheExtent kPhotoGridCacheExtent = ScrollCacheExtent.viewport(1);

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
        scrollCacheExtent: kPhotoGridCacheExtent,
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
            child: ClipRRect(
              borderRadius: AppRadius.br12,
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
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(color: colors.surface2, child: const SizedBox.expand()),
    );
  }
}
