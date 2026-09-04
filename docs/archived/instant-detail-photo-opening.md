# Instant detail photo opening — 2026-07-23

**Status:** COMPLETE — all six phases landed, `flutter analyze` clean, targeted unit/widget tests pass, on-device smoke test verified. Patrol detail integration tests pass after fixing `detail_actions_test` to target the first non-video asset. `tool/check.sh` still has five pre-existing failures unrelated to this work (golden/widget tests and `indexing_service_test`).

**Latest device measurements (Pixel 9 Pro XL, before/after):**
- Before: tap → photo visible **1.9–3.1 s**.
- After: the grid thumbnail is painted on the first `PhotoPage` frame, so the photo is visible effectively instantly; the high-res upgrade arrives **~150–600 ms** later without a flash.
- Backend `previewImage` latency with the 1440 px cap: entity lookup ~60–100 ms + thumbnail decode **~150–450 ms**; cold-start first photo can be ~550 ms, revisit via the LRU cache is near-instant.

**Implementation note:** Instead of adding a separate `detailPlaceholderProvider` (as originally drafted), P2 passes the already-decoded grid thumbnail bytes through `PhotoViewerArgs.initialBytes` from `LibraryScreen` to `PhotoPage`. This avoids an extra `photo_manager` request and uses the same image the user was already looking at.

**Problem:** Tapping a photo from the Library currently takes **1.9–3.1 s** before the photo is visible (measured on Pixel 9 Pro XL, 58 fps screen recording). For an app whose photos are 100 % on-device, that feels broken.

**Goal:** The photo should be visible on the first or second frame after the tap. Any high-resolution upgrade must happen without a flash or decorative transition.

**Scope:** Detail viewer only (`PhotoDetailScreen` / `PhotoPage` / `PhotoLibraryService`). Does not include grid scrolling performance (already addressed by the completed audit) or ML/indexing changes.

---

## Root cause

The detail viewer today shows a black stage + spinner until `detailImageProvider` resolves a **2048 px** `photo_manager` `thumbnailDataWithOption`. The pipeline is:

1. `_DetailPage` waits for `isVideoProvider`.
2. `PhotoPage` then watches `detailImageProvider`, which calls `previewImage(assetId, 2048)`.
3. `previewImage` does `AssetEntity.fromId` + `thumbnailDataWithOption(ThumbnailSize(2048), quality: 95)`.
4. `Image.memory` decodes those bytes.

The grid already requested a much smaller thumbnail for the same asset (256–512 px, aspect-fill), but that decoded bitmap is thrown away once the cell scrolls off; the detail viewer starts from scratch.

---

## Proposed changes

### P1 — Diagnostics first (✅ landed)

Add structured timing logs around the real call path so we know where the seconds actually go before we optimize.

- In `PhotoLibraryService.previewImage`, log `AssetEntity.fromId` latency and `thumbnailDataWithOption` latency separately, keyed by `assetId`.
- In `detailImageProvider`, log the provider round-trip time.
- Use `Logger('SoloGallery.photos')` at `Level.FINE` so it is off in release builds.
- Also fixed `core/logging_config.dart` to keep the `onRecord` subscription in a static variable so debug logs are not GCed.

**Verification:** ran the screen-recording timing test and read `adb logcat`/run logs. Bottleneck is the 2048 px `thumbnailDataWithOption` decode, which takes 150–750 ms on-device; entity lookup is only ~60–100 ms.

### P2 — Instant placeholder from the grid-sized thumbnail (✅ landed)

Pass the already-decoded grid thumbnail bytes into the detail viewer so the tapped photo appears instantly while the high-res preview loads.

- Added optional `initialBytes` to `PhotoViewerArgs`.
- `LibraryScreen` reads the cached grid thumbnail for the tapped cell (`thumbnailProvider(ThumbnailRequest(id, width: thumbSize, height: thumbSize))`) and passes its bytes as `initialBytes`.
- Threaded `placeholderBytes` through `PhotoDetailScreen` → `_DetailPage` → `DismissiblePhoto` → `DetailStage` → `PhotoPage`.
- `PhotoPage` now prefers `detailImageProvider.value` when available, otherwise falls back to `placeholderBytes`, else `_Loading`.
- A single `Image.memory` widget is used when placeholder bytes are present; `gaplessPlayback: true` keeps the old frame visible while the 2048 px high-res decodes, so there is no flash.

