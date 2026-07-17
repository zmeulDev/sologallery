# SoloGallery — Resume Checkpoint

_Last updated: 2026-07-18. Read this + `CLAUDE.md` to resume with zero
re-discovery. Per CLAUDE.md workflow: **plan mode first** — save/approve a plan
in `docs/plans/` before writing code._

## Where we are

- **Phase 1** (scaffolding) ✅ — `docs/plans/phase1-scaffolding.md`
- **Phase 2** (permissions + month gallery) ✅ — `docs/plans/phase2-permissions-gallery.md`
- **Phase 3a** (detail viewer + EXIF + favorite/share/delete/add-to-album) ✅ —
  `docs/plans/phase3a-detail-viewer.md`

Tree is green: `tool/check.sh` passes (analyze clean, codegen ok, **80 host
tests** incl. alchemist goldens). Phase-3a patrol favorite/EXIF/add-album passes
on the Pixel 9 Pro XL. Release manifest verified network-free. Not committed —
user handles git.

## Next up — Phase 3b: Saved + Albums screens

Phase 3 was split; 3b is the remaining half. Build the two screens as
first-class destinations (their DAOs are already wired + tested from the 3a
detail actions):

- **Saved** (`/saved`, `lib/features/saved/saved_screen.dart` — currently a
  `PlaceholderView`): favorites grid, newest-favorited first. Reuse
  `FavoritesDao.watchAll()` + `PagedAssetsNotifier` (built in Phase 2 for exactly
  this) + `AssetThumbnail`; tap → detail viewer with the favorites sequence as
  `PhotoViewerArgs`. AsyncValue loading/empty/error states.
- **Albums** (`/albums`, `lib/features/albums/albums_screen.dart` — placeholder):
  album list (`AlbumsDao.watchAllAlbums`), create album, delete album, and the
  `/album/:id` album-detail grid (`AlbumsDao.watchEntries`) → detail viewer.
  Add the `/album/:id` route (mirror `/photo/:id` / `/month/:key`).
- Invoke `/frontend-design:frontend-design` before building these screens.
- Tests: DAO paths already covered; add provider + widget + golden tiers and an
  on-device patrol favorite-round-trip + album-open smoke.

## Reusable building blocks (already in place)

- `favoritesDaoProvider`, `albumsDaoProvider` (`lib/core/database/database_provider.dart`)
- `PagedAssetsNotifier` (`lib/services/paged_assets_notifier.dart`) — shared grid paginator
- `AssetThumbnail` + `thumbnailProvider`; `PhotoViewerArgs` + `/photo/:id` viewer
- Detail providers/actions (`lib/features/detail/`) — pattern to mirror

## Known follow-ups / debts

- **`test_assets/` seed set still unpopulated** (deferred since Phase 2) — blocks
  the seeded-delete patrol smoke (`integration_test/detail_actions_test.dart`,
  `skip:true`) and the share patrol case. Populate: 48MP HEIC, GPS JPEG, no-EXIF
  JPEG, a video, a small PNG (see CLAUDE.md → Deterministic test assets).
- Detail **zoom** shows a screen-capped preview, not the full original — a
  zoom-to-original pass is a later enhancement.
- **App id** is still `com.example.sologallery` — change before any release.
- **Phase 4** (after 3b): videos, search, ML/indexing (google_mlkit_*,
  tflite_flutter — still deferred) + the ML schema tables.

## Gotchas worth re-reading before test work

CLAUDE.md → Known gotchas, especially the newest: **Drift + widget tests** (a
stream `.first` deadlocks under FakeAsync — use one-shot `.get()`; drift's
dispose zero-timer trips the teardown invariant — dispose the tree + `pump(1s)`;
a `TextField` on screen breaks `pumpAndSettle` — use bounded pumps). Also: `adb`
isn't on PATH — patrol needs `~/Library/Android/sdk/platform-tools` prepended, or
its finalizer throws `AdbExecutableNotFound`.
