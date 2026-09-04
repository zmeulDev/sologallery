import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../core/database/daos/faces_dao.dart';
import '../core/database/daos/index_dao.dart';
import '../core/database/daos/memories_dao.dart';
import '../core/database/daos/settings_dao.dart';
import '../core/database/database_provider.dart';
import 'indexing_consent.dart';
import 'indexing_triggers.dart';
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
/// Runs only in the foreground and pauses when the app goes idle (AGENTS.md:
/// pause on `inactive`/`paused`, resume on `resumed`). Orchestration is on the
/// main isolate; only the ML runs off-thread (in [MlWorker]).
class IndexingService {
  IndexingService({
    required this.dao,
    required this.faces,
    required this.memories,
    required this.settings,
    required this.photos,
    required this.worker,
    this.resweepDebounce = const Duration(seconds: 2),
    this.reclusterThreshold = 20,
    this.memoryRefreshThreshold = 50,
  }) {
    // Built in the constructor body, not the initializer list: both need a
    // tear-off of an instance method (`start`, `_awaitNotPaused`), which
    // isn't available yet during initializer-list evaluation.
    _consent = IndexingConsent(
      dao: dao,
      faces: faces,
      memories: memories,
      settings: settings,
      start: start,
    );
    _triggers = IndexingTriggers(
      faces: faces,
      settings: settings,
      memories: memories,
      reclusterThreshold: reclusterThreshold,
      memoryRefreshThreshold: memoryRefreshThreshold,
      awaitNotPaused: _awaitNotPaused,
      cancelled: () => _cancelled,
    );
  }

  static final _log = Logger('SoloGallery.ml');

  /// Owns the consent-toggle side effects (onboarding's [applyConsent] and
  /// each Settings toggle) — see [IndexingConsent].
  late final IndexingConsent _consent;

  /// Owns the post-pass triggers (incremental face clustering, the periodic
  /// global re-cluster, memory regeneration) — see [IndexingTriggers].
  late final IndexingTriggers _triggers;

  /// Thumbnail edge (px) for the OCR-only pass — larger than the 512 label/face
  /// thumbnail so small/distant text is recognized. Still a bounded thumbnail
  /// (never the original), so the HEIC-OOM rule holds.
  static const _ocrEdge = 1024;

  final IndexDao dao;
  final FacesDao faces;
  final MemoriesDao memories;
  final SettingsDao settings;
  final PhotoLibraryService photos;
  final MlWorker worker;

  // reclusterBaselineKey and clusterAlgoKey/clusterAlgoVersion (below) are
  // defined in indexing_consent.dart, shared with [IndexingConsent] which
  // resets them on a consent change.

  /// `app_settings` key + value identifying the face *pipeline* — detector
  /// options, quality gate, crop — that produced the stored embeddings. Bump it
  /// whenever any of those change: unlike a clustering change, which the global
  /// re-cluster can heal from the embeddings it already has, a pipeline change
  /// makes the embeddings themselves stale and they can only be recovered by
  /// re-analyzing the images. Without this an existing install keeps its
  /// pre-gate faces forever, since `pendingMlIds` only offers unstamped rows.
  static const _facePipelineKey = 'face_pipeline_version';
  static const _facePipelineVersion = '2';

  /// New faces since the last global re-cluster before one is triggered. Small
  /// in tests.
  final int reclusterThreshold;

  // memoriesDateKey/memoriesCountKey (below) are also defined in
  // indexing_consent.dart, shared with [IndexingConsent].

  /// New cached assets since the last regeneration before one is forced
  /// mid-day. Small in tests.
  final int memoryRefreshThreshold;

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

  /// Timestamp of the last progress emit, for [_emitProgress]'s throttle.
  DateTime? _lastProgressEmit;

  /// Emits indexing progress at most every [_progressThrottle] during a pass.
  /// The dial and the Settings stats rebuild per emit, so an unthrottled
  /// per-asset emit on a 1k-asset first run is a thousand rebuilds for a count
  /// the eye can't read that fast. The caller emits the final state
  /// (remaining 0) separately and unconditionally after the loop, so a
  /// throttled mid-pass value can't linger through the cluster/memories work
  /// that follows.
  void _emitProgress(IndexingStatus status) {
    final now = DateTime.now();
    if (_lastProgressEmit == null ||
        now.difference(_lastProgressEmit!) >= _progressThrottle) {
      _lastProgressEmit = now;
      _emit(status);
    }
  }

