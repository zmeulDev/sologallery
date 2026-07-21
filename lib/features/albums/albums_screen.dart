import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/photo_library_service.dart' show DeviceFolder;
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/folder_list.dart';
import '../../widgets/section_header.dart';
import '../../widgets/people_strip.dart';
import '../folders/folders_providers.dart';
import '../people/people_providers.dart';
import '../settings/consent_provider.dart';
import 'albums_providers.dart';
import 'widgets/album_card.dart';

/// Albums: user-created collections as a grid of cover cards, with the device's
/// People and Folders below them so the tab is the one place to browse
/// collections. The "+" action creates an album; a long-press on a card offers
/// to delete it. Tapping a card opens its full grid at `/album/:id`.
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumSummariesProvider);
    final facesOn = ref.watch(facesEnabledProvider).value ?? false;
    final people = facesOn
        ? ref.watch(personSummariesProvider).value ?? const <PersonSummary>[]
        : const <PersonSummary>[];
    final folders =
        ref.watch(deviceFoldersProvider).value ?? const <DeviceFolder>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.s16),
            child: Center(
              child: AppButton.primary(
                label: 'New',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: () => _createAlbum(context, ref),
              ),
            ),
          ),
        ],
      ),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const EmptyState(
          title: 'Couldn\'t load your albums',
          detail: 'Something went wrong. Come back in a moment.',
        ),
        data: (list) {
          // Only when there is nothing to show anywhere does the full-screen
          // empty state take over; otherwise the People/Folders sections carry
          // the screen and a compact note stands in for the missing grid.
          if (list.isEmpty && people.isEmpty && folders.isEmpty) {
            return EmptyState(
              title: 'No albums yet',
              detail: 'Group photos your way. Tap + to make your first album.',
              action: AppButton.secondary(
                label: 'New album',
                icon: Icons.add_rounded,
                onPressed: () => _createAlbum(context, ref),
              ),
            );
          }
          return _Sections(
            albums: list,
            people: people,
            folders: folders,
            onOpen: (a) => context.push('/album/${a.id}'),
            onDelete: (a) => _confirmDelete(context, ref, a),
          );
        },
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

/// The scrolling body: Albums grid (or its stand-in note), then People, then
/// Folders — each led by a section header, scrolling as one.
class _Sections extends StatelessWidget {
  const _Sections({
    required this.albums,
    required this.people,
    required this.folders,
    required this.onOpen,
    required this.onDelete,
  });

  final List<AlbumSummary> albums;
  final List<PersonSummary> people;
  final List<DeviceFolder> folders;
  final void Function(AlbumSummary) onOpen;
  final void Function(AlbumSummary) onDelete;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s12,
            AppSpace.s16,
            AppSpace.s8,
          ),
          sliver: SliverToBoxAdapter(child: SectionHeader(label: 'Albums')),
        ),
        if (albums.isEmpty)
          const SliverToBoxAdapter(child: _NoAlbumsNote())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              0,
              AppSpace.s16,
              AppSpace.s24,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.s20,
                crossAxisSpacing: AppSpace.s16,
                childAspectRatio: 0.82, // square cover + two label lines
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => AlbumCard(
                  summary: albums[i],
                  onTap: () => onOpen(albums[i]),
                  onLongPress: () => onDelete(albums[i]),
                ),
                childCount: albums.length,
              ),
            ),
          ),
        if (people.isNotEmpty)
          SliverToBoxAdapter(child: PeopleStrip(people: people)),
        if (folders.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s12,
              AppSpace.s16,
              AppSpace.s8,
            ),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(label: 'Device folders'),
            ),
          ),
          SliverToBoxAdapter(child: FolderList(folders: folders)),
        ],
        // The nav capsule floats over the body, so the Scaffold reports its
        // height as the bottom inset — the last folder row has to clear it.
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpace.s16 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

/// The compact stand-in shown in the Albums section when there are no albums but
/// People or Folders still carry the screen — quieter than the full-screen
/// empty state.
class _NoAlbumsNote extends StatelessWidget {
  const _NoAlbumsNote();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s4,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Text(
        'No albums yet — tap + to make one.',
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
