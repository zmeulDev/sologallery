import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_library_service.dart';

/// Reactive pagination base for cache-backed asset-id grids (Library's
/// full-month grid and the "Older" grid). Unlike [PagedAssetsNotifier] — the
/// one-shot paginator still used by Search — this watches a single growing
/// window (`LIMIT _limit OFFSET 0`) so the grid re-emits live as the metadata
/// sweep, ML backfill, or a deletion changes the cache.
///
/// Subclasses supply [watchWindow]; [loadMore] grows the window by [pageSize]
/// and re-subscribes. State is the accumulated list of [AssetRef]s, newest
/// first.
abstract class WatchedAssetsNotifier extends AsyncNotifier<List<AssetRef>> {
  /// Assets added to the window per page.
  int get pageSize => 90;

  int _limit = 0;
  bool _hasMore = true;
  StreamSubscription<List<AssetRef>>? _sub;

  /// Whether another page may be available (the last window came back full).
  bool get hasMore => _hasMore;

  /// A live stream of the newest [limit] assets for this grid.
  Stream<List<AssetRef>> watchWindow(int limit);

  @override
  Future<List<AssetRef>> build() {
    _limit = pageSize;
    _hasMore = true;
    ref.onDispose(() => _sub?.cancel());
    return _subscribe(_limit);
  }

  /// (Re)subscribes to a [limit]-sized window. Completes with the first
  /// emission (for `build`/`loadMore` awaiting) and pushes every later emission
  /// into [state].
  Future<List<AssetRef>> _subscribe(int limit) {
    final completer = Completer<List<AssetRef>>();
    _sub?.cancel();
    _sub = watchWindow(limit).listen(
      (rows) {
        _hasMore = rows.length == limit;
        if (completer.isCompleted) {
          state = AsyncData(rows);
        } else {
          completer.complete(rows);
        }
      },
      onError: (Object e, StackTrace st) {
        if (completer.isCompleted) {
          state = AsyncError(e, st);
        } else {
          completer.completeError(e, st);
        }
      },
    );
    return completer.future;
  }

  /// Grows the window by [pageSize] and re-subscribes. No-op once exhausted.
  Future<void> loadMore() async {
    if (!_hasMore) return;
    _limit += pageSize;
    final rows = await _subscribe(_limit);
    state = AsyncData(rows);
  }
}