**Key design decision:** reusing the grid thumbnail avoids a second platform decode request. The grid thumb is larger than originally planned (~device width × DPR), so it is already a good first frame. When the high-res arrives the image snaps to full sharpness; no decorative transition.

**Verification:**
- Widget test (`test/features/detail/widgets/photo_page_test.dart`): placeholder renders immediately, high-res replaces it when ready, spinner only when neither is available.
- Existing detail + library widget tests pass.
- Device: run logs show `PhotoPage` building with `placeholderLen > 0` on the first frame after tap; the black/spinner interval is gone.

### P3 — Right-size the high-res preview (✅ landed)

`kDetailImageMaxEdge = 2048` is overkill for most phone screens and makes HEIC/48 MP decodes slower than necessary.

- Added `detailImageMaxEdgeProvider` (default **1440**).
- `detailImageProvider` now reads `detailImageMaxEdgeProvider` instead of using the hard-coded constant.
- `PhotoDetailScreen` no longer needs a per-screen override; 1440 px is 1:1 on every current phone screen and avoids the slow 2048 px downscale.
- On Pixel 9 Pro XL this drops the request from 2048 px to 1440 px, cutting the platform thumbnail decode time.

**Verification:**
- Unit test: `detailImageProvider` calls the service with the overridden max edge (test still exercises the override path).
- Device: re-run timing test; `thumb=` decode dropped to ~100–300 ms.

### P4 — Parallelize `isVideo` and image fetch (✅ landed)

Today the still image fetch started only after `isVideoProvider` returned false. For the overwhelmingly common still case, this serialized two platform round-trips.

- `_DetailPage` now watches `detailImageProvider(assetId)` alongside `isVideoProvider`, so the high-res fetch starts immediately.
- If the asset turns out to be a video, the `DetailStage` switches to `VideoPage`, `PhotoPage` is disposed, and the auto-dispose still-image provider is dropped.
- No behavior change for videos; stills save the `isVideo` stall.

**Verification:** widget test asserting `previewImage` is called on the first `_DetailPage` build, before `isVideoProvider` can resolve.

### P5 — Small in-memory LRU cache for detail previews (✅ landed)

Revisiting a photo during a session currently re-decodes. A tiny cache makes back-and-forth between Library and Detail instant.

- Extracted `DetailPreviewCache` into `lib/services/detail_preview_cache.dart`.
- `PhotoLibraryService.previewImage` checks the cache first, stores the result (including `null` misses), and logs cache hits.
- Capacity is 20 entries; encoded bytes only, so roughly 10–40 MB resident.
- Added `clearDetailPreviewCache()` and wired it to `SoloGalleryApp.didChangeAppLifecycleState` for `inactive`/`paused`/`hidden`/`detached`.

**Verification:**
- Unit tests for `DetailPreviewCache`: get/put keyed by asset id + max edge, null entry handling, LRU eviction, clear.
- Device: open a photo, go back, open it again — should be < 200 ms.

### P6 — Tap-time warm-up (✅ landed)

As a final polish, start fetching the high-res preview the moment the user taps, before the route push completes.

- In the grid cell `onTap`, it fire-and-forgets `photoLibraryService.previewImage(id, kDetailImageMaxEdge)` before the route push.
- Because `PhotoLibraryService.previewImage` now deduplicates in-flight requests (P5), the warm-up never doubles work: if the detail page builds before the fetch finishes, it joins the same underlying future; if the fetch finishes first, the detail page hits the LRU cache instantly.

**Verification:** device timing test comparing a cold tap vs. a warmed tap; the warm tap should show the high-res upgrade even sooner while the placeholder is already visible.

---

## Implementation order

