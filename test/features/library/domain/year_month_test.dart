import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/library/domain/year_month.dart';

void main() {
  group('YearMonth', () {
    test('fromDate extracts year and month', () {
      final ym = YearMonth.fromDate(DateTime(2026, 7, 18, 9, 30));
      expect(ym, const YearMonth(2026, 7));
    });

    test('key is zero-padded and round-trips through tryParseKey', () {
      expect(const YearMonth(2026, 7).key, '2026-07');
      expect(const YearMonth(2026, 11).key, '2026-11');
      expect(YearMonth.tryParseKey('2026-07'), const YearMonth(2026, 7));
    });

    test('tryParseKey rejects malformed keys', () {
      expect(YearMonth.tryParseKey('2026'), isNull);
      expect(YearMonth.tryParseKey('2026-13'), isNull);
      expect(YearMonth.tryParseKey('2026-00'), isNull);
      expect(YearMonth.tryParseKey('abc-07'), isNull);
      expect(YearMonth.tryParseKey('2026-07-01'), isNull);
    });

    test('label is human readable', () {
      expect(const YearMonth(2026, 7).label, 'July 2026');
      expect(const YearMonth(2025, 1).label, 'January 2025');
      expect(const YearMonth(2025, 12).label, 'December 2025');
    });

    test('start and end bound the month', () {
      const ym = YearMonth(2026, 7);
      expect(ym.start, DateTime(2026, 7));
      expect(ym.end, DateTime(2026, 8));
      expect(const YearMonth(2026, 12).end, DateTime(2027));
    });

    test('ordering compares year then month', () {
      expect(const YearMonth(2026, 7).compareTo(const YearMonth(2026, 6)),
          greaterThan(0));
      expect(const YearMonth(2025, 12).compareTo(const YearMonth(2026, 1)),
          lessThan(0));
      expect(const YearMonth(2026, 7).compareTo(const YearMonth(2026, 7)), 0);
    });

  });
}
