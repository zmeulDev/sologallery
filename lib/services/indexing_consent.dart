import 'dart:async' show unawaited;

import 'package:logging/logging.dart';

import '../core/database/daos/faces_dao.dart';
import '../core/database/daos/index_dao.dart';
import '../core/database/daos/memories_dao.dart';
import '../core/database/daos/settings_dao.dart';

/// `app_settings` key holding the face count at the last global re-cluster.
/// Shared with `IndexingService._maybeGlobalRecluster`, which reads this same
/// baseline to decide whether enough new faces have accrued to re-cluster —
/// every place [IndexingConsent] resets it is a place that invalidates it.
const reclusterBaselineKey = 'faces_at_last_recluster';

/// `app_settings` key + value identifying the clustering algorithm the stored
/// person assignments were produced by. Bumped whenever grouping changes so
/// existing installs re-cluster once instead of keeping the groups the old
/// algorithm decided on. Shared with `IndexingService._maybeGlobalRecluster`.
const clusterAlgoKey = 'cluster_algo_version';
const clusterAlgoVersion = '2';

/// `app_settings` keys for the memory-regeneration baseline: the local date
/// memories were last generated on, and the cache size at that moment. Shared
/// with `IndexingService._maybeRegenerateMemories`.
const memoriesDateKey = 'memories_generated_on';
const memoriesCountKey = 'memories_asset_baseline';

/// [IndexingService]'s consent-toggle side effects: applying onboarding's
/// three-answer consent, and each individual Settings toggle.
///
/// Lives in a service collaborator rather than the UI because withdrawing
/// consent has to delete the derived data, and enabling has to arrange for it
/// to be derived — and this needs the DAOs and the pass lifecycle
/// ([start]), not just a settings write.
class IndexingConsent {
  IndexingConsent({
    required this.dao,
    required this.faces,
    required this.memories,
    required this.settings,
    required this.start,
  });

  static final _log = Logger('SoloGallery.ml');

  final IndexDao dao;
  final FacesDao faces;
  final MemoriesDao memories;
  final SettingsDao settings;

  /// Kicks a fresh indexing pass, or folds this change into one already
  /// running. Injected from `IndexingService.start` — every method below ends
  /// with `unawaited(start())` once its writes are durable, exactly as it did
  /// before the move.
  final Future<void> Function() start;

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
  /// transaction ([SettingsDao.setConsent]) before any pass can observe them,
  /// and exactly one pass is kicked at the end.
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
      await settings.put(reclusterBaselineKey, '0');
    }
    if (!memoriesEnabled) await memories.clearMemories();

    // If the folder scope changed while ML features remain on, derived data may
    // now cover assets that should be excluded. Wipe it so the next pass
    // re-analyzes only the included folders.
    if (needsMl && previousExcluded != excludedFolderIds) {
      await dao.clearContent();
      await faces.clearFaces();
      await faces.clearPersons();
      await settings.put(reclusterBaselineKey, '0');
      await settings.put(clusterAlgoKey, clusterAlgoVersion);
      await memories.clearMemories();
    }

    // Memories are planned from labels and clusters, so every branch above
    // invalidates the current plan: clear the baselines and the pass replans
    // immediately rather than waiting for the once-a-day trigger.
    await settings.put(memoriesDateKey, '');
    await settings.put(memoriesCountKey, '0');

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
      await settings.put(memoriesDateKey, '');
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
      await settings.put(memoriesDateKey, '');
      await settings.put(memoriesCountKey, '0');
      unawaited(start());
    } else {
      await memories.clearMemories();
      await settings.put(memoriesDateKey, '');
      await settings.put(memoriesCountKey, '0');
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
      await settings.put(reclusterBaselineKey, '0');
      // Person-kind memories were built from those clusters; drop the baseline
      // so the next pass replans without them.
      await settings.put(memoriesDateKey, '');
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
    await settings.put(reclusterBaselineKey, '0');
    // The next pass should not treat this as an algorithm change; stamp the
    // current version so the small post-reset face count doesn't force a global
    // re-cluster immediately.
    await settings.put(clusterAlgoKey, clusterAlgoVersion);
    await memories.clearMemories();
    await settings.put(memoriesDateKey, '');
    await settings.put(memoriesCountKey, '0');

    // Re-queue everything so the next pass re-analyzes only included folders.
    await dao.resetMlPending();

    _log.info('Excluded folder set changed — reset derived data');
    unawaited(start());
  }
}
