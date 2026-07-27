import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../features/detail/detail_providers.dart';
import '../features/detail/photo_viewer_args.dart';
import '../services/permission_provider.dart' show photoLibraryServiceProvider;
import '../services/photo_library_service.dart';
import '../services/thumbnail_provider.dart';
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

/// Requested pixel size of each grid cell's thumbnail. Shared between the tap
/// handler's cache-warming read and the [AssetThumbnail] below it — they must
/// match or the tap reads a different [ThumbnailRequest] than the one already
/// resolved for the cell, missing the in-memory cache it's meant to hit.
const int _kCellThumbnailSize = 400;

/// A paginating three-column grid of asset thumbnails, shared by the full-month
/// grid and the "Older" grid. Tapping a cell opens the detail viewer swiping
/// across [items]; scrolling near the end calls [onLoadMore]. When [hasMore] is
/// true, trailing placeholder cells stand in for the next, still-loading page.
class AssetGrid extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            onTap: () {
              final id = items[i].id;
              final thumb = ref.read(
                thumbnailProvider(
                  ThumbnailRequest(
                    id,
                    width: _kCellThumbnailSize,
                    height: _kCellThumbnailSize,
                  ),
                ),
              );
              // Warm the high-res image before the push so the detail page
              // hits the cache.
              ref
                  .read(photoLibraryServiceProvider)
                  .previewImage(id, kDetailImageMaxEdge)
                  .ignore();
              context.push(
                '/photo/${Uri.encodeComponent(id)}',
                extra: PhotoViewerArgs(
                  [for (final a in items) a.id],
                  i,
                  initialBytes: thumb.value,
                ),
              );
            },
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: AssetThumbnail(
                assetId: items[i].id,
                size: _kCellThumbnailSize,
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
