import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../core/database/daos/faces_dao.dart';
import '../core/database/daos/index_dao.dart';
import '../core/database/daos/settings_dao.dart';
import '../core/database/database_provider.dart';
import '../features/people/domain/face_clustering.dart';
import 'ml_service.dart';
import 'permission_provider.dart';
import 'photo_library_service.dart';

/// Progress of the background indexer. [remaining] of [total] assets in the
/// current pass are still to label; [isIndexing] drives the subtle Search hint.
class IndexingStatus {
  const IndexingStatus({required this.remaining, required this.total});
  const IndexingStatus.idle() : remaining = 0, total = 0;

  final int remaining;
  final int total;

  bool get isIndexing => remaining > 0;

  @override
  bool operator ==(Object other) =>
      other is IndexingStatus &&
      other.remaining == remaining &&
      other.total == total;

  @override
  int get hashCode => Object.hash(remaining, total);
}

/// Orchestrates on-device indexing: walks the library for unindexed assets,
/// labels each via the background [MlWorker] on a downsized thumbnail (never the
/// original), and writes `photo_asset` + `photo_label` rows.
///
/// Runs only in the foreground and pauses when the app goes idle (CLAUDE.md:
/// pause on `inactive`/`paused`, resume on `resumed`). Orchestration is on the
/// main isolate; only the ML runs off-thread (in [MlWorker]).
class IndexingService {
  IndexingService({
    required this.dao,
    required this.faces,
    required this.settings,
    required this.photos,
    required this.worker,
    this.tempDir,
    this.resweepDebounce = const Duration(seconds: 2),
    this.reclusterThreshold = 20,
  });

  static final _log = Logger('SoloGallery.ml');

  /// Thumbnail edge (px) for the OCR-only pass — larger than the 512 label/face
  /// thumbnail so small/distant text is recognized. Still a bounded thumbnail
  /// (never the original), so the HEIC-OOM rule holds.
  static const _ocrEdge = 1024;

  final IndexDao dao;
  final FacesDao faces;
  final SettingsDao settings;
  final PhotoLibraryService photos;
  final MlWorker worker;

  /// `app_settings` key holding the face count at the last global re-cluster.
  static const _reclusterBaselineKey = 'faces_at_last_recluster';

  /// New faces since the last global re-cluster before one is triggered. Small
  /// in tests.
  final int reclusterThreshold;

  /// Where transient ML thumbnails are written; resolved lazily on device.
  Directory? tempDir;

  /// How long to coalesce a burst of library-change callbacks before
  /// re-sweeping. Small in tests; ~2s on device.
  final Duration resweepDebounce;

  bool _running = false;
  bool _paused = false;
  bool _cancelled = false;
  bool _swept = false;

  /// Set when the device library changes mid-pass; makes [_run] loop once more
  /// so a photo added/removed during ML is still swept in.
  bool _dirty = false;

  /// Whether the foreground change listener has been registered (once per
  /// service lifetime).
  bool _changeNotifyStarted = false;

  /// Debounces the burst of change callbacks `photo_manager` emits per change.
  Timer? _resweepTimer;

  final _controller = StreamController<IndexingStatus>.broadcast();
  IndexingStatus _current = const IndexingStatus.idle();

  final _sweptController = StreamController<bool>.broadcast();

  /// The latest status followed by every change.
  Stream<IndexingStatus> watchStatus() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Whether the first metadata sweep has populated the `photo_asset` cache —
  /// the Library screen waits on this before deciding the grid is empty, rather
  /// than flashing "No photos" against a briefly-empty cache. Emits the current
  /// value immediately, then every change.
  Stream<bool> watchSwept() async* {
    yield _swept;
    yield* _sweptController.stream;
  }

  void _emit(IndexingStatus status) {
    _current = status;
    if (!_controller.isClosed) _controller.add(status);
  }

  void _markSwept() => _setSwept(true);

  void _setSwept(bool value) {
    if (_swept == value) return;
    _swept = value;
    if (!_sweptController.isClosed) _sweptController.add(value);
  }

  /// Starts (or no-ops if already running) a full indexing pass. Fire-and-forget.
  Future<void> start() async {
    _ensureChangeNotify();
    if (_running) return;
    _running = true;
    _cancelled = false;
    _paused = false;
    try {
      await _run();
    } catch (e, st) {
      _log.severe('Indexing pass failed', e, st);
    } finally {
      _running = false;
    }
  }

  /// Pauses processing between assets (app backgrounded).
  void pause() => _paused = true;

  /// Resumes a paused pass, or kicks a fresh pass if none is running.
  void resume() {
    _paused = false;
    if (!_running) unawaited(start());
  }

  bool _rebuilding = false;

