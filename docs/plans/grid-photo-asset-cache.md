# Grid on `photo_asset` cache

> **STATUS: ✅ COMPLETE** (2026-07-18). Library + Saved grids read the
> `photo_asset` cache; a fast metadata sweep (decoupled from ML) fills it.
> Schema **v4** (nullable `indexed_at`, `is_dated`). All 198 host tests green
> (analyze + codegen + tests); on-device `library_month_grouping_test` (cache
> path, real DATE_TAKEN axis) + `ml_indexing_test` pass on the Pixel 9 Pro XL;
> manual boot smoke clean. Two gotchas recorded in CLAUDE.md (UTC datetime
> extraction; migration `else if` + to-current validation).
>
> **Follow-ups (not done, out of scope):** a `photo_manager` change listener to
> re-sweep while foregrounded (today new photos appear on the next `resume`);
> the paged full-month/Older grids aren't reactive (invalidated on delete). The
> `test_assets/` seed set is still unpopulated (pre-existing debt).

## Context

The Library and Saved grids read the photo library two different ways today:

- **Library home** (`library_providers.dart`) builds month sections by asking
  `photo_manager` for a *candidate month span*, then runs **one filtered path
  query per candidate month** to skip empties and fetch 6 previews + a count
  (`PhotoLibraryService.monthsInLibrary` / `monthSummary`). On a large library
  this is many platform-channel round-trips, ordering depends on MediaStore
  quirks, and every reveal re-hits the OS.
- **Full-month / Older grids** page live via `photo_manager`
  (`MonthAssetsNotifier` / `OlderAssetsNotifier` → `monthAssets` / `olderAssets`).
- **Saved** already reads the DB (`FavoritesDao.watchAll`) but shows dangling
  favorites whose underlying asset was deleted (broken thumbnails).

We already maintain a `photo_asset` cache table (`createdAt`, `isVideo`,
`width`, `height`), and Search already queries it. The goal is to make the grids
read from that cache: **instant paints, one grouped SQL query instead of N path
queries, stable ordering, and reactivity** (grid reflows as photos are
added/deleted).

**The blocker:** `photo_asset` is written *only after* slow per-asset ML
analysis (`IndexDao.upsertIndexed` bundles metadata + labels + text + faces), so
the cache lags the library badly — a fresh install would show an empty grid for
minutes. **Fix: decouple a fast metadata-only sweep from the slow ML pass** so
the cache is filled within seconds of grant, then ML backfills labels/faces.
This needs a small schema bump (v3 → v4).

Decisions locked with the user: **fast metadata sweep first**; scope is
**Library + Saved** (Saved = join favorites to the pruned cache so deleted-asset
favorites drop out).

---

## Design

### 1. Schema v3 → v4 (`tables.dart`, `app_database.dart`)

`PhotoAssets`:
- `indexedAt` → **nullable** (`dateTime().nullable()`). `NULL` = metadata-swept
  but not yet ML-analyzed; non-null = ML done. This replaces the
  `indexedAssetIds()` set-diff — ML "todo" becomes `WHERE indexed_at IS NULL`.
- Add `BoolColumn get isDated => boolean().withDefault(const Constant(true))()`.
  `false` only for Android *undated* assets (their `createdAt` is a `DATE_ADDED`
  fallback); drives the "Older" bucket. iOS: always true.

`app_database.dart`: `schemaVersion => 4`; add `if (from < 4)` upgrade using a
single `m.alterTable(TableMigration(photoAssets, newColumns: [photoAssets.isDated]))`
— recreates the table with relaxed `indexed_at` nullability **and** the new
`is_dated` column, copying existing rows (all already-ML'd → keep their
`indexedAt`, default `is_dated = true`).

DoD #4: dump `drift_schemas/drift_schema_v4.json`, regenerate
`test/core/database/generated_migrations/schema.dart`, add the v3→v4 case to
`migration_test.dart`.

### 2. `IndexDao` (`daos/index_dao.dart`)

