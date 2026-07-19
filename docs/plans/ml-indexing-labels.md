# ML/Indexing slice 1 — image labels + content search

Status: **COMPLETE** (2026-07-18). `tool/check.sh` green (**164 host tests** incl.
DAO, migration v1→v2, provider content-search, and fake-worker service tests);
`integration_test/ml_indexing_test.dart` green on the Pixel 9 Pro XL (real
isolate + bundled ML Kit model + DB write + content search). Release manifest
re-verified network-free after stripping ML Kit's injected c2dm push
permission + receiver. `google_mlkit_image_labeling: ^0.15.0` added.
Next step: none for this slice. Follow-ups: OCR (text recognition) and
faces/people (tflite + `face_embedding` + People screen) are the next slices;
`test_assets/` still unseeded (HEIC OOM assertion runs against the live library
for now); indexing could later back the gallery grid (currently `photo_manager`
direct).

## Context

Search currently covers only metadata (date / media-type / album / favorites)
because there is no ML index — `docs/spec.md#data-model` defers `photo_asset` /
`photo_label` to "a later schema version." This slice builds that index: an
on-device, background-isolate image-labeling pipeline that populates
`photo_label`, then wires those labels into the Search screen so text queries
like "dog" or "beach" return matching photos. Faces/OCR are deferred to later
slices.

Hard constraints (CLAUDE.md Absolute rules):
- **Zero network** — ML Kit must use its **bundled** image-labeling model (no
  Play-Services model download). After adding the dep, re-verify the release
  merged manifest is free of `INTERNET` and strip it with `tools:node="remove"`
  if injected (same pattern already used for `video_player`).
- **All ML on a background isolate** — never the UI isolate.
- **Never decode originals for grid/ML** — feed ML a downsized JPEG **thumbnail**
  (via `PhotoLibraryService.thumbnail`), never the original (also dodges the
  48MP-HEIC OOM gotcha).
- **Index only in the foreground, pause when idle** — pause on lifecycle
  `inactive`/`paused`, resume on `resumed` (no OS background task).

## Approach

### 1. Schema v2 (`lib/core/database/tables.dart` + `app_database.dart`)
Add two tables (drift):
- `PhotoAssets` — the indexed-asset cache / cursor. Columns: `assetId` (text PK),
  `createdAt` (DateTime), `isVideo` (bool), `width` (int), `height` (int),
  `indexedAt` (DateTime). A row means "this asset has been through indexing."
- `PhotoLabels` — one row per label: `id` (autoInc PK), `assetId` (text,
  `references PhotoAssets(assetId) onDelete: cascade`), `label` (text),
  `confidence` (real). Add drift indexes on `PhotoLabels.assetId` and
  `PhotoLabels.label` for the search query.

