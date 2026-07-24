import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/format/count_labels.dart';

void main() {
  group('photoCountLabel', () {
    test('singular', () {
      expect(photoCountLabel(1), '1 photo');
    });

    test('plural', () {
      expect(photoCountLabel(2), '2 photos');
      expect(photoCountLabel(128), '128 photos');
      expect(photoCountLabel(1204), '1204 photos');
    });

    test('zero without an override reads "0 photos"', () {
      expect(photoCountLabel(0), '0 photos');
    });

    test('zero override is returned only for a count of 0', () {
      expect(photoCountLabel(0, zero: 'Empty'), 'Empty');
      expect(photoCountLabel(1, zero: 'Empty'), '1 photo');
      expect(photoCountLabel(2, zero: 'Empty'), '2 photos');
    });
  });

  group('itemCountLabel', () {
    test('counts items, since a month section mixes stills and video', () {
      expect(itemCountLabel(12), '12 items');
      expect(itemCountLabel(0), '0 items');
    });

    test('is singular for exactly one', () {
      expect(itemCountLabel(1), '1 item');
    });
  });

  group('compactCount', () {
    test('leaves anything under a thousand alone', () {
      expect(compactCount(0), '0');
      expect(compactCount(7), '7');
      expect(compactCount(142), '142');
      expect(compactCount(999), '999');
    });

    test('keeps one decimal through the first order of magnitude', () {
      expect(compactCount(1200), '1.2k');
      expect(compactCount(9949), '9.9k');
    });

    test('drops a trailing .0 rather than reading "1.0k"', () {
      expect(compactCount(1000), '1k');
      expect(compactCount(1049), '1k');
    });

    test('goes to whole thousands at ten thousand', () {
      expect(compactCount(10000), '10k');
      expect(compactCount(12345), '12k');
      expect(compactCount(120000), '120k');
    });

    test('never exceeds the four glyphs the dial has room for', () {
      for (final n in [0, 1, 999, 1000, 5678, 9999, 10000, 99999]) {
        expect(compactCount(n).length, lessThanOrEqualTo(4), reason: '$n');
      }
    });
  });
}
