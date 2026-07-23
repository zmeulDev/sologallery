import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/asset_grid.dart';
import '../../widgets/cover_row.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/filter_pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/people_strip.dart';
import '../people/people_providers.dart';
import 'widgets/recently_viewed_row.dart';
import '../settings/consent_provider.dart';
import 'domain/search_date.dart';
import 'search_providers.dart';

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

    return Scaffold(
      appBar: AppBar(),
      body: idle
          ? _IdleView(
              searchField: searchField,
              onBrowseLabel: _search,
            )
          : Column(
              children: [
                searchField,
                // Facets are an answer-narrowing tool, so they arrive with the
                // answers. On the idle screen they would be four controls
                // narrowing nothing, competing with the browse entry points that
                // are the actual invitation.
                _FilterBar(type: type, favoritesOnly: favoritesOnly),
                // "Still analyzing" is an app-wide condition, not a Search one —
                // the shell's `IndexingDial` says it once, beside the nav capsule.
                Expanded(
                  child: _Results(
                    albums: albums,
                    showNoMatch: albums.isEmpty,
                  ),
                ),
              ],
            ),
    );
  }
}

/// The query field: a filled, rounded input sitting in the body under the page
/// title, rather than standing in for the title itself. Owning a real title
/// costs one row of height and buys the screen the same header anatomy as
/// Library, Saved and Albums.
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
          fillColor: colors.surface2,
          border: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
            error: (e, st) =>
                const EmptyState.note('Couldn\'t run that search.'),
            data: (items) {
              if (items.isEmpty) {
                // Albums may still be the result; only claim "no matches" when
                // nothing matched at all.
                return showNoMatch
                    ? const EmptyState.note('No matches.')
                    : const SizedBox.shrink();
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
          ),
        ),
      ],
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
          child: SectionHeader(label: 'Albums'),
        ),
        for (final album in albums)
          CoverRow(
            coverAssetId: album.coverAssetId,
            name: album.name,
            count: album.entryCount,
            onTap: () => context.push('/album/${album.id}'),
          ),
      ],
    );
  }
}

/// The idle state: a recency ribbon and a lowered search field above the
/// existing browse entry points — People strip, label chips, and the privacy
/// note.
///
/// Device folders deliberately live on the Albums tab and not here: they are a
/// place you browse *collections*, not a way to narrow a query, and Albums is
/// already the screen that gathers every collection in one list.
class _IdleView extends ConsumerWidget {
  const _IdleView({
    required this.searchField,
    required this.onBrowseLabel,
  });

  /// The shared search field, placed lower on the idle screen than on the
  /// results screen.
  final Widget searchField;

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
        const _PageHeader(),
        const _RecentlyViewedStrip(),
        searchField,
        // Nothing to browse yet — a new library, an unfinished index, or every
        // analysis declined. The prompt explains what the field accepts
        // instead of leaving a blank screen under it.
        if (people.isEmpty && labels.isEmpty) const _IdleHint(),
        if (people.isNotEmpty) PeopleStrip(people: people),
        if (labels.isNotEmpty)
          _BrowseLabels(labels: labels, onTap: onBrowseLabel),
        const _PrivacyNote(),
      ],
    );
  }
}

/// Large page title and subtitle for the idle Search screen.
class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search',
            style: styles.pageTitle.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Find photos, dates, albums, and more',
            style: styles.body.copyWith(color: colors.textSecondary),
          ),
        ],
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
    final recent = ref.watch(recentlyViewedProvider(12));
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (ids) => RecentlyViewedRow(assetIds: ids),
    );
  }
}

/// States plainly that searching is local. It sits on the idle screen — the
/// moment the user is deciding what to hand over — because that is when the
/// claim is worth anything; buried in Settings it would only reassure someone
/// already looking for reassurance.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s20,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Text(
            'Search runs entirely on this device. Labels, text (OCR) and faces '
            'are indexed locally and never leave your phone.',
            style: styles.body.copyWith(color: colors.textSecondary),
          ),
        ),
      ),
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
