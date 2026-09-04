import 'dart:collection' show LinkedHashMap;

/// Generic capacity-bounded LRU cache. Backed by a [LinkedHashMap], whose
/// insertion order doubles as recency order: [get] and [put] both re-insert
/// the touched key at the end (most-recently-used), so the map's first key is
/// always the next eviction candidate.
///
/// Pure Dart — no Flutter or plugin imports — so it is domain-shaped and
/// host-testable independent of any caller.
class SimpleLru<K, V> {
  SimpleLru(this.capacity) : assert(capacity > 0);

  /// Maximum number of entries held before the least-recently-used one is
  /// evicted.
  final int capacity;

  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  /// Returns the cached value, or `null` if [key] is not present.
  /// A cached `null` value (when `V` is nullable) round-trips as `null` too;
  /// use [contains] to distinguish a miss from a known cached `null`.
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    final value = _cache[key] as V;
    // Move to most-recently-used position.
    _cache.remove(key);
    _cache[key] = value;
    return value;
  }

  /// Stores [value] under [key] and evicts the least-recently-used entry if
  /// the cache is now over [capacity].
  void put(K key, V value) {
    _cache.remove(key);
    _cache[key] = value;
    if (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Drops every entry.
  void clear() => _cache.clear();

  /// How many entries are currently held.
  int get length => _cache.length;

  /// Whether [key] is present, including as a cached `null` value.
  bool contains(K key) => _cache.containsKey(key);
}
