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

Tree is green: `tool/check.sh` passes (analyze clean, codegen ok, **164 host
tests** incl. alchemist goldens). Schema is now **v2** (`photo_asset`,
`photo_label`; migration test + committed dump). A background-isolate indexer
(`IndexingService` + `MlWorkerController` running ML Kit's **bundled** image
labeler) populates labels, lifecycle-gated (pause on background); Search now does
**content** search over labels ("dog" → photos). Verified on the Pixel 9 Pro XL
via `integration_test/ml_indexing_test.dart` (real isolate + model + DB). Release
manifest re-verified network-free after stripping ML Kit's injected c2dm push
permission + receiver (new gotcha). `google_mlkit_image_labeling` added; the
`android/build.gradle.kts` Kotlin-target rule now matches each module's own Java
target (ML Kit modules pin 11/1.8). Not committed — user handles git.

## Next up — Phase 4 (remaining)

**ML/indexing slice 2+**: OCR (text recognition) and/or faces/people
(`face_embedding` + tflite + clustering + People screen). Optional: move the
gallery grid onto the `photo_asset` cache. See Known follow-ups below.

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
- **App id** is still `com.example.sologallery` — change before any release.
- **Phase 4 remaining** (videos ✅ done): search, then ML/indexing
  (google_mlkit_*, tflite_flutter — still deferred) + the ML schema tables.

## Gotchas worth re-reading before test work

CLAUDE.md → Known gotchas, especially the newest: **Drift + widget tests** (a
stream `.first` deadlocks under FakeAsync — use one-shot `.get()`; drift's
dispose zero-timer trips the teardown invariant — dispose the tree + `pump(1s)`;
a `TextField` on screen breaks `pumpAndSettle` — use bounded pumps). Also: `adb`
isn't on PATH — patrol needs `~/Library/Android/sdk/platform-tools` prepended, or
its finalizer throws `AdbExecutableNotFound`.
