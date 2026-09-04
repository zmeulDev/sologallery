import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_library_service.dart';

/// Shared pagination base for asset-id grids (Library's full-month grid now;
/// the Saved grid in a later phase). Subclasses supply [fetchPage]; this base
/// loads the first page in [build] and appends further pages via [loadMore]
/// without flipping the screen back to a loading state.
///
/// State is the accumulated list of [AssetRef]s, newest first.
abstract class PagedAssetsNotifier extends AsyncNotifier<List<AssetRef>> {
  /// Assets fetched per page.
  int get pageSize => 90;

  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  /// Whether another page may be available.
  bool get hasMore => _hasMore;

  /// Fetches page [page] (0-based) of [pageSize] assets. Return fewer than
  /// [pageSize] to signal the end.
  Future<List<AssetRef>> fetchPage(int page, int pageSize);

  @override
  Future<List<AssetRef>> build() async {
    _page = 0;
    _hasMore = true;
    _loadingMore = false;
    final first = await fetchPage(0, pageSize);
    _hasMore = first.length == pageSize;
    return first;
  }

  /// Appends the next page. No-op while a load is in flight or once exhausted.
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final next = await fetchPage(_page + 1, pageSize);
      // The grid is autoDispose and `loadMore` is fired from a scroll callback,
      // so the screen can be gone by the time the page resolves. Bail rather
      // than write `state` on a disposed notifier (an UnmountedRefException).
      // WatchedAssetsNotifier gets this for free via its `ref.onDispose` cancel.
      if (!ref.mounted) return;
      _page += 1;
      _hasMore = next.length == pageSize;
      state = AsyncData([...(state.value ?? const []), ...next]);
    } finally {
      _loadingMore = false;
    }
  }
}
