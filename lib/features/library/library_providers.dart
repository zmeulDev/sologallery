import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/permission_provider.dart';
import 'domain/month_summary.dart';
import 'domain/year_month.dart';

/// The month sections shown on the Library screen, revealed lazily.
///
/// On build it loads the library's candidate month span, then fills the first
/// batch of non-empty [MonthSummary]s. [loadMore] appends the next batch as the
/// user scrolls. Idle (empty) unless photo access allows reading the library;
/// it re-runs automatically when access changes (via the watched
/// [permissionProvider]).
class LibraryMonthsNotifier extends AsyncNotifier<List<MonthSummary>> {
  /// Non-empty months resolved per batch.
  static const _batchSize = 4;

  List<YearMonth> _candidates = const [];
  int _cursor = 0;
  bool _loadingMore = false;

  bool get hasMore => _cursor < _candidates.length;

  @override
  Future<List<MonthSummary>> build() async {
    final access = ref.watch(permissionProvider);
    if (!access.canReadLibrary) {
      _candidates = const [];
      _cursor = 0;
      return const [];
    }
    _candidates = await ref.read(photoLibraryServiceProvider).monthsInLibrary();
    _cursor = 0;
    return _fill(const []);
  }

  /// Walks candidate months from [_cursor], skipping empties, until [_batchSize]
  /// non-empty summaries have been added or candidates are exhausted.
  Future<List<MonthSummary>> _fill(List<MonthSummary> acc) async {
    final service = ref.read(photoLibraryServiceProvider);
    final result = [...acc];
    var added = 0;
    while (_cursor < _candidates.length && added < _batchSize) {
      final summary = await service.monthSummary(_candidates[_cursor]);
      _cursor++;
      if (summary != null) {
        result.add(summary);
        added++;
      }
    }
    return result;
  }

  /// Appends the next batch without flipping the screen back to a loading state.
  Future<void> loadMore() async {
    if (_loadingMore || !hasMore) return;
    _loadingMore = true;
    try {
      final next = await _fill(state.value ?? const []);
      state = AsyncData(next);
    } finally {
      _loadingMore = false;
    }
  }
}

final libraryMonthsProvider =
    AsyncNotifierProvider.autoDispose<LibraryMonthsNotifier, List<MonthSummary>>(
  LibraryMonthsNotifier.new,
);