  /// Wipes the ML index (cache + labels/OCR/faces + persons) and re-runs a full
  /// pass from scratch — Settings' "Rebuild index". Cancels any active pass
  /// first, flips the cache back to not-swept (the Library shows its spinner)
  /// while the fresh sweep repopulates it. Re-entrant calls are ignored.
  Future<void> rebuild() async {
    if (_rebuilding) return;
    _rebuilding = true;
    try {
      _cancelled = true;
      while (_running) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      _cancelled = false;
      await dao.clearIndex(); // cascades labels/OCR/faces
      await faces.clearPersons();
      _setSwept(false);
      _emit(const IndexingStatus.idle());
      _log.info('Rebuilding index from scratch');
      await start();
    } finally {
      _rebuilding = false;
    }
  }

  Future<void> dispose() async {
    _cancelled = true;
    _resweepTimer?.cancel();
    if (_changeNotifyStarted) await photos.stopLibraryChangeNotify();
    await _controller.close();
    await _sweptController.close();
    worker.dispose();
  }

  /// Registers the foreground library-change listener once. Wired from [start],
  /// so it covers both the warm-start and permission-grant entry points.
  void _ensureChangeNotify() {
    if (_changeNotifyStarted) return;
    _changeNotifyStarted = true;
    unawaited(photos.startLibraryChangeNotify(_onLibraryChanged));
  }

  /// Debounces the burst of change events into a single re-sweep.
  void _onLibraryChanged() {
    _resweepTimer?.cancel();
    _resweepTimer = Timer(resweepDebounce, _kickResweep);
  }

  /// Re-sweeps the cache after a debounced library change. Skips while
  /// backgrounded (resume already re-sweeps); folds into an in-flight pass via
  /// [_dirty] rather than racing a second one.
  void _kickResweep() {
    if (_paused || _cancelled) return;
    if (_running) {
      _dirty = true;
    } else {
      unawaited(start());
    }
  }

  Future<void> _run() async {
    do {
      _dirty = false;
      await _sweepMetadata();
      if (_cancelled) return;

      final todo = await dao.pendingMlIds();
      if (todo.isEmpty) {
        _emit(const IndexingStatus.idle());
        continue;
      }

      _log.info('Indexing ${todo.length} new asset(s)');
      var done = 0;
      _emit(IndexingStatus(remaining: todo.length, total: todo.length));

      for (final id in todo) {
        if (_cancelled) return;
        while (_paused && !_cancelled) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (_cancelled) return;

        await _indexOne(id);
        done++;
        _emit(IndexingStatus(remaining: todo.length - done, total: todo.length));
        await Future<void>.delayed(Duration.zero); // keep the UI isolate smooth
      }
      await _clusterNewFaces();
      if (_cancelled) return;
      await _maybeGlobalRecluster();
      _emit(const IndexingStatus.idle());
      _log.info('Indexing pass complete (${todo.length} asset(s))');
    } while (_dirty && !_cancelled);
  }

  /// Fast metadata-only pass: caches lean `photo_asset` rows for the whole
  /// library (no ML, no thumbnails), then prunes rows whose asset is gone
  /// (deleted / dropped from a limited-access subset). This is what fills the
  /// grid within seconds of grant — ML backfills labels/faces afterwards. New
  /// rows land with `indexedAt = NULL`, so [_run] picks them up for ML next.
  Future<void> _sweepMetadata() async {
    const pageSize = 500;
    final live = <String>{};
    for (final dated in const [true, false]) {
      var page = 0;
      while (!_cancelled) {
        final rows = await photos.libraryMetadataPage(
          dated: dated,
          page: page,
          pageSize: pageSize,
        );
        if (rows.isEmpty) break;
        await dao.upsertMetadata([
          for (final r in rows)
            (
              id: r.id,
              createdAt: r.createdAt,
              isVideo: r.isVideo,
              width: r.width,
              height: r.height,
              isDated: dated,
            ),
        ]);
        for (final r in rows) {
          live.add(r.id);
        }
        page++;
      }
    }
    if (_cancelled) return;

    final cached = await dao.allCachedIds();
    final stale = [for (final id in cached) if (!live.contains(id)) id];
    if (stale.isNotEmpty) {
      // Chunk to keep the IN(...) list bounded.
      for (var i = 0; i < stale.length; i += 500) {
        await dao.deleteAssets(
          stale.sublist(i, i + 500 > stale.length ? stale.length : i + 500),
        );
      }
      _log.info('Pruned ${stale.length} stale cache row(s)');
    }
    _markSwept();
  }

  /// Assigns every not-yet-clustered face to a person — the nearest existing
  /// cluster above the similarity threshold, or a new person. Incremental and
  /// deterministic (faces come back in stable id order).
  Future<void> _clusterNewFaces() async {
    final unclustered = await faces.unclusteredFaces();
    if (unclustered.isEmpty) return;
    final clusterer =
        IncrementalClusterer(initial: await faces.clusteredCentroids());
    for (final f in unclustered) {
      if (_cancelled) return;
      var personId = clusterer.nearest(f.embedding);
      personId ??= await faces.createPerson(coverAssetId: f.assetId);
      await faces.assignPersonToFace(f.id, personId);
      clusterer.add(personId, f.embedding);
    }
    _log.info('Clustered ${unclustered.length} new face(s)');
  }

