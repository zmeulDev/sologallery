import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart' show AssetRef;
import 'domain/library_filter.dart';
import 'domain/year_month.dart';

/// A non-empty calendar month and its exact photo count, for the Library home.
typedef MonthCount = ({YearMonth month, int count});

/// A non-empty calendar year and its exact photo count.
typedef YearCount = ({int year, int count});

/// How the Library home is currently grouped.
///
/// A [Notifier] rather than a `StateProvider`, matching the convention the
/// Search facets already follow.
class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => LibraryFilter.all;

  void set(LibraryFilter filter) => state = filter;
}

/// The Library home's current grouping. Screen-scoped UI state, so it is
/// deliberately *not* persisted to `AppSettings` — reopening the app returns to
/// the full timeline rather than stranding the user inside a week they filtered
/// to days ago.
///
/// Kept alive (no `autoDispose`) so switching tabs and coming back doesn't
/// silently reset the filter out from under the user.
final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(
      LibraryFilterNotifier.new,
    );

/// The Library home's month sections, newest first — one grouped SQL query over
/// the `photo_asset` cache (only non-empty months are returned). Reactive: the
/// grid reflows as the metadata sweep fills the cache and as photos are added or
/// deleted. Idle (empty) unless photo access allows reading the library.
final libraryMonthCountsProvider = StreamProvider.autoDispose<List<MonthCount>>(
  (ref) {
    final access = ref.watch(permissionProvider);
    if (!access.canReadLibrary) return Stream.value(const []);
    return ref.watch(indexDaoProvider).watchMonthCounts();
  },
);

/// Up to six newest preview ids for one [month], loaded lazily per visible
/// section and reactive — re-emits as the cache changes so a new capture shows
/// in the section thumbnails without leaving the app. Keyed by [YearMonth].
final monthPreviewsProvider = StreamProvider.autoDispose
    .family<List<String>, YearMonth>((ref, month) {
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
final olderPreviewsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(indexDaoProvider).watchOlderPreviews();
});

/// The Library's year sections under the `Year` filter, newest first — the
/// year-grouped mirror of [libraryMonthCountsProvider].
final libraryYearCountsProvider = StreamProvider.autoDispose<List<YearCount>>((
  ref,
) {
  final access = ref.watch(permissionProvider);
  if (!access.canReadLibrary) return Stream.value(const []);
  return ref.watch(indexDaoProvider).watchYearCounts();
});

/// Up to six newest preview ids for one calendar year, loaded lazily per
/// visible section. Keyed by the year.
final yearPreviewsProvider = StreamProvider.autoDispose
    .family<List<String>, int>((ref, year) {
      return ref.watch(indexDaoProvider).watchYearPreviews(year);
    });

/// How far back the `This week` filter reaches.
const kThisWeekWindow = Duration(days: 7);

/// Assets captured in the last [kThisWeekWindow], newest first.
///
/// The cutoff is resolved when the provider is first read, not on every rebuild
/// — a window that slid forward mid-scroll would drop photos out from under the
/// grid. `autoDispose` means leaving the filter and coming back re-resolves it,
/// which is the right moment for the window to move.
final thisWeekAssetsProvider = StreamProvider.autoDispose<List<AssetRef>>((
  ref,
) {
  final access = ref.watch(permissionProvider);
  if (!access.canReadLibrary) return Stream.value(const []);
  final cutoff = DateTime.now().subtract(kThisWeekWindow);
  return ref.watch(indexDaoProvider).watchRecentSince(cutoff);
});
