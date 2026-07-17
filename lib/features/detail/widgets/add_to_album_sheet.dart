import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' show Album;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../detail_providers.dart';

/// Opens the add-to-album picker for [assetId]. Resolves to the album name the
/// photo was added to (for a confirmation), or null if the sheet was dismissed.
Future<String?> showAddToAlbumSheet(BuildContext context, String assetId) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToAlbumSheet(assetId: assetId),
  );
}

/// Lists existing albums to add [assetId] to, with an inline "new album" field.
/// Tapping an album (or creating one) adds the photo and pops with its name.
class AddToAlbumSheet extends ConsumerStatefulWidget {
  const AddToAlbumSheet({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<AddToAlbumSheet> createState() => _AddToAlbumSheetState();
}

class _AddToAlbumSheetState extends ConsumerState<AddToAlbumSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addTo(Album album) async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(detailActionsProvider).addToAlbum(album.id, widget.assetId);
    if (mounted) Navigator.of(context).pop(album.name);
  }

  Future<void> _createAndAdd() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final actions = ref.read(detailActionsProvider);
    final id = await actions.createAlbum(name);
    await actions.addToAlbum(id, widget.assetId);
    if (mounted) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final albums = ref.watch(albumsListProvider);

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        // Lift above the keyboard when the create field is focused.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  'ADD TO ALBUM',
                  style: text.sectionLabel.copyWith(color: colors.textSecondary),
                ),
              ),
              _CreateRow(
                controller: _controller,
                enabled: !_busy,
                onSubmit: _createAndAdd,
              ),
              Divider(height: 1, color: colors.border),
              Flexible(
                child: albums.when(
                  loading: () => const _ListNote('Loading albums…'),
                  error: (_, _) => const _ListNote('Couldn\'t load albums.'),
                  data: (list) => list.isEmpty
                      ? const _ListNote(
                          'No albums yet — type a name above to make one.')
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: list.length,
                          itemBuilder: (context, i) => _AlbumTile(
                            album: list[i],
                            onTap: _busy ? null : () => _addTo(list[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(
        children: [
          Icon(Icons.add, color: colors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'New album',
                hintStyle: TextStyle(color: colors.textMuted),
              ),
              style: TextStyle(color: scheme.onSurface, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: enabled ? onSubmit : null,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album, required this.onTap});

  final Album album;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.photo_album_outlined, color: colors.textSecondary),
      title: Text(
        album.name,
        style: TextStyle(color: scheme.onSurface, fontSize: 14),
      ),
    );
  }
}

class _ListNote extends StatelessWidget {
  const _ListNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Text(
        text,
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