  /// Periodically re-clusters *all* faces from scratch to undo the order-drift of
  /// incremental assignment (one person splitting into several). Runs only once
  /// [_reclusterThreshold] new faces have accrued since the last re-cluster
  /// (baseline persisted in `app_settings`), preserving user renames/covers.
  /// DB-only work — no ML — so it stays cheap.
  Future<void> _maybeGlobalRecluster() async {
    final total = await faces.faceCount();
    final baseline =
        int.tryParse(await settings.read(_reclusterBaselineKey) ?? '') ?? 0;
    if (total - baseline < reclusterThreshold) return;

    final all = await faces.allFacesForClustering();
    if (all.isEmpty) return;
    final groups =
        clusterAll([for (final f in all) (id: f.id, embedding: f.embedding)]);
    final plan = planClusters(
      groups: groups,
      faceMeta: {
        for (final f in all) f.id: (personId: f.personId, assetId: f.assetId),
      },
      persons: {
        for (final p in await faces.allPersons())
          p.id: (displayName: p.displayName, coverAssetId: p.coverAssetId),
      },
    );
    if (_cancelled) return;
    await faces.rebuildClusters(plan);
    await settings.put(_reclusterBaselineKey, total.toString());
    _log.info(
      'Global re-cluster: ${all.length} face(s) -> ${groups.length} person(s)',
    );
  }

  Future<void> _indexOne(String id) async {
    try {
      final meta = await photos.assetIndexMeta(id);
      if (meta == null) return; // unresolvable — retried next pass

      var labels = const <Label>[];
      var text = '';
      var detectedFaces = const <DetectedFace>[];
      final bytes = await photos.thumbnail(id, 512, 512);
      if (bytes != null) {
        final file = await _writeTemp('sg_idx', id, bytes);
        // A larger thumbnail for OCR only — recovers small text the 512 misses.
        // Labels/faces stay on the 512 file (bounded memory, stable box space).
        final ocrBytes = await photos.thumbnail(id, _ocrEdge, _ocrEdge);
        final ocrFile =
            ocrBytes != null ? await _writeTemp('sg_ocr', id, ocrBytes) : null;
        try {
          final analysis =
              await worker.analyzeFile(file.path, ocrPath: ocrFile?.path);
          labels = analysis.labels;
          text = analysis.text;
          detectedFaces = analysis.faces;
        } finally {
          if (await file.exists()) await file.delete();
          if (ocrFile != null && await ocrFile.exists()) await ocrFile.delete();
        }
      }

      await dao.upsertIndexed(
        assetId: id,
        createdAt: meta.createdAt,
        isVideo: meta.isVideo,
        width: meta.width,
        height: meta.height,
        labels: labels,
        text: text,
      );
      // FaceRecord is structurally identical to DetectedFace.
      await faces.insertFaces(id, [
        for (final f in detectedFaces)
          (
            left: f.left,
            top: f.top,
            right: f.right,
            bottom: f.bottom,
            embedding: f.embedding,
          ),
      ]);
    } catch (e, st) {
      _log.warning('Indexing failed for $id', e, st);
    }
  }

  Future<File> _writeTemp(String prefix, String id, Uint8List bytes) async {
    final dir = tempDir ??= await getTemporaryDirectory();
    final file = File('${dir.path}/${prefix}_${id.hashCode}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

/// App-wide ML worker, kept alive; disposed with the container.
final mlWorkerProvider = Provider<MlWorker>((ref) {
  final worker = MlWorkerController();
  ref.onDispose(worker.dispose);
  return worker;
});

/// App-wide indexing service, kept alive (owns the pass + worker lifetime).
final indexingServiceProvider = Provider<IndexingService>((ref) {
  final service = IndexingService(
    dao: ref.watch(indexDaoProvider),
    faces: ref.watch(facesDaoProvider),
    settings: ref.watch(settingsDaoProvider),
    photos: ref.watch(photoLibraryServiceProvider),
    worker: ref.watch(mlWorkerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Indexing progress for the subtle Search hint.
final indexingStatusProvider = StreamProvider<IndexingStatus>((ref) {
  return ref.watch(indexingServiceProvider).watchStatus();
});

/// Whether the first metadata sweep has run — gates the Library screen so it
/// shows a spinner (not an empty state) until the `photo_asset` cache is filled.
final libraryCacheReadyProvider = StreamProvider<bool>((ref) {
  return ref.watch(indexingServiceProvider).watchSwept();
});
