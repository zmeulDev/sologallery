import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/index_dao.dart' show FavoriteAsset;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_grid.dart' show kPhotoGridCacheExtent;
import '../../widgets/asset_hero_tag.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/empty_state.dart';
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

class _SavedGrid extends StatelessWidget {
  const _SavedGrid({required this.favorites});

  final List<FavoriteAsset> favorites;

  @override
  Widget build(BuildContext context) {
    final assetIds = [for (final f in favorites) f.assetId];
    return CustomScrollView(
      scrollCacheExtent: kPhotoGridCacheExtent,
      slivers: [
        SliverPadding(
          // Clears the floating nav capsule (reported as the bottom inset).
          padding: EdgeInsets.all(AppSpace.s16).copyWith(
            bottom: AppSpace.s16 + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverGrid(
            gridDelegate: MasonryGridDelegate(
              items: [
                for (final f in favorites) (width: f.width, height: f.height),
              ],
              columns: SavedScreen._columns,
              gutter: AppSpace.s8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _SavedCell(assetIds: assetIds, index: i),
              childCount: favorites.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedCell extends StatelessWidget {
  const _SavedCell({required this.assetIds, required this.index});

  final List<String> assetIds;
  final int index;

  @override
  Widget build(BuildContext context) {
    final id = assetIds[index];
    return GestureDetector(
      onTap: () =>
          context.push('/photo/$id', extra: PhotoViewerArgs(assetIds, index)),
      child: ClipRRect(
        borderRadius: AppRadius.br12,
        child: Hero(
          tag: assetHeroTag(id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetThumbnail(assetId: id, size: 500, showVideoBadge: true),
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
