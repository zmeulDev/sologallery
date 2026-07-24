# Plan — Phase 3a: Photo Detail Viewer + EXIF + Actions

> **Status: ✅ Complete** (2026-07-18). `tool/check.sh` green (analyze clean,
> codegen ok, **80 host tests** incl. 3 new alchemist goldens). Release merged
> manifest re-verified network-free (share_plus adds no INTERNET). **On-device
> patrol** (Pixel 9 Pro XL): the real photo_manager grant → grid → open photo →
> favorite → EXIF sheet → create-album → back flow **passes** (`❌ Failed: 0`),
> exercising the real `photo_manager` + Drift path (fake-pairing rule satisfied)
> and serving as the manual end-to-end verification for those actions.
>
> **Follow-ups (carried forward):**
> - **Share** and **seeded-delete** patrol cases are `skip: true` — share sheet
>   labels are device/locale-specific; delete is destructive and needs a
>   throwaway asset. Both actions' *logic* is covered by host tests
>   (`DetailActions.delete` purge + cancelled-OS-dialog path; `shareAssets`
>   fake). Populate `test_assets/` (still deferred since Phase 2) to enable the
>   delete smoke, and enable share per-device.
> - Pinch-zoom loads a screen-capped preview, not the full original — a
>   zoom-to-original pass is a later enhancement.
> - **Phase 3b:** full Saved grid + Albums list/create/`/album/:id` screens.
>
> **Done:** data layer (`AssetDetail`, `assetDetail`/`previewImage`/`deleteAssets`/
> `shareAssets` on `PhotoLibraryService`; `share_plus` dep; `favoritesDaoProvider`/
> `albumsDaoProvider`; `AlbumsDao.removeAssetEverywhere`) · `detail_providers.dart`
> (`assetDetailProvider`, `detailImageProvider`, `isFavoriteProvider`,
> `albumsListProvider`, `DetailActions`) · `/photo/:id` route + `PhotoViewerArgs` ·
> full detail UI (`PhotoDetailScreen`, `photo_page`, `detail_action_bar`,
> `exif_sheet`, `add_to_album_sheet`, pure `asset_detail_display` formatters) ·
> both inert tap sites wired (Library previews + month grid) · host tests: EXIF
> formatter units, `DetailActions`/provider tests, `removeAssetEverywhere` DAO
> test, detail-screen widget tests, 3 alchemist goldens (action bar, EXIF sheet,
> add-to-album — light+dark). `flutter analyze` clean.
>
> **Next step:** run `tool/check.sh` clean end-to-end, then on-device patrol
> (`integration_test/detail_actions_test.dart`) + manual verify on the Pixel 9
> Pro XL, then release-manifest network-free re-check. Populate `test_assets/`
> to enable the skipped seeded-delete patrol case.
>
> **Deviations / decisions:**
> - EXIF orientation is carried in `AssetDetail` but **not shown** in the sheet
>   (low end-user value; kept the sheet to Taken/Dimensions/Resolution/Size/Type/
>   Location). GPS read via `latlngAsync()` — the sync getters are null on
>   Android 10+.
> - Added `previewImage` (not in the original plan) because iOS
>   `thumbnailDataWithSize` hardcodes `ResizeContentMode.fill` (crops); the new
>   method uses `fit` on iOS so the detail image isn't cropped.
> - `AddToAlbumSheet` root is a `Material` (not a colored `Container`) so
>   `ListTile` ink/text render correctly (also unblocked the alchemist golden).
> - Host widget tests override `detailImageProvider → null` to avoid a pending
>   image-decode timer; the real preview path is covered on-device by patrol.

## Context

Phase 2 shipped the permission flow and the month-grouped Library grid, but
every photo cell is **inert** — `library_screen.dart` and `month_grid_screen.dart`
both carry a literal "inert until the Phase 3 detail viewer" comment, and the
`/photo/:id` route does not exist. There is no way to open a photo, see its
metadata, or act on it.