  /// Coalesces progress emits during a pass. ~250 ms is faster than the dial's
  /// number can usefully change to the eye, and slow enough that a 1k-asset
  /// pass emits ~4 times mid-flight instead of 1k.
  static const _progressThrottle = Duration(milliseconds: 250);

  void _markSwept() => _setSwept(true);

  void _setSwept(bool value) {
    if (_swept == value) return;
    _swept = value;
    if (!_sweptController.isClosed) _sweptController.add(value);
  }

  /// Starts a full indexing pass, or folds the request into the one already
  /// running. Fire-and-forget.
  ///
  /// A request that arrives mid-pass is never dropped: the caller changed
  /// something the in-flight pass may have already read past — a consent flag,
  /// or newly arrived assets — so it sets [_dirty] and the pass loops again
  /// with fresh state. Returning silently instead is what left face detection
  /// enabled but never run on first launch.
  Future<void> start() async {
    _ensureChangeNotify();
    if (_running) {
      _dirty = true;
      return;
    }
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

  /// Blocks until the app is no longer paused, or the pass is cancelled. The
  /// per-asset ML loop checks `_paused` inline; the metadata sweep, the periodic
  /// cluster/memories helpers, and the section entries in [_run] call this so a
  /// backgrounded app doesn't keep driving platform-channel round-trips, file
  /// I/O, or DB work (Absolute rule: no work runs while the app isn't in use).
  /// On cancel this returns promptly and the caller bails on its next
  /// `_cancelled` check.
  Future<void> _awaitNotPaused() async {
    while (_paused && !_cancelled) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
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
      await dao.clearIndex(); // cascades labels/OCR/faces (and memory entries)
      await faces.clearPersons();
      // The cascade empties each memory's entries but leaves the rows behind;
      // drop them so the carousel doesn't hold stale titles, and clear the
      // baselines so the next pass regenerates immediately.
      await memories.clearMemories();
      await settings.put(memoriesDateKey, '');
      await settings.put(memoriesCountKey, '0');
      _setSwept(false);
      _emit(const IndexingStatus.idle());
      _log.info('Rebuilding index from scratch');
      await start();
    } finally {
      _rebuilding = false;
    }
  }

  // --- Consent toggles ------------------------------------------------------
  //
  // Implementation lives in [IndexingConsent] (indexing_consent.dart) — this
  // service still owns the DAOs and the pass lifecycle it needs, injected in
  // via the constructor. Kept as plain delegates here because this is the
  // surface the UI (and its tests) calls.

  /// Applies all three consent answers and the folder scope at once —
  /// onboarding's single entry point. See [IndexingConsent.applyConsent].
  Future<void> applyConsent({
    required bool searchEnabled,
    required bool memoriesEnabled,
    required bool facesEnabled,
    required Set<String> excludedFolderIds,
  }) => _consent.applyConsent(
    searchEnabled: searchEnabled,
    memoriesEnabled: memoriesEnabled,
    facesEnabled: facesEnabled,
    excludedFolderIds: excludedFolderIds,
  );

  /// Enables or disables content search (ML labels + OCR text). See
  /// [IndexingConsent.setSearchEnabled].
  Future<void> setSearchEnabled(bool enabled) =>
      _consent.setSearchEnabled(enabled);

  /// Enables or disables auto-curated Memories. See
  /// [IndexingConsent.setMemoriesEnabled].
  Future<void> setMemoriesEnabled(bool enabled) =>
      _consent.setMemoriesEnabled(enabled);

  /// Enables or disables face detection / People. See
  /// [IndexingConsent.setFacesEnabled].
  Future<void> setFacesEnabled(bool enabled) =>
      _consent.setFacesEnabled(enabled);

  /// Applies a new set of folder ids excluded from analysis. See
  /// [IndexingConsent.setExcludedFolderIds].
  Future<void> setExcludedFolderIds(Set<String> ids) =>
      _consent.setExcludedFolderIds(ids);

