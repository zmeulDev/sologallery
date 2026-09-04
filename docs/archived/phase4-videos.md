# Phase 4 — Video support (first slice) ✅

_Completed 2026-07-18. Status: DONE — tree green, verified on device._

## Goal

First slice of Phase 4 (which also holds search + ML). Make videos first-class:
show them in the month gallery and all grids with a **duration badge**, and play
them **in the detail viewer**. No schema change, no ML, no migration — the gallery
still reads `photo_manager` directly. Favorite / album / share / delete already
key by asset id, so they work for videos unchanged.

## What shipped

- **Library query now includes videos** — `photo_library_service.dart`:
  `_imagesPath` uses `RequestType.common` + a `videoOption`. Manifest gained
  `READ_MEDIA_VIDEO`.
- **Service video API** — `videoDuration(id)`, `isVideoAsset(id)`, `videoFile(id)`
  (local `entity.file`, never a URL); `AssetDetail.videoDuration` (shown as a
  "Duration" chip in the EXIF sheet via `formatDuration`).
- **Grid duration badge** — `videoDurationProvider` (per-id, `thumbnail_provider.dart`);
  `AssetThumbnail` gained `showVideoBadge` + a self-contained `DurationBadge`
  (translucent ink pill, `m:ss`/`h:mm:ss`). All four grid sites pass the flag;
  album **covers** don't (no badge). Per-id provider chosen over threading through
  `AssetRef` because Saved/Album grids hold only ids from the DB.
- **In-viewer playback** — `isVideoProvider` + `videoFileProvider`
  (`detail_providers.dart`); the PageView itemBuilder branches via `_DetailPage`
  → `VideoPage` (video) vs `PhotoPage` (still). `VideoPage`
  (`features/detail/widgets/video_page.dart`) uses `video_player`: tap to
  play/pause, scrubbable progress bar, centered play glyph while paused; starts
  paused, pauses on `deactivate`, disposes the controller (no off-screen play).
- **Dependency** — `video_player: ^2.9.2`. Its `INTERNET` + `ACCESS_NETWORK_STATE`
  are stripped from the release manifest with `tools:node="remove"` (see CLAUDE.md
  gotcha); `WAKE_LOCK` kept.

## Tests (all green)

- Host (110 total, +9): `formatDuration` unit; `AssetThumbnail` badge (video /
  still / flag-off) `test/widgets/asset_thumbnail_test.dart`; `DurationBadge`
  golden light+dark `duration_badge.png`; detail still-vs-video branch in
  `detail_screen_test.dart`. Fake gained `videoDurations` +
  `videoDuration`/`isVideoAsset`/`videoFile` overrides.
- On-device (patrol, Pixel 9 Pro XL): `integration_test/video_playback_test.dart`
  — open newest month's grid → scroll to a video badge → open → **real**
  `VideoPlayer` mounts (controller init succeeds) → play/pause toggles. Paired
  with the faked `videoFile` host tests (fake-pairing rule). `detail_actions`
  patrol re-run green (mixed-media query didn't regress the photo flow).
- Release manifest re-verified network-free (no INTERNET / ACCESS_NETWORK_STATE /
  READ_PHONE_STATE / c2dm).

## Follow-ups / debt

- `test_assets/` video still unpopulated (Phase-2 debt) — the patrol test relied
  on a real device video (Jul 2026). Seed the deterministic video for CI.
- Detail zoom-to-original still a later enhancement (unchanged).
- **Remaining Phase 4:** search, then ML/indexing (google_mlkit_*, tflite_flutter)
  + the ML schema tables. Not started.
