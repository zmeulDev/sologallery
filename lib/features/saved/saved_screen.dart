import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_space.dart';
import '../../widgets/asset_hero_tag.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/empty_state.dart';
import '../detail/photo_viewer_args.dart';
import 'saved_providers.dart';

/// Saved: every favorited photo in one grid, newest-favorited first. Tapping a
/// cell opens the detail viewer swiping across the favorites sequence, so an
/// unfavorite there flows straight back into this grid.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(savedFavoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState(
          title: 'Couldn\'t load your favorites',
          detail: 'Something went wrong. Come back in a moment.',
        ),
        data: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'No favorites yet',
                detail: 'Tap the heart on a photo and it will be collected here.',
              )
            : _SavedGrid(assetIds: [for (final f in rows) f.assetId]),
      ),
    );
  }
}

class _SavedGrid extends StatelessWidget {
  const _SavedGrid({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpace.s2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpace.s2,
        crossAxisSpacing: AppSpace.s2,
      ),
      itemCount: assetIds.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => context.push(
          '/photo/${assetIds[i]}',
          extra: PhotoViewerArgs(assetIds, i),
        ),
        child: Hero(
          tag: assetHeroTag(assetIds[i]),
          child: AssetThumbnail(
            assetId: assetIds[i],
            size: 400,
            showVideoBadge: true,
          ),
        ),
      ),
    );
  }
}
