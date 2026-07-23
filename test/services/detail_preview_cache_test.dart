import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/detail_preview_cache.dart';

void main() {
  Uint8List bytes(String marker) => Uint8List.fromList(marker.codeUnits);

  test('stores and retrieves bytes keyed by asset id and max edge', () {
    final cache = DetailPreviewCache();
    final a = bytes('a-2048');
    final b = bytes('a-1024');

    cache.put('a', 2048, a);
    cache.put('a', 1024, b);

    expect(cache.get('a', 2048), a);
    expect(cache.get('a', 1024), b);
    expect(cache.get('missing', 2048), isNull);
  });

  test('caches a null result as a real entry', () {
    final cache = DetailPreviewCache();
    cache.put('a', 2048, null);

    expect(cache.get('a', 2048), isNull);
    expect(cache.length, 1);
  });

  test('evicts the least recently used entry at capacity', () {
    final cache = DetailPreviewCache();

    for (var i = 0; i < 20; i++) {
      cache.put('id-$i', 2048, bytes('$i'));
    }
    expect(cache.length, 20);

    // Touch id-0 so it becomes most-recently-used.
    cache.get('id-0', 2048);

    // Adding id-20 should evict id-1 (the oldest after the touch), not id-0.
    cache.put('id-20', 2048, bytes('20'));
    expect(cache.length, 20);
    expect(cache.get('id-0', 2048), isNotNull);
    expect(cache.get('id-1', 2048), isNull);
    expect(cache.get('id-20', 2048), isNotNull);
  });

  test('clear drops every entry', () {
    final cache = DetailPreviewCache();
    cache.put('a', 2048, bytes('a'));
    cache.clear();
    expect(cache.length, 0);
    expect(cache.get('a', 2048), isNull);
  });
}