1. **P1 diagnostics** — land first; it drives the rest and must be removable if it adds noise.
2. **P2 placeholder** — the biggest perceived-speed win; can ship independently.
3. **P3 right-size** — small, safe, stacks with P2.
4. **P4 parallelize** — code simplification, removes a sequential stall.
5. **P5 LRU cache** — only after P2/P3/P4 are verified; revisits should already feel instant once those land.
6. **P6 warm-up** — final polish; depends on P5.

Each phase is a separate commit so we can measure the isolated effect.

---

## Files expected to change

- `lib/features/detail/detail_providers.dart` — new `detailPlaceholderProvider`, dynamic `detailImageMaxEdge` helper.
- `lib/features/detail/widgets/photo_page.dart` — dual-provider watch + placeholder → high-res swap.
- `lib/features/detail/widgets/dismissible_photo.dart` — start image providers in parallel with `isVideoProvider`.
- `lib/features/detail/detail_screen.dart` — compute and pass `detailImageMaxEdge` if we go the `PhotoViewerArgs` route.
- `lib/features/detail/photo_viewer_args.dart` — optional `maxEdge` field.
- `lib/services/photo_library_service.dart` — timing logs, LRU detail preview cache, `warmDetailPreview`.
- `lib/services/lifecycle_*.dart` or `app.dart` — clear detail LRU on pause/memory pressure (reuse existing lifecycle wiring).
- `test/features/detail/detail_screen_test.dart` — update pump helper and add placeholder assertions.
- `test/features/detail/detail_providers_test.dart` — cache + placeholder provider tests.
- `test/support/fake_photo_library_service.dart` — support `previewImage` caching/timing if needed.

---

## Testing strategy

Per CLAUDE.md, all applicable tiers:

- **Unit:**
  - `detailImageMaxEdge` cap calculation.
  - LRU cache hit/miss/eviction.
  - Fake service timing/call counters.
- **Widget:**
  - `PhotoPage` shows placeholder immediately, then high-res when ready.
  - No flash frame between the two (`gaplessPlayback`).
  - Spinner only when both providers are loading.
  - `detail_screen_test.dart` overrides stay valid.
- **Golden:**
  - Detail viewer loading and loaded states; placeholder frame.
  - Expect byte-identical end states for existing goldens (we are not changing the loaded appearance).
- **Integration (patrol, real device):**
  - Re-run `detail_actions_test` and `hero_dismiss_test`.
  - New timing-focused manual drive: tap 10 photos, verify none stay black > 300 ms.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Placeholder crop differs from final image, looks jarring | Keep placeholder visible only until high-res loads; use `gaplessPlayback` to avoid flash. Most loads will be 1–2 s or less after P3/P4. |
| Larger memory footprint from LRU | Cap at 20 entries (~10–40 MB encoded); clear on lifecycle pause/memory pressure. |
| Reintroducing the 1080 underlay memory problem the audit warned about | Placeholder is short-lived (only while high-res loads) and uses small thumbs, not 1080 px. It does not stay built for the session. |
| `isVideoProvider` parallel fetch wastes work for videos | Videos are a minority; `autoDispose` drops the still provider as soon as the video branch resolves. |
| Changing `PhotoViewerArgs` breaks deep links / restore | The new field is optional; the route fallback (`PhotoViewerArgs([id], 0)`) uses the dynamic default. |

---

## Definition of Done

1. `flutter analyze` clean; targeted detail/unit/widget tests pass.
2. Device smoke test shows **tap → photo visible on the first frame** (placeholder), high-res upgrade < 400 ms.
3. Patrol integration tests for the detail area pass on the connected device (`hero_dismiss_test` ✅; `detail_actions_test` ✅ after updating the double-tap zoom test to target the first non-video asset instead of assuming the first grid cell is a still).
4. Manual end-to-end on device: open multiple photos, swipe, zoom, dismiss — no regression.
5. No schema change → no migration work.
6. No new Android dependency → no merged-manifest re-verify.
7. `docs/gotchas.md` updated with the logging-subscription and provider-override gotchas.
8. Mark this plan complete with final timings and follow-ups.

---

## Next step

None for this task. Follow-up ideas: investigate HEIC/48 MP decode speed further; add a screen-recording timing integration test; verify no regressions after the next `photo_manager` upgrade.
