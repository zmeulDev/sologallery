import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/detail/domain/asset_detail_display.dart';

void main() {
  test('formatDimensions', () {
    expect(formatDimensions(6048, 8064), '6048 × 8064');
  });

  group('formatMegapixels', () {
    test('rounds to one decimal', () {
      expect(formatMegapixels(6048, 8064), '48.8 MP');
    });
    test('empty when an edge is zero', () {
      expect(formatMegapixels(0, 100), '');
    });
  });

  group('formatFileSize', () {
    test('bytes / KB / MB thresholds', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2 KB');
      expect(formatFileSize(2202009), '2.1 MB');
    });
    test('null / negative are unknown', () {
      expect(formatFileSize(null), isNull);
      expect(formatFileSize(-5), isNull);
    });
  });

  group('formatType', () {
    test('takes the subtype uppercased', () {
      expect(formatType('image/heic'), 'HEIC');
      expect(formatType('image/jpeg'), 'JPEG');
    });
    test('null / empty', () {
      expect(formatType(null), isNull);
      expect(formatType(''), isNull);
    });
  });

  group('formatDuration', () {
    test('m:ss under an hour', () {
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(formatDuration(const Duration(minutes: 12, seconds: 30)), '12:30');
    });
    test('h:mm:ss past an hour', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
    test('null for a still', () {
      expect(formatDuration(null), isNull);
    });
  });

  test('formatTakenDate is zero-padded 24-hour', () {
    expect(formatTakenDate(DateTime(2026, 7, 12, 14, 3)), 'Jul 12, 2026 · 14:03');
  });

  group('formatCoordinates', () {
    test('four decimals', () {
      expect(formatCoordinates(37.7749295, -122.4194155), '37.7749, -122.4194');
    });
    test('null when either is missing', () {
      expect(formatCoordinates(null, 1), isNull);
      expect(formatCoordinates(1, null), isNull);
    });
  });
}
