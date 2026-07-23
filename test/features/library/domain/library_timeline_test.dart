import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/library/domain/library_filter.dart';
import 'package:sologallery/features/library/domain/library_timeline.dart';
import 'package:sologallery/features/library/domain/year_month.dart';

void main() {
  ({YearMonth month, int count}) m(int year, int month, int count) =>
      (month: YearMonth(year, month), count: count);

  List<TimelineRow> rows(
    List<({YearMonth month, int count})> counts, {
    int olderCount = 0,
    LibraryFilter filter = LibraryFilter.all,
  }) =>
      buildTimelineRows(counts: counts, olderCount: olderCount, filter: filter);

  group('all', () {
    test('leads with the carousel, filter bar, then one row per month', () {
      final result = rows([m(2026, 7, 4), m(2026, 6, 2)]);
      expect(result, [
        isA<MemoriesRow>(),
        isA<FilterBarRow>(),
        isA<MonthRow>().having((r) => r.month, 'month', YearMonth(2026, 7)),
        isA<MonthRow>().having((r) => r.month, 'month', YearMonth(2026, 6)),
      ]);
    });

    test('never inserts a year hero, even across a year boundary', () {
      final result = rows([m(2026, 1, 1), m(2025, 12, 1)]);
      expect(result.whereType<YearRow>(), isEmpty);
    });

    test('keeps the carousel and filter bar even with no months at all', () {
      expect(rows([]), [isA<MemoriesRow>(), isA<FilterBarRow>()]);
    });
  });

  group('months', () {
    test('opens with the filter bar, then a hero per year carrying totals', () {
      final result = rows([
        m(2026, 7, 4),
        m(2026, 6, 2),
        m(2025, 12, 9),
      ], filter: LibraryFilter.months);
      expect(result, [
        isA<FilterBarRow>(),
        isA<YearRow>()
            .having((r) => r.year, 'year', 2026)
            .having((r) => r.count, 'count', 6), // 4 + 2
        isA<MonthRow>().having((r) => r.month, 'month', YearMonth(2026, 7)),
        isA<MonthRow>().having((r) => r.month, 'month', YearMonth(2026, 6)),
        isA<YearRow>()
            .having((r) => r.year, 'year', 2025)
            .having((r) => r.count, 'count', 9),
        isA<MonthRow>().having((r) => r.month, 'month', YearMonth(2025, 12)),
      ]);
    });

    test('drops the carousel — the time filters read as pure navigation', () {
      final result = rows([m(2026, 7, 1)], filter: LibraryFilter.months);
      expect(result.whereType<MemoriesRow>(), isEmpty);
      expect(result.first, isA<FilterBarRow>());
    });

    test('emits one hero per year, not one per month', () {
      final result = rows([
        m(2026, 7, 1),
        m(2026, 6, 1),
        m(2026, 5, 1),
      ], filter: LibraryFilter.months);
      expect(result.whereType<YearRow>(), hasLength(1));
    });

    test('a year that reappears later gets its own hero', () {
      // Not reachable from the newest-first DAO ordering, but the flattener
      // must not silently merge two runs of the same year into one section.
      final result = rows([
        m(2026, 7, 1),
        m(2025, 6, 1),
        m(2026, 1, 1),
      ], filter: LibraryFilter.months);
      expect(result.whereType<YearRow>(), hasLength(3));
    });
  });

  group('older', () {
    test('trails the months when there are undated assets', () {
      final result = rows([m(2026, 7, 1)], olderCount: 12);
      expect(result.last, isA<OlderRow>().having((r) => r.count, 'count', 12));
    });

    test('is absent when the count is zero', () {
      expect(rows([m(2026, 7, 1)]).whereType<OlderRow>(), isEmpty);
    });

    test('stays outside the year grouping — undated assets have no year', () {
      final result = rows(
        [m(2026, 7, 1)],
        olderCount: 3,
        filter: LibraryFilter.months,
      );
      expect(result.last, isA<OlderRow>());
      expect(result.whereType<YearRow>(), hasLength(1));
    });

    test('can be the only content row', () {
      expect(rows([], olderCount: 5, filter: LibraryFilter.months), [
        isA<FilterBarRow>(),
        isA<OlderRow>(),
      ]);
    });
  });
}
