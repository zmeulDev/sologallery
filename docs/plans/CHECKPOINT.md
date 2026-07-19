# SoloGallery — Resume Checkpoint

_Last updated: 2026-07-18. Read this + `CLAUDE.md` to resume with zero
re-discovery. Per CLAUDE.md workflow: **plan mode first** — save/approve a plan
in `docs/plans/` before writing code._

## Where we are

- **Phase 1** (scaffolding) ✅ — `docs/plans/phase1-scaffolding.md`
- **Phase 2** (permissions + month gallery) ✅ — `docs/plans/phase2-permissions-gallery.md`
- **Phase 3a** (detail viewer + EXIF + favorite/share/delete/add-to-album) ✅ —
  `docs/plans/phase3a-detail-viewer.md`
- **Phase 3b** (Saved + Albums screens) ✅ — `docs/plans/phase3b-saved-albums.md`
- **Phase 4 — videos** (playback + grid duration badges) ✅ —
  `docs/plans/phase4-videos.md`
- **Library month-grouping fix** (Android `DATE_TAKEN` windowing + "Older"
  bucket) ✅ — `docs/plans/library-month-grouping-fix.md`
- **Phase 4 — Search** (metadata: date / media type / album name / favorites)
  ✅ — `docs/plans/search-metadata.md`
- **Phase 4 — ML/indexing slice 1** (image labels + content search) ✅ —
  `docs/plans/ml-indexing-labels.md`
- **Phase 4 — ML/indexing slice 2** (OCR + faces/people) ✅ —
  `docs/plans/ml-indexing-ocr-faces.md`
- **Grid on `photo_asset` cache** (Library + Saved read the cache; fast metadata
  sweep decoupled from ML; schema v4) ✅ — `docs/plans/grid-photo-asset-cache.md`
- **Cache live updates** (foreground `photo_manager` change listener → debounced
  re-sweep; reactive paged full-month/Older grids + previews) ✅ —
  `docs/plans/cache-live-updates.md`
- **Settings screen** (photo access + manage-limited, library stats, rebuild
  index, appearance/theme override, about) ✅ — `docs/plans/settings-screen.md`

Tree is green: `tool/check.sh` passes (analyze clean, codegen ok, host tests
incl. alchemist goldens). Schema is now **v5**: adds `app_settings` (generic
key/value prefs — backs the persisted theme override) on top of v4's
`photo_asset` (nullable `indexed_at` = ML-pending + `is_dated`), `photo_label`,
`photo_text` (OCR), `persons` + `face_embedding` (people). A
background-isolate indexer (`IndexingService` + `MlWorkerController`) runs, per
asset in one pass, ML Kit **bundled** image labeling + Latin OCR + face detection
plus a bundled **MobileFaceNet tflite** embedder; incremental nearest-centroid
clustering assigns faces to `persons`. Search does **content** search over labels
**and** OCR text; a People strip on Search idle → `/people` (grid) → `/person/:id`
(rename + photos). Verified on the Pixel 9 Pro XL via
`integration_test/ml_indexing_test.dart` (real isolate + all 3 models + tflite +
DB). Release manifest re-verified network-free after stripping ML Kit/tflite
injected perms (c2dm, READ_PHONE_STATE, WRITE_EXTERNAL_STORAGE). Deps:
google_mlkit_text_recognition, google_mlkit_face_detection, tflite_flutter, image
+ `assets/models/mobilefacenet.tflite` (BSD-3). Not committed — user handles git.

## Phase 4 — ✅ complete

All Phase 4 work is done, including the final polish trio
(`docs/plans/phase4-polish.md`):
- **Tighter avatar crop** — `FaceAvatar` uses a `kFaceFill` (1.3) over-zoom via
  the pure `faceAvatarPlacement` helper (host-unit-tested; tune the const to
  taste).
- **Higher-res OCR** — `MlWorker.analyzeFile(jpegPath, {ocrPath})` runs OCR on a
  separate **1024px** thumbnail (`_ocrEdge`) while labels/faces stay on 512
  (box space + HEIC-OOM rule unchanged). Indexer writes/cleans a 2nd temp.
- **Global re-cluster** — pure `clusterAll` + `planClusters`
  (`face_clustering.dart`) + `FacesDao.allFacesForClustering`/`faceCount`/
  `rebuildClusters`; `IndexingService._maybeGlobalRecluster` runs after a pass
  once ≥ `reclusterThreshold` (20) new faces accrued since the `app_settings`
  baseline, **preserving user renames/covers**. Heals the incremental
  assigner's order-drift (one person split into several).

**Device verification still owed** (host tests green): P1 visual crop; P2 small
text now findable; P3 duplicated person collapses + keeps its name;
`ml_indexing_test.dart` on device — **which needs photo access re-granted on the
Pixel** (the last run found it revoked: open the app once and Allow).

## Next up

No planned feature backlog remains. Candidate future work (unprompted): the
Edit feature (`edit_instruction` table exists, no `lib/features/edit/` yet),
`test_assets/` seeding to unblock the skipped patrol smokes, app-id rename
before release.

