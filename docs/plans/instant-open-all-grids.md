# Screen performance pass — Albums / People / Search / Saved (2026-07-27)

**Status:** VERIFIED (host + partial device), 2026-07-27. All tiers implemented
(Tier 1 P1/P2/G1, Tier 2 P3/P4/G2/G3, Tier 3 P5/P6/P7/G4/B9), diff-reviewed,
and checked as below.

### Verification results (2026-07-27)
- **`flutter analyze`:** clean (fixed one `use_null_aware_elements` info in the
  P1 folder builder: `if (folder != null) folder` → `?folder`).
- **`dart run build_runner build`:** 466 outputs, no errors (no schema change).
- **`flutter test` (host suite): 764/764 PASS.** First run surfaced 12 failures,
  ALL fixture bugs in the newly-written tests (no production regression): 8
  instant-open tests fed non-decodable `Uint8List.fromList([1,2,3])` thumbnail
  bytes → switched to real `test_assets/small_png.png` via a new
  `validThumbnailBytes` helper in `test/support/asset_fixtures.dart`; 3
  `FaceAvatar` tests lacked `theme: AppTheme.light` → added; 1 `PeopleStrip`
  test leaked a pending timer from P4's async `personCoversProvider` → added the
  same override the other People tests already had. Zero `lib/` changes to fix.