Phase 3's full non-goal list (per `phase2-permissions-gallery.md`) is large:
detail viewer + EXIF + favorite/share/delete/add-to-album **and** the full
Saved + Albums screens. Per user decision we **split**:

- **Phase 3a (this plan):** the full-screen detail viewer, the EXIF reveal, and
  the four actions (favorite · share · delete · add-to-existing-album). The
  add-to-album action wires the **AlbumsDao** and favorites wire the
  **FavoritesDao** for the first time, so the persistence those DAOs back is
  proven now.
- **Phase 3b (later):** the full Saved grid and Albums list/create/`/album/:id`
  screens as first-class destinations.

Locked decisions: EXIF shows **photo_manager-native fields only** (dimensions,
file size, taken-date, mime, orientation, GPS) — no extra EXIF package. Delete
is a **real device-library deletion** via photo_manager's native trash dialog,
preceded by our own confirm and followed by purging our DB rows. Share adds
**`share_plus`** (OS share sheet, local, exports a temp copy — no library
duplication).

## Scope / non-goals (3a)

- No Saved or Albums *screens* (3b). 3a only reads/writes their DAOs from the
  detail actions (favorite toggle, add-to-album picker with inline create).
- No video playback (Phase 4 — viewer is image-only, matching the `image`-only
  library queries).
- No pinch-zoom-to-original / full-res decode (follow-up). Detail shows a
  screen-sized image, capped to avoid the 48MP HEIC OOM (CLAUDE.md gotcha).
- No search, no edit-instructions.

---

## Data layer

### `lib/services/photo_library_service.dart` (extend)
Add a pure projection next to `AssetRef` (same file, consistent with the
codebase) and three methods:

- `class AssetDetail` — pure fields: `id`, `width`, `height`, `sizeBytes` (int?,
  best-effort), `mimeType` (String?), `createdAt`, `orientationDegrees` (int),
  `latitude`/`longitude` (double?), `isVideo` (bool), `title` (String?).
- `Future<AssetDetail?> assetDetail(String id)` — resolve via the existing
  `_entityCache`/`AssetEntity.fromId`, read `width`/`height`/`typeInt`/
  `mimeTypeAsync`/`orientation`/`latitude`/`longitude`/`title`/`createDateTime`;
  `sizeBytes` best-effort via `(await entity.file)?.length()` (metadata read, not
  a decode; nullable on failure). Runs in the service (off the UI build path).
- `Future<List<String>> deleteAssets(List<String> ids)` —
  `PhotoManager.editor.deleteWithIds(ids)` (returns successfully-deleted ids);
  evict those from `_entityCache`; log.
- `Future<void> shareAssets(List<String> ids, {Rect? sharePositionOrigin})` —
  resolve each entity's original `file`, collect paths, hand to `share_plus`.
  **Verify the exact `share_plus` entrypoint against the resolved version at
  implementation** — v10 is `SharePlus.instance.share(ShareParams(files: [...],
  sharePositionOrigin: rect))`. Skip ids whose file can't be resolved.

Detail **image bytes reuse the existing `thumbnail(id, w, h)`** path via
`thumbnailProvider` at a large size (see UI). No new image method — honors "UI
never imports photo_manager" and the sized-thumbnail rule.

### `lib/core/database/database_provider.dart` (extend)
Add keep-alive DAO providers reading the generated getters on `AppDatabase`
(`@DriftDatabase(daos: …)` produces `favoritesDao` / `albumsDao`):

```dart
final favoritesDaoProvider = Provider((ref) => ref.watch(databaseProvider).favoritesDao);
final albumsDaoProvider    = Provider((ref) => ref.watch(databaseProvider).albumsDao);
```

### `lib/core/database/daos/albums_dao.dart` (extend)
Add `Future<int> removeAssetEverywhere(String assetId)` —
`delete(albumEntries)..where((e) => e.assetId.equals(assetId))` — used by the
delete flow to purge album membership. **No schema change** (query only), so no
migration test needed.

