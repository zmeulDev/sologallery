import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/simple_lru.dart';

void main() {
  test('stores and retrieves values keyed by key', () {
    final cache = SimpleLru<String, int>(4);

    cache.put('a', 1);
    cache.put('b', 2);

    expect(cache.get('a'), 1);
    expect(cache.get('b'), 2);
    expect(cache.get('missing'), isNull);
  });

  test('caches a null value as a real entry when V is nullable', () {
    final cache = SimpleLru<String, int?>(4);
    cache.put('a', null);

    expect(cache.get('a'), isNull);
    expect(cache.contains('a'), isTrue);
    expect(cache.length, 1);
  });

  test('distinguishes a miss from a cached null', () {
    final cache = SimpleLru<String, int?>(4);
    cache.put('a', null);

    expect(cache.contains('a'), isTrue);
    expect(cache.contains('missing'), isFalse);
  });

  test('evicts the least recently used entry at capacity', () {
    final cache = SimpleLru<String, int>(4);

    for (var i = 0; i < 4; i++) {
      cache.put('id-$i', i);
    }
    expect(cache.length, 4);

    // Touch id-0 so it becomes most-recently-used.
    cache.get('id-0');

    // Adding id-4 should evict id-1 (the oldest after the touch), not id-0.
    cache.put('id-4', 4);
    expect(cache.length, 4);
    expect(cache.get('id-0'), isNotNull);
    expect(cache.get('id-1'), isNull);
    expect(cache.get('id-4'), isNotNull);
  });

  test('re-putting an existing key refreshes its recency without growing', () {
    final cache = SimpleLru<String, int>(2);
    cache.put('a', 1);
    cache.put('b', 2);
    cache.put('a', 10);
    cache.put('c', 3); // over capacity: evicts 'b', the true oldest.

    expect(cache.length, 2);
    expect(cache.get('a'), 10);
    expect(cache.get('b'), isNull);
    expect(cache.get('c'), 3);
  });

  test('clear drops every entry', () {
    final cache = SimpleLru<String, int>(4);
    cache.put('a', 1);
    cache.clear();
    expect(cache.length, 0);
    expect(cache.get('a'), isNull);
    expect(cache.contains('a'), isFalse);
  });

  test('works with non-String keys', () {
    final cache = SimpleLru<int, String>(2);
    cache.put(1, 'one');
    cache.put(2, 'two');
    cache.put(3, 'three'); // evicts 1, the oldest.

    expect(cache.get(1), isNull);
    expect(cache.get(2), 'two');
    expect(cache.get(3), 'three');
  });
}
