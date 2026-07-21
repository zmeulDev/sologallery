# ML/Indexing slice 2 — OCR + faces/people

Status: **COMPLETE** (2026-07-18). All three parts done. `tool/check.sh` green
(**190 host tests**: clustering unit, faces/index DAO, migration v1→v2→v3,
provider content-search, People widgets, fake-worker service incl. clustering);
`integration_test/ml_indexing_test.dart` green on the Pixel 9 Pro XL (real isolate
running label + OCR + face-detect + **tflite** embed, writing photo_text +
face_embeddings). Release manifest re-verified network-free after stripping ML
Kit / tflite injected perms (c2dm, READ_PHONE_STATE, WRITE_EXTERNAL_STORAGE).
Deps added: google_mlkit_text_recognition, google_mlkit_face_detection,
tflite_flutter, image; asset assets/models/mobilefacenet.tflite (BSD-3, attributed
in assets/models/README.md). Next step: none. Follow-ups — periodic global
re-cluster (v1 is incremental nearest-centroid), higher-res OCR pass, tighter
face-avatar crop (stores box in 512-thumb coords), and seed test_assets/ for the
HEIC OOM assertion (currently runs against the live library).

## Context

Slice 1 built the indexing pipeline (background-isolate `MlWorkerController`,
`IndexingService`, `IndexDao`, schema v2 `photo_asset`/`photo_label`) and content
search over image labels. This slice extends the *same* pipeline with two more
on-device signals: **OCR** (text in photos → searchable) and **faces/people**
(detect + embed faces, cluster into people, browse/name them). Both reuse the
existing isolate, indexer, migration harness, and search wiring — the new work is
two more models, schema v3, clustering math, and a People feature.

Hard constraints (unchanged): **zero network** (all models bundled/on-device;
re-verify the release manifest and strip any injected Play-Services push perms as
in slice 1), **all ML on the background isolate**, **feed ML a downsized
thumbnail** (never originals), **pause indexing when backgrounded**.

Sequenced so it stays checkpointable: **Part A (OCR)** → **Part B (face
detect+embed+cluster)** → **Part C (People UI)**. One branch, verified together.

## Dependencies + assets
- `google_mlkit_text_recognition` (bundled Latin model).
- `google_mlkit_face_detection` (bundled).
- `tflite_flutter` (FFI — runs in the isolate with no messenger).
- `image` (pure-Dart decode/crop/resize of face boxes in the isolate).
- Asset `assets/models/mobilefacenet.tflite` (~5 MB, 112×112×3 → Float32 192-d
  embedding). Fetched at build time from a known licensed source
  (MobileFaceNet, e.g. `MCarlomagno/FaceRecognitionAuth`); **confirm the license
  before committing** and record it in `assets/models/README.md`. Runtime never
  hits the network — the model ships in the APK. Declare it under `flutter:
  assets:` in `pubspec.yaml`.

## Part A — OCR

### Schema v3 (`tables.dart`, `app_database.dart`)
Add `PhotoTexts`: `assetId` (text PK, `references PhotoAssets onDelete: cascade`),
`text` (text). One row per asset holding the recognized text. Bump to v3;
`onUpgrade (from<3)` creates it. Dump v3 + generate + migration test v2→v3.

### Worker + indexer
Widen `MlWorker` from `labelFile` to `analyzeFile(path)` returning an
`ImageAnalysis` record `(labels, text, faces)` — one file decode, all models in
one round-trip. The worker adds a reusable `TextRecognizer(script: latin)`.
`IndexDao.upsertIndexed` also writes the `photo_text` row. (Faces handled in
Part B extend the same record.)

### Search
Rename/extend `IndexDao.searchByLabel` → `searchContent`: match
`photo_label.label LIKE` **OR** `photo_text.text LIKE` (LEFT JOIN `photo_text`),
same date/type/favorites facets, deduped per asset. `SearchAssetsNotifier`'s
content branch calls it unchanged otherwise.

## Part B — faces: detect + embed + cluster

### Schema v3 (continued)
- `Persons`: `id` (autoInc PK), `displayName` (text nullable), `coverAssetId`
  (text nullable), `createdAt`.
- `FaceEmbeddings`: `id` (autoInc PK), `assetId` (`references PhotoAssets
  cascade`), `personId` (int nullable, `references Persons onDelete: setNull`),
  `embedding` (blob — `Float32List` bytes), `left`/`top`/`right`/`bottom` (int,
  box in the 512-thumb coordinate space so avatars can crop it). Index on
  `personId` and `assetId`.

### Worker
The isolate loads the tflite model once (model bytes passed at spawn via the
existing `_WorkerInit`, `Interpreter.fromBuffer`). In `analyzeFile`: run
`FaceDetector.processImage` (ML Kit, needs the already-initialized messenger) →
for each `face.boundingBox`, decode the thumbnail with `image`, crop+resize to
112×112, normalize, `interpreter.run` → 192-d `Float32List`. Return
`faces: List<(Rect box, Float32List embedding)>`.

### Clustering (pure-Dart domain, unit-tested)
`lib/features/people/domain/face_clustering.dart`: cosine similarity + an
incremental greedy assigner — for each new face, compare to each existing
person's centroid (mean embedding); assign to the nearest above a tuned cosine
threshold (~0.65), else create a new person. Deterministic; no Flutter/plugin
imports. Centroid recompute lives in a DAO helper.

