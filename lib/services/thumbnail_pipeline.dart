import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:photo_manager/photo_manager.dart';

import 'adjacent_thumbnail_cache.dart';
import 'detail_preview_cache.dart';
import 'thumbnail_disk_cache.dart';
import 'thumbnail_gate.dart';

/// Owns [PhotoLibraryService]'s thumbnail-serving path: the two
/// [ThumbnailGate]s (grid vs. indexing), the persistent [ThumbnailDiskCache]
/// that backs grid cells, and the two in-memory LRUs that back the detail
/// viewer (preview + adjacent). This is the gate → disk-cache → native-decode
/// chain described on [PhotoLibraryService.thumbnail].
///
/// Entity resolution stays owned by [PhotoLibraryService] — the same
/// `_entityCache` also serves non-thumbnail concerns (video, EXIF detail,
/// delete), so it isn't duplicated here. This class is handed a
/// [resolveEntity] callback instead of importing `AssetEntity.fromId` itself.
class ThumbnailPipeline {
  ThumbnailPipeline({
    required this.resolveEntity,
    ThumbnailDiskCache? thumbnailDiskCache,
  }) : _thumbnailDiskCache =
           thumbnailDiskCache ?? ThumbnailDiskCache.appSupport();

  static final _log = Logger('SoloGallery.photos');

  /// Resolves (and caches) the [AssetEntity] for an asset id, or null if it
  /// can't be resolved (e.g. deleted). Injected from [PhotoLibraryService] —
  /// see the class doc comment.
  final Future<AssetEntity?> Function(String assetId) resolveEntity;

  final _detailPreviewCache = DetailPreviewCache();
  final _adjacentThumbnailCache = AdjacentThumbnailCache();
  final Map<String, Future<Uint8List?>> _previewPending = {};

  /// Persistent grid-thumbnail bytes, so a section opened for the first time
  /// *ever* re-decodes but every later open (incl. after a restart) is a file
  /// read — see [ThumbnailDiskCache] and [thumbnail].
  final ThumbnailDiskCache _thumbnailDiskCache;

  /// Caps concurrent grid-thumbnail decodes and discards ones whose cell has
  /// scrolled away — see [ThumbnailGate]. [previewImage] deliberately does not
  /// go through it: the detail viewer asks for one large image (plus its ±3
  /// neighbours) and must not queue behind a grid fling's backlog.
  final ThumbnailGate _thumbnailGate = ThumbnailGate();

  /// A separate, smaller pool for indexing's own thumbnails. A pass requests
  /// one 512 (and optionally one 1024 OCR) thumbnail per asset, sequentially,
  /// so it never needs more than a slot or two — but sharing the grid's 6-slot
  /// gate meant a pass starved scrolling to 5 during indexing. Its own pool
  /// keeps the grid's slots reserved for the grid and the pass's for the pass.
  final ThumbnailGate _indexingGate = ThumbnailGate(maxConcurrent: 3);

  /// A `width`×`height` thumbnail for [assetId], or null if the asset can't be
  /// resolved (e.g. deleted) or [cancelled] reported the caller gave up while
  /// the request was queued. Never decodes the original at full size
  /// (Absolute rules) — the detail viewer requests a screen-capped size, the
  /// grid a cell-sized one.
  ///
  /// Grid requests (the default, `indexing: false`) are backed by the
  /// persistent [ThumbnailDiskCache]: a hit returns file bytes without touching
  /// the native decoder, a miss decodes once and persists (see [_gridThumbnail]).
  ///
  /// Pass [indexing] true for the background indexer's own ML thumbnails (512 /
  /// 1024): they use a separate pool ([_indexingGate]), yield the native decode
  /// pool to an active grid, and are **not** persisted — each is consumed once by
  /// the analysis pass and never re-read, so caching them would only waste disk.
  Future<Uint8List?> thumbnail(
    String assetId,
    int width,
    int height, {
    bool Function()? cancelled,
    bool indexing = false,
  }) {
    if (indexing) {
      return _indexingGate.run(() async {
        // Yield the shared native decode pool (Android: Glide's thread pool) to
        // any in-flight foreground grid burst — e.g. a "View all" screenful —
        // before submitting ours. The separate gates cap Dart-side concurrency
        // but both bottom out on the same native decoders, so a pass opening
        // over a fresh grid would otherwise steal decode threads from the cells
        // the user is looking at (docs/plans/month-grid-thumbnail-latency.md).
        await _thumbnailGate.whenQuiet();
        final entity = await resolveEntity(assetId);
        if (entity == null) return null;
        return entity.thumbnailDataWithSize(ThumbnailSize(width, height));
      }, cancelled: cancelled);
    }
    return _thumbnailGate.run(
      () => _gridThumbnail(assetId, width, height),
      cancelled: cancelled,
    );
  }

  /// The grid-cell decode path: return the persisted thumbnail if we have it,
  /// otherwise decode it natively (the expensive Glide downsample of the
  /// original) and persist the bytes so the next open — this session or a later
  /// launch — is a plain file read. Grid requests are always square
  /// (`width == height`), so the disk key uses `width` as the size dimension.
  ///
  /// The persist is fire-and-forget: a slow or failing disk write must not hold
  /// up the cell, which already has its bytes.
  Future<Uint8List?> _gridThumbnail(String assetId, int width, int height) async {
    final entity = await resolveEntity(assetId);
    if (entity == null) return null;
    final signature = entity.modifiedDateSecond ?? 0;
    final cached = await _thumbnailDiskCache.get(assetId, width, signature);
    if (cached != null) return cached;
    final bytes = await entity.thumbnailDataWithSize(ThumbnailSize(width, height));
    if (bytes != null) {
      unawaited(_thumbnailDiskCache.put(assetId, width, signature, bytes));
    }
    return bytes;
  }

