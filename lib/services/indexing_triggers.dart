import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import '../core/database/daos/faces_dao.dart';
import '../core/database/daos/memories_dao.dart';
import '../core/database/daos/settings_dao.dart';
import '../features/memories/domain/memory_builder.dart';
import '../features/memories/domain/planned_memory.dart';
import '../features/people/domain/face_clustering.dart';
import 'indexing_consent.dart'
    show
        reclusterBaselineKey,
        clusterAlgoKey,
        clusterAlgoVersion,
        memoriesDateKey,
        memoriesCountKey;

/// `IndexingService`'s post-pass triggers: incremental face clustering, the
/// periodic global re-cluster, and auto-curated memory regeneration. Already
/// decoupled from per-asset indexing in `IndexingService._run` — each is
/// called after the per-asset ML loop, keyed off its own DB-persisted
/// baseline rather than per-asset state.
///
/// Pause/cancel state stays owned by `IndexingService`'s pass loop and is
/// injected here ([awaitNotPaused], [cancelled]) rather than duplicated, so
/// these triggers observe the same live flags [IndexingService._run] does.
class IndexingTriggers {
  IndexingTriggers({
    required this.faces,
    required this.settings,
    required this.memories,
    required this.reclusterThreshold,
    required this.memoryRefreshThreshold,
    required this.awaitNotPaused,
    required this.cancelled,
  });

  static final _log = Logger('SoloGallery.ml');

  final FacesDao faces;
  final SettingsDao settings;
  final MemoriesDao memories;

  /// New faces since the last global re-cluster before one is triggered.
  final int reclusterThreshold;

  /// New cached assets since the last regeneration before one is forced
  /// mid-day.
  final int memoryRefreshThreshold;

  /// Blocks until the app is no longer paused, or the pass is cancelled —
  /// injected from `IndexingService._awaitNotPaused`.
  final Future<void> Function() awaitNotPaused;

