import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../core/database/daos/faces_dao.dart';
import '../core/database/daos/index_dao.dart';
import '../core/database/daos/memories_dao.dart';
import '../core/database/daos/settings_dao.dart';
import '../core/database/database_provider.dart';
import '../features/memories/domain/memory_builder.dart';
import '../features/memories/domain/planned_memory.dart';
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
    required this.memories,
    required this.settings,
    required this.photos,
    required this.worker,
    this.resweepDebounce = const Duration(seconds: 2),
    this.reclusterThreshold = 20,
    this.memoryRefreshThreshold = 50,
  });

  static final _log = Logger('SoloGallery.ml');

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

  /// `app_settings` key holding the face count at the last global re-cluster.
  static const _reclusterBaselineKey = 'faces_at_last_recluster';

  /// `app_settings` key + value identifying the clustering algorithm the stored
  /// person assignments were produced by. Bump the version whenever grouping
  /// changes so existing installs re-cluster once instead of keeping the groups
  /// the old algorithm decided on.
  static const _clusterAlgoKey = 'cluster_algo_version';
  static const _clusterAlgoVersion = '2';

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

  /// `app_settings` keys for the memory-regeneration baseline: the local date
  /// memories were last generated on, and the cache size at that moment.
  static const _memoriesDateKey = 'memories_generated_on';
  static const _memoriesCountKey = 'memories_asset_baseline';

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
      await settings.put(_memoriesDateKey, '');
      await settings.put(_memoriesCountKey, '0');
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
  // Both live here rather than in the UI because withdrawing consent has to
  // delete the derived data, and enabling has to arrange for it to be derived —
  // and this service owns the baseline keys, the DAOs, and the pass lifecycle.

  /// Applies all three consent answers and the folder scope at once —
  /// onboarding's single entry point.
  ///
  /// Deliberately *not* three [setSearchEnabled] / [setMemoriesEnabled] /
  /// [setFacesEnabled] calls in a row. Each of those persists its own flag and
  /// then kicks a pass, so the first one starts a pass that reads the other two
  /// flags before they have been written. Faces lost that race on first run:
  /// the pass ran with `facesEnabled: false`, still stamped `indexed_at` on
  /// every asset, and since [IndexDao.pendingMlIds] only returns unstamped rows
  /// nothing ever revisited them — People stayed empty until the user toggled
  /// face detection in Settings. Here the flags and folder scope land in one
  /// transaction before any pass can observe them, and exactly one pass is kicked
  /// at the end.
  Future<void> applyConsent({
    required bool searchEnabled,
    required bool memoriesEnabled,
    required bool facesEnabled,
    required Set<String> excludedFolderIds,
  }) async {
    final previousExcluded = await settings.readExcludedFolderIds();

    await settings.setConsent(
      search: searchEnabled,
      memories: memoriesEnabled,
      faces: facesEnabled,
      excludedFolderIds: excludedFolderIds,
    );

    final needsMl = searchEnabled || facesEnabled;

    // Enabling either ML feature re-queues the whole cache: anything indexed
    // while it was off carries an `indexed_at` stamp that would otherwise hide
    // it from pendingMlIds forever.
    if (needsMl) await dao.resetMlPending();

    // Declining deletes what was already derived. An upgrading user reaches
    // this step with labels, faces, persons and memories already on disk from
    // before consent existed, and "no" has to mean the inferences go — not
    // merely that the UI stops showing them.
    if (!searchEnabled) await dao.clearContent();
    if (!facesEnabled) {
      await faces.clearFaces();
      await faces.clearPersons();
      await settings.put(_reclusterBaselineKey, '0');
    }
    if (!memoriesEnabled) await memories.clearMemories();

    // If the folder scope changed while ML features remain on, derived data may
    // now cover assets that should be excluded. Wipe it so the next pass
    // re-analyzes only the included folders.
    if (needsMl && previousExcluded != excludedFolderIds) {
      await dao.clearContent();
      await faces.clearFaces();
      await faces.clearPersons();
      await settings.put(_reclusterBaselineKey, '0');
      await settings.put(_clusterAlgoKey, _clusterAlgoVersion);
      await memories.clearMemories();
    }

    // Memories are planned from labels and clusters, so every branch above
    // invalidates the current plan: clear the baselines and the pass replans
    // immediately rather than waiting for the once-a-day trigger.
    await settings.put(_memoriesDateKey, '');
    await settings.put(_memoriesCountKey, '0');

    // One pass, after everything is durable. If the permission-grant pass is
    // still in flight, [start] folds this into it (_dirty) instead of dropping
    // it, and that pass re-reads the flags on its next round.
    unawaited(start());
  }

  /// Enables or disables content search (ML labels + OCR text).
  ///
  /// Disabling deletes every label and OCR row — consent withdrawn means the
  /// inferences go, not just the search box. Enabling re-queues the whole cache
  /// for analysis (assets indexed while it was off are stamped `indexed_at`, so
  /// they would otherwise never be revisited).
  Future<void> setSearchEnabled(bool enabled) async {
    await settings.setSearchEnabled(enabled);
    if (enabled) {
      await dao.resetMlPending();
      unawaited(start());
    } else {
      await dao.clearContent();
      // Theme memories were built from those labels; replan without them.
      await settings.put(_memoriesDateKey, '');
      _log.info('Content search disabled — cleared labels and OCR text');
    }
  }

  /// Enables or disables auto-curated Memories.
  ///
  /// Disabling drops every memory row (consent withdrawn = data gone). Enabling
  /// clears the regeneration baseline so the next pass rebuilds immediately
  /// rather than waiting for the once-a-day trigger; memories are planned from
  /// already-cached data, so no re-analysis is needed.
  Future<void> setMemoriesEnabled(bool enabled) async {
    await settings.setMemoriesEnabled(enabled);
    if (enabled) {
      await settings.put(_memoriesDateKey, '');
      await settings.put(_memoriesCountKey, '0');
      unawaited(start());
    } else {
      await memories.clearMemories();
      await settings.put(_memoriesDateKey, '');
      await settings.put(_memoriesCountKey, '0');
      _log.info('Memories disabled — cleared curated memories');
    }
  }

  /// Enables or disables face detection / People.
  ///
  /// Disabling deletes every face embedding *and* person cluster. Enabling has
  /// to backfill: assets indexed while the feature was off have `indexed_at`
  /// set, so [IndexDao.pendingMlIds] would skip them forever — [resetMlPending]
  /// re-queues the whole cache (labels/OCR survive, `upsertIndexed` replaces
  /// them in place).
  Future<void> setFacesEnabled(bool enabled) async {
    await settings.setFacesEnabled(enabled);
    if (enabled) {
      await dao.resetMlPending();
      unawaited(start());
    } else {
      await faces.clearFaces();
      await faces.clearPersons();
      await settings.put(_reclusterBaselineKey, '0');
      // Person-kind memories were built from those clusters; drop the baseline
      // so the next pass replans without them.
      await settings.put(_memoriesDateKey, '');
      _log.info('Face detection disabled — cleared faces and persons');
    }
  }

  /// Applies a new set of folder ids excluded from analysis.
  ///
  /// Correctly identifying only the newly excluded/included assets requires the
  /// same expensive folder paging the indexer already does, and the setting
  /// changes rarely — so a full derived-data reset is the right trade-off.
  Future<void> setExcludedFolderIds(Set<String> ids) async {
    await settings.setExcludedFolderIds(ids);

    // Wipe every inference that the new scope invalidates.
    await dao.clearContent();
    await faces.clearFaces();
    await faces.clearPersons();
    await settings.put(_reclusterBaselineKey, '0');
    // The next pass should not treat this as an algorithm change; stamp the
    // current version so the small post-reset face count doesn't force a global
    // re-cluster immediately.
    await settings.put(_clusterAlgoKey, _clusterAlgoVersion);
    await memories.clearMemories();
    await settings.put(_memoriesDateKey, '');
    await settings.put(_memoriesCountKey, '0');

    // Re-queue everything so the next pass re-analyzes only included folders.
    await dao.resetMlPending();

    _log.info('Excluded folder set changed — reset derived data');
    unawaited(start());
  }

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
      Set<String> excludedAssetIds = const {};
      if (needsMl) {
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
        _log.info('Indexing ${todo.length} new asset(s)');
        var done = 0;
        _emitProgress(
          IndexingStatus(remaining: todo.length, total: todo.length),
        );

        for (final id in todo) {
          if (_cancelled) return;
          while (_paused && !_cancelled) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          if (_cancelled) return;

          await _indexOne(
            id,
            searchEnabled: searchEnabled,
            facesEnabled: facesEnabled,
            excluded: excludedAssetIds.contains(id),
          );
          done++;
          _emitProgress(
            IndexingStatus(remaining: todo.length - done, total: todo.length),
          );
          await Future<void>.delayed(Duration.zero); // keep the UI isolate smooth
        }
        // The final progress state lands unconditionally so the dial doesn't
        // linger on a throttled mid-pass value during the post-todo
        // cluster/memories work that follows (a throttled emit may have skipped
        // the last few updates).
        _emit(IndexingStatus(remaining: 0, total: todo.length));
        _log.info('Indexing pass complete (${todo.length} asset(s))');
      }

      // Outside the `todo` branch for the same reason as memories below: on a
      // fully indexed library `todo` is empty every launch, and the periodic
      // global re-cluster — the only thing that heals a grouping an older
      // algorithm left behind — would never run again. Both calls open with a
      // cheap DB check and return immediately when there is nothing to do.
      if (facesEnabled) {
        await _clusterNewFaces();
        if (_cancelled) return;
        await _maybeGlobalRecluster();
        if (_cancelled) return;
      }

      // Outside the `todo` branch on purpose: on a typical launch there is no
      // ML work pending, but memories still need their once-a-day refresh.
      if (memoriesEnabled) {
        await _maybeRegenerateMemories(
          searchEnabled: searchEnabled,
          facesEnabled: facesEnabled,
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

  /// Assigns every not-yet-clustered face to a person — the nearest existing
  /// cluster above the similarity threshold, or a new person. Incremental and
  /// deterministic (faces come back in stable id order).
  ///
  /// Two phases: decide every face's person in memory (no DB writes), then
  /// apply the whole plan in one transaction. The in-memory decision uses a
  /// synthetic negative id for each new person so the clusterer can track it
  /// before the DB mints a real id. Batching the writes collapses what was one
  /// `watchPersonSummaries` emission per face into a single one, so the People
  /// strip no longer rebuilds once per face during a pass.
  Future<void> _clusterNewFaces() async {
    final unclustered = await faces.unclusteredFaces();
    if (unclustered.isEmpty) return;
    await _awaitNotPaused();
    if (_cancelled) return;
    final clusterer =
        IncrementalClusterer(initial: await faces.clusteredExemplars());

    // Phase 1 — decide in memory.
    var nextSynthetic = -1;
    final faceToPerson = <int, int>{}; // faceId -> personId (real or synthetic)
    final syntheticCover = <int, String>{}; // syntheticId -> first face's asset
    for (final f in unclustered) {
      await _awaitNotPaused();
      if (_cancelled) return;
      var personId = clusterer.nearest(f.embedding);
      if (personId == null) {
        personId = nextSynthetic--;
        syntheticCover[personId] = f.assetId;
      }
      faceToPerson[f.id] = personId;
      clusterer.add(personId, f.embedding);
    }

    // Phase 2 — group faces by person and apply in one batch.
    final byPerson = <int, List<int>>{};
    for (final faceId in faceToPerson.keys) {
      final personId = faceToPerson[faceId]!;
      byPerson.putIfAbsent(personId, () => []).add(faceId);
    }
    final plan = [
      for (final personId in byPerson.keys)
        IncrementalClusterPlan(
          faceIds: byPerson[personId]!,
          reusePersonId: personId > 0 ? personId : null,
          coverAssetId:
              personId > 0 ? null : syntheticCover[personId],
        ),
    ];
    await faces.applyIncrementalClusters(plan);
    _log.info('Clustered ${unclustered.length} new face(s)');
  }

  /// Periodically re-clusters *all* faces from scratch to undo the order-drift of
  /// incremental assignment (one person splitting into several). Runs once
  /// [reclusterThreshold] new faces have accrued since the last re-cluster
  /// (baseline persisted in `app_settings`), or once after an algorithm change,
  /// preserving user renames/covers. No ML — but the agglomeration itself goes
  /// to a worker isolate, since it is quadratic in the face count and the UI
  /// isolate must never carry it.
  Future<void> _maybeGlobalRecluster() async {
    await _awaitNotPaused();
    if (_cancelled) return;
    final total = await faces.faceCount();
    final baselineRaw = await settings.read(_reclusterBaselineKey);
    final baseline = int.tryParse(baselineRaw ?? '') ?? 0;
    // A clustering-algorithm change makes every stored grouping stale, so the
    // first pass after an upgrade re-clusters regardless of the baseline. Only
    // for an install that has actually clustered before (baseline written) —
    // a fresh one has nothing to heal and reaches the threshold on its own.
    final staleAlgo = baselineRaw != null &&
        await settings.read(_clusterAlgoKey) != _clusterAlgoVersion;
    if (!staleAlgo && total - baseline < reclusterThreshold) return;

    final all = await faces.allFacesForClustering();
    if (all.isEmpty) return;
    final input = [for (final f in all) (id: f.id, embedding: f.embedding)];
    final groups = await Isolate.run(() => clusterAll(input));
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
    await settings.put(_clusterAlgoKey, _clusterAlgoVersion);
    _log.info(
      'Global re-cluster: ${all.length} face(s) -> ${groups.length} person(s)',
    );
  }

  /// Rebuilds the auto-curated memories, at most once a day (or sooner once
  /// [memoryRefreshThreshold] new photos have landed). Baselines persist in
  /// `app_settings`, mirroring [_maybeGlobalRecluster].
  ///
  /// DB reads + a pure planning pass, no ML. Runs on the indexing loop, so it
  /// inherits the app's pause/resume gating for free.
  Future<void> _maybeRegenerateMemories({
    required bool searchEnabled,
    required bool facesEnabled,
  }) async {
    await _awaitNotPaused();
    if (_cancelled) return;
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final total = await memories.cachedAssetCount();
    final lastDate = await settings.read(_memoriesDateKey);
    final baseline =
        int.tryParse(await settings.read(_memoriesCountKey) ?? '') ?? 0;

    final newDay = lastDate != todayKey;
    final enoughNew = total - baseline >= memoryRefreshThreshold;
    if (!newDay && !enoughNew) return;
    if (total == 0) return;

    final plan = await _planMemories(
      now,
      searchEnabled: searchEnabled,
      facesEnabled: facesEnabled,
    );
    if (_cancelled) return;

    await memories.applyPlan(plan);
    await settings.put(_memoriesDateKey, todayKey);
    await settings.put(_memoriesCountKey, total.toString());
    _log.info('Regenerated ${plan.length} memory/memories');
  }

  /// Gathers the builder's inputs and plans. The planning itself runs via
  /// [Isolate.run]: trip clustering scans up to 20k records, and the Absolute
  /// rule is that heavy work never lands on the UI isolate. [MemoryBuilder] is
  /// pure with sendable inputs, so this is free.
  Future<List<PlannedMemory>> _planMemories(
    DateTime now, {
    required bool searchEnabled,
    required bool facesEnabled,
  }) async {
    final onThisDay = await memories.onThisDay(now.month, now.day);
    final recentDated = await memories.recentDatedProjection();

    // Theme memories ("Dogs", "Food") are built from ML labels, so they only
    // exist when the user consented to content analysis.
    final labels = <LabelCandidate>[];
    for (final tally in searchEnabled ? await memories.topLabels() : const []) {
      if (!MemoryBuilder.isPresentableLabel(tally.label)) continue;
      if (tally.assetCount < MemoryBuilder.minThemeAssets) continue;
      labels.add(
        (
          label: tally.label,
          assets: await memories.assetsForLabel(tally.label),
        ),
      );
    }

    // Person memories are built from face clusters, so they only exist when the
    // user consented to face detection. Memories-on/faces-off still yields
    // on-this-day and theme memories.
    final people = <PersonCandidate>[];
    final summaries = facesEnabled
        ? await faces.watchPersonSummaries().first
        : const <PersonSummary>[];
    for (final p in summaries.take(_personCandidateLimit)) {
      // Unnamed clusters have no title to show, so they can't be a memory.
      final name = p.displayName;
      if (name == null || name.isEmpty) continue;
      if (p.faceCount < _minPersonFaces) continue;
      final assets = await faces.assetsForPerson(p.id);
      people.add(
        (
          personId: p.id,
          name: name,
          coverAssetId: p.coverAssetId,
          assets: [
            for (final a in assets) (assetId: a.id, createdAt: a.createdAt),
          ],
        ),
      );
    }

    return Isolate.run(
      () => MemoryBuilder.build(
        today: now,
        onThisDay: onThisDay,
        recentDated: recentDated,
        labels: labels,
        people: people,
      ),
    );
  }

  /// How many of the most-photographed people are even considered — bounds the
  /// per-person asset queries above.
  static const _personCandidateLimit = 10;

  /// A person needs at least this many detected faces before their cluster is
  /// trustworthy enough to headline a memory.
  static const _minPersonFaces = 15;

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
