import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/adjacent_thumbnail_cache.dart';

void main() {
  Uint8List bytes(String marker) => Uint8List.fromList(marker.codeUnits);

  test('stores and retrieves bytes keyed by asset id only', () {
    final cache = AdjacentThumbnailCache();
    final a = bytes('a');
    final b = bytes('b');

    cache.put('a', a);
    cache.put('b', b);

    expect(cache.get('a'), a);
    expect(cache.get('b'), b);
    expect(cache.get('missing'), isNull);
  });

  test('caches a null result as a real entry', () {
    final cache = AdjacentThumbnailCache();
    cache.put('a', null);

    expect(cache.get('a'), isNull);
    expect(cache.contains('a'), isTrue);
    expect(cache.length, 1);
  });

  test('distinguishes a miss from a cached null', () {
    final cache = AdjacentThumbnailCache();
    cache.put('a', null);

    expect(cache.contains('a'), isTrue);
    expect(cache.contains('missing'), isFalse);
  });

  test('evicts the least recently used entry at capacity', () {
    final cache = AdjacentThumbnailCache();

    for (var i = 0; i < 16; i++) {
      cache.put('id-$i', bytes('$i'));
    }
    expect(cache.length, 16);

    // Touch id-0 so it becomes most-recently-used.
    cache.get('id-0');

    // Adding id-16 should evict id-1 (the oldest after the touch), not id-0.
    cache.put('id-16', bytes('16'));
    expect(cache.length, 16);
    expect(cache.get('id-0'), isNotNull);
    expect(cache.get('id-1'), isNull);
    expect(cache.get('id-16'), isNotNull);
  });

  test('clear drops every entry', () {
    final cache = AdjacentThumbnailCache();
    cache.put('a', bytes('a'));
    cache.clear();
    expect(cache.length, 0);
    expect(cache.get('a'), isNull);
    expect(cache.contains('a'), isFalse);
  });
}
