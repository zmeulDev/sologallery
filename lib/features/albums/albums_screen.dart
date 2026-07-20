import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/theme/app_space.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state.dart';
import 'albums_providers.dart';
import 'widgets/album_card.dart';

/// Albums: user-created collections as a grid of cover cards. The "+" action
/// creates an album; a long-press on a card offers to delete it. Tapping a card
/// opens its full grid at `/album/:id`.
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumSummariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'New album',
            onPressed: () => _createAlbum(context, ref),
          ),
        ],
      ),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState(
          title: 'Couldn\'t load your albums',
          detail: 'Something went wrong. Come back in a moment.',
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                title: 'No albums yet',
                detail: 'Group photos your way. Tap + to make your first album.',
                action: AppButton.secondary(
                  label: 'New album',
                  icon: Icons.add_rounded,
                  onPressed: () => _createAlbum(context, ref),
                ),
              )
            : _AlbumsGrid(
                albums: list,
                onOpen: (a) => context.push('/album/${a.id}'),
                onDelete: (a) => _confirmDelete(context, ref, a),
              ),
      ),
    );
  }

  Future<void> _createAlbum(BuildContext context, WidgetRef ref) async {
    final name = await showAppTextInputDialog(
      context,
      title: 'New album',
      hint: 'Album name',
      confirmLabel: 'Create',
      maxLength: 200,
    );
    if (name == null) return;
    await ref.read(albumActionsProvider).create(name);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AlbumSummary album,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete "${album.name}"?',
      message: 'The album is removed. Your photos stay in your library.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await ref.read(albumActionsProvider).delete(album.id);
    }
  }
}

class _AlbumsGrid extends StatelessWidget {
  const _AlbumsGrid({
    required this.albums,
    required this.onOpen,
    required this.onDelete,
  });

  final List<AlbumSummary> albums;
  final void Function(AlbumSummary) onOpen;
  final void Function(AlbumSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s24,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpace.s20,
        crossAxisSpacing: AppSpace.s16,
        childAspectRatio: 0.82, // square cover + two label lines
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) => AlbumCard(
        summary: albums[i],
        onTap: () => onOpen(albums[i]),
        onLongPress: () => onDelete(albums[i]),
      ),
    );
  }
}
