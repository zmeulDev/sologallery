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
import '../../services/indexing_service.dart';
import '../people/people_providers.dart';
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
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          _SearchField(
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
          // Facets are an answer-narrowing tool, so they arrive with the
          // answers. On the idle screen they would be four controls narrowing
          // nothing, competing with the browse entry points that are the
          // actual invitation.
          if (!idle) _FilterBar(type: type, favoritesOnly: favoritesOnly),
          if (ref.watch(indexingStatusProvider).value?.isIndexing ?? false)
            const _IndexingNote(),
          Expanded(
            child: idle
                ? _IdleView(onBrowseLabel: _search)
                : _Results(albums: albums, showNoMatch: albums.isEmpty),
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

/// The idle state: browse entry points — a People strip (when clusters exist),
/// then label chips (when content search is on) — closed by the note explaining
/// where all of this is computed.
///
/// Device folders deliberately live on the Albums tab and not here: they are a
/// place you browse *collections*, not a way to narrow a query, and Albums is
/// already the screen that gathers every collection in one list.
class _IdleView extends ConsumerWidget {
  const _IdleView({required this.onBrowseLabel});

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
      children: [
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
