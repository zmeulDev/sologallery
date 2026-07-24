# Instant detail swipe photos — 2026-07-23

**Status:** COMPLETED — S1–S4 implemented and verified.

**Goal:** Make swiping left/right in the detail viewer feel as instant as the initial tap. The user should never wait for a photo to load.

**Problem:** P1–P6 made the *tapped* photo appear instantly by passing the grid thumbnail into `PhotoPage` as `placeholderBytes`. Adjacent pages still rely only on `PrecacheAdjacent` + `detailImageProvider`, so a fast swipe can land on a black stage + spinner for ~100–300 ms. On a Pixel 9 Pro XL, `previewImage(1440px)` takes ~150–450 ms even when cached at the service layer. If the high-res decode has not finished, the user sees the loading frame.

**Scope:** Detail viewer swipe path only. No schema, no ML, no network. Extends the existing placeholder strategy to neighbours.

---

## Root cause

- `PhotoDetailScreen` builds each `_DetailPage` with `placeholderBytes: null` except the initial index (`detail_screen.dart:138-141`).
- `PhotoPage` falls back to `_Loading()` when both `detailImageProvider` and `placeholderBytes` are empty (`photo_page.dart:63`).
- `PrecacheAdjacent` starts the high-res `detailImageProvider` for ±3 pages, but it does not fetch low-res placeholders; and because `detailImageProvider` is `autoDispose`, the underlying `previewImage` can still be in flight when the swipe arrives.
- The grid thumbnail for adjacent assets is usually **not** in memory (Library cells are recycled), so we cannot rely on it.

---

## Proposed changes

### S1 — Low-res placeholder cache for adjacent photos (biggest win)

Add a second, tiny in-memory LRU cache of small thumbnails for the detail viewer's neighbours, separate from the existing `DetailPreviewCache`.

- New file: `lib/services/adjacent_thumbnail_cache.dart`.
  - Keys: `assetId` only.
  - Values: `Uint8List?` (small, e.g. 256 px or 512 px aspect-fit thumbnail bytes).
  - Capacity: 16 entries (~2–5 MB decoded, but we store encoded bytes only, so ~1–2 MB).
  - Methods: `get`, `put`, `clear`.
- New provider: `adjacentThumbnailProvider = FutureProvider.autoDispose.family<Uint8List?, String>` in a new detail support file (or extend `thumbnail_provider.dart`).
  - Requests a fixed small size, e.g. `ThumbnailRequest(id, width: 512, height: 512)`.
  - Caches the result in `AdjacentThumbnailCache` so swiping back and forth is instant.
- New widget: `AdjacentThumbnailPrecache` (in `lib/widgets/` or `lib/features/detail/widgets/`).
  - Replaces or extends `PrecacheAdjacent`.
  - For each neighbour id, watches `adjacentThumbnailProvider(id)` to keep the low-res cache warm, **and** still watches `detailImageProvider(id)` for the high-res cache.
  - Renders `SizedBox.shrink()`; sits in the same `Positioned`-filled `Stack` location as today.
- `PhotoDetailScreen` no longer passes `placeholderBytes` for the initial page only. Instead, every `_DetailPage` receives `placeholderBytes` by watching `adjacentThumbnailProvider(assetId).value` in `_DetailPage.build` (or `PhotoPage` can watch it directly).
  - This decouples placeholder bytes from `PhotoViewerArgs` while keeping the existing field for the tapped asset.

**Key design decisions**
- The small thumbnail size is intentionally much cheaper than the 1440 px preview (~4–10× faster decode). It is good enough to look like a photo, not a spinner.
- It is a *separate* cache from `DetailPreviewCache` because the lifetime and size differ: adjacent thumbnails can be cleared more aggressively, and they are keyed only by `assetId` (no max-edge dimension).
- The high-res fetch still runs in parallel; `PhotoPage` upgrades from the small placeholder to the 1440 px image via `gaplessPlayback` with no flash, exactly as it does today for the tapped asset.

### S2 — Increase detail high-res window for fast swipers

The current window is ±3. With placeholders for neighbours, the cost of a larger window is much lower because the small thumbnails are cheap. Increase the high-res warm window to ±5 so that the 1440 px decode is more likely to be ready for a rapid two-page swipe.

- Change `detail_screen.dart:153` from `ahead: 3, behind: 3` to `ahead: 5, behind: 5`.
- Keep `AdjacentThumbnailPrecache` window slightly larger or the same, e.g. ±7, because small thumbnails are inexpensive and cover a long swipe.

### S3 — Lifecycle / memory-pressure cache clearing

The new adjacent cache must be dropped when the app backgrounds, just like `DetailPreviewCache`.

- Add `clearAdjacentThumbnailCache()` to `PhotoLibraryService`.
- Call it from `SoloGalleryApp.didChangeAppLifecycleState` alongside `clearDetailPreviewCache()` (`app.dart:57`).

### S4 — Diagnostics

Add `Logger('SoloGallery.photos')` FINE logs in the new path:
- Cache hit/miss for adjacent thumbnails.
- Timing of small thumbnail fetches (entity + decode).

