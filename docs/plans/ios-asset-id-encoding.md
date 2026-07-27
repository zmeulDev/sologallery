# Fix `Page Not Found` on iOS photo detail navigation

## Context

Tapping a photo thumbnail on iOS opens a GoRouter "Page Not Found" error screen
instead of the detail viewer. Repro is consistent across Library / Saved /
Albums / Folder detail / Search screens; only the recently-viewed carousel works.
Caused by iOS `AssetEntity.id` containing forward slashes (`{uuid}/L0/001` for
originals, `{uuid}/L0/002` for alternatives), which break the `/photo/:id` route
when interpolated raw.

## Root cause

PhotoKit asset ids are *paths*: `603345BD-E05C-40D8-8A29-3335675F276B/L0/001`.
Android ids are bare uuids. Five call sites build the detail route:

```text
lib/features/saved/saved_screen.dart:207                '/photo/$id'                 ❌
lib/features/library/library_screen.dart:568             '/photo/$id'                 ❌
lib/features/albums/album_detail_screen.dart:258         '/photo/$id'                 ❌
lib/widgets/asset_grid.dart:101                          '/photo/$id'                 ❌
lib/features/search/widgets/recently_viewed_row.dart:103 '/photo/${Uri.encodeComponent(assetId)}'  ✅
```

For an iOS id like `603345BD-…/L0/001`, the unsafe sites produce
`/photo/603345BD-…/L0/001` — three path segments — but `/photo/:id` matches only
two. GoRouter reports `GoException: no route for location` and the default error
screen renders as "Page Not Found". The `previewImage(…) cache hit` line you see
in logs is the cache-warm step *before* the failing push, which is why the bug
presents as a successful thumbnail followed by a routing error.

`Uri.encodeComponent` escapes `/` to `%2F`, so the encoded path
`/photo/603345BD-…%2FL0%2F001` matches cleanly. This is what the carousel already
does correctly.

## Plan

Fix the four unsafe call sites only. Leave the route definition (`/photo/:id`)
strict — no wildcard, no path decoding at the router. Mirrors the working
carousel pattern exactly.

### Edits

1. `lib/features/saved/saved_screen.dart:207`
   `'/photo/$id'` → `'/photo/${Uri.encodeComponent(id)}'`
2. `lib/features/library/library_screen.dart:568`
   `'/photo/$id'` → `'/photo/${Uri.encodeComponent(id)}'`
3. `lib/features/albums/album_detail_screen.dart:258`
   `'/photo/$id'` → `'/photo/${Uri.encodeComponent(id)}'`
4. `lib/widgets/asset_grid.dart:101`
   `'/photo/$id'` → `'/photo/${Uri.encodeComponent(id)}'`

(All four already import `package:go_router/go_router.dart`.)

No changes to:
- `lib/features/search/widgets/recently_viewed_row.dart` (already correct)
- `lib/core/router/app_router.dart` (route stays `/photo/:id`)
- Database layer (root cause is in the URL builder, not the data model)

## Verification

1. `tool/check.sh` passes (analyze + build_runner + tests).
2. Widget test: navigate from a Library preview grid to detail with an
   iOS-shaped id (`{uuid}/L0/001`) and assert `PhotoDetailScreen` is on the
   stack — covers the regression at the widget layer. Use the existing
   `library_screen_test.dart` patterns (see `lib/features/library/`).
3. On-device manual repro on the iPhone 17 Pro Max: tap a Library preview, a
   Saved cell, an album photo, and a folder-detail cell. All four should open
   the detail viewer (no `Page Not Found`). Confirm in
   `adb logcat -s flutter:V SoloGallery:V` that no `GoException` lines appear
   after the taps.

## Out of scope

- Layered defense (filter empty ids at the DAO, guard at every tap site).
  The empty-id theory is no longer the leading hypothesis; the slashes-in-id
  fix fully explains the symptom. Revisit only if "Page Not Found" recurs
  with a non-path-shaped id in the logs.
- Recently-viewed bootstrap cleanup (table may carry stale rows from prior
  installs; not the cause of this bug, separate concern).