  /// Whether the in-flight pass has been cancelled — injected so these
  /// triggers check the same live flag `IndexingService._run` does, not a
  /// stale snapshot taken at construction time.
  final bool Function() cancelled;

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
  Future<void> clusterNewFaces() async {
    final unclustered = await faces.unclusteredFaces();
    if (unclustered.isEmpty) return;
    await awaitNotPaused();
    if (cancelled()) return;
    final clusterer = IncrementalClusterer(
      initial: await faces.clusteredExemplars(),
    );

    // Phase 1 — decide in memory.
    var nextSynthetic = -1;
    final faceToPerson = <int, int>{}; // faceId -> personId (real or synthetic)
    final syntheticCover = <int, String>{}; // syntheticId -> first face's asset
    for (final f in unclustered) {
      await awaitNotPaused();
      if (cancelled()) return;
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
          coverAssetId: personId > 0 ? null : syntheticCover[personId],
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
  Future<void> maybeGlobalRecluster() async {
    await awaitNotPaused();
    if (cancelled()) return;
    final total = await faces.faceCount();
    final baselineRaw = await settings.read(reclusterBaselineKey);
    final baseline = int.tryParse(baselineRaw ?? '') ?? 0;
    // A clustering-algorithm change makes every stored grouping stale, so the
    // first pass after an upgrade re-clusters regardless of the baseline. Only
    // for an install that has actually clustered before (baseline written) —
    // a fresh one has nothing to heal and reaches the threshold on its own.
    final staleAlgo =
        baselineRaw != null &&
        await settings.read(clusterAlgoKey) != clusterAlgoVersion;
    if (!staleAlgo && total - baseline < reclusterThreshold) return;

    final all = await faces.allFacesForClustering();
    if (all.isEmpty) return;
    final input = [for (final f in all) (id: f.id, embedding: f.embedding)];
    final faceMeta = {
      for (final f in all) f.id: (personId: f.personId, assetId: f.assetId),
    };
    final personsMeta = {
      for (final p in await faces.allPersons())
        p.id: (displayName: p.displayName, coverAssetId: p.coverAssetId),
    };
    // Both clusterAll (quadratic in face count) and planClusters
    // (faces×groups) are pure functions of the plain data gathered above, so
    // the whole planning pass — not just clustering — goes to a worker
    // isolate; neither may run on the caller's (UI) isolate.
    final plan = await Isolate.run(
      () => planClusters(
        groups: clusterAll(input),
        faceMeta: faceMeta,
        persons: personsMeta,
      ),
    );
    if (cancelled()) return;
    await faces.rebuildClusters(plan);
    await settings.put(reclusterBaselineKey, total.toString());
    await settings.put(clusterAlgoKey, clusterAlgoVersion);
    _log.info(
      'Global re-cluster: ${all.length} face(s) -> ${plan.length} person(s)',
    );
  }

  /// Rebuilds the auto-curated memories, at most once a day (or sooner once
  /// [memoryRefreshThreshold] new photos have landed). Baselines persist in
  /// `app_settings`, mirroring [maybeGlobalRecluster].
  ///
  /// DB reads + a pure planning pass, no ML. Runs on the indexing loop, so it
  /// inherits the app's pause/resume gating for free.
  Future<void> maybeRegenerateMemories({
    required bool searchEnabled,
    required bool facesEnabled,
    required Set<String> excludedAssetIds,
  }) async {
    await awaitNotPaused();
    if (cancelled()) return;
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final total = await memories.cachedAssetCount();
    final lastDate = await settings.read(memoriesDateKey);
    final baseline =
        int.tryParse(await settings.read(memoriesCountKey) ?? '') ?? 0;

    final newDay = lastDate != todayKey;
    final enoughNew = total - baseline >= memoryRefreshThreshold;
    if (!newDay && !enoughNew) return;
    if (total == 0) return;

    final plan = await _planMemories(
      now,
      searchEnabled: searchEnabled,
      facesEnabled: facesEnabled,
      excludedAssetIds: excludedAssetIds,
    );
    if (cancelled()) return;

    await memories.applyPlan(plan);
    await settings.put(memoriesDateKey, todayKey);
    await settings.put(memoriesCountKey, total.toString());
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
    required Set<String> excludedAssetIds,
  }) async {
    // On-this-day and trips are the only inputs drawn from raw metadata rather
    // than from ML output, so they are the only ones the folder gate does not
    // already cover. Without this filter a user who limited analysis to one
    // folder still gets memories built entirely out of the folders they
    // excluded — label and person memories stay inside the gate, date-window
    // ones would not.
    final onThisDay = _withoutExcluded(
      await memories.onThisDay(now.month, now.day),
      excludedAssetIds,
    );
    final recentDated = _withoutExcluded(
      await memories.recentDatedProjection(),
      excludedAssetIds,
    );

    // Theme memories ("Dogs", "Food") are built from ML labels, so they only
    // exist when the user consented to content analysis.
    final labels = <LabelCandidate>[];
    for (final tally in searchEnabled ? await memories.topLabels() : const []) {
      if (!MemoryBuilder.isPresentableLabel(tally.label)) continue;
      if (tally.assetCount < MemoryBuilder.minThemeAssets) continue;
      labels.add((
        label: tally.label,
        assets: await memories.assetsForLabel(tally.label),
      ));
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
      people.add((
        personId: p.id,
        name: name,
        coverAssetId: p.coverAssetId,
        assets: [
          for (final a in assets) (assetId: a.id, createdAt: a.createdAt),
        ],
      ));
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

  /// Drops assets in analysis-excluded folders from a memory input. Returns
  /// [assets] untouched when nothing is excluded, which is the common case.
  static List<DatedAsset> _withoutExcluded(
    List<DatedAsset> assets,
    Set<String> excludedAssetIds,
  ) {
    if (excludedAssetIds.isEmpty) return assets;
    return [
      for (final a in assets)
        if (!excludedAssetIds.contains(a.assetId)) a,
    ];
  }

  /// How many of the most-photographed people are even considered — bounds the
  /// per-person asset queries above.
  static const _personCandidateLimit = 10;

  /// A person needs at least this many detected faces before their cluster is
  /// trustworthy enough to headline a memory.
  static const _minPersonFaces = 15;
}
