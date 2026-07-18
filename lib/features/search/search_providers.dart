import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../services/paged_assets_notifier.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart';
import '../albums/albums_providers.dart';
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

/// The photo results grid: the library scoped by the parsed date window, the
/// media-type facet, and (optionally) the favorites set, newest first.
///
/// Rebuilds whenever any facet changes (page resets to 0). When nothing is
/// being searched on — no date, "all" media, favorites off — it yields an empty
/// list so the screen shows its idle hint rather than the whole library.
class SearchAssetsNotifier extends PagedAssetsNotifier {
  MediaTypeFilter _type = MediaTypeFilter.all;
  bool _favoritesOnly = false;
  DateWindow? _window;

  /// When favorites-only is active, the bounded, already-filtered result set
  /// (favorites live in Drift, not a `photo_manager` path) — sliced per page.
  List<AssetRef>? _favoriteMatches;

  bool get _idle =>
      _window == null && _type == MediaTypeFilter.all && !_favoritesOnly;

  @override
  Future<List<AssetRef>> build() async {
    _type = ref.watch(searchTypeProvider);
    _favoritesOnly = ref.watch(searchFavoritesOnlyProvider);
    _window = parseDateQuery(ref.watch(searchQueryProvider));
    _favoriteMatches = null;

    if (_favoritesOnly) {
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