  /// Empties the persistent grid-thumbnail cache — for a settings "clear cache"
  /// action or a wholesale library reset. Individual edited/replaced assets
  /// invalidate themselves through the `modifiedDateSecond` signature in the
  /// cache key, so this is only for a deliberate full wipe.
  Future<void> clearThumbnailDiskCache() => _thumbnailDiskCache.clear();

  /// A high-quality, screen-sized preview for the detail viewer — the whole
  /// image, uncropped, capped at [maxEdge] px on its longest side. Uses `fit`
  /// resize on iOS (the plain [ThumbnailOption] hardcodes `fill`, which
  /// would crop); Android's scaler already fits within the box. The cap keeps a
  /// 48MP HEIC from decoding at full size (the OOM gotcha) while staying far
  /// sharper than a grid thumbnail. Never the full original (Absolute rules).
  ///
  /// Results are cached in a small in-memory LRU so revisiting the same photo
  /// during a session is instant; call [clearDetailPreviewCache] on lifecycle
  /// pause or memory pressure to reclaim the RAM. Concurrent requests for the
  /// same key share one underlying fetch.
  Future<Uint8List?> previewImage(String assetId, int maxEdge) {
    final cached = _detailPreviewCache.get(assetId, maxEdge);
    if (cached != null) {
      _log.fine('previewImage($assetId, ${maxEdge}px) cache hit');
      return Future.value(cached);
    }

    final key = '$assetId:$maxEdge';
    final pending = _previewPending[key];
    if (pending != null) {
      _log.fine('previewImage($assetId, ${maxEdge}px) pending dedupe');
      return pending;
    }

    final future = _fetchPreviewImage(assetId, maxEdge);
    _previewPending[key] = future;
    future.whenComplete(() => _previewPending.remove(key));
    return future;
  }

  Future<Uint8List?> _fetchPreviewImage(String assetId, int maxEdge) async {
    final total = Stopwatch()..start();
    final entityTimer = Stopwatch()..start();
    final entity = await resolveEntity(assetId);
    entityTimer.stop();
    if (entity == null) {
      total.stop();
      _detailPreviewCache.put(assetId, maxEdge, null);
      _log.fine(
        'previewImage($assetId) entity unresolved after '
        '${entityTimer.elapsedMilliseconds}ms',
      );
      return null;
    }
    final size = ThumbnailSize.square(maxEdge);
    final option = (Platform.isIOS || Platform.isMacOS)
        ? ThumbnailOption.ios(
            size: size,
            quality: 95,
            resizeContentMode: ResizeContentMode.fit,
          )
        : ThumbnailOption(size: size, quality: 95);
    final thumbTimer = Stopwatch()..start();
    final bytes = await entity.thumbnailDataWithOption(option);
    thumbTimer.stop();
    total.stop();
    _detailPreviewCache.put(assetId, maxEdge, bytes);
    _log.fine(
      'previewImage($assetId, ${maxEdge}px) '
      'entity=${entityTimer.elapsedMilliseconds}ms '
      'thumb=${thumbTimer.elapsedMilliseconds}ms '
      'total=${total.elapsedMilliseconds}ms '
      'bytes=${bytes?.length ?? 0}',
    );
    return bytes;
  }

  /// A small, fast thumbnail for the detail viewer's adjacent pages. Capped at
  /// [maxEdge] px on its longest side, it is meant as an instant placeholder
  /// while the larger [previewImage] decodes. Results are cached in a tiny LRU
  /// so swiping back and forth between the same neighbours is instant.
  ///
  /// This deliberately does not go through [thumbnail] / [ThumbnailGate]: the
  /// detail viewer issues a bounded number of these (≤15) and iOS needs
  /// `ResizeContentMode.fit` to avoid square-cropping the placeholder.
  Future<Uint8List?> adjacentThumbnail(String assetId, int maxEdge) async {
    final cached = _adjacentThumbnailCache.get(assetId);
    if (cached != null) {
      _log.fine('adjacentThumbnail($assetId) cache hit');
      return cached;
    }
    if (_adjacentThumbnailCache.contains(assetId)) {
      _log.fine('adjacentThumbnail($assetId) cache hit (null)');
      return null;
    }

    final sw = Stopwatch()..start();
    final bytes = await _fetchAdjacentThumbnail(assetId, maxEdge);
    sw.stop();
    _adjacentThumbnailCache.put(assetId, bytes);
    _log.fine(
      'adjacentThumbnail($assetId, ${maxEdge}px) fetched in '
      '${sw.elapsedMilliseconds}ms bytes=${bytes?.length ?? 0}',
    );
    return bytes;
  }

  Future<Uint8List?> _fetchAdjacentThumbnail(String assetId, int maxEdge) async {
    final entity = await resolveEntity(assetId);
    if (entity == null) return null;
    final size = ThumbnailSize.square(maxEdge);
    final option = (Platform.isIOS || Platform.isMacOS)
        ? ThumbnailOption.ios(
            size: size,
            quality: 90,
            resizeContentMode: ResizeContentMode.fit,
          )
        : ThumbnailOption(size: size, quality: 90);
    return entity.thumbnailDataWithOption(option);
  }

  /// Drops the in-memory adjacent thumbnail cache. Call from lifecycle pause
  /// and memory-pressure handlers to keep background RAM low.
  void clearAdjacentThumbnailCache() {
    _adjacentThumbnailCache.clear();
  }

  /// Drops the in-memory detail preview cache and any in-flight dedupe futures.
  /// Call from lifecycle pause and memory-pressure handlers to keep background
  /// RAM low.
  void clearDetailPreviewCache() {
    _detailPreviewCache.clear();
    _previewPending.clear();
  }
}
