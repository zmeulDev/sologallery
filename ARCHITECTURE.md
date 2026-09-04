# SoloGallery — Architecture

How the app is built. For *what* it is and why, see [PRD.md](PRD.md). For the
rules an agent must follow while changing it, see [AGENTS.md](AGENTS.md). For
visual language, see [docs/design-system.md](docs/design-system.md). For traps
that have already cost a day, see [docs/gotchas.md](docs/gotchas.md).

SoloGallery is a privacy-first, fully on-device photo manager for Android and
iOS. There are **zero network calls** after install. All processing — indexing,
image labeling, OCR, face detection and clustering, memory curation — happens on
the device.

---

## Contents

- [Layers](#layers) · [Data model](#data-model) · [Routing](#routing)
- [Isolate model](#isolate-model) · [Thumbnail caching stack](#thumbnail-caching-stack)
- [ML pipeline](#ml-pipeline) · [A traced read path](#a-traced-read-path)
- [Project structure](#project-structure) · [Test strategy](#test-strategy)

---

## Layers

Three layers, one dependency direction:

```
UI  ──▶  Domain  ◀──  Data
        (pure Dart)
```

UI depends on Domain. Data depends on Domain. Domain depends on nothing Flutter-
or plugin-specific. Layers are wired with Riverpod providers — never by direct
construction inside a widget.

### UI — `lib/features/*`, `lib/widgets/*`

Widgets and Riverpod consumers only. Anything past layout and interaction
belongs in a provider or a service. Async state is consumed as `AsyncValue`
through `when(...)` or an exhaustive `switch`, and every screen renders explicit
**loading / error / empty / data** branches. `.value!` appears nowhere in the
codebase.

`features/*` is one folder per screen or feature; `widgets/*` holds the shared
design-system components. Screen-scoped providers are `autoDispose`.

Side effects live in `*Actions` classes exposed as plain `Provider`s
(`DetailActions`, `PeopleActions`, `AlbumActions`, `MemoryActions`) rather than
inside widget callbacks.

> **House exception to the `when(...)` rule.** A number of sites read a
> feature-flag or count as `ref.watch(x).value ?? fallback` — booleans and
> counts that compose synchronously inside a `Stack` or a `Consumer`, where
> blocking on `when(...)` would flash a spinner over already-cached pixels, or
> where the caller needs a `bool` rather than a `Widget`. These fail closed to a
> sensible default and carry a comment at nearly every site. This is deliberate
> and accepted; `.value!`, which throws, is not.

### Domain — pure Dart

Plain models and logic with **no Flutter imports and no plugin imports**. Unit
testable on the host with zero mocking of infrastructure. Verified clean: no
`package:flutter` import exists under any `features/*/domain/`.

| File | What it computes |
|---|---|
| `library/domain/library_timeline.dart` | flattens month/year counts into timeline rows |
| `library/domain/year_month.dart` | year-month value type + route-key codec |
| `library/domain/library_filter.dart` | the four filter pill states |
| `detail/domain/adjacent_ids.dart` | which neighbours to pre-warm |
| `detail/domain/asset_detail_display.dart` | EXIF value formatting |
| `detail/domain/zoom_transform.dart` | focal-point zoom matrix |
| `people/domain/face_clustering.dart` | cosine similarity, average-linkage agglomeration, incremental assignment |
| `memories/domain/memory_builder.dart` | memory scoring and selection |
| `memories/domain/memory_kind.dart`, `planned_memory.dart` | memory value types |
| `saved/domain/masonry_layout.dart` | column-balanced masonry placement |
| `search/domain/search_date.dart` | date-phrase parsing |

### Data — `lib/services/*`, `lib/core/database/*`

The only layer that touches persistence or native plugins.

`photo_library_service.dart` is the **sole** `photo_manager` wrapper — verified:
no other file in `lib/` imports the plugin. App-wide services (database, photo
library, indexing, ML worker) are kept alive at the root; only screen-scoped
state is `autoDispose`.

| Service | Owns | Provider | Lifetime |
|---|---|---|---|
| `PhotoLibraryService` | all `photo_manager` access: permissions, queries, thumbnails, delete, share, video | `photoLibraryServiceProvider` | keepAlive |
| `PermissionNotifier` | `PhotoAccess` state | `permissionProvider` | keepAlive |
| `IndexingService` | metadata sweep, ML pass loop, clustering and memory triggers, consent side effects, pause/resume | `indexingServiceProvider` | keepAlive |
| `MlWorkerController` | the ML isolate: spawn, protocol, graceful shutdown | `mlWorkerProvider` | keepAlive |
| `ThumbnailDiskCache` | persistent JPEG cache for grid thumbnails | internal to `PhotoLibraryService` | — |
| `ThumbnailGate` | concurrency cap + cancel-aware queue for native decodes | two internal instances | — |
| `DetailPreviewCache` | in-memory LRU of screen-sized previews (cap 20) | internal | — |
| `AdjacentThumbnailCache` | in-memory LRU of neighbour placeholders (cap 16) | internal | — |
| `PagedAssetsNotifier` | one-shot page-append pagination base | subclassed | `autoDispose` |
| `WatchedAssetsNotifier` | reactive growing-window pagination base | subclassed | `autoDispose` |

`thumbnailProvider`, `adjacentThumbnailProvider` and `videoDurationProvider` are
`FutureProvider.autoDispose.family` wrappers over `PhotoLibraryService`.
`indexingStatusProvider` and `libraryCacheReadyProvider` are `StreamProvider`s
exposing the keep-alive indexing service's streams.

The two pagination bases look similar but are not duplicates: `PagedAssetsNotifier`
appends fixed pages once (Search), `WatchedAssetsNotifier` re-subscribes a single
growing live window so ongoing sweeps, ML writes and deletions re-emit into the
grid (every Library grid).

### Cross-cutting rules

- **Never duplicate photos** — everything references `photo_manager` asset ids.
  Favorites, album membership, faces and edits are all keyed by asset id.
- **Non-destructive edits only** — edits are serialized JSON in
  `edit_instructions`; originals are never modified.
- **Never decode originals for grid cells** — thumbnails come from
  `photo_manager` at an explicit `ThumbnailSize`.
- **Zero network** — no HTTP client, no Firebase, no analytics, no cloud SDK.

---

## Data model

Drift (SQLite), one connection via `driftDatabase(name: 'sologallery')`.
`PRAGMA foreign_keys = ON` is set in `beforeOpen` — SQLite defaults it off and
the cascades depend on it.

**Current schema version: 10** (`lib/core/database/app_database.dart`). Every
upgrade path to the current version is covered by a `SchemaVerifier` migration
test against the committed dumps in `drift_schemas/` (`v1` … `v10`).

### User-authored state

The only tables that must exist before ML indexing.

| Table | Key | Columns | Notes |
|---|---|---|---|
| `favorites` | `assetId` (PK) | `favoritedAt` | favorite flag keyed by asset id, so it works before indexing |
| `albums` | `id` (autoInc PK) | `name`, `coverAssetId?`, `createdAt`, `sortIndex` | user albums |
| `album_entries` | `id` (autoInc PK) | `albumId`→`albums.id` (cascade), `assetId`, `addedAt`; UNIQUE(`albumId`,`assetId`) | membership by asset-id reference |
| `edit_instructions` | `assetId` (PK) | `instructionsJson`, `updatedAt` | non-destructive edit JSON. **Scaffolding — the editor UI is not built; see [PRD.md](PRD.md#planned-non-destructive-editor)** |

### Indexing + ML

All derived, all rebuildable from the photo library.

| Table | Key | Columns | Notes |
|---|---|---|---|
| `photo_assets` | `assetId` (PK) | `createdAt`, `isVideo`, `width`, `height`, `isDated`, `indexedAt?` | indexing cursor + lean cached metadata. `indexedAt IS NULL` means metadata swept but ML pending, so remaining work is exactly the NULL rows. `isDated` is false only for Android undated assets, which route to the "Older" bucket. Compound index `photo_asset_dated_created` on (`isDated`, `createdAt`) |
| `photo_labels` | `id` (autoInc PK) | `assetId`→`photo_assets` (cascade), `label`, `confidence` | ML Kit image labels, one row per (asset, label). Indexed on `assetId` and `label` |
| `photo_texts` | `assetId` (PK) | `content` | on-device OCR. The column is `content`, not `text` — a Drift column cannot reuse a builder name |
| `persons` | `id` (autoInc PK) | `displayName?`, `coverAssetId?`, `createdAt`, `mergedInto?`→`persons.id` (setNull) | face clusters. `mergedInto` is a **redirect, not a move**: the absorbed row keeps its faces, which is what makes a user merge survive the periodic global re-cluster |
| `face_embeddings` | `id` (autoInc PK) | `assetId`→`photo_assets` (cascade), `personId?`→`persons` (setNull), `embedding` (blob), `left`, `top`, `right`, `bottom` | box edges are **fractions in `[0, 1]`**, never pixels — a pixel box is meaningless without the dimensions it was measured against. Indexed on `assetId` and `personId` |

### Preferences, memories, history

| Table | Key | Columns | Notes |
|---|---|---|---|
| `app_settings` | `key` (PK) | `value` | generic key/value prefs — `theme_mode`, the three consent flags, the consent-version marker, excluded folder ids. Never `shared_preferences` (Drift-for-all-persistence rule) |
| `memories` | `id` (autoInc PK) | `sourceKey` (unique), `kind`, `title`, `subtitle?`, `coverAssetId?`→`photo_assets` (setNull), `score`, `periodStart?`, `periodEnd?`, `generatedAt`, `seenAt?`, `hidden` | auto-curated collections. Regeneration **upserts on `sourceKey`** rather than wiping the table, so `seenAt`/`hidden` survive and the carousel never reshuffles under the user |
| `memory_entries` | `id` (autoInc PK) | `memoryId`→`memories` (cascade), `assetId`→`photo_assets` (cascade), `position`; UNIQUE(`memoryId`,`assetId`) | ordered membership. Indexed on `memoryId` |
| `recently_viewed` | `assetId` (PK) | `viewedAt` | backs the Search screen's "recently viewed" row |

### Version history

| v | Change |
|---|---|
| 1 | `favorites`, `albums`, `album_entries`, `edit_instructions` |
| 2 | + `photo_assets`, `photo_labels` |
| 3 | + `photo_texts`, `persons`, `face_embeddings` |
| 4 | `photo_assets.indexed_at` → nullable; + `photo_assets.is_dated` |
| 5 | + `app_settings` |
| 6 | + `memories`, `memory_entries` |
| 7 | `face_embeddings` boxes → normalized `[0, 1]` reals; existing faces and clusters are dropped and re-derived (pixel values cannot be converted — the dimensions they were relative to were never stored, which *is* the bug) |
| 8 | + `persons.merged_into` |
| 9 | + compound index `photo_asset_dated_created` on `photo_assets(is_dated, created_at)` |
| 10 | + `recently_viewed` |

### DAOs

`lib/core/database/daos/`, all reached through the keep-alive `databaseProvider`.

| DAO | Owns |
|---|---|
| `FavoritesDao` | favorite flag CRUD and watch |
| `AlbumsDao` | album CRUD, membership, `watchAlbumSummaries` (cover = explicit, else newest photo) |
| `IndexDao` | metadata sweep upsert/prune, the ML-pending cursor, every Library grid query (month/year/day/older/recent — counts, previews, paged and watched windows), Saved, recently-viewed, and Search's label tally + content `LIKE` |
| `FacesDao` | face embedding CRUD, incremental and global clustering persistence, person merge/unmerge via a `COALESCE` redirect chain, People UI queries |
| `MemoriesDao` | memory read side, plan-generation input projections, `applyPlan` (upsert by `sourceKey`, preserving `seenAt`/`hidden`) |
| `SettingsDao` | typed helpers over the k/v table: theme mode, three consent flags + consent version, excluded folder ids |
| `EditInstructionsDao` | edit JSON CRUD. **Registered in `@DriftDatabase` but has no provider and no callers** — see [PRD.md](PRD.md#planned-non-destructive-editor) |

> **Before adding v11**, re-read the migration trap in
> [docs/gotchas.md](docs/gotchas.md) (Drift section): `m.createTable` builds the
> **current** shape, so any table whose columns change after it was introduced
> needs an `else if` guard on the later step. That is why `photo_assets` (v4),
> `face_embeddings` (v7) and `persons` (v8) each have one.

---

## Routing

GoRouter, with a `StatefulShellRoute.indexedStack` for the four bottom-nav tabs
so each tab keeps its own state. The shell (`lib/widgets/app_shell.dart`) renders
the active branch plus `NavPillBar` and its trailing `IndexingDial`.

A root `redirect` on `permissionProvider` + `consentProvider` sends first-run
users to onboarding.

**Shell branches (bottom nav):**

| Screen | Route |
|---|---|
| Library (home grid) | `/` |
| Search | `/search` |
| Saved (favorites) | `/saved` |
| Albums | `/albums` |

**Root-navigator routes (outside the shell).** All carry
`parentNavigatorKey: _rootNavigatorKey` and `NoTransitionPage` — no push
animation, per the no-decorative-motion rule.

| Screen | Route |
|---|---|
| Onboarding | `/onboarding` (redirect target, not pushed) |
| Detail (full-screen viewer) | `/photo/:id` |
| Month grid | `/month/:key` |
| Year grid | `/year/:year` |
| Day grid | `/day/:date` |
| Older grid (undated assets) | `/older` |
| Album detail | `/album/:id` |
| Folder detail | `/folder?id=&name=` |
| People | `/people` |
| Person detail | `/person/:id` |
| Memory player | `/memory/:id` |
| Settings | `/settings` (pushed from the Library app bar) |
| Analysis settings | `/settings/analysis` |

Folder detail takes its id as a **query parameter, not a path segment** — an iOS
folder id is a `PHAssetCollection` local identifier and may contain `/`, which no
encoding makes safe in a `:id` segment. `name` only titles the app bar.

Settings is an app-bar affordance on Library, not a tab: it is visited rarely,
where Search earns a permanent slot. Because the Search branch outlives a visit,
its field takes focus from `searchTabActiveProvider` (published by the shell)
rather than `autofocus`, and releases it when the tab is left.

---

## Isolate model

The UI isolate never runs ML and never runs an unbounded computation.

### The long-lived ML worker

One isolate, spawned by `MlWorkerController._spawn` (`ml_service.dart`) and owned
by the keep-alive `mlWorkerProvider`. `IndexingService` never spawns it — it only
calls `worker.analyze(...)`.

- **Handoff.** `RootIsolateToken.instance` plus the TFLite model bytes (loaded
  through `rootBundle` on the main isolate, which is where the root binding
  lives) are passed in a `WorkerInit` record to `Isolate.spawn`. Inside the
  worker, `BackgroundIsolateBinaryMessenger.ensureInitialized(init.token)` runs
  **before any ML Kit call** — without it the platform channels hang forever.
  TFLite is FFI (`Interpreter.fromBuffer`) and needs no messenger.
- **Protocol.** A `ReceivePort`/`SendPort` pair. The worker's `commands.listen`
  processes `_AnalyzeJob` / `_ShutdownJob` sequentially, which is what guarantees
  shutdown only runs after any in-flight analysis finishes. Image bytes cross the
  port directly, so the UI isolate does no file I/O for ML; the worker writes and
  deletes its own temp JPEGs under a path resolved once at spawn.
- **Correlation.** A monotonic `id` per call and a `Map<int, Completer<ImageAnalysis>>`
  on the controller side resolve the right future on `_AnalyzeResult`/`_AnalyzeError`.
- **Shutdown.** `dispose()` sends `_ShutdownJob`, waits for `_ShutdownAck` (the
  worker has closed every model, so a kill is now safe), then force-kills after a
  short grace timer; a 60 s outer timer force-kills a stuck worker. An `onExit`
  port marks the controller torn down if the isolate dies unexpectedly.

### Throwaway compute isolates

Two pure computations are handed to `Isolate.run` rather than the worker, because
they are heavy but not ML:

- `_maybeGlobalRecluster` → `planClusters(clusterAll(...))` — quadratic in face count.
- `_planMemories` → `MemoryBuilder.build(...)` — plans over up to ~20k records.

### Lifecycle

`IndexingService` orchestrates on the **main** isolate; `pause()`/`resume()` flip
a `_paused` flag, and every long loop polls `_awaitNotPaused()` (200 ms) between
units of work. The worker isolate is never torn down on pause — only starved of
new jobs.

Wired from `app.dart`'s `WidgetsBindingObserver`:

- `resumed` → refresh `permissionProvider`, `indexingService.resume()`
- `inactive` / `paused` / `hidden` / `detached` → `indexingService.pause()`, and
  clear the two short-lived in-memory thumbnail LRUs

---

## Thumbnail caching stack

Two distinct tiers that deliberately do not share machinery.

### Grid path

`AssetThumbnail` → `thumbnailProvider(ThumbnailRequest(id, w, h))` → four layers:

1. **Riverpod `autoDispose.family` cache** — dedupes identical in-flight and
   recent requests per cell. Disposal sets a `disposed` flag forwarded as
   `cancelled`; it does not truly cancel the platform call.
2. **`ThumbnailGate`** — bounds concurrent native decodes (cap 6 for grid, a
   separate cap 3 for indexing). LIFO queue, and it re-checks `cancelled` both
   before and after queueing so a scrolled-off cell's completed-but-discarded
   decode does not count against real work.
3. **`ThumbnailDiskCache`** — grid only. Key `assetId:size:signature`, where the
   signature is `modifiedDateSecond`. On miss it decodes and persists
   fire-and-forget into `<app support>/thumb_cache/`; FIFO-by-mtime eviction at a
   200 MB budget, checked every 64 writes.
4. **Native decode** — `photo_manager`'s Glide/PhotoKit call, the actual pixel
   source on a full miss.

### Detail path

Bypasses the gate and the disk cache entirely — a different tier, screen-sized
and higher quality, with a much smaller working set.

- `previewImage` → `DetailPreviewCache` (memory LRU, cap 20, key
  `assetId:maxEdge`), with a `_previewPending` map deduping concurrent same-key
  fetches → native `thumbnailDataWithOption`.
- `adjacentThumbnail` → `AdjacentThumbnailCache` (memory LRU, cap 16, key
  `assetId`) → native fetch.

Both LRUs are cleared together on app-lifecycle background, not on a memory
pressure callback.

### Where the tiers touch

`PhotoLibraryService.thumbnail(..., indexing: true)`, used only by
`IndexingService`, skips the disk cache and runs through `_indexingGate`, which
itself calls `_thumbnailGate.whenQuiet()` first. A background indexing decode
therefore always yields the native decode pool to an in-flight foreground scroll
burst. Indexing thumbnails are never persisted — they are consumed once.

---

## ML pipeline

Per asset, in `IndexingService._indexOne`:

1. `photos.assetIndexMeta(id)` — cheap metadata read, no pixels. Bail if unresolvable.
2. If the asset's folder is not excluded and (`searchEnabled || facesEnabled`),
   fetch a **512×512** thumbnail via `photos.thumbnail(..., indexing: true)`.
3. If `searchEnabled`, additionally fetch a **1024×1024** thumbnail for OCR —
   it recovers small text the 512 misses. Labels and faces always stay on the
   512 image: bounded memory, and a stable normalized-box space.
4. `worker.analyze(...)` runs in the isolate, **sequentially**:
   image labeling (confidence ≥ 0.6) → OCR (Latin recognizer, on the OCR bytes if
   present) → face detection (`fast` mode, with landmarks) → a per-face pose gate
   (`faceIsUsable`: yaw ≤ 35°, roll ≤ 25°, both eyes and a nose landmark
   required) → for surviving faces only, decode the thumbnail once, crop and
   resize each face to 112×112 → MobileFaceNet TFLite embedding, normalized
   against the **actually decoded** image size, never a guessed constant.
5. Results are written together: `IndexDao.upsertIndexed` stamps `indexedAt`,
   batch-replaces the label set and replaces the OCR text; then `FacesDao.insertFaces`
   delete-and-reinserts that asset's faces.
6. **Clustering is decoupled** from per-asset indexing. After the batch loop,
   `_clusterNewFaces()` assigns unclustered faces to the nearest cluster (an
   in-memory decision pass, then one batched transaction).
   `_maybeGlobalRecluster()` re-runs clustering from scratch every 20 new faces,
   or on an algorithm-version bump, to undo incremental drift — reusing person
   rows so names and covers survive.
7. **Memories** are planned separately, after clustering, in
   `_maybeRegenerateMemories` (daily, or every 50 new assets), from
   already-persisted labels, clusters and dates. No ML re-run.
8. **Progress** is broadcast as `IndexingStatus(remaining, total)`, throttled to
   one emit per 250 ms with an unconditional final `remaining: 0`, and consumed
   by `IndexingDial`. A separate `watchSwept()` / `libraryCacheReadyProvider`
   boolean tells the Library grid when the first **metadata sweep** finished, so
   it shows a spinner instead of a false "No photos" empty state.

Consent changes are applied in a single DB transaction (`SettingsDao.setConsent`),
specifically to close a first-run race where `IndexingService` could read the
flags mid-write and permanently skip a feature.

---

## A traced read path

Library grid loading a month section, end to end:

1. `LibraryScreen` under the `all` or `months` filter watches
   `libraryMonthCountsProvider`, which watches `permissionProvider` and, if the
   library is readable, subscribes to `IndexDao.watchMonthCounts()` — a grouped
   `STRFTIME('%Y-%m', created_at, 'unixepoch', 'localtime')` over
   `photo_assets WHERE is_dated`, served by the `photo_asset_dated_created`
   index. Wrapped in `_keepAliveAfterFirst` so the Drift stream and its
   downstream thumbnail requests survive scroll-induced provider churn.
2. Each visible month section independently subscribes to
   `monthPreviewsProvider(YearMonth)` → `IndexDao.watchMonthPreviews(month, limit: 6)`
   for its ≤6 preview cells.
3. Tapping the section header navigates to `/month/:key` → `MonthGridScreen` →
   `monthAssetsProvider(month)`, an `AsyncNotifierProvider.autoDispose.family`
   over `WatchedAssetsNotifier`. `build()` subscribes at `limit = 90`;
   `loadMore()` grows the limit and re-subscribes — a single live window rather
   than offset paging, so sweeps, ML writes and deletions re-emit into the grid.
4. Each `AssetRef` (id + `createdAt` only — no plugin types) renders as an
   `AssetThumbnail`, which reads `thumbnailProvider` → `PhotoLibraryService.thumbnail()`
   → gate → disk cache → native decode, and the bytes flow back through the
   `FutureProvider.autoDispose`.
5. Underneath, `IndexingService._sweepMetadata` (paged 500 at a time) is what
   populated `photo_assets` in the first place, and the ML pass backfills
   `indexedAt`, labels and faces asynchronously. The grid never blocks on ML —
   only `libraryCacheReadyProvider` gates the empty state.

---

## Project structure

```text
lib/
  main.dart
  app.dart                          # ThemeData, router, root providers, lifecycle observer
  core/
    theme/                          # app_colors, app_text_styles, app_radius, app_space, app_theme
    router/                         # GoRouter config
    format/                         # count_labels.dart
    database/                       # app_database, tables, database_provider
      daos/                         # 7 DAOs
    logging_config.dart             # the one sanctioned debugPrint sink
  features/
    albums/ detail/ folders/ library/ memories/
    onboarding/ people/ saved/ search/ settings/
      domain/                       # pure Dart (where the feature has logic)
      widgets/                      # feature-local widgets
  services/
    photo_library_service.dart      # the sole photo_manager wrapper
    permission_provider.dart        # library-access state
    thumbnail_provider.dart         # per-request Riverpod wrappers
    thumbnail_disk_cache.dart       # persistent grid-thumbnail cache
    thumbnail_gate.dart             # native-decode concurrency cap
    detail_preview_cache.dart       # screen-sized preview LRU
    adjacent_thumbnail_cache.dart   # neighbour placeholder LRU
    paged_assets_notifier.dart      # one-shot pagination base (Search)
    watched_assets_notifier.dart    # reactive growing-window base (Library grids)
    ml_service.dart                 # ML isolate: ML Kit + TFLite
    indexing_service.dart           # background indexing orchestration
  widgets/                          # 20 shared design-system components
    app_shell.dart nav_pill_bar.dart indexing_dial.dart
    app_button.dart app_card.dart app_dialog.dart app_sheet.dart
    asset_grid.dart asset_thumbnail.dart circle_icon_button.dart
    consent_switch.dart cover_row.dart empty_state.dart filter_pill.dart
    folder_list.dart limited_access_banner.dart people_strip.dart
    precache_adjacent.dart section_header.dart segmented_control.dart
test/                               # unit + widget + golden, mirrors lib/
integration_test/                   # 17 on-device patrol tests
patrol_test/                        # patrol harness entrypoint
test_assets/                        # seeded device assets
drift_schemas/                      # v1 … v10 schema dumps
tool/check.sh                       # analyze + build_runner + tests
docs/
  design-system.md                  # visual language
  gotchas.md                        # hard-won traps
  plans/                            # in-flight plan / handoff docs
```

---

## Test strategy

Every layer has a required tier. "Write tests" means all applicable tiers, not
one unit test.

### 1. Unit (`flutter_test`, host)

- Pure-Dart domain logic — clustering, date grouping, masonry, zoom math.
- **DAOs against in-memory Drift** — `NativeDatabase.memory()`, real schema, real
  queries, every method including cascades. Enable foreign keys in the test
  connection too.
- **Providers via `ProviderContainer`** with overrides; state transitions and disposal.
- **Migration tests** — `SchemaVerifier` against the committed dumps, every
  upgrade path v1→…→10.

### 2. Widget (host)

- Screens with mocked providers: loading / data / error / empty.
- **Golden tests** (`alchemist`), light and dark — this is what makes the design
  system enforceable. `test/widgets/design_goldens_test.dart` and
  `test/features/detail/detail_goldens_test.dart`, images under `<dir>/goldens/ci/`.
  Every new design-system widget gets one.

### 3. Integration (`integration_test` + `patrol`, real device)

- Boot, onboarding, tab navigation, grid scroll, detail open, favorite round-trip.
- **Permission matrix** — patrol drives the native dialogs that plain
  `integration_test` cannot: full access · limited/partial (iOS limited library,
  Android picker subset — `photo_manager` returns a different asset set and the
  UI must handle it) · denied · denied→granted via Settings · revoked mid-session.
- **Real-isolate ML smoke test** — spawn the actual worker, process seeded assets
  end to end, assert rows in `photo_labels` / `face_embeddings`.

### 4. Fake-pairing rule

Any fake or mock of infrastructure must be paired with **≥1 on-device
integration test of the real implementation**. Two production bugs (the isolate
binding hang and the HEIC OOM) were invisible to `flutter test` because fakes
bypassed the real path. Only two fakes exist — `FakeMlWorker` and
`FakePhotoLibraryService` — and each `integration_test` file names the fake it
counterparts in its doc comment.

### Deterministic test assets

Never depend on whatever happens to be on the device. The fixtures are pushed to
app-private storage (Android `adb push` to the app-external files dir; iOS
`xcrun devicectl device copy to … appDataContainer … --destination Documents`)
and resolved by `integration_test/support/fixture_file.dart`. Library-level
tests that go through `photo_manager`'s queries additionally need them in
MediaStore — see `test_assets/README.md`.

Required set (`test_assets/`, generated by `tool/gen_test_assets.dart`):
`large_48mp.heic` (the ~48MP OOM regression asset) · `gps_exif.jpg` ·
`no_exif.jpg` · `small_png.png` · `synthetic_face.jpg`. Note `small_png.png`
produces no ML Kit label ≥ 0.6 on device — `no_exif.jpg` backs the
label-derivation assertion instead.

> **Known gap.** `gps_exif.jpg` is generated and documented but referenced by
> **no test** — EXIF rendering has no fixture coverage (remediation task 2.3).
> `ml_indexing_test.dart` now uses `synthetic_face.jpg` / `no_exif.jpg` /
> `large_48mp.heic` (including the HEIC-thumbnail smoke case) and no longer reads
> arbitrary device photos. The video asset is still missing — no `ffmpeg` on
> this machine, so it has to be supplied by hand.
