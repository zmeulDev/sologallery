import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../services/permission_provider.dart';
import 'domain/year_month.dart';

/// A non-empty calendar month and its exact photo count, for the Library home.
typedef MonthCount = ({YearMonth month, int count});

/// The Library home's month sections, newest first — one grouped SQL query over
/// the `photo_asset` cache (only non-empty months are returned). Reactive: the
/// grid reflows as the metadata sweep fills the cache and as photos are added or
/// deleted. Idle (empty) unless photo access allows reading the library.
final libraryMonthCountsProvider =
    StreamProvider.autoDispose<List<MonthCount>>((ref) {
  final access = ref.watch(permissionProvider);
  if (!access.canReadLibrary) return Stream.value(const []);
  return ref.watch(indexDaoProvider).watchMonthCounts();
});

/// Up to six newest preview ids for one [month], loaded lazily per visible
/// section and reactive — re-emits as the cache changes so a new capture shows
/// in the section thumbnails without leaving the app. Keyed by [YearMonth].
final monthPreviewsProvider =
    StreamProvider.autoDispose.family<List<String>, YearMonth>((ref, month) {
  return ref.watch(indexDaoProvider).watchMonthPreviews(month);
});

/// Count of undated ("Older") photos — the trailing section, undated assets that
/// can't be placed in a calendar month. Zero on iOS (every asset is dated) and
/// when there are none. Idle unless photo access allows reading the library.
final olderCountProvider = StreamProvider.autoDispose<int>((ref) {
  final access = ref.watch(permissionProvider);
  if (!access.canReadLibrary) return Stream.value(0);
  return ref.watch(indexDaoProvider).watchOlderCount();
});

/// Up to six preview ids for the "Older" section, reactive.
final olderPreviewsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(indexDaoProvider).watchOlderPreviews();
});