New methods:
- `upsertMetadata(rows)` — batch upsert of `(id, createdAt, isVideo, width,
  height, isDated)`. Uses `DoUpdate` that **omits `indexedAt`** so an already-ML'd
  row keeps its marker; new rows insert `indexedAt = NULL`. (Do **not** use
  `insertAllOnConflictUpdate` — it would null out `indexedAt` on ML'd rows.)
- `allCachedIds()` → `Set<String>`; `deleteAssets(List<String>)` — prune step
  computes the set difference (cached − live) in Dart and deletes in batches
  (cascades remove labels/text/faces). Avoids a giant `NOT IN (...)`.
- `pendingMlIds()` → ids `WHERE indexed_at IS NULL`, newest first (recent photos
  labelled first). Replaces the `indexedAssetIds()` diff in `IndexingService`.
- **Grid reads** (all over dated rows, `is_dated = true`, newest first):
  - `watchMonthCounts()` → `Stream<List<({YearMonth month, int count})>>`, grouped
    by `created_at` year+month (`photoAssets.createdAt.year` / `.month` extract
    expressions), ordered desc. SQL only returns non-empty months — no more
    candidate-span + skip-empties loop.
  - `monthPreviews(YearMonth, {limit})` → up to N asset ids for a month.
  - `monthAssets(YearMonth, {limit, offset})` → paged `AssetRef`s (full-month grid).
  - `watchOlderCount()` / `olderPreviews({limit})` / `olderAssets({limit, offset})`
    over `is_dated = false`, ordered by `created_at` (= date_added fallback).
    Empty on iOS.
- **Saved:** `watchFavoritesInCache()` → `Stream<List<Favorite>>` = favorites
  **inner-joined** to `photo_assets`, ordered by `favoritedAt` desc. Dangling
  favorites (asset pruned from cache) naturally drop out.

`IndexDao` already declares `Favorites` in `@DriftAccessor` — no accessor change.

### 3. `PhotoLibraryService` (`photo_library_service.dart`)

Add one bulk metadata reader for the sweep (metadata comes inline from
`getAssetListPaged` — no per-asset `_entity` round-trip):

```dart
Future<List<({String id, DateTime createdAt, bool isVideo, int width, int height})>>
    libraryMetadataPage({required bool dated, required int page, required int pageSize})
```

- `dated: true` → `_darwinFilter()` (iOS) or `_androidWindow(min: epoch 1ms)`
  (Android). `dated: false` → `_androidUndated()` (Android) / empty on iOS.
- Maps each `AssetEntity` → tuple via `createDateTime`, `type == video`,
  `width`, `height`. Reuses the existing filter helpers.

### 4. `IndexingService` (`indexing_service.dart`)

Prepend a fast **metadata sweep** to `_run()` (before the ML loop):

1. Page `libraryMetadataPage(dated: true)` and `(dated: false)`; tag `isDated`;
   `dao.upsertMetadata(...)` in batches. Collect all live ids.
2. `dao.deleteAssets(cachedIds − liveIds)` — prune deletions / limited-subset
   shrink.
3. Mark first-sweep-complete (see gating below), then continue to the ML loop.

ML loop: replace `dao.indexedAssetIds()` diff with `dao.pendingMlIds()`.
`upsertIndexed` already stamps `indexedAt = now`, flipping NULL → done.

Sweep runs on the existing triggers (`app.dart`: init, permission-granted,
`resume`) since it's the head of `_run()`. Since the sweep writes `photo_asset`,
the DAO `.watch()` streams emit and the grid paints — that's the reactive glue.
*(Follow-up, out of scope: a `photo_manager` change listener to re-sweep while
foregrounded; today new photos appear on next resume.)*

**Fresh-install gating:** expose `Stream<bool> watchSwept()` (or a `swept` flag
on the broadcast controller) so the Library screen shows a loading spinner until
the first sweep completes, instead of flashing "No photos yet" against the
briefly-empty cache. `libraryCacheReadyProvider` (StreamProvider<bool>) wraps it.

### 5. Providers + screens

- **`library_providers.dart`:** replace `LibraryMonthsNotifier` +
  `olderSummaryProvider` with:
  - `libraryMonthCountsProvider` = `StreamProvider.autoDispose` over
    `watchMonthCounts()` (gated by `permissionProvider`).
  - `monthPreviewsProvider` = `FutureProvider.autoDispose.family<List<String>, YearMonth>`.
  - `olderCountProvider` (stream) + `olderPreviewsProvider` (future).
- **`library_screen.dart`:** `ListView.builder` over month counts; each
  `_MonthSection` watches `monthPreviewsProvider(month)` for its 6 previews
  (lazy — only visible sections load). Older section appended when
  `olderCountProvider > 0`. No manual batch/`loadMore` — the counts query is one
  cheap grouped stream. Loading state honors `libraryCacheReadyProvider`.
- **`month_assets_provider.dart`:** `MonthAssetsNotifier` / `OlderAssetsNotifier`
  `fetchPage` → `dao.monthAssets` / `dao.olderAssets` instead of the service.
- **`saved_providers.dart`:** `savedFavoritesProvider` → `watchFavoritesInCache()`.
  `saved_screen.dart` unchanged (still `List<Favorite>` → grid).

### 6. Cleanup

Once nothing calls them, remove the now-dead live-grid service methods:
`monthsInLibrary`, `monthSummary`, `monthAssets`, `olderSummary`, `olderAssets`
(and `MonthSummary` / `OlderSummary` domain types if unreferenced). *No dead
code* (Absolute rules). Verify with a `grep` before deleting.

---

## Files touched

- `lib/core/database/tables.dart` — `PhotoAssets` columns
- `lib/core/database/app_database.dart` — v4 + migration
- `lib/core/database/daos/index_dao.dart` — sweep/prune/grid/saved queries
- `lib/services/photo_library_service.dart` — `libraryMetadataPage`; remove dead readers
- `lib/services/indexing_service.dart` — metadata sweep + `pendingMlIds` + swept signal
- `lib/features/library/library_providers.dart`, `library_screen.dart`
- `lib/features/library/month_assets_provider.dart`
- `lib/features/saved/saved_providers.dart`
- `drift_schemas/drift_schema_v4.json`,
  `test/core/database/generated_migrations/schema.dart`,
  `test/core/database/migration_test.dart`

## Tests

- **`index_dao_test.dart`** (in-memory Drift, FK on): `upsertMetadata` preserves
  `indexedAt` on re-sweep; prune cascades to labels/text/faces; `watchMonthCounts`
  groups/orders correctly; dated vs `is_dated=false` split; `pendingMlIds`;
  `watchFavoritesInCache` drops a favorite whose asset isn't cached.
- **`migration_test.dart`:** v3 → v4 against the committed dump.
- **Widget:** Library shows month sections from an in-memory DB
  (`databaseProvider.overrideWithValue`), spinner-until-swept, empty state; Saved
  hides a dangling favorite. Follow the FakeAsync/Drift traps in CLAUDE.md
  (one-shot `.get()`, bounded pumps, dispose+`pump(1s)`).
- **On device (Pixel 9 Pro XL):** grant → grid paints from the sweep within
  seconds (before ML); month counts/order match; delete a photo → it leaves the
  grid on next resume; Older bucket holds undated assets. Reuse/extend
  `integration_test/library_month_grouping_test.dart`.
- Full `tool/check.sh` green; release merged-manifest still network-free (no dep
  change, but re-verify per DoD #5).

## Verification (end-to-end)

1. `tool/check.sh` (analyze + codegen + host tests incl. new DAO/migration/widget).
2. `flutter test integration_test -d 46121FDAS008AA` for the library grouping test.
3. Manual on device: fresh grant → fast paint; scroll; open month grid; delete
   from detail → resume → gone; favorite → appears in Saved; delete a favorited
   asset → drops from Saved.
4. Update `docs/plans/CHECKPOINT.md` + this task's plan doc; prune CLAUDE.md.
