import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/index_dao.dart' show FavoriteAsset;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/permission_provider.dart' show photoLibraryServiceProvider;
import '../../services/thumbnail_provider.dart';
import '../../widgets/asset_grid.dart' show kPhotoGridCacheExtent;
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/empty_state.dart';
import '../detail/detail_providers.dart' show kDetailImageMaxEdge;
import '../detail/photo_viewer_args.dart';
import 'saved_providers.dart';
import 'widgets/masonry_grid_delegate.dart';

/// Saved: every favorited photo in one grid, newest-favorited first. Tapping a
/// cell opens the detail viewer swiping across the favorites sequence, so an
/// unfavorite there flows straight back into this grid.
///
/// Two wide columns that keep each photo's real aspect ratio, rather than the
/// square three-up used by Library and Search. Those grids are for *finding* a
/// photo among thousands, where a uniform scan pattern wins; this one is a
/// small, deliberately-kept set, so the photos get to be their own shape.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  /// Wide enough that a portrait photo still reads at a glance.
  static const int _columns = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(savedFavoritesProvider);
    // A count in the bar only when there's something to count — the empty state
    // already speaks for zero.
    final count = favorites.value?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        actions: [if (count > 0) _CountLabel(count: count)],
      ),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState(
          title: 'Couldn\'t load your favorites',
          detail: 'Something went wrong. Come back in a moment.',
        ),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'No favorites yet',
                detail:
                    'Tap the heart on a photo and it will be collected here.',
              )
            : _SavedGrid(favorites: rows),
      ),
    );
  }
}

/// The favorite tally, shown as a quiet trailing label in the app bar.
class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.s16),
      child: Center(
        child: Text(
          count == 1 ? '1 favorite' : '$count favorites',
          style: styles.caption.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _SavedGrid extends StatefulWidget {
  const _SavedGrid({required this.favorites});

  final List<FavoriteAsset> favorites;

  @override
  State<_SavedGrid> createState() => _SavedGridState();
}

class _SavedGridState extends State<_SavedGrid> {
  late List<String> _assetIds;
  late List<({int width, int height})> _items;
  late MasonryGridDelegate _delegate;

  @override
  void initState() {
    super.initState();
    _rebuildFromFavorites();
  }

  @override
  void didUpdateWidget(_SavedGrid old) {
    super.didUpdateWidget(old);
    if (_favoritesChanged(old.favorites, widget.favorites)) {
      _rebuildFromFavorites();
    }
  }

  void _rebuildFromFavorites() {
    _assetIds = [for (final f in widget.favorites) f.assetId];
    _items = [
      for (final f in widget.favorites) (width: f.width, height: f.height),
    ];
    _delegate = MasonryGridDelegate(
      items: _items,
      columns: SavedScreen._columns,
      gutter: AppSpace.s8,
    );
  }

  /// Cheap content comparison over the favorites (a deliberately-kept, small
  /// set) so `_delegate`'s identity — and the layout memo it holds — survives
  /// benign rebuilds that carry the same favorites, e.g. a parent repaint.
  bool _favoritesChanged(
    List<FavoriteAsset> oldFavorites,
    List<FavoriteAsset> newFavorites,
  ) {
    if (oldFavorites.length != newFavorites.length) return true;
    for (var i = 0; i < newFavorites.length; i++) {
      final oldFavorite = oldFavorites[i];
      final newFavorite = newFavorites[i];
      if (oldFavorite.assetId != newFavorite.assetId ||
          oldFavorite.width != newFavorite.width ||
          oldFavorite.height != newFavorite.height) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Shared target thumbnail pixel size for every cell this build, sized off
    // the actual on-screen column width (not a fixed guess) so a cell never
    // requests more pixels than it can show, and never blurs up from fewer.
    final width = MediaQuery.sizeOf(context).width - 2 * AppSpace.s16;
    final columnWidth = (width - AppSpace.s8) / SavedScreen._columns;
    final thumbSize =
        (columnWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
    return CustomScrollView(
      scrollCacheExtent: kPhotoGridCacheExtent,
      slivers: [
        SliverPadding(
          // Clears the floating nav capsule (reported as the bottom inset).
          padding: EdgeInsets.all(AppSpace.s16).copyWith(
            bottom: AppSpace.s16 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverGrid(
            gridDelegate: _delegate,
            delegate: SliverChildBuilderDelegate(
              (context, i) => _SavedCell(
                assetIds: _assetIds,
                index: i,
                thumbSize: thumbSize,
              ),
              childCount: widget.favorites.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedCell extends ConsumerWidget {
  const _SavedCell({
    required this.assetIds,
    required this.index,
    required this.thumbSize,
  });

  final List<String> assetIds;
  final int index;
  final int thumbSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = assetIds[index];
    return GestureDetector(
      onTap: () {
        final thumb = ref.read(
          thumbnailProvider(
            ThumbnailRequest(id, width: thumbSize, height: thumbSize),
          ),
        );
        // Warm the high-res image before the push so the detail page hits the
        // cache.
        ref
            .read(photoLibraryServiceProvider)
            .previewImage(id, kDetailImageMaxEdge)
            .ignore();
        context.push(
          '/photo/${Uri.encodeComponent(id)}',
          extra: PhotoViewerArgs(assetIds, index, initialBytes: thumb.value),
        );
      },
      child: ClipRRect(
        borderRadius: AppRadius.br12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AssetThumbnail(assetId: id, size: thumbSize, showVideoBadge: true),
            // A quiet heart marks the whole grid as favorites at a glance;
            // unfavoriting still flows through the detail viewer.
            const Positioned(
              top: AppSpace.s8,
              right: AppSpace.s8,
              child: _HeartBadge(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small translucent heart over a favorited thumbnail. Carries its own
/// contrast (scrim circle + white glyph) so it reads on any photo in either
/// theme, matching the over-media idiom used by the duration badge.
class _HeartBadge extends StatelessWidget {
  const _HeartBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppOverMedia.scrim,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Icon(
          Icons.favorite_rounded,
          size: 14,
          color: AppOverMedia.glyph,
        ),
      ),
    );
  }
}
