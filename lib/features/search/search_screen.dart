import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_grid.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../services/indexing_service.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/month_section_header.dart';
import '../folders/folders_providers.dart';
import '../library/month_grid_screen.dart' show CenteredNote;
import '../people/people_providers.dart';
import '../settings/consent_provider.dart';
import '../people/widgets/face_avatar.dart';
import 'domain/search_date.dart';
import 'search_providers.dart';

/// Metadata search (`/search`, the second bottom-nav tab). Searches the
/// library by capture date ("June 2026", "2026"), media type, favorites, and
/// album name — the metadata available before ML indexing lands.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Debounces text edits so the date parse / album match only run once typing
  /// settles.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(searchQueryProvider.notifier).set(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;

    // Focus follows the tab: typing starts as soon as Search is selected, and
    // the keyboard leaves with the tab rather than lingering over the branch
    // the user switched to.
    ref.listen<bool>(searchTabActiveProvider, (_, active) {
      if (active) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
      }
    });

    final query = ref.watch(searchQueryProvider);
    final type = ref.watch(searchTypeProvider);
    final favoritesOnly = ref.watch(searchFavoritesOnlyProvider);
    final albums = ref.watch(searchAlbumsProvider);

    final idle =
        query.trim().isEmpty && type == MediaTypeFilter.all && !favoritesOnly;

    return Scaffold(
      appBar: AppBar(
        // The field spans the full title area so taps anywhere in the bar focus
        // it, while its *text* is inset to 16 — the same left edge as the filter
        // pills and results below. Leaving both at 0 hung the query and hint 16
        // px left of every other element on the screen.
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          style: styles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            // The hint only promises content matching when the user has
            // actually enabled it — otherwise typing "dog" would silently
            // return nothing after the field invited it.
            hintText: ref.watch(searchEnabledProvider).value ?? false
                ? 'Search photos, text, dates, albums'
                : 'Search by date or album',
            hintStyle: styles.body.copyWith(color: colors.textMuted),
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () => setState(_clear),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(type: type, favoritesOnly: favoritesOnly),
          if (ref.watch(indexingStatusProvider).value?.isIndexing ?? false)
            const _IndexingNote(),
          Expanded(
            child: idle
                ? const _IdleView()
                : _Results(albums: albums, showNoMatch: albums.isEmpty),
          ),
        ],
      ),
    );
  }
}

