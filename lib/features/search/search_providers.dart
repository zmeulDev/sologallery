import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/database/database_provider.dart';
import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../services/paged_assets_notifier.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../albums/albums_providers.dart';
import '../memories/domain/memory_builder.dart';
import '../people/people_providers.dart';
import '../saved/saved_providers.dart';
import 'domain/search_date.dart';

/// The raw search text. Written (debounced) by the search field via [set]; the
/// date parse and album-name match derive from it. A [Notifier] (not the legacy
/// `StateProvider`) to match the project's Riverpod conventions.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Whether the Search tab is the selected bottom-nav branch. Written by
/// `AppShell`, read by [SearchScreen] to take and release focus on the query
/// field — `StatefulShellRoute.indexedStack` builds every branch eagerly, so
/// an `autofocus` field would grab focus at boot on the Library tab. Kept
/// alive (no `autoDispose`) because it is shell-lifetime state.
class SearchTabActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final searchTabActiveProvider =
    NotifierProvider<SearchTabActiveNotifier, bool>(
  SearchTabActiveNotifier.new,
);

/// The media-type facet (default: everything).
class SearchTypeNotifier extends Notifier<MediaTypeFilter> {
  @override
  MediaTypeFilter build() => MediaTypeFilter.all;

  void set(MediaTypeFilter value) => state = value;
}

final searchTypeProvider =
    NotifierProvider.autoDispose<SearchTypeNotifier, MediaTypeFilter>(
  SearchTypeNotifier.new,
);

/// The favorites-only facet.
class SearchFavoritesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final searchFavoritesOnlyProvider =
    NotifierProvider.autoDispose<SearchFavoritesNotifier, bool>(
  SearchFavoritesNotifier.new,
);

/// Albums whose name contains the query (case-insensitive). Empty while the
/// query is blank or the album stream is still loading — albums are few, so the
/// existing [albumSummariesProvider] is filtered client-side rather than adding
/// a dedicated query.
final searchAlbumsProvider = Provider.autoDispose<List<AlbumSummary>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final all = ref.watch(albumSummariesProvider).value ?? const [];
  return [
    for (final a in all)
      if (a.name.toLowerCase().contains(query)) a,
  ];
});

/// People whose display name contains the query (case-insensitive). Empty while
/// the query is blank, face detection is disabled, or the people stream is still
/// loading. Unnamed clusters are never returned here because there is nothing to
/// match against a text query.
final searchPeopleProvider = Provider.autoDispose<List<PersonSummary>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final all = ref.watch(personSummariesProvider).value ?? const [];
  return [
    for (final p in all)
      if (p.displayName?.toLowerCase().contains(query) ?? false) p,
  ];
});

/// How many browse-label chips the idle screen offers. Ten is what fits as a
/// scannable block above the privacy note without turning into a tag cloud.
const browseLabelCount = 10;

/// The most recently viewed photos, newest first, for the idle Search screen.
/// A small bounded shortcut rather than a full history log.
final recentlyViewedProvider =
    StreamProvider.autoDispose.family<List<String>, int>((ref, limit) {
  return ref.watch(indexDaoProvider).watchRecentlyViewed(limit: limit);
});

/// The browse chips on the idle screen: the [browseLabelCount] labels this
/// library actually carries most often, most photos first.
///
/// Candidates are [MemoryBuilder.presentableLabels] — ML Kit's raw label set is
/// too coarse to browse ("Person", "Room", "Event"), and keeping the one
/// allowlist means "browsable" and "presentable as a memory" can't drift apart.
/// Empty while nothing is labeled yet (fresh library, indexer still running, or
/// content search declined), which hides the section rather than offering chips
/// that match no photo.
final topBrowseLabelsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  return ref
      .watch(indexDaoProvider)
      .watchTopLabels(
        allow: MemoryBuilder.presentableLabels,
        limit: browseLabelCount,
      )
      .map((rows) => [for (final r in rows) r.label]);
});

/// The photo results grid, newest first. Two sources depending on the query:
///
/// - **Content search** — non-empty text that isn't a date → matches on-device
///   ML labels (`IndexDao.searchByLabel`), refined by the media-type and
///   favorites facets in SQL. This is what makes "dog"/"beach" return photos.
/// - **Metadata search** — a date query (windowed) and/or the media-type /
///   favorites facets with no text → the `photo_manager` path from the previous
///   slice.
///
/// Rebuilds whenever any facet changes (page resets to 0). Idle — empty text,
/// "all" media, favorites off — yields an empty list so the screen shows its
/// idle hint rather than the whole library.
class SearchAssetsNotifier extends PagedAssetsNotifier {
  MediaTypeFilter _type = MediaTypeFilter.all;
  bool _favoritesOnly = false;
  String _query = '';
  DateWindow? _window;

  /// True when the query is free text (not a date) — routed to label search.
  bool _contentSearch = false;

  /// When favorites-only is active on the metadata path, the bounded,
  /// already-filtered result set (favorites live in Drift, not a `photo_manager`
  /// path) — sliced per page.
  List<AssetRef>? _favoriteMatches;

  bool get _idle =>
      _query.isEmpty && _type == MediaTypeFilter.all && !_favoritesOnly;

  @override
  Future<List<AssetRef>> build() async {
    _type = ref.watch(searchTypeProvider);
    _favoritesOnly = ref.watch(searchFavoritesOnlyProvider);
    _query = ref.watch(searchQueryProvider).trim();
    _window = parseDateQuery(_query);
    _contentSearch = _query.isNotEmpty && _window == null;
    _favoriteMatches = null;

    // The favorites metadata path resolves the bounded set up front; content
    // search filters favorites in SQL instead, so it skips this.
    if (_favoritesOnly && !_contentSearch) {
      final favorites = await ref.watch(savedFavoritesProvider.future);
      _favoriteMatches =
          await ref.read(photoLibraryServiceProvider).resolveFavoriteMatches(
                ids: [for (final f in favorites) f.assetId],
                min: _window?.start,
                max: _window?.endExclusive,
                type: _type,
              );
    }

    return super.build();
  }

  @override
  Future<List<AssetRef>> fetchPage(int page, int pageSize) {
    if (_idle) return Future.value(const []);

    if (_contentSearch) {
      return ref.read(indexDaoProvider).searchContent(
            query: _query,
            type: _type,
            favoritesOnly: _favoritesOnly,
            limit: pageSize,
            offset: page * pageSize,
          );
    }

    if (_favoritesOnly) {
      final all = _favoriteMatches ?? const [];
      final start = page * pageSize;
      if (start >= all.length) return Future.value(const []);
      final end = start + pageSize > all.length ? all.length : start + pageSize;
      return Future.value(all.sublist(start, end));
    }

    return ref.read(photoLibraryServiceProvider).searchAssets(
          min: _window?.start,
          max: _window?.endExclusive,
          type: _type,
          page: page,
          pageSize: pageSize,
        );
  }
}

final searchAssetsProvider =
    AsyncNotifierProvider.autoDispose<SearchAssetsNotifier, List<AssetRef>>(
  SearchAssetsNotifier.new,
);
