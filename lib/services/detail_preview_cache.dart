import 'dart:collection' show LinkedHashMap;
import 'dart:typed_data';

/// Tiny in-memory LRU for screen-sized detail previews. Keyed by asset id +
/// the requested max edge so a phone-sized request and a tablet-sized request
/// are cached independently. Capacity is intentionally small: encoded bytes
/// only, not decoded bitmaps, so 20 entries costs roughly 10–40 MB and is
/// dropped on lifecycle pause or memory pressure.
class DetailPreviewCache {
  static const _capacity = 20;

  final LinkedHashMap<String, Uint8List?> _cache =
      LinkedHashMap<String, Uint8List?>();

  String _key(String assetId, int maxEdge) => '$assetId:$maxEdge';

  /// Returns the cached bytes, or `null` if the key is not present.
  /// A cached `null` (entity unresolved) is returned as `null` and the caller
  /// must use [contains] if it needs to distinguish a miss.
  Uint8List? get(String assetId, int maxEdge) {
    final key = _key(assetId, maxEdge);
    if (!_cache.containsKey(key)) return null;
    final bytes = _cache[key];
    // Move to most-recently-used position.
    _cache.remove(key);
    _cache[key] = bytes;
    return bytes;
  }

  /// Stores [bytes] (which may be `null`) and evicts the oldest entry if the
  /// cache is over capacity.
  void put(String assetId, int maxEdge, Uint8List? bytes) {
    final key = _key(assetId, maxEdge);
    _cache.remove(key);
    _cache[key] = bytes;
    if (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Drops every entry.
  void clear() => _cache.clear();

  /// How many entries are currently held.
  int get length => _cache.length;
}