---

## Domain / providers — `lib/features/detail/`

`detail_providers.dart`:
- `assetDetailProvider` — `FutureProvider.autoDispose.family<AssetDetail?, String>`
  → `photoLibraryServiceProvider.assetDetail(id)`.
- `isFavoriteProvider` — `StreamProvider.autoDispose.family<bool, String>`
  → `favoritesDaoProvider.watchIsFavorite(id)`.
- `albumsListProvider` — `StreamProvider.autoDispose<List<Album>>`
  → `albumsDaoProvider.watchAllAlbums()` (Album = our Drift row type, fine in UI).
- A thin `DetailActions` controller (or inline `ref.read` handlers) for:
  - toggle favorite → `favoritesDao.add/remove`
  - add to album → `albumsDao.addEntry` (+ `createAlbum` for inline new album)
  - delete → `photoLibraryService.deleteAssets([id])`; on success purge
    `favoritesDao.remove(id)` + `albumsDao.removeAssetEverywhere(id)`, then
    `ref.invalidate(libraryMonthsProvider)` and the affected
    `monthAssetsProvider`.

`PhotoViewerArgs { List<String> assetIds; int initialIndex }` — passed via
GoRouter `extra`; deep-link fallback (`extra == null`) builds `[pathId]`, index 0.

---

## UI layer  (invoke `/frontend-design:frontend-design` before building)

### Route — `lib/core/router/app_router.dart`
Add a top-level pushed route mirroring `/month/:key`:
```dart
GoRoute(
  path: '/photo/:id',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (c, s) => PhotoDetailScreen(
    args: s.extra as PhotoViewerArgs? ?? PhotoViewerArgs([s.pathParameters['id']!], 0),
  ),
)
```

### Screen — `lib/features/detail/detail_screen.dart`
`PhotoDetailScreen`: black full-screen Scaffold; `PageView` over `args.assetIds`
(`PageController(initialPage: args.initialIndex)`), current index in local state.
Top: back + dedicated **EXIF (info) button**. Bottom: `DetailActionBar`. Handles
the delete-empties-sequence case (remove id, pop when empty).

### Widgets — `lib/features/detail/widgets/` (design-system, golden-tested)
- `photo_page.dart` — `InteractiveViewer` + `Image.memory` of a large
  `thumbnailProvider(ThumbnailRequest(id, width: W, height: H))` request sized to
  the screen (`MediaQuery` longest edge × DPR, **capped ~2048px**), `BoxFit.contain`,
  quiet placeholder while loading. **Verify aspect + HEIC on device** — if
  photo_manager crops the non-square request, switch to a square-capped box.
- `detail_action_bar.dart` — favorite (filled/outline from `isFavoriteProvider`),
  share, add-to-album, delete. Design-system component.
- `exif_sheet.dart` — `showModalBottomSheet` rendering `assetDetailProvider(id)`
  as EXIF chips: key uppercase 9sp / value 12sp-600 per CLAUDE.md typography
  (dims, size, taken-date, mime, orientation, GPS lat/long). AsyncValue states.
- `add_to_album_sheet.dart` — lists `albumsListProvider` + an inline "New album"
  create field; tap adds via `addEntry`; empty state when no albums.
- `delete_confirm` — our own confirm (sheet/dialog) before the OS trash dialog.

### Wire the two inert tap sites
- `library_screen.dart` `_PreviewGrid`: wrap each `AssetThumbnail` in a tap →
  `context.push('/photo/$id', extra: PhotoViewerArgs(previewAssetIds, index))`.
  Remove the "inert" comment.
- `month_grid_screen.dart` `_Grid`: cell tap →
  `context.push('/photo/$id', extra: PhotoViewerArgs([for (a in items) a.id], i))`.
  Remove the "inert" comment.

---

