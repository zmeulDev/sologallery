import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_grid.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/month_section_header.dart';
import '../library/month_grid_screen.dart' show CenteredNote;
import 'domain/search_date.dart';
import 'search_providers.dart';

/// Metadata search (`/search`, pushed from the Library app bar). Searches the
/// library by capture date ("June 2026", "2026"), media type, favorites, and
/// album name — the metadata available before ML indexing lands.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
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

    final query = ref.watch(searchQueryProvider);
    final type = ref.watch(searchTypeProvider);
    final favoritesOnly = ref.watch(searchFavoritesOnlyProvider);
    final albums = ref.watch(searchAlbumsProvider);

    final idle =
        query.trim().isEmpty && type == MediaTypeFilter.all && !favoritesOnly;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          style: styles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Search by date or album',
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
          Expanded(
            child: idle
                ? const _IdleHint()
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
        for (final album in albums) _AlbumRow(album: album),
      ],
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = album.coverAssetId;
    return InkWell(
      onTap: () => context.push('/album/${album.id}'),
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
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body.copyWith(color: scheme.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              album.entryCount == 1 ? '1 photo' : '${album.entryCount} photos',
              style: styles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The starting prompt, shown before any query or facet is set.
class _IdleHint extends StatelessWidget {
  const _IdleHint();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Search your library by date, album name, or media type.',
          textAlign: TextAlign.center,
          style: styles.body.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
