import 'dart:collection' show LinkedHashMap;
import 'dart:typed_data';

/// Tiny in-memory LRU for low-resolution detail-viewer neighbours. Keyed only
/// by asset id — the placeholder is always a single small size, so unlike
/// [DetailPreviewCache] there is no max-edge dimension in the key.
///
/// Capacity is intentionally small: encoded bytes only, not decoded bitmaps,
/// so 16 entries costs roughly 1–2 MB and is dropped on lifecycle pause or
/// memory pressure.
class AdjacentThumbnailCache {
  static const _capacity = 16;

  final LinkedHashMap<String, Uint8List?> _cache =
      LinkedHashMap<String, Uint8List?>();

  /// Returns the cached bytes, or `null` if the key is not present.
  /// A cached `null` (entity unresolved) is returned as `null`; use [contains]
  /// if you need to distinguish a miss from a known-missing asset.
  Uint8List? get(String assetId) {
    if (!_cache.containsKey(assetId)) return null;
    final bytes = _cache[assetId];
    // Move to most-recently-used position.
    _cache.remove(assetId);
    _cache[assetId] = bytes;
    return bytes;
  }

  /// Stores [bytes] (which may be `null`) and evicts the oldest entry if the
  /// cache is over capacity.
  void put(String assetId, Uint8List? bytes) {
    _cache.remove(assetId);
    _cache[assetId] = bytes;
    if (_cache.length > _capacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Drops every entry.
  void clear() => _cache.clear();

  /// How many entries are currently held.
  int get length => _cache.length;

  /// Whether [assetId] is present in the cache, including as a cached `null`.
  bool contains(String assetId) => _cache.containsKey(assetId);
}