## Dependencies & platform config
- `pubspec.yaml`: add `share_plus` to `dependencies`.
- Android: share_plus bundles its own FileProvider — no manifest edits expected.
  Delete via MediaStore needs no new permission beyond the Phase-2
  `READ_MEDIA_IMAGES` (the OS renders the trash dialog).
- **Re-verify the release merged manifest is still network-free** (DoD #5):
  `./gradlew :app:processReleaseManifest` + grep — confirm share_plus adds no
  `INTERNET`.

---

## Tests (all applicable tiers — CLAUDE.md Test strategy)

**Unit (host):**
- Extend the fake `PhotoLibraryService` (from Phase 2) with `assetDetail`,
  `deleteAssets` (records + returns ids), `shareAssets` (records).
- `AlbumsDao.removeAssetEverywhere` against in-memory Drift (add to the existing
  albums DAO test) — inserts across two albums, remove, assert both gone,
  siblings untouched.
- Providers via `ProviderContainer` + in-memory db + fake photo service:
  `isFavoriteProvider` add/remove round-trip; `assetDetailProvider`; the **delete
  handler** purges favorites **and** album entries and invalidates library.

**Widget (host, mocked providers):**
- `PhotoDetailScreen`: image page + action bar render; favorite icon reflects
  `isFavoriteProvider`; EXIF button opens sheet showing fields; add-to-album
  sheet lists albums, inline-creates, and adds; delete shows our confirm.

**Golden (alchemist, light + dark):** `detail_action_bar` (favorite on/off),
`exif_sheet`, `add_to_album_sheet`.

**Integration (on-device, patrol) — satisfies the fake-pairing rule** (real
`deleteAssets`/`shareAssets` are the infra fakes above):
- Library → tap a preview → detail opens → swipe pages → favorite toggles and
  the icon reflects it → EXIF sheet shows real dimensions → add-to-album
  create+add → back.
- **Real delete smoke** — destructive, so it must target a **seeded throwaway
  asset**, never the device's own photos (deterministic-assets rule). Seed via
  the CLAUDE.md `adb push test_assets/ …` flow, delete through the UI, drive the
  native trash dialog with patrol, assert the asset leaves the grid and the
  favorites/album rows are purged. **Dependency:** the `test_assets/` seed set
  is still unpopulated (deferred in Phase 2) — populating at least one throwaway
  asset is a prerequisite for this test.
- **Share** — patrol taps share, asserts the native share sheet appears, dismisses.

---

## Verification (Definition of Done)
1. `tool/check.sh` — analyze clean, codegen, all unit + widget + golden pass.
2. `flutter test integration_test -d 46121FDAS008AA` (patrol) — detail/actions +
   seeded delete smoke pass on the Pixel 9 Pro XL.
3. Manual on-device: open a photo, swipe, favorite (icon persists across
   reopen), EXIF sheet shows dims/GPS, add to a new album, delete a **seeded**
   asset → OS dialog → gone from grid + rows purged, share opens the sheet.
   Debug via `flutter logs` (not `adb logcat` — `developer.log` gotcha); no
   screenshots.
4. Release merged manifest re-verified network-free (share_plus adds no INTERNET).
5. No schema change → no migration test. CLAUDE.md Known gotchas updated if
   share_plus/delete surprises surface.
6. Copy this plan to `docs/plans/phase3a-detail-viewer.md`, mark complete with
   final state + follow-ups (3b, pinch-to-original, test_assets seeding); update
   the project-status memory.

## Sequencing (suggested)
1. `share_plus` dep + service methods (`assetDetail`, `deleteAssets`,
   `shareAssets`) + DAO providers + `removeAssetEverywhere` → unit tests.
2. `detail_providers` + `PhotoViewerArgs` + `/photo/:id` route.
3. frontend-design pass → `PhotoDetailScreen` + `photo_page` + `detail_action_bar`
   + `exif_sheet` + `add_to_album_sheet`; wire the two tap sites.
4. Widget + golden tests.
5. patrol matrix + seeded delete smoke; manual on-device; manifest re-verify.
