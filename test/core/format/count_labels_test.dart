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
}