### Indexer + DAO
`IndexDao` (extend or a sibling `FacesDao`): `insertFaces`, `assignPersonToFace`,
`personCentroids`, `watchPersons` (cover + face count), `assetIdsForPerson`,
`renamePerson`. After a batch's embeddings are written, `IndexingService` runs
the incremental clustering assignment for the new faces.

## Part C — People UI (`lib/features/people/`)
- `/people` — grid of person cards (circular face-crop avatar + count),
  reusing `AlbumCard`'s card pattern + `MonthSectionHeader`. New `FaceAvatar`
  widget: loads the asset thumbnail and `ClipOval`+`Align`/scale to the stored
  box.
- `/person/:id` — that person's photos via `AssetGrid`; app-bar rename action
  (`Persons.displayName`), title falls back to "Unnamed".
- **Entry point** (bottom nav is spec-fixed at 4 tabs, unchanged): a **People
  strip** on the Search screen's idle state — a horizontal row of `FaceAvatar`s
  with a "See all" → `/people`. Natural discovery home, no nav change.
- Providers mirror `albums_providers.dart` (stream summaries / person / entries /
  rename action). Routes added to `app_router.dart` (pushed, like `/album/:id`).

## Files (representative)
- Edit: `pubspec.yaml` (3 deps + model asset), `lib/core/database/tables.dart`,
  `app_database.dart` (v3 + migration), `database_provider.dart`,
  `lib/services/ml_service.dart` (text + face models, `analyzeFile`,
  model-bytes init), `lib/services/indexing_service.dart` (write text/faces,
  run clustering), `lib/core/database/daos/index_dao.dart` (`searchContent`,
  text/faces writes), `lib/features/search/search_providers.dart` +
  `search_screen.dart` (People strip), `app_router.dart`,
  `android/app/src/main/AndroidManifest.xml` (re-verify/strip),
  `android/build.gradle.kts` (only if a new module needs Java-target matching).
- New: `lib/core/database/daos/faces_dao.dart` (or extend IndexDao),
  `lib/features/people/domain/face_clustering.dart`,
  `lib/features/people/people_providers.dart`,
  `lib/features/people/people_screen.dart`,
  `lib/features/people/person_detail_screen.dart`,
  `lib/features/people/widgets/face_avatar.dart`,
  `assets/models/mobilefacenet.tflite` (+ `README.md` license),
  `drift_schemas/drift_schema_v3.json`, `.../generated_migrations/schema_v3.dart`.

## Tests (Test strategy tiers)
- **Unit (host):** `face_clustering` — cosine, assignment above/below threshold,
  new-cluster creation, determinism. Pure Dart.
- **DAO (in-memory drift):** `photo_text` write + cascade; `searchContent`
  matches label OR text (+ facets); faces insert / `assignPerson` /
  `assetIdsForPerson` / `renamePerson` / cascade; `personCentroids`.
- **Migration:** `SchemaVerifier` v2→v3 (and existing v1→v2) vs committed dump.
- **Provider (`ProviderContainer`):** content search now also hits OCR text;
  People summary/detail providers over a seeded in-memory DB. (Heed the
  Riverpod-3 test traps already in CLAUDE.md.)
- **Widget (host):** `people_screen`/`person_detail` states; Search idle People
  strip renders when persons exist; `FaceAvatar` golden (light/dark).
- **Service (host, fake worker):** `IndexingService` writes text+faces and runs
  clustering; extend `FakeMlWorker` to return canned text + face embeddings.
- **Fake-pairing (REQUIRED, on-device):** extend/add
  `integration_test/ml_indexing_test.dart` to exercise the **real** isolate
  running all three models (label + OCR + face detect/embed) on device incl. a
  HEIC asset — asserts `photo_text` and `face_embeddings` rows and that clustering
  groups the same person. The isolate-binding-hang / HEIC-OOM / tflite-in-isolate
  proof the fake can't give.

## Verification
1. `tool/check.sh` green (analyze, v3 codegen, migration, DAO/clustering/provider/
   widget/service tests).
2. Release merged-manifest network-free after adding the two ML Kit deps (DoD #5)
   — strip any injected Play-Services push perms (slice-1 pattern).
3. On-device `integration_test/ml_indexing_test.dart` green on the Pixel 9 Pro XL
   (real 3-model isolate + tflite + DB + clustering).
4. Manual e2e: let indexing run; search photo text; open People, confirm a
   cluster, rename a person, open their photos.
5. Update `docs/plans/` + `CHECKPOINT.md`; record new gotchas (expect: tflite
   model asset/init in isolate, `image`-based face crop, face_detection manifest
   perms, clustering threshold tuning).

## Decisions / notes
- **One decode, all models** per asset in the isolate (label + OCR + faces) — the
  file is read once; `analyzeFile` returns everything.
- **Incremental clustering** (nearest-centroid) over global re-clustering — cheap,
  deterministic, good enough for v1; a periodic re-cluster is a later refinement.
- **Face box stored in 512-thumb coords** so `FaceAvatar` crops from the same
  thumbnail the grid already caches (no original decode).
- **People entry via the Search idle strip**, not a 5th bottom-nav tab (nav is
  spec-fixed). Revisit if People grows.
- **OCR on the 512 thumbnail** may miss tiny text — acceptable v1; higher-res OCR
  pass is a follow-up. `test_assets/` still unseeded (HEIC runs against the live
  library).
- If sequencing runs long, Part A (OCR) is independently shippable and can be
  committed before Part B/C.
