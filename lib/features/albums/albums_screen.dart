import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
            icon: const Icon(Icons.add),
            tooltip: 'New album',
            onPressed: () => _createAlbum(context, ref),
          ),
        ],
      ),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const _AlbumsMessage(
          title: 'Couldn\'t load your albums',
          detail: 'Something went wrong. Come back in a moment.',
        ),
        data: (list) => list.isEmpty
            ? _AlbumsMessage(
                title: 'No albums yet',
                detail: 'Group photos your way. Tap + to make your first album.',
                action: _NewAlbumButton(onTap: () => _createAlbum(context, ref)),
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
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateAlbumDialog(),
    );
    if (name == null) return;
    await ref.read(albumActionsProvider).create(name);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AlbumSummary album,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${album.name}"?'),
        content: const Text(
          'The album is removed. Your photos stay in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 16,
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

/// Inline "new album" name entry. Pops the trimmed name, or null if cancelled or
/// blank.
class _CreateAlbumDialog extends StatefulWidget {
  const _CreateAlbumDialog();

  @override
  State<_CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends State<_CreateAlbumDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New album'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLength: 200,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Album name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _NewAlbumButton extends StatelessWidget {
  const _NewAlbumButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('New album'),
      ),
    );
  }
}

/// Centered title + supporting line for the empty and error states, optionally
/// with a call-to-action beneath. Mirrors the Library message treatment.
class _AlbumsMessage extends StatelessWidget {
  const _AlbumsMessage({
    required this.title,
    required this.detail,
    this.action,
  });

  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.body.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.textSecondary),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