Bump `schemaVersion` to 2; extend `MigrationStrategy.onUpgrade` (`from==1`) to
`m.createTable(photoAssets); m.createTable(photoLabels)`. Register both tables
(and a new `IndexDao`) on `@DriftDatabase`. Then: `drift_dev schema dump` →
`drift_schemas/drift_schema_v2.json`; `drift_dev schema generate` →
`test/core/database/generated_migrations/schema_v2.dart`; add a v1→v2 case to
`test/core/database/migration_test.dart` (DoD #4).

### 2. `IndexDao` (`lib/core/database/daos/index_dao.dart`)
`@DriftAccessor([PhotoAssets, PhotoLabels, Favorites])`. Reuse the
`FavoritesDao` write idioms (`insertOrReplace`, `..where`). Methods:
- `Future<Set<String>> indexedAssetIds()` — all `photo_asset.assetId` (the
  orchestrator subtracts these from the library's ids to find work).
- `Future<void> upsertIndexed(PhotoAssetRow meta, List<(String,double)> labels)`
  — in one transaction: upsert the `photo_asset` row, delete its old labels,
  insert the new ones (re-index safe).
- `Future<List<AssetRef>> searchByLabel({required String query, DateTime? min,
  DateTime? max, required MediaTypeFilter type, required bool favoritesOnly,
  required int limit, required int offset})` — join `photo_label` ⋈
  `photo_asset` (⋈ `favorites` when `favoritesOnly`), `WHERE label LIKE
  '%'||?||'%'` plus the date/type/favorites predicates, `GROUP BY assetId`,
  `ORDER BY createdAt DESC`, paginated. Returns `AssetRef`s (id + createdAt).
- `Future<int> unindexedCount(Set<String> libraryIds)` helper for status
  (computed in the service from `indexedAssetIds`).

### 3. ML worker (`lib/services/ml_service.dart`)
`MlWorkerController` (main isolate): lazily spawns one long-lived worker isolate
via `Isolate.spawn`, handing it the `RootIsolateToken`. Exposes
`Future<List<(String label, double confidence)>> labelFile(String jpegPath)` and
`void dispose()`. Worker entrypoint:
`BackgroundIsolateBinaryMessenger.ensureInitialized(token)` **first** (the
known isolate-binding-hang gotcha — this must run before any plugin call), then
a reusable `ImageLabeler(ImageLabelerOptions(confidenceThreshold: 0.6))`
processing `InputImage.fromFilePath(path)` and replying with labels. Plain-class
result types (no plugin types cross the port beyond the reply records).

### 4. `IndexingService` (`lib/services/indexing_service.dart`, keep-alive)
Root-scoped provider (like `databaseProvider`). Orchestrates on the **main**
isolate:
- Compute `todo = libraryAssetIds − indexDao.indexedAssetIds()`. Gets library
  ids from a new lightweight `PhotoLibraryService.allAssetIds()` (paged id-only
  scan; add it beside `searchAssets`).
- For each asset (small batches, yielding between): `thumbnail(id, 512, 512)` →
  write bytes to a temp file (`path_provider` temp dir) → `worker.labelFile` →
  `indexDao.upsertIndexed(meta, labels)` → delete temp file. `meta` fields
  (isVideo/size) come from a cheap `PhotoLibraryService` lookup (reuse
  `isVideoAsset`; width/height from the entity — add a tiny `assetMeta(id)` or
  extend an existing call).
- `pause()` / `resume()` / cancellation flag; `start()` is idempotent and no-ops
  without library access. Exposes `ValueNotifier<IndexingStatus>` (or a
  `StreamController`) → `indexingStatusProvider` (remaining / total).
- Logging via `SoloGallery.ml` (`package:logging`).

### 5. Lifecycle + kickoff (`lib/app.dart`)
The existing `WidgetsBindingObserver` gains: `resumed` → `indexing.resume()`;
`inactive`/`paused` → `indexing.pause()`. Kick `indexing.start()` once access is
granted (watch `permissionProvider`; start when `canReadLibrary`). Keep the
existing permission-refresh-on-resume.

### 6. Content search wiring (`lib/features/search/search_providers.dart`)
Extend `SearchAssetsNotifier` (built last slice on `PagedAssetsNotifier`): in
`fetchPage`, branch on the query —
- **non-empty, non-date text** → `indexDao.searchByLabel(...)` (content search;
  date/type/favorites facets pushed into SQL). This replaces the old "idle when
  text isn't a date" gap so "dog" now returns photos.
- **date-only / facet-only** (no text) → the existing `photo_manager`
  `searchAssets` / `resolveFavoriteMatches` path (unchanged).
Update the screen's idle definition accordingly and add a subtle
`indexingStatusProvider` note in Search ("Still indexing your library — results
will improve") while `remaining > 0`.

### 7. Dependency + manifest
Add `google_mlkit_image_labeling` to `pubspec.yaml`. After `pub get` + a debug
build, run the release-manifest check (DoD #5 / CLAUDE.md); if `INTERNET` (or
Play-Services network perms) merges in, strip via `tools:node="remove"` in
`android/app/src/main/AndroidManifest.xml`. Confirm the model is bundled (no
runtime download) so runtime stays network-free.

## Files
- New: `lib/core/database/daos/index_dao.dart`,
  `lib/services/ml_service.dart`, `lib/services/indexing_service.dart`,
  `drift_schemas/drift_schema_v2.json`,
  `test/core/database/generated_migrations/schema_v2.dart`.
- Edit: `lib/core/database/tables.dart`, `lib/core/database/app_database.dart`,
  `lib/core/database/database_provider.dart` (add `indexDaoProvider`),
  `lib/services/photo_library_service.dart` (`allAssetIds`, asset meta),
  `lib/app.dart`, `lib/features/search/search_providers.dart`,
  `lib/features/search/search_screen.dart`, `pubspec.yaml`,
  possibly `android/app/src/main/AndroidManifest.xml`.
- Tests: `test/core/database/index_dao_test.dart`,
  `test/core/database/migration_test.dart` (v1→v2 case),
  `test/features/search/search_providers_test.dart` (content-search branch),
  `test/services/indexing_service_test.dart` (fake worker + fake photo service),
  `test/support/fake_ml_worker.dart` (fake `MlWorkerController`),
  `integration_test/ml_indexing_test.dart` (real-isolate on-device).

## Tests (Test strategy tiers)
- **Unit — DAO (in-memory drift, FK on):** `upsertIndexed` insert + re-index
  overwrite + cascade delete; `indexedAssetIds`; `searchByLabel` across each
  facet (label match, date window, media type via `isVideo`, favorites join,
  pagination).
- **Migration:** `SchemaVerifier` v1→v2 against the committed v2 dump.
- **Provider (`ProviderContainer`, real async):** `searchAssetsProvider`
  content-search branch over a seeded in-memory DB + fake photo service; the
  date-only path still uses `photo_manager`. Heed the Riverpod-3 test traps
  (no awaiting an autoDispose `StreamProvider.future`; scheduler-batched
  recompute needs a real timer turn — both now in CLAUDE.md).
- **Service (host, fake worker):** `IndexingService` orchestration — unindexed
  cursor, batching, `pause()`/`resume()`, idempotent `start()`, no-op without
  access. Uses `FakeMlWorkerController` (returns canned labels).
- **Fake-pairing (REQUIRED):** `FakeMlWorkerController` is paired with
  `integration_test/ml_indexing_test.dart` — spawns the **real**
  `MlWorkerController`, indexes real device assets end-to-end, asserts
  `photo_label` rows are written and content search returns them. This is the
  binding-hang / real-model proof the fake can't give. (HEIC-specific OOM
  assertion wants the seeded `test_assets/` HEIC — still unpopulated; noted as a
  follow-up, run against the live library meanwhile.)

## Verification
1. `tool/check.sh` green — analyze, `build_runner` (new schema codegen),
   migration test, DAO/provider/service host tests.
2. Release merged-manifest check network-free after adding ML Kit (DoD #5).
3. `flutter test integration_test/ml_indexing_test.dart -d 46121FDAS008AA` green
   on the Pixel 9 Pro XL — real isolate + bundled model + DB write.
4. Manual e2e on device: launch, let indexing run (watch `SoloGallery.ml` logs
   via `flutter logs`), then search a concrete label ("dog"/"car"/"food") and
   confirm matching photos; background/foreground to confirm pause/resume.
5. Update `docs/plans/` (mark slice complete) + `CHECKPOINT.md`; record any new
   gotcha (expect one around ML Kit isolate init or the manifest).

## Decisions / notes
- **photo_asset kept lean** (assetId, createdAt, isVideo, w/h, indexedAt) — only
  what indexing + label search consume now; GPS/modified/duration deferred until
  a consumer needs them (spec warns against committing the shape prematurely).
- **Labels returned to the main isolate to write** (small payload); the worker
  does ML only. DB access stays single-isolate (no multi-isolate drift setup).
- **Grid still reads `photo_manager` directly** — this slice does not move the
  gallery onto `photo_asset`; that's a separate later change.
- Faces/OCR, `face_embedding`, the People screen, and tflite are out of scope.