**Settings (just landed):** `settings_screen.dart` rebuilt into grouped cards
(section-label + surface-card idiom). Schema **v5** adds `app_settings`
(key/value) + `SettingsDao`; the theme override persists there and drives
`app.dart`'s `themeMode` via `themeModeProvider`. Rebuild-index =
`IndexDao.clearIndex()` (cascades) + `FacesDao.clearPersons()` +
`IndexingService.rebuild()` (cancel active pass → clear → flip swept
false→true → re-sweep). Stats from `IndexDao.watchLibraryTotals` +
`peopleCountProvider` + `indexingStatusProvider`. `package_info_plus` added for
the About version (re-verify release manifest network-free on next build).
Theme picker (`ThemeModePicker`, reuses `FilterPill`) has an alchemist golden.

**Cache live-updates (just landed):** `PhotoLibraryService.startLibraryChangeNotify`
wraps `photo_manager`'s `startChangeNotify`/`addChangeCallback`;
`IndexingService` registers it once (lazily in `start()`), debounces the change
burst (`resweepDebounce`, ~2s) and re-sweeps — with a `_dirty` loop so a change
mid-pass triggers one more sweep. Guarded by `_paused` (no work while
backgrounded). The paged full-month/Older grids now use `WatchedAssetsNotifier`
(a live growing-window `.watch()`, `LIMIT` grows, offset stays 0) over new
`IndexDao.watchMonthAssets`/`watchOlderAssets`; month/Older **previews** are
`StreamProvider`s over `watchMonthPreviews`/`watchOlderPreviews`. Detail delete
no longer invalidates the grids (they react to the cache prune). On-device
pairing: `integration_test/cache_live_update_test.dart` (needs a device run —
writes+deletes one app-owned probe image). `PagedAssetsNotifier` is untouched
(Search still uses it).

**How the grid works now:** `IndexingService._sweepMetadata` runs at the head of
each pass (init / permission-grant / resume in `app.dart`, **plus** on a
debounced foreground library change), caching lean
`photo_asset` rows for the whole library (no ML) and pruning deleted ones; ML
then backfills labels/faces for `indexed_at IS NULL` rows. Library home =
`libraryMonthCountsProvider` (one grouped stream via `IndexDao.watchMonthCounts`,
local-month) + lazy `monthPreviewsProvider`; Older = `olderCountProvider` /
`olderPreviewsProvider`. Full-month/Older grids stream `IndexDao.watchMonthAssets`
/ `watchOlderAssets` (reactive growing window; the one-shot `monthAssets`/
`olderAssets` remain for the offset-paged integration test). Saved =
`IndexDao.watchFavoritesInCache` (favorites ⨝ cache, so
deleted-asset favorites drop). `libraryCacheReadyProvider` gates the empty state
until the first sweep. Detail delete prunes the cache row so reactive grids
update immediately.

## What 3b delivered (for reference)

- **Saved** (`/saved`): `saved_providers.dart` (`savedFavoritesProvider`, a
  `StreamProvider` over `FavoritesDao.watchAll` — a DB stream, **not**
  `PagedAssetsNotifier`; favorites are a bounded reactive set) + rebuilt
  `saved_screen.dart` (3-col grid → detail viewer).
- **Albums** (`/albums`, `/album/:id`): `albums_providers.dart` (summaries /
  album / entries / create+delete actions), `widgets/album_card.dart`, rebuilt
  `albums_screen.dart` (2-col cards, create dialog, long-press delete),
  `album_detail_screen.dart`. New DAO reads `watchAlbum` + `watchAlbumSummaries`
  (+ `AlbumSummary` DTO). `/album/:id` route added.

## Reusable building blocks (already in place)

- `favoritesDaoProvider`, `albumsDaoProvider` (`lib/core/database/database_provider.dart`)
- `PagedAssetsNotifier` (`lib/services/paged_assets_notifier.dart`) — shared grid paginator
- `AssetThumbnail` + `thumbnailProvider`; `PhotoViewerArgs` + `/photo/:id` viewer
- Detail providers/actions (`lib/features/detail/`) — pattern to mirror
- Saved/Albums providers + `AlbumCard` (`lib/features/saved`, `lib/features/albums`)

## Known follow-ups / debts

- **`test_assets/` seed set still unpopulated** (deferred since Phase 2) — blocks
  the seeded-delete patrol smoke (`integration_test/detail_actions_test.dart`,
  `skip:true`) and the share patrol case. Populate: 48MP HEIC, GPS JPEG, no-EXIF
  JPEG, a video, a small PNG (see CLAUDE.md → Deterministic test assets).
- Detail **zoom** shows a screen-capped preview, not the full original — a
  zoom-to-original pass is a later enhancement.
- **App id** is `com.zmeul.sologallery` (renamed for release). Release signing is still the debug key — see docs/plans/publication-prep.md.
- **Phase 4 remaining** (videos ✅ done): search, then ML/indexing
  (google_mlkit_*, tflite_flutter — still deferred) + the ML schema tables.

## Gotchas worth re-reading before test work

CLAUDE.md → Known gotchas, especially the newest: **Drift + widget tests** (a
stream `.first` deadlocks under FakeAsync — use one-shot `.get()`; drift's
dispose zero-timer trips the teardown invariant — dispose the tree + `pump(1s)`;
a `TextField` on screen breaks `pumpAndSettle` — use bounded pumps). Also: `adb`
isn't on PATH — patrol needs `~/Library/Android/sdk/platform-tools` prepended, or
its finalizer throws `AdbExecutableNotFound`.
