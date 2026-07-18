import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/search/domain/search_date.dart';

void main() {
  group('parseDateQuery', () {
    test('parses a bare year into a full-year window', () {
      expect(
        parseDateQuery('2026'),
        DateWindow(DateTime(2026), DateTime(2027)),
      );
    });

    test('parses "month year" with a full month name', () {
      expect(
        parseDateQuery('June 2026'),
        DateWindow(DateTime(2026, 6), DateTime(2026, 7)),
      );
    });

    test('parses a 3-letter month abbreviation', () {
      expect(
        parseDateQuery('jun 2026'),
        DateWindow(DateTime(2026, 6), DateTime(2026, 7)),
      );
    });

    test('is case-insensitive and trims whitespace', () {
      expect(
        parseDateQuery('  DECEMBER 2026 '),
        DateWindow(DateTime(2026, 12), DateTime(2027)),
      );
    });

    test('accepts "year month" order', () {
      expect(
        parseDateQuery('2026 march'),
        DateWindow(DateTime(2026, 3), DateTime(2026, 4)),
      );
    });

    test('parses ISO-ish numeric month/year', () {
      expect(
        parseDateQuery('2026-06'),
        DateWindow(DateTime(2026, 6), DateTime(2026, 7)),
      );
      expect(
        parseDateQuery('2026/06'),
        DateWindow(DateTime(2026, 6), DateTime(2026, 7)),
      );
      expect(
        parseDateQuery('06/2026'),
        DateWindow(DateTime(2026, 6), DateTime(2026, 7)),
      );
    });

    test('December rolls the exclusive bound into the next January', () {
      final w = parseDateQuery('dec 2026')!;
      expect(w.endExclusive, DateTime(2027, 1));
    });

    test('February window is short but end-exclusive is March 1', () {
      final w = parseDateQuery('feb 2024')!; // leap year
      expect(w.start, DateTime(2024, 2));
      expect(w.endExclusive, DateTime(2024, 3));
    });

    test('returns null for a bare month (ambiguous across years)', () {
      expect(parseDateQuery('june'), isNull);
    });

    test('returns null for non-date text', () {
      expect(parseDateQuery('iceland'), isNull);
      expect(parseDateQuery('summer trip'), isNull);
      expect(parseDateQuery(''), isNull);
      expect(parseDateQuery('   '), isNull);
    });

    test('rejects out-of-range months and implausible years', () {
      expect(parseDateQuery('13/2026'), isNull);
      expect(parseDateQuery('2026 13'), isNull);
      expect(parseDateQuery('99'), isNull); // not 4 digits
    });
  });
}
