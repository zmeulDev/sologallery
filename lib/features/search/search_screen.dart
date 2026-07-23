import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../core/format/count_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_grid.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/people_strip.dart';
import '../../widgets/section_header.dart';
import '../people/people_providers.dart';
import '../settings/consent_provider.dart';
import 'domain/search_date.dart';
import 'search_providers.dart';
import 'widgets/recently_viewed_row.dart';

/// Metadata + content search (`/search`, the second bottom-nav tab). Searches
/// the library by capture date ("June 2026", "2026"), media type, favorites,
/// album name, and — when content search is enabled — on-device ML labels.
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
  void initState() {
    super.initState();
    // Restore a query that outlived this State (a fresh branch build, or a chip
    // set while the tab was away) so the field matches what's being searched.
    _controller.text = ref.read(searchQueryProvider);
  }

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

  /// A browse chip commits its label immediately (no debounce) and mirrors it
  /// into the field so the two never diverge.
  void _search(String value) {
    _debounce?.cancel();
    _controller.text = value;
    ref.read(searchQueryProvider.notifier).set(value);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    // Keep the keyboard from lingering over another branch when the user
    // leaves Search; do not auto-focus on entry so the idle screen opens calm.
    ref.listen<bool>(searchTabActiveProvider, (_, active) {
      if (!active) _focusNode.unfocus();
    });

    final query = ref.watch(searchQueryProvider);
    final type = ref.watch(searchTypeProvider);
    final favoritesOnly = ref.watch(searchFavoritesOnlyProvider);
    final albums = ref.watch(searchAlbumsProvider);
    final people = ref.watch(searchPeopleProvider);

    final idle =
        query.trim().isEmpty && type == MediaTypeFilter.all && !favoritesOnly;

    // The field mirrors the query through its controller, so it doesn't
    // rebuild on every keystroke — only the hint depends on a provider,
    // and only on whether content search is enabled. Watch that one
    // provider in a Consumer scoped to the field so a keystroke (which
    // ticks searchQueryProvider) doesn't rebuild it.
    final searchField = Consumer(
      builder: (context, ref, _) => _SearchField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onClear: _clear,
        // The hint only promises content matching when the user has
        // actually enabled it — otherwise typing "dog" would silently
        // return nothing after the field invited it.
        hintText: ref.watch(searchEnabledProvider).value ?? false
            ? 'Photos, places, people, text…'
            : 'Dates, albums, media type…',
      ),
    );

    final filterBar = _FilterBar(type: type, favoritesOnly: favoritesOnly);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: idle
          ? _IdleBody(
              searchField: searchField,
              filterBar: filterBar,
              onBrowseLabel: _search,
            )
          : _ResultsBody(
              searchField: searchField,
              filterBar: filterBar,
              albums: albums,
              people: people,
            ),
    );
  }
}

/// The query field: a filled, rounded input sitting in the body just below the
/// app bar on every Search state. Owning a real title in the app bar costs no
/// body space and gives the screen the same header anatomy as Library, Saved
/// and Albums.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s4,
        AppSpace.s16,
        AppSpace.s12,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: false,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        style: styles.body.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          filled: true,
          // Elevated surface fill + hairline border makes the field read as a
          // real card against the page background, rather than disappearing
          // into it.
          fillColor: scheme.surface,
          border: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide(color: colors.textSecondary),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colors.textMuted,
          ),
          // Tracks the controller directly, so a chip that writes the field
          // reveals the clear button without the screen rebuilding for it.
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Clear',
                    color: colors.textMuted,
                    onPressed: onClear,
                  ),
          ),
          hintText: hintText,
          hintStyle: styles.body.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}

/// The facet row: media type (single-select) plus a favorites toggle. Visible
/// on both the idle and results states so the user knows these narrowing
/// controls exist before committing a query.
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

/// The results body: facets at the top, matching people, then the anchored
/// field + album chips + photo grid, with the recently-viewed carousel pinned at
/// the bottom.
class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.searchField,
    required this.filterBar,
    required this.albums,
    required this.people,
  });

  final Widget searchField;
  final Widget filterBar;
  final List<AlbumSummary> albums;
  final List<PersonSummary> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filterBar,
        if (people.isNotEmpty) PeopleStrip(people: people),
        searchField,
        if (albums.isNotEmpty) _AlbumsResult(albums: albums),
        Expanded(
          child: _Results(anyMatch: albums.isNotEmpty || people.isNotEmpty),
        ),
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: const _RecentlyViewedStrip(),
        ),
      ],
    );
  }
}

/// Photo results below albums and people. When only non-photo result types
/// matched, the grid area stays empty rather than redundantly claiming "No
/// matches."
class _Results extends ConsumerWidget {
  const _Results({required this.anyMatch});

