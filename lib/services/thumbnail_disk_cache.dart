import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A persistent, on-disk cache of grid-sized thumbnail JPEG bytes, keyed by
/// `assetId:size:signature`. It exists because native thumbnail generation is a
/// full Glide **decode of the original file** (not a MediaStore pre-generated
/// thumbnail — that table is empty on Android 15), so the first paint of a fresh
/// grid section costs ~48 ms/cell. `photo_manager` caches decoded bytes in
/// memory only, so every first visit *per session* re-pays it. Persisting the
/// bytes turns that into "first visit *ever*": a subsequent open — even after an
/// app restart or a memory-cache eviction — is a small file read, no re-decode.
/// See docs/plans/month-grid-thumbnail-latency.md.
///
/// Best-effort throughout: every operation swallows I/O errors and degrades to a
/// miss, because a failed cache read/write must never break (or block) the grid,
/// which always has the live decode to fall back on.
///
/// Eviction is FIFO by file mtime under a byte budget — thumbnails are cheap to
/// regenerate on a miss, so there is no need to track per-read access times (and
/// no read-path writes). The sweep runs only every [_sweepEvery] writes to keep
/// directory listings off the hot path.
class ThumbnailDiskCache {
  ThumbnailDiskCache({
    required this.resolveDirectory,
    this.maxBytes = _defaultMaxBytes,
    this.sweepEvery = _defaultSweepEvery,
  })  : assert(maxBytes > 0),
        assert(sweepEvery > 0);

  /// The real app cache: a `thumb_cache/` subdir of the application support
  /// directory (survives across launches, not swept by the OS like the temp
  /// dir). `path_provider` is only touched on the first thumbnail op, so
  /// constructing the service off the UI isolate stays channel-free.
  factory ThumbnailDiskCache.appSupport() => ThumbnailDiskCache(
        resolveDirectory: () async => Directory(
          p.join((await getApplicationSupportDirectory()).path, 'thumb_cache'),
        ),
      );

  static const _defaultMaxBytes = 200 * 1024 * 1024; // 200 MB
  static const _defaultSweepEvery = 64;

  /// Resolves the cache directory on first use — split out so the real app can
  /// route it through `path_provider` (async, channel-backed) while tests inject
  /// a temp dir. Called at most once; the result is memoized.
  final Future<Directory> Function() resolveDirectory;
  final int maxBytes;

  /// How many [put]s between eviction sweeps — keeps directory listings off the
  /// hot path. Injectable for tests.
  final int sweepEvery;

  Directory? _dir;
  int _writesSinceSweep = 0;

  /// Resolves (once) and ensures the cache directory exists, or null if it can't
  /// be created — in which case the cache silently disables itself.
  Future<Directory?> _directory() async {
    final existing = _dir;
    if (existing != null) return existing;
    try {
      final dir = await resolveDirectory();
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Filesystem-safe, stable, collision-free file name for a cache key. The id
  /// is base64url-encoded (iOS ids contain `/`); size and signature are appended
  /// plainly. Stable across runs — unlike `Object.hash`, which is seeded per
  /// isolate — so a persisted entry is still found after a restart.
  String _fileName(String assetId, int size, int signature) {
    final id = base64Url.encode(utf8.encode(assetId));
    return '${id}_${size}_$signature.jpg';
  }

  /// Cached bytes for the key, or null on a miss (or any read error).
  Future<Uint8List?> get(String assetId, int size, int signature) async {
    final dir = _dir ?? await _directory();
    if (dir == null) return null;
    final file = File(p.join(dir.path, _fileName(assetId, size, signature)));
    try {
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Persists [bytes] under the key, then occasionally evicts down to budget.
  /// Fire-and-forget from the caller's view — never awaited on the grid's hot
  /// path, and never throws.
  Future<void> put(
    String assetId,
    int size,
    int signature,
    Uint8List bytes,
  ) async {
    final dir = await _directory();
    if (dir == null) return;
    try {
      final file = File(p.join(dir.path, _fileName(assetId, size, signature)));
      await file.writeAsBytes(bytes, flush: false);
    } catch (_) {
      return;
    }
    if (++_writesSinceSweep >= sweepEvery) {
      _writesSinceSweep = 0;
      await _evictToBudget(dir);
    }
  }

  /// Deletes oldest-first (by mtime) until the directory is under [maxBytes].
  Future<void> _evictToBudget(Directory dir) async {
    try {
      final stats = <(File, FileStat)>[];
      var total = 0;
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        final stat = await entry.stat();
        total += stat.size;
        stats.add((entry, stat));
      }
      if (total <= maxBytes) return;
      stats.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, stat) in stats) {
        if (total <= maxBytes) break;
        try {
          await file.delete();
          total -= stat.size;
        } catch (_) {
          // Skip a file we can't delete; keep draining the rest.
        }
      }
    } catch (_) {
      // A failed sweep just leaves the cache slightly over budget.
    }
  }

  /// Empties the cache (settings "clear cache", or a wholesale library change).
  Future<void> clear() async {
    final dir = _dir ?? await _directory();
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort.
    }
    _dir = null;
    _writesSinceSweep = 0;
  }
}
