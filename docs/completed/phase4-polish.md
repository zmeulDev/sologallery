# Plan — Phase 4 polish (all three, sequenced)

**STATUS: ✅ Complete (host side).** P1 avatar crop (`kFaceFill` + pure
`faceAvatarPlacement`), P2 higher-res OCR (`analyzeFile(ocrPath:)`, 1024 OCR
temp), P3 global re-cluster (`clusterAll`/`planClusters` + `FacesDao`
`allFacesForClustering`/`faceCount`/`rebuildClusters` + `IndexingService`
threshold trigger via `app_settings`) all landed with unit/DAO/service tests.
**Remaining: on-device verification** — needs photo access re-granted on the
Pixel (the ML integration test found it revoked). No new deps.


_On approval, saved to `docs/plans/phase4-polish.md`. Completes the Phase 4
backlog in `docs/plans/CHECKPOINT.md`. Built and verified **one part at a time,
in order**; the tree stays green between parts. Each part is small enough to
land independently (git commits are the user's)._

## Context

Three independent people/OCR quality refinements remain from Phase 4. They share
no code, so they're built in ascending risk: (1) avatar crop — UI only; (2)
higher-res OCR — worker protocol; (3) global re-cluster — domain + DAO + service.
The ML pipeline today runs labels + OCR + faces on **one 512px thumbnail**
(`IndexingService._indexOne` → `photos.thumbnail(id, 512, 512)` →
`MlWorker.analyzeFile`), face boxes stored in that 512 space; clustering is
incremental only (`IndexingService._clusterNewFaces` +
`IncrementalClusterer`).

## Part 1 — Tighter avatar crop (UI only)

**Problem:** `FaceAvatar` (`lib/features/people/widgets/face_avatar.dart`)
scales the raw ML Kit box so its longer side just fills the circle, so the
portrait sits loose with background in the circle corners.

**Change:** apply a fill factor that zooms the face in (crops tighter). Replace
`final scale = size / max(boxW, boxH)` with
`size * kFaceFill / max(boxW, boxH)` where `kFaceFill ≈ 1.3` (a named const,
documented as tunable), keeping the existing center math. No schema/service
change.

**Tests:** update the `face_avatar` alchemist golden
(`test/widgets/design_goldens_test.dart` already covers people? if not, add a
`FaceAvatar` scenario over an in-memory-seeded person) — regenerate with
`--update-goldens`. Verify visually on device.

## Part 2 — Higher-res OCR (faces/labels stay at 512)

**Problem:** OCR on the 512 thumbnail misses small/distant text.

**Changes:**
- **`lib/services/ml_service.dart`** — `MlWorker.analyzeFile(String jpegPath,
  {String? ocrPath})`. In `_workerMain`, run `recognizer.processImage` on
  `InputImage.fromFilePath(ocrPath ?? msg.path)`; labels + faces stay on
  `jpegPath` (512), so face-box coordinate space and the avatar are unchanged.
  Thread `ocrPath` through `_AnalyzeJob`.
- **`lib/services/indexing_service.dart`** `_indexOne` — also request a larger
  thumbnail (`photos.thumbnail(id, kOcrEdge, kOcrEdge)`, `kOcrEdge = 1024`),
  write a second temp JPEG, pass its path as `ocrPath`; delete both temps in
  `finally`. Still a bounded thumbnail (not the original — HEIC-OOM rule holds).
- **`test/support/fake_ml_worker.dart`** — match the new signature; record
  `ocrPath` (add an `ocrCalls` list) so tests can assert the higher-res path was
  used.

**Tests:**
- `indexing_service_test.dart` — assert `_indexOne` passes a distinct `ocrPath`
  (the fake records it) and OCR text still persists.
- **Fake-pairing (on-device):** extend `integration_test/ml_indexing_test.dart`
  to assert OCR text is still extracted end-to-end via the real worker with the
  larger OCR image (regression + smoke; a deterministic small-text asset is the
  existing `test_assets/` debt, noted).

## Part 3 — Global re-cluster (domain + DAO + service)

**Problem:** incremental greedy clustering is order-dependent — one person drifts
into several `persons` rows over time and can't self-heal.

**Domain — `lib/features/people/domain/face_clustering.dart`:**
add a pure `List<List<int>> clusterAll(List<({int id, Float32List embedding})>
faces, {double threshold = 0.65})` — greedy nearest-centroid from empty over a
stable id order (reuses `cosineSimilarity`/`Centroid`), returning groups of face
ids. Unit-testable on host.

**DAO — `lib/core/database/daos/faces_dao.dart`:**
- `allFacesForClustering()` → `(int id, int? personId, String assetId,
  Float32List embedding)` list, ordered by id.
- `Future<int> faceCount()`.
- `rebuildClusters(...)` in a transaction: take the computed groups + a
  name/cover-preservation mapping, bulk-update `face_embedding.personId`,
  update reused persons, insert new ones, delete now-empty persons. Reuses
  `createPerson`/`renamePerson` patterns.

**Name/cover preservation (in the service or a small pure helper):** process
groups largest-first; each group claims the most common non-null old `personId`
among its faces if not already claimed (keep its `displayName`; set
`coverAssetId` to an in-group face's asset if the old cover left the group);
otherwise mint a new person. Deterministic.

**Service — `lib/services/indexing_service.dart`:** after a pass's
`_clusterNewFaces`, decide whether to global-recluster: read
`faces_since_recluster` baseline from `app_settings` (via a new
`SettingsDao.read(key)` one-shot + `put`), compare to `faces.faceCount()`; if the
delta ≥ `kReclusterThreshold` (~20), run `clusterAll` → `rebuildClusters`, then
store the new baseline. Add `SettingsDao` to `IndexingService`'s deps +
`indexingServiceProvider`. Guard so it never runs on the UI isolate work path
(it's DB-only, cheap) and respects `_cancelled`.

**Tests:**
- `face_clustering_test.dart` — `clusterAll` merges near-duplicate embeddings and
  splits distinct ones; deterministic by id order.
- `faces_dao_test.dart` — `allFacesForClustering`, `faceCount`, and
  `rebuildClusters` (assignments updated, empty persons removed, a renamed
  person keeps its name across a rebuild).
- `indexing_service_test.dart` — after enough new faces, a global re-cluster
  collapses two incremental persons that are actually one into a single person,
  preserving a user rename; below threshold it doesn't run.
- **On-device:** `ml_indexing_test.dart` still clusters end-to-end (regression).

## Verification (each part, before starting the next)

1. `tool/check.sh` green (analyze, codegen, host tests incl. goldens/migration).
2. Device (Pixel 9 Pro XL): P1 — avatars frame faces tightly; P2 — a photo with
   small text becomes findable in Search that wasn't; P3 — after indexing, a
   duplicated person collapses and keeps its name; `ml_indexing_test.dart`
   passes on device.
3. No new Android deps → no manifest re-verify needed.

## On completion

Mark Phase 4 done in `docs/plans/CHECKPOINT.md`; prune Phase-4 backlog. Record
any surprising failures in CLAUDE.md → Known gotchas.
