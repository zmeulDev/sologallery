import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_space.dart';
import '../../widgets/asset_hero_tag.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/empty_state.dart';
import '../detail/photo_viewer_args.dart';
import 'albums_providers.dart';

/// The full grid of one album's photos (`/album/:id`), reached from an album
/// card. Tapping a cell opens the detail viewer swiping across this album.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(albumProvider(albumId));
    final entries = ref.watch(albumEntriesProvider(albumId));

    return Scaffold(
      appBar: AppBar(title: Text(album.value?.name ?? 'Album')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState.note('Couldn\'t load this album.'),
        data: (items) => items.isEmpty
            ? const EmptyState.note(
                'This album is empty.\nAdd photos from any photo\'s menu.')
            : _Grid(assetIds: [for (final e in items) e.assetId]),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.assetIds});

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