  Future<void> dispose() async {
    _cancelled = true;
    _resweepTimer?.cancel();
    if (_changeNotifyStarted) await photos.stopLibraryChangeNotify();
    await _controller.close();
    await _sweptController.close();
    await worker.dispose();
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
    // The flags the previous round ran with (null on the first round).
    bool? ranWithSearch;
    bool? ranWithFaces;

    do {
      _dirty = false;
      // Re-read the consent flags at the top of every round, not once per pass:
      // a flag flipped while this pass was in flight is precisely what set
      // _dirty, and looping again on the stale answer would defeat the point.
      // Still once per *round*, never per asset.
      final searchEnabled = await settings.readSearchEnabled();
      final facesEnabled = await settings.readFacesEnabled();
      final memoriesEnabled = await settings.readMemoriesEnabled();

      // A feature that switched on since the last round means everything that
      // round processed was stamped `indexed_at` without it, and pendingMlIds
      // only returns unstamped rows — so those assets would never be revisited.
      // The enabling caller does call resetMlPending, but it lands *while* the
      // round is still running and the rest of that round re-stamps straight
      // over it. Re-queueing here, after the round has ended, is the only point
      // where the reset can't be undone.
      if ((searchEnabled && ranWithSearch == false) ||
          (facesEnabled && ranWithFaces == false)) {
        await dao.resetMlPending();
      }
      // Same problem, different cause: when the face pipeline itself changed,
      // every stored embedding was produced by the old detector/gate/crop and
      // is not comparable with what this build produces. Re-analyzing is the
      // only way back, so unstamp everything once and let the pass redo it.
      // Only for an install that has already indexed under an older version —
      // a fresh one has nothing stale, and stamping it here keeps the next
      // pipeline change detectable.
      if (facesEnabled && ranWithFaces == null) {
        final stamped = await settings.read(_facePipelineKey);
        if (stamped != _facePipelineVersion) {
          if (stamped != null || await faces.faceCount() > 0) {
            _log.info('Face pipeline changed — re-analyzing every asset');
            await dao.resetMlPending();
          }
          await settings.put(_facePipelineKey, _facePipelineVersion);
        }
      }
      ranWithSearch = searchEnabled;
      ranWithFaces = facesEnabled;
      // Labels/OCR and faces are the only things ML produces. With both
      // declined there is no analysis to do at all — the pass degrades to the
      // metadata sweep that fills the grid, and the worker never spawns.
      final needsMl = searchEnabled || facesEnabled;

      // Build the excluded-asset set once per round. If the user changes the
      // exclusion list mid-pass, the next round re-reads it via _dirty.
      // Memories need it too — a date-window memory is derived content, and the
      // folder sheet promises excluded photos are skipped — so this is not
      // gated on `needsMl`.
      Set<String> excludedAssetIds = const {};
      if (needsMl || memoriesEnabled) {
        final excludedFolderIds = await settings.readExcludedFolderIds();
        if (excludedFolderIds.isNotEmpty) {
          excludedAssetIds = await _excludedAssetIds(excludedFolderIds);
        }
      }
      if (_cancelled) return;

      await _sweepMetadata();
      if (_cancelled) return;

      final todo = needsMl ? await dao.pendingMlIds() : const <String>[];
      if (todo.isNotEmpty) {
        // Every pending asset is walked, but an excluded one is only stamped
        // `indexed_at` — no thumbnail, no ML. Counting those in the dial makes
        // it promise work it will never do: a library where one folder of 66 is
        // analyzed would open on "891 left" and race through 825 of them,
        // contradicting the "66 photos" the folder sheet just committed to. So
        // progress is measured over the analyzable subset only.
        final analyzable = todo
            .where((id) => !excludedAssetIds.contains(id))
            .length;
        _log.info(
          'Indexing ${todo.length} new asset(s); $analyzable to analyze',
        );
        var done = 0;
        _emitProgress(IndexingStatus(remaining: analyzable, total: analyzable));

        for (final id in todo) {
          if (_cancelled) return;
          while (_paused && !_cancelled) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          if (_cancelled) return;

          final excluded = excludedAssetIds.contains(id);
          await _indexOne(
            id,
            searchEnabled: searchEnabled,
            facesEnabled: facesEnabled,
            excluded: excluded,
          );
          if (!excluded) {
            done++;
            _emitProgress(
              IndexingStatus(remaining: analyzable - done, total: analyzable),
            );
          }
          await Future<void>.delayed(Duration.zero); // keep the UI isolate smooth
        }
        // The final progress state lands unconditionally so the dial doesn't
        // linger on a throttled mid-pass value during the post-todo
        // cluster/memories work that follows (a throttled emit may have skipped
        // the last few updates).
        _emit(IndexingStatus(remaining: 0, total: analyzable));
        _log.info('Indexing pass complete (${todo.length} asset(s))');
      }

      // Outside the `todo` branch for the same reason as memories below: on a
      // fully indexed library `todo` is empty every launch, and the periodic
      // global re-cluster — the only thing that heals a grouping an older
      // algorithm left behind — would never run again. Both calls open with a
      // cheap DB check and return immediately when there is nothing to do.
      if (facesEnabled) {
        await _triggers.clusterNewFaces();
        if (_cancelled) return;
        await _triggers.maybeGlobalRecluster();
        if (_cancelled) return;
      }

      // Outside the `todo` branch on purpose: on a typical launch there is no
      // ML work pending, but memories still need their once-a-day refresh.
      if (memoriesEnabled) {
        await _triggers.maybeRegenerateMemories(
          searchEnabled: searchEnabled,
          facesEnabled: facesEnabled,
          excludedAssetIds: excludedAssetIds,
        );
        if (_cancelled) return;
      }
      _emit(const IndexingStatus.idle());
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
        await _awaitNotPaused();
        if (_cancelled) break;
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

  /// Collects every asset id contained in [folderIds] by paging each folder.
  /// Checked once per indexing round; assets in the returned set get no ML work.
  Future<Set<String>> _excludedAssetIds(Set<String> folderIds) async {
    const pageSize = 500;
    final excluded = <String>{};
    for (final folderId in folderIds) {
      var page = 0;
      while (!_cancelled) {
        await _awaitNotPaused();
        if (_cancelled) break;
        final refs = await photos.folderAssets(
          folderId: folderId,
          page: page,
          pageSize: pageSize,
        );
        if (refs.isEmpty) break;
        for (final r in refs) {
          excluded.add(r.id);
        }
        page++;
      }
    }
    return excluded;
  }

  Future<void> _indexOne(
    String id, {
    required bool searchEnabled,
    required bool facesEnabled,
    required bool excluded,
  }) async {
    try {
      final meta = await photos.assetIndexMeta(id);
      if (meta == null) return; // unresolvable — retried next pass

      var labels = const <Label>[];
      var text = '';
      var detectedFaces = const <DetectedFace>[];

      // Assets in excluded folders are stamped as indexed but never analyzed:
      // the setting is about analysis scope, not library visibility.
      if (!excluded) {
        // No consented feature needs pixels, so don't even render a thumbnail.
        // `indexing: true` routes these through the separate pool so a pass
        // doesn't take slots from the grid's gate mid-fling. The bytes go
        // straight to the worker over the SendPort — no temp file on the UI
        // isolate (the worker writes its own).
        final bytes = (searchEnabled || facesEnabled)
            ? await photos.thumbnail(id, 512, 512, indexing: true)
            : null;
        if (bytes != null) {
          // A larger thumbnail for OCR only — recovers small text the 512 misses.
          // Labels/faces stay on the 512 bytes (bounded memory, stable box space).
          final ocrBytes = searchEnabled
              ? await photos.thumbnail(id, _ocrEdge, _ocrEdge, indexing: true)
              : null;
          final analysis = await worker.analyze(
            bytes: bytes,
            ocrBytes: ocrBytes,
            content: searchEnabled,
            faces: facesEnabled,
          );
          labels = analysis.labels;
          text = analysis.text;
          detectedFaces = analysis.faces;
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
      // FaceRecord is structurally identical to DetectedFace. Nothing to insert
      // when face detection is off — the worker returns no faces either.
      // Excluded assets also skip faces: the worker never ran for them.
      if (facesEnabled && !excluded) {
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
      }
    } catch (e, st) {
      _log.warning('Indexing failed for $id', e, st);
    }
  }
}

/// App-wide ML worker, kept alive; disposed with the container.
final mlWorkerProvider = Provider<MlWorker>((ref) {
  final worker = MlWorkerController();
  ref.onDispose(() async => await worker.dispose());
  return worker;
});

/// App-wide indexing service, kept alive (owns the pass + worker lifetime).
final indexingServiceProvider = Provider<IndexingService>((ref) {
  final service = IndexingService(
    dao: ref.watch(indexDaoProvider),
    faces: ref.watch(facesDaoProvider),
    memories: ref.watch(memoriesDaoProvider),
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