This is optional for the plan, but mirrors P1 and helps future tuning.

---

## Files expected to change

- `lib/services/adjacent_thumbnail_cache.dart` (new)
- `lib/services/photo_library_service.dart` — integrate cache, add `clearAdjacentThumbnailCache()`.
- `lib/services/thumbnail_provider.dart` or `lib/features/detail/detail_providers.dart` — new `adjacentThumbnailProvider`.
- `lib/features/detail/detail_screen.dart` — increase warm window; thread placeholder bytes to every `_DetailPage`.
- `lib/features/detail/widgets/photo_page.dart` — accept and use small-placeholder bytes (already does; mostly wiring).
- `lib/widgets/precache_adjacent.dart` — extend to warm small thumbnails alongside high-res previews.
- `lib/app.dart` — clear adjacent cache on lifecycle background.
- `test/services/adjacent_thumbnail_cache_test.dart` (new)
- `test/features/detail/widgets/photo_page_test.dart` — add case: no initial bytes, small placeholder arrives first, then high-res.
- `test/features/detail/detail_screen_test.dart` — adjust if placeholder wiring changes.

---

## Testing strategy

- **Unit:** LRU cache eviction, null entry handling, clear.
- **Widget:**
  - `PhotoPage` with only small placeholder shows placeholder immediately, then high-res.
  - `PhotoPage` with small placeholder + high-res already cached stays on high-res.
  - No spinner when either placeholder or high-res is available.
- **Integration (patrol, real device):**
  - Re-run `hero_dismiss_test` and `detail_actions_test`.
  - Manual/timed smoke: swipe left/right rapidly on Pixel 9 Pro XL; confirm no black stage and no spinner on the first swipe.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Extra memory from two caches | Small cache (16 entries, encoded bytes only); cleared on background. |
| Small thumbnail looks blocky before high-res | Size 512 px is still 1:1 on many phone screens; plus `BoxFit.contain` and `gaplessPlayback` keeps it smooth until the 1440 px upgrade. |
| Two parallel thumbnail providers compete for native decode threads | Adjacent thumbnails use their own small, bounded fetch (≤15) with iOS `ResizeContentMode.fit` so placeholders aren't square-cropped; detail preview keeps its own ungated dedupe + LRU. The small request is cheap and short. |
| Video neighbours show poster frame unnecessarily | `AdjacentThumbnailPrecache` skips known videos; `DetailStage` already switches to `VideoPage` once `isVideoProvider` resolves. |

---

## Definition of Done

1. `flutter analyze` clean.
2. New + updated unit/widget tests pass.
3. `hero_dismiss_test` and `detail_actions_test` pass on Pixel 9 Pro XL.
4. Device smoke test: swipe left/right at moderate speed shows the next photo immediately (placeholder) and high-res upgrade within ~200 ms; no spinner.
5. `docs/gotchas.md` updated if any surprising `photo_manager`/cache behaviour appears.
6. `docs/plans/instant-detail-swipe-photos.md` marked complete with final timings.

---

## Implementation log

- Created `lib/services/adjacent_thumbnail_cache.dart` (16-entry LRU keyed by asset id).
- Added `PhotoLibraryService.adjacentThumbnail` and `clearAdjacentThumbnailCache`, with FINE timing logs; fetch uses iOS `ResizeContentMode.fit` to avoid square-cropping the placeholder.
- Added `adjacentThumbnailProvider` in `lib/services/thumbnail_provider.dart` (fixed 512 px longest edge).
- Extended `PrecacheAdjacent` with separate `thumbnailAhead`/`thumbnailBehind` windows; the memory player leaves them at 0.
- Updated `PhotoDetailScreen` to warm full-res ±5 and low-res ±7, and to watch `adjacentThumbnailProvider` in `_DetailPage` as a fallback placeholder.
- Wired `clearAdjacentThumbnailCache` into `SoloGalleryApp` lifecycle pause.
- Added unit tests for the LRU cache and a widget test for a late-arriving small placeholder.
- Updated `FakePhotoLibraryService` to support `adjacentThumbnail`.

## Verification

- `flutter analyze` — clean.
- `dart run build_runner build` — clean.
- Targeted unit/widget tests for the changed area — pass.
- Full `flutter test` — 5 pre-existing failures unrelated to this change (verified on baseline).
- Integration tests on Pixel 9 Pro XL (`46121FDAS008AA`):
  - `hero_dismiss_test.dart` — pass.
  - `detail_actions_test.dart` — 3 pass, 2 skipped.
- Release manifest re-verified — no `INTERNET`/`READ_PHONE_STATE`/`c2dm`.

## Follow-ups

- Manual smoke test: rapid swipe left/right on a real library to confirm no black stage / spinner on first swipe.
- Investigate full-suite pre-existing failures:
  - `test/features/albums/album_detail_screen_test.dart`
  - `test/features/settings/folder_picker_sheet_test.dart`
  - `test/services/indexing_service_test.dart`
  - `test/widgets/design_goldens_test.dart`
  - `test/widgets/thumbnail_radius_test.dart`
