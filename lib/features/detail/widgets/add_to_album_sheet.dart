import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' show Album;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_sheet.dart';
import '../../../widgets/cover_row.dart';
import '../detail_providers.dart';

/// Opens the add-to-album picker for [assetId]. Resolves to the album name the
/// photo was added to (for a confirmation), or null if the sheet was dismissed.
Future<String?> showAddToAlbumSheet(BuildContext context, String assetId) {
  return showAppSheet<String>(
    context,
    isScrollControlled: true,
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
    final colors = Theme.of(context).extension<AppColors>()!;
    final albums = ref.watch(albumsListProvider);

    return AppSheet(
      label: 'ADD TO ALBUM',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreateRow(
            controller: _controller,
            enabled: !_busy,
            onSubmit: _createAndAdd,
          ),
          Divider(height: 1, color: colors.border),
          Flexible(
            child: albums.when(
              loading: () => const AppSheetNote('Loading albums…'),
              error: (_, _) => const AppSheetNote('Couldn\'t load albums.'),
              data: (list) => list.isEmpty
                  ? const AppSheetNote(
                      'No albums yet — type a name above to make one.')
                  : ListView.builder(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.s8),
                      itemCount: list.length,
                      itemBuilder: (context, i) => CoverRow(
                        coverAssetId: list[i].coverAssetId,
                        name: list[i].name,
                        fallbackIcon: Icons.photo_album_outlined,
                        onTap: _busy ? null : () => _addTo(list[i]),
                      ),
                    ),
            ),
          ),
        ],
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
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        AppSpace.s4,
        AppSpace.s12,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          Icon(Icons.add_rounded, color: colors.textSecondary, size: 22),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                isDense: true,
                // Opt out of the app-wide filled decoration — the row reads
                // as a plain inline field.
                filled: false,
                border: InputBorder.none,
                hintText: 'New album',
                hintStyle: TextStyle(color: colors.textMuted),
              ),
              style: styles.body.copyWith(color: scheme.onSurface),
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