/// The facet row: media type (single-select) plus a favorites toggle.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.type, required this.favoritesOnly});

  final MediaTypeFilter type;
  final bool favoritesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setType(MediaTypeFilter t) =>
        ref.read(searchTypeProvider.notifier).set(t);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          FilterPill(
            label: 'All',
            selected: type == MediaTypeFilter.all,
            onTap: () => setType(MediaTypeFilter.all),
          ),
          const SizedBox(width: 8),
          FilterPill(
            label: 'Photos',
            selected: type == MediaTypeFilter.photos,
            onTap: () => setType(MediaTypeFilter.photos),
          ),
          const SizedBox(width: 8),
          FilterPill(
            label: 'Videos',
            selected: type == MediaTypeFilter.videos,
            onTap: () => setType(MediaTypeFilter.videos),
          ),
          const SizedBox(width: 16),
          FilterPill(
            label: 'Favorites',
            selected: favoritesOnly,
            onTap: () =>
                ref.read(searchFavoritesOnlyProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

/// Results below the facet bar: matching albums (compact rows) above the photo
/// grid. [showNoMatch] is true when there are no album matches, so an empty
/// photo result can fall back to a "No matches" note.
class _Results extends ConsumerWidget {
  const _Results({required this.albums, required this.showNoMatch});

  final List<AlbumSummary> albums;
  final bool showNoMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(searchAssetsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (albums.isNotEmpty) _AlbumsResult(albums: albums),
        Expanded(
          child: assets.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const CenteredNote('Couldn\'t run that search.'),
            data: (items) {
              if (items.isEmpty) {
                // Albums may still be the result; only claim "no matches" when
                // nothing matched at all.
                return showNoMatch
                    ? const CenteredNote('No matches.')
                    : const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: MonthSectionHeader(label: 'Photos'),
                  ),
                  Expanded(
                    child: AssetGrid(
                      items: items,
                      hasMore:
                          ref.watch(searchAssetsProvider.notifier).hasMore,
                      onLoadMore: () =>
                          ref.read(searchAssetsProvider.notifier).loadMore(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Matching albums as a short list of compact rows (cover · name · count).
class _AlbumsResult extends StatelessWidget {
  const _AlbumsResult({required this.albums});

  final List<AlbumSummary> albums;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: MonthSectionHeader(label: 'Albums'),
        ),
        for (final album in albums)
          _CoverRow(
            coverAssetId: album.coverAssetId,
            name: album.name,
            count: album.entryCount,
            onTap: () => context.push('/album/${album.id}'),
          ),
      ],
    );
  }
}

/// A compact collection row — cover · name · photo count — shared by the album
/// results and the idle Folders section so both read as one list idiom.
class _CoverRow extends StatelessWidget {
  const _CoverRow({
    required this.coverAssetId,
    required this.name,
    required this.count,
    required this.onTap,
  });

  /// Null renders a flat placeholder tile (an empty album, or a folder whose
  /// cover couldn't be resolved).
  final String? coverAssetId;
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = coverAssetId;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 44,
                child: cover == null
                    ? ColoredBox(color: colors.surface2)
                    : AssetThumbnail(assetId: cover, size: 120),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body.copyWith(color: scheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count == 1 ? '1 photo' : '$count photos',
              style: styles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet line shown while the background indexer is still labeling photos —
/// content-search results improve as it progresses.
class _IndexingNote extends StatelessWidget {
  const _IndexingNote();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'Still indexing your library — results will keep improving.',
        style: styles.caption.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

/// The idle state: browse entry points — a People strip (when clusters exist)
/// above the device's folders. Scrolls, since the folder list is unbounded.
/// Falls back to the search prompt when there's nothing to browse yet (no face
/// clusters, and folders still loading or genuinely absent).
class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(personSummariesProvider).value ?? const [];
    final folders = ref.watch(deviceFoldersProvider).value ?? const [];

    if (people.isEmpty && folders.isEmpty) return const _IdleHint();

    return ListView(
      children: [
        if (people.isNotEmpty) _PeopleStrip(people: people),
        if (folders.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: MonthSectionHeader(label: 'Folders'),
          ),
          for (final folder in folders)
            _CoverRow(
              coverAssetId: folder.coverAssetId,
              name: folder.name,
              count: folder.count,
              onTap: () => context.push(
                Uri(
                  path: '/folder',
                  queryParameters: {'id': folder.id, 'name': folder.name},
                ).toString(),
              ),
            ),
        ],
      ],
    );
  }
}

/// A horizontal row of person avatars linking into the People screens.
class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({required this.people});

  final List<PersonSummary> people;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonthSectionHeader(
            label: 'People',
            trailing: TextButton(
              onPressed: () => context.push('/people'),
              child: const Text('See all'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            // Height must equal the avatar diameter: a horizontal ListView gives
            // children a *tight* cross-axis (height) constraint, so a taller
            // strip would stretch the avatar into an oval.
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => context.push('/person/${people[i].id}'),
                child: FaceAvatar(personId: people[i].id, size: 72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The starting prompt, shown before any query or facet is set.
class _IdleHint extends ConsumerWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final searchOn = ref.watch(searchEnabledProvider).value ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          searchOn
              ? 'Search your library by what is in a photo, text it contains, '
                  'date, album name, or media type.'
              : 'Search your library by date, album name, or media type. '
                  'Turn on content search in Settings to search by what is in '
                  'a photo.',
          textAlign: TextAlign.center,
          style: styles.body.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