- **Device (Pixel 9 Pro XL, Android 17, profile build):**
  - `integration_test/device_folders_test.dart` — PASS (all 4, incl. cold-service
    deep-link). Confirms P1's real `photo_manager` folder path + `folderAssets`
    cold-start refill.
  - `integration_test/search_test.dart` — PASS (all 3, incl. favourites
    resolution → exercises P7's concurrent `resolveFavoriteMatches`). Needed
    `adb pm grant` of media perms after the teardown-uninstall wiped them.
  - Manual profile-mode drive via adb: Library grid scrolled 2026→2022 across
    ~40 flings with **zero "Skipped frames"/Davey logs**; photo-open from grid
    (G1) and Albums tab-switch (P1) painted immediately with no stall and no
    jank logs; video cells showed duration badges (P5 gate intact) while
    scrolling past photos logged no jank. No crashes/ANR throughout.
- **NOT measured on-device (covered by host tests only):** Saved masonry scroll
  jank (P2/P3/G3) and People strip/grid scroll (P4) — a fresh install has no
  favourites and no analyzed faces, and seeding enough favourites via blind adb
  proved unreliable (detail viewer's single-tap-toggles-chrome). Precise
  first-paint/frame-time numbers also unavailable via adb (Flutter renders off
  the platform frame-stats collector; needs DevTools over the VM service).

### Decisions locked (Tier 1)
- **P1 (B1):** parallelize `deviceFolders()` per-folder count+cover with
  `Future.wait`, AND memoize the result in `PhotoLibraryService._folderCache`,
  cleared by the existing library-change callback (`_handleChange`) +
  `stopLibraryChangeNotify`. Provider stays `autoDispose` (now cheap — no IPC on
  revisit). Chosen over dropping `autoDispose` because service-level memoization
  gets correct invalidation for free from the change callback, with no schema
  change and no layer coupling.
- **P2 (B3+B4): DONE.** mutable layout memo inside `MasonryGridDelegate` keyed on
  `crossAxisExtent` (delegate no longer `const`); `_SavedGrid` → `StatefulWidget`
  caching `items`/`assetIds`/`delegate`, recomputed only on real favourites
  content change (cheap content compare — favourites is a small set). Stable
  delegate identity is what lets the memo survive scroll frames.
  Files: `lib/features/saved/widgets/masonry_grid_delegate.dart`,
  `lib/features/saved/saved_screen.dart`. Tests added (not run per user
  instruction): `test/features/saved/widgets/masonry_grid_delegate_test.dart`
  (memo hit/miss on `crossAxisExtent`), and a widget test appended to
  `test/features/saved/saved_screen_test.dart` (identical `gridDelegate` across
  a rebuild with structurally-equal but freshly-allocated favourites, via a
  `StreamController` override of `savedFavoritesProvider`).
- **G1:** `AssetGrid` → `ConsumerWidget`; tap warms `thumbnailProvider` at
  width/height **400** (matches `AssetThumbnail(size: 400)` for a cache hit) +
  fires `previewImage(id, kDetailImageMaxEdge).ignore()`, pushes with
  `initialBytes`.

### Decisions locked (Tier 2)
- **P3 (B5) — scope reduced from "page the window" to a provider `distinct`.**
  Full pagination was rejected: it would regress the app-bar favourites count
  (loaded window ≠ true total), and P2 already eliminated the masonry reflow
  (B3/B4) that was B5's felt symptom. Favourites is a small, deliberately-kept
  set, so the residual cost is only Drift re-emitting an unchanged result on
  every `photo_asset` write during backfill. Fix: `savedFavoritesProvider`
  streams `watchFavoritesInCache().distinct(listEquals)` — `FavoriteAsset` is a
  record (structural `==`), so a no-op emission is dropped while a real change
  (favourite added/removed, or cached dims resolving 0→real) still propagates.
  *Optional follow-up if Saved ever grows large:* a dimension-carrying
  `WatchedFavoritesNotifier` (paged window) + a separate `COUNT(*)` provider for
  the bar. Not needed now.
- **G2 — album detail has its OWN `_Grid`, not the shared `AssetGrid`,** so G1
  did not cover it; applied the same warm-up/`initialBytes` mirror directly.
- **P4 (B2) — batched covers, not grouped SQL.** `coverFacesFor(personIds)`
  reuses the proven `coverFace` per person under one `Future.wait`; a single
  `personCoversProvider` resolves all covers once off the summaries stream;
  `FaceAvatar` gains an optional `cover:` (grid + strip pass it, person-detail
  keeps the `personCoverProvider` fallback). Kills the per-cell scroll-in
  fan-out without touching `coverFace`'s cover-selection logic.

Started as "extend the instant-detail-open technique to all grids." Widened
after the user reported all four symptoms — screens slow to appear, janky
scroll, sub-screens slow to open, photos slow to open — on Albums, Album
detail, People, Search, and Saved/Favourites. Investigation found real
bottlenecks beyond tap-open. This plan covers both.

Reference technique (already applied to the detail viewer): never show a
spinner/black — paint a decoded placeholder instantly, upgrade with
`gaplessPlayback`; right-size requests; short-lived LRU caches cleared on
background; parallelize platform round-trips; precache neighbours. See
`docs/completed/instant-detail-*.md`.

---

## Root causes by symptom (all verified, file:line)

### "Screen slow to appear"
- **B1 — `deviceFoldersProvider` scan (Albums + Search).** `deviceFolders()`
  loops every folder doing **2 serialized platform round-trips each**
  (`assetCountAsync` + a 1-item cover fetch) — `2×N` IPC calls, no batching
  (`photo_library_service.dart:399-434`). It's `autoDispose`
  (`folders_providers.dart:11`) so the whole scan **re-runs on every visit**;
  `_pathCache` doesn't memoize the result. Gates first paint of Albums. **Top
  cause.**
- **B5 — unbounded favorites stream (Saved).** `savedFavoritesProvider` →
  `watchFavoritesInCache` has **no LIMIT** (`index_dao.dart:487-502`,
  `saved_providers.dart:14`); the entire favourites set is streamed and
  re-mapped on the UI isolate on every emission, and it re-fires repeatedly
  during ML/metadata backfill → each time triggers a full masonry reflow.
- **B8 — serial favourite resolve (Search, favourites facet).**
  `resolveFavoriteMatches` loops `await _entity(id)` sequentially over every
  favourite (`photo_library_service.dart:353-369`, `search_providers.dart:172`)
  — results can't appear until the whole chain resolves.

### "Janky / stuttery scroll"
- **B3 — masonry layout recomputed every frame (Saved). Top jank cause.**
  `MasonryGridDelegate.getLayout` runs `layoutMasonry` over **all** favourites
  plus a per-column member loop on **every** layout pass, and a sliver
  re-lays-out as the scroll offset moves — so this O(n) allocation runs each
  frame even though `crossAxisExtent` is constant (`masonry_grid_delegate.dart:29-62`,
  `masonry_layout.dart:80-117`).
- **B4 — identity guard defeated (Saved).** `_SavedGrid.build` allocates fresh
  `items`/`assetIds` lists every build (`saved_screen.dart:89,100-102`), so the
  `identical(oldDelegate.items, items)` `shouldRelayout` guard
  (`masonry_grid_delegate.dart:49`) never holds → full reflow on every rebuild.
- **B2 — per-cell face-avatar fan-out (People grid + strip).** Each avatar cell
  fires `personCoverProvider` (**2–3 DB queries per person**,
  `faces_dao.dart:360-378`) + a thumbnail header decode as it scrolls in
  (`face_avatar.dart:152,167`).
- **B6 — redundant per-cell video probe (Saved).** Every Saved cell passes
  `showVideoBadge:true` → a second `AssetEntity.fromId` round-trip via
  `videoDurationProvider` (`saved_screen.dart:134`, `asset_thumbnail.dart:69`)
  even for photos; the DB row already has `isVideo`.
- **B7 — live label aggregate (Search idle).** `topBrowseLabelsProvider` is a
  reactive `GROUP BY label` re-emitting on every indexer write
  (`search_providers.dart:121`, `index_dao.dart:538-559`).

### "Slow to open a photo" (tap → detail viewer)
- **G-series** below. Only the Library preview grid warms + forwards
  `initialBytes`; every other grid opens on the `PhotoPage` spinner.

### "Slow to open the sub-screen" (album card / avatar → its grid)
- Album detail / person detail route through the shared `AssetGrid`; making the
  grid paint instantly (G1) + its first-page thumbnails warm covers most of it.
  Entry providers (`albumEntriesProvider`) are cheap Drift streams — not a
  bottleneck.

### Rule violation (not a navigate-in cost, fix while here)
- **B9 — `planClusters` on the UI isolate.** Only `clusterAll` is offloaded via
  `Isolate.run`; `planClusters` (O(faces×groups)) runs on the UI isolate
  (`indexing_service.dart:735-736`). Move it inside the same `Isolate.run`.

Verified NOT bottlenecks: `albumSummariesProvider` / `personSummariesProvider`
/ `facesEnabledProvider` are plain Drift streams (People screen reads
precomputed clusters — no live ML on navigate); Search date parsing is
debounced 280 ms and O(1) per query; Saved aspect ratios use cached DB
dimensions (no per-cell decode).

---

## Plan (priority = symptom impact)

### Tier 1 — biggest felt wins
- **P1 (B1)** — Fix `deviceFolders()`: `Future.wait` the per-folder count+cover
  calls instead of the serial loop, and stop recomputing every visit (keep-alive
  or memoize the result; ideally persist folder rows to Drift and stream them).
- **P2 (B3+B4)** — Memoize the masonry layout keyed by `(crossAxisExtent,
  identical(items))`; stabilize the `items`/`assetIds` list identity across
  benign rebuilds so the relayout guard actually holds.
- **G1** — Shared `AssetGrid` → `ConsumerWidget`; on tap read
  `thumbnailProvider(...).value` for `initialBytes` + fire-and-forget
  `previewImage(id, kDetailImageMaxEdge)` (mirror `library_screen.dart:555-574`).
  Fixes tap-open for month/year/older/day, folder detail, person detail, Search
  results in one change.

### Tier 2
- **P3 (B5)** — Page the favourites window (reuse the Library
  `WatchedAssetsNotifier` pattern) instead of the unbounded stream; at minimum
  stabilize identity so unchanged emissions don't reflow.
- **P4 (B2)** — Fold the cover box into `watchPersonSummaries` (one join returns
  id+name+count+cover) so avatar cells stop doing per-cell `coverFace` queries;
  pre-warm avatar thumbs.
- **G2 — DONE.** `_Grid` (`album_detail_screen.dart`) → `ConsumerWidget`; tap
  reads `thumbnailProvider(ThumbnailRequest(id, width: 400, height: 400))`
  (matches the `AssetThumbnail(size: 400)` below it), fires
  `previewImage(id, kDetailImageMaxEdge).ignore()`, pushes with
  `initialBytes: thumb.value` — same pattern as G1's `AssetGrid`. Tests added
  (not run per user instruction): two cases appended to
  `test/features/albums/album_detail_screen_test.dart` (non-null
  `initialBytes` + correct `assetIds`/index; pre-warm calls `previewImage`
  with `kDetailImageMaxEdge`), using a `GoRouter`-backed pump helper
  (`pumpWithRouter`) mirroring `test/widgets/asset_grid_test.dart`'s
  push-capture pattern.
- **G3** — Saved masonry tap warm-up + `initialBytes`; right-size the requested
  thumbnail to the wider 2-col cell (`saved_screen.dart:127,134`).

### Tier 3 — cheap polish
- **P5 (B6)** — Gate `showVideoBadge` / `videoDurationProvider` on the DB
  `isVideo` flag so photos skip the extra probe.
- **P6 (B7)** — Throttle/snapshot `topBrowseLabelsProvider` instead of a live
  aggregate.
- **P7 (B8)** — Resolve favourite entities concurrently (bounded `Future.wait`)
  or intersect in SQL on the Search favourites path.
- **G4 — DONE.** Search recently-viewed row: right-size `size` + tap warm-up
  (`recently_viewed_row.dart` `_RecentCell`). Tests added (not run per user
  instruction): `test/features/search/widgets/recently_viewed_row_test.dart`
  (new file).
- **B9** — Move `planClusters` into the `Isolate.run` with `clusterAll`.

Suggested order: P1 → P2 → G1 (each independently shippable + device-measurable),
then Tier 2, then Tier 3.

---

## Testing (per CLAUDE.md tiers)
- **Unit:** masonry memoization (same width+items → identical layout instance,
  no recompute); `deviceFolders` concurrent-fetch correctness; paged favourites
  window; `watchPersonSummaries` cover join.
- **Widget:** each converted grid pushes `PhotoViewerArgs` with non-null
  `initialBytes` when cached; Saved grid doesn't relayout on an
  identical-content rebuild; video badge absent for image rows.
- **Golden:** grids/masonry/avatars unchanged — existing goldens hold.
- **Integration (Pixel 9 Pro XL):** navigate to Albums/People/Search/Saved and
  measure first-paint; scroll Saved + People for frame drops; open a photo from
  each grid (no spinner); re-run `detail_actions_test` / `hero_dismiss_test` /
  `album_detail_screen_test`.

## Definition of Done
1. `tool/check.sh` clean.
2. Device: Albums/Saved/Search appear without a stall; Saved + People scroll at
   60fps; grids open photos instantly; sub-screens paint immediately.
3. Integration tests for touched areas pass on device.
4. No schema change unless P3/P4 add a persisted folder/cover table → then dump
   schema + migration test.
5. No new dep → no manifest re-verify.
6. This doc updated with before/after device timings; move to `docs/completed/`.

## Next step
**ALL tiers implemented (P1–P7, G1–G4, B9); tests written but NOT run** (user
runs the suite at the end). Nothing verified yet — no `flutter analyze`, no
`tool/check.sh`, no device pass.

Before shipping, in order:
1. `tool/check.sh` (analyze + build_runner + unit/widget tests). Two likely
   friction points: P5 added an `indexDaoProvider` read inside
   `videoDurationProvider`, so several widget tests were patched to back
   `databaseProvider` with an in-memory DB — watch for any badge-bearing
   thumbnail test that still lacks one; and confirm the new `.distinct` /
   record-equality tests behave under `pumpEventQueue()`.
2. Touched integration tests on the Pixel 9 Pro XL: Albums/People/Search/Saved
   first-paint, Saved + People scroll, open-a-photo-from-each-grid,
   `detail_actions_test` / `hero_dismiss_test` / `album_detail_screen_test`.
3. Record before/after first-paint + scroll timings here, then move this doc to
   `docs/completed/`.

Source files touched (16): P1 `photo_library_service.dart`; P2
`masonry_grid_delegate.dart` + `saved_screen.dart`; G1 `asset_grid.dart`; P3
`saved_providers.dart`; G3 `saved_screen.dart`; P4 `faces_dao.dart` +
`people_providers.dart` + `face_avatar.dart` + `people_screen.dart` +
`people_strip.dart`; G2 `album_detail_screen.dart`; P5 `thumbnail_provider.dart`
+ `index_dao.dart`; P6 `search_providers.dart`; P7 `photo_library_service.dart`;
G4 `recently_viewed_row.dart`; B9 `indexing_service.dart`.

New test files: `test/widgets/asset_grid_test.dart`,
`test/features/saved/widgets/masonry_grid_delegate_test.dart`,
`test/features/people/face_avatar_widget_test.dart`,
`test/services/thumbnail_provider_test.dart`,
`test/features/search/widgets/recently_viewed_row_test.dart`. Edited test files:
`saved_providers_test.dart`, `saved_screen_test.dart`, `faces_dao_test.dart`,
`index_dao_test.dart`, `people_screen_test.dart`, `design_goldens_test.dart`,
`album_detail_screen_test.dart`, `search_providers_test.dart`,
`face_clustering_test.dart`, plus the badge-bearing widget tests patched for P5
(`asset_thumbnail_test.dart`, `thumbnail_radius_test.dart`,
`folder_detail_screen_test.dart`, `library_screen_test.dart`,
`library_spacing_test.dart`) and `fake_photo_library_service.dart`
(`videoDurationCalls` recorder).

Testing gaps (no host-test seam — on-device integration only): P1 and P7 (the
`FakePhotoLibraryService` overrides those methods; see the "Testing gap" notes
below). Possible follow-ups noted inline: P3 paged window if Saved grows large;
P6 query-level throttle (vs. the emission-level `distinct` shipped).

## Testing gap (P1 / B1)
`deviceFolders()` was fixed (parallel `Future.wait` per-folder resolve +
`_folderCache` memoization, invalidated by `_handleChange` /
`stopLibraryChangeNotify`), but neither change has unit coverage.
`FakePhotoLibraryService.deviceFolders()`
(`test/support/fake_photo_library_service.dart:198-209`) fully **overrides**
the base method with its own duplicate sort/filter logic instead of calling
`super.deviceFolders()`, and there is no `MethodChannel` mock or wrapper seam
for `PhotoManager`'s static calls anywhere in the test suite. So the fake
never exercises the real service body — `_folderCache` and the `Future.wait`
resolution are both unreachable from host tests as things stand.
`folders_providers_test.dart`'s "sorts by count descending" / "breaks ties by
name" tests only validate the fake's own re-implementation of that logic, not
the fixed `photo_library_service.dart` code path.
To close this, `PhotoLibraryService` needs a seam over
`PhotoManager.getAssetPathList` / `AssetPathEntity` (e.g. an injectable
path-lister function or a thin wrapper interface) so a host test can fake the
platform call and assert (1) a second `deviceFolders()` call doesn't re-invoke
it (memoization) and (2) `_handleChange`/`stopLibraryChangeNotify` clear the
cache. Until then, real coverage is the on-device integration test only.

## Testing gap (P7 / B8)
`resolveFavoriteMatches` was fixed (concurrent `Future.wait` over
`_entity(id)` instead of a sequential loop, `photo_library_service.dart:357-`
onward), but the change has no unit coverage for the same reason as P1:
`FakePhotoLibraryService.resolveFavoriteMatches`
(`test/support/fake_photo_library_service.dart:180-196`) fully **overrides**
the base method with its own duplicate filter/sort logic keyed off the fake's
in-memory `assets`/`undatedAssets` maps, instead of calling
`super.resolveFavoriteMatches()`. There's still no `MethodChannel` mock or
wrapper seam for `AssetEntity.fromId` (which backs `_entity`) anywhere in the
test suite, so a host test can't reach the real method body — the
`Future.wait` concurrency and the index-correspondence pairing (`ids[i]` ↔
`entities[i]`) are both unreachable from host tests as things stand. Until
`PhotoLibraryService` grows an injectable seam over `AssetEntity.fromId`
(same shape as the `deviceFolders` gap above), real coverage of this method —
serial or concurrent — is the on-device integration test only. No new test
was added for this fix; behaviour (filtering, window, drop-unresolvable,
sort) is unchanged from the prior serial version, only the resolve strategy
changed.