  final bool anyMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(searchAssetsProvider);
    return assets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          const EmptyState.note('Couldn\'t run that search.'),
      data: (items) {
        if (items.isEmpty) {
          // Albums or people may still be the answer; only claim "no matches"
          // when nothing at all matched.
          return anyMatch
              ? const SizedBox.shrink()
              : const EmptyState.note('No matches.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SectionHeader(
                label: 'Photos',
                trailing: _ResultCount(
                  count: items.length,
                  hasMore: ref
                      .watch(searchAssetsProvider.notifier)
                      .hasMore,
                ),
              ),
            ),
            Expanded(
              child: AssetGrid(
                items: items,
                hasMore: ref.watch(searchAssetsProvider.notifier).hasMore,
                onLoadMore: () =>
                    ref.read(searchAssetsProvider.notifier).loadMore(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The trailing "N results" tally on the Photos header. A trailing `+` marks a
/// count still growing as more pages load, rather than claiming a total.
class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.count, required this.hasMore});

  final int count;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final n = '$count${hasMore ? '+' : ''}';
    return Text(
      count == 1 && !hasMore ? '1 result' : '$n results',
      style: styles.caption.copyWith(color: colors.textSecondary),
    );
  }
}

/// Matching albums as a short horizontal scroller of cover chips, so the
/// section is compact and never pushes the photo grid off screen.
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
          child: SectionHeader(label: 'Albums'),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
            itemBuilder: (context, index) => _AlbumTile(album: albums[index]),
          ),
        ),
      ],
    );
  }
}

/// One album in the horizontal results scroller: square cover, name, count.
class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    final cover = album.coverAssetId;

    return GestureDetector(
      onTap: () => context.push('/album/${album.id}'),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.br12,
              child: SizedBox(
                width: 84,
                height: 84,
                child: cover == null
                    ? ColoredBox(
                        color: colors.surface2,
                        child: Center(
                          child: Icon(
                            Icons.photo_album_outlined,
                            size: 28,
                            color: colors.textMuted,
                          ),
                        ),
                      )
                    : AssetThumbnail(assetId: cover, size: 256),
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.caption.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              photoCountLabel(album.entryCount, zero: 'Empty'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The idle state: facet pills at the top, then browse entry points (labels,
/// people), then the search field and subtitle, and the recency carousel at the
/// bottom. Device folders deliberately live on the Albums tab and not here:
/// they are a place you browse *collections*, not a way to narrow a query.
class _IdleBody extends ConsumerWidget {
  const _IdleBody({
    required this.searchField,
    required this.filterBar,
    required this.onBrowseLabel,
  });

  /// The shared search field, placed below the browse entry points.
  final Widget searchField;

  /// The shared facet bar, visible before a query is entered and placed at the
  /// top of the screen.
  final Widget filterBar;

  /// Commits a tapped label chip as the active query.
  final void Function(String) onBrowseLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(personSummariesProvider).value ?? const [];
    final searchOn = ref.watch(searchEnabledProvider).value ?? false;
    // Only what the library actually carries: with content search off there is
    // nothing to browse, and while the indexer is still working the list fills
    // in as labels land.
    final labels = searchOn
        ? ref.watch(topBrowseLabelsProvider).value ?? const <String>[]
        : const <String>[];

    return ListView(
      // Clears the floating nav capsule (reported as the bottom inset).
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      children: [
        filterBar,
        const _SearchSubtitle(),
        searchField,
        if (labels.isNotEmpty)
          _BrowseLabels(labels: labels, onTap: onBrowseLabel),
        if (people.isNotEmpty) PeopleStrip(people: people),
        const _RecentlyViewedStrip(),
        if (people.isEmpty && labels.isEmpty) const _IdleHint(),
      ],
    );
  }
}

/// Compact subtitle for the idle Search screen, replacing the previous large
/// page title so the search field can stay anchored at the top.
class _SearchSubtitle extends StatelessWidget {
  const _SearchSubtitle();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s4,
      ),
      child: Text(
        'Find photos, dates, albums, and more',
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

/// The recently viewed ribbon: watches the DAO stream and delegates to the
/// public [RecentlyViewedRow] widget. Loading/error states are silent.
class _RecentlyViewedStrip extends ConsumerWidget {
  const _RecentlyViewedStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedProvider(20));
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (ids) => RecentlyViewedRow(assetIds: ids),
    );
  }
}

/// A wrap of label chips that each run a content search for their text — the
/// tap-to-browse entry into ML labels. [labels] arrives ranked by how many
/// photos carry it (see `topBrowseLabelsProvider`), so the widest doors are
/// first; it is never empty, the caller drops the section instead.
class _BrowseLabels extends StatelessWidget {
  const _BrowseLabels({required this.labels, required this.onTap});

  final List<String> labels;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(label: 'On-device labels'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in labels)
                FilterPill(
                  label: label,
                  selected: false,
                  onTap: () => onTap(label),
                ),
            ],
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
