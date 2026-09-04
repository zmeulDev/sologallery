# Plan — Phase 2: Permissions + Month-Grouped Gallery

> **Status: ✅ Complete** (2026-07-17). `tool/check.sh` green (analyze clean,
> codegen ok, 56 host tests incl. Alchemist goldens). Release merged manifest
> re-verified network-free. Patrol on-device (Pixel 9 Pro XL): **grant → month
> grid renders** and **deny → onboarding** both pass, exercising the real
> `photo_manager` path (fake-pairing rule satisfied). First-run permission flow
> also manually verified end-to-end on device.
>
> **Deviations / follow-ups:**
> - **Android has no `notDetermined`** — onboarding tracks a local `_attempted`
>   flag so first-run shows "Allow" (not "Open Settings"). Recorded in CLAUDE.md.
> - **JVM Java-target fix extended** for the `patrol` module (align
>   `com.android.library` Java to 17 via the Android extension, not raw
>   `JavaCompile`). Recorded in CLAUDE.md.
> - **`developer.log` doesn't reach logcat** — the `SoloGallery:V` filter is
>   effectively empty; use `flutter logs`/DevTools. Recorded in CLAUDE.md.
> - Patrol **limited-access** case is `skip: true` (device-specific system photo
>   picker); the limited banner itself is covered by widget tests. Patrol
>   automation of denied→Settings→granted and revoked-mid-session not added
>   (Settings-toggle UI is fragile); the resume-refresh path is covered by the
>   `app.dart` lifecycle observer + manual verification.
> - `test_assets/` deterministic seed set (48MP HEIC, GPS JPEG, …) not populated
>   — needs real sample media; the patrol smoke asserts against the device's
>   real library instead. Left for the seeding/ML phase.

## Context

Phase 1 left a compiling, tested baseline: theme, GoRouter shell with four
placeholder tabs, Drift v1 schema, and a **stub** `PhotoLibraryService` that
only reads permission state (no prompt, no queries). The Library screen is a
`PlaceholderView`.

Phase 2 makes the app actually show photos. It delivers the first
permission-driven, plugin-backed feature, so it establishes the patterns every
later screen reuses: the `photo_manager` permission flow, asset/thumbnail
queries through the single service wrapper, the pure-Dart month-grouping domain
piece, the `AsyncValue`/paged provider pattern, and the first on-device patrol
permission-matrix tests.

Per CLAUDE.md this is architecture-heavy work kept in the main Opus session (no
delegation). All new UI surfaces are built **after invoking
`/frontend-design:frontend-design`**.

### Decisions locked with the user
- **View-all:** build the full-month grid screen **and** a `/month/:key` route
  this phase. Tapping a photo is inert until the Phase 3 detail viewer.
- **Permission UX:** a **dedicated onboarding screen** (route `/onboarding`,
  outside the tab shell), gated by a GoRouter redirect.
- **Testing:** set up **patrol** now and cover the full permission matrix
  on-device, in addition to unit + widget + golden tiers.

## Non-goals (later phases)
- Photo detail viewer `/photo/:id`, EXIF, favorite/share/delete actions (Phase 3)
- Saved/Albums screen logic (Phase 3) — but the shared paginator is built here
- Videos (Phase 2 is `RequestType.image` only), search, ML/indexing (Phase 4)

---

## Architecture

Strict layering (docs/spec.md#architecture): plugin types (`AssetEntity`,
`PermissionState`) never leave the data layer. Domain and UI reference photos by
**asset id** only.

### Data layer — `lib/services/`

**`photo_library_service.dart`** — extend the stub (keep `currentPermission`):
- `requestAccess()` → `PhotoManager.requestPermissionExtend()`, map result
- `openSettings()` → `PhotoManager.openSetting()`
- `presentLimited()` → `PhotoManager.presentLimited()` (iOS re-select / Android
  picker subset)
- `monthsInLibrary()` → resolves the `onlyAll` image path, reads total count and
  newest/oldest `createDateTime` (range 0..1 and last), returns the descending
  list of candidate `YearMonth`s spanning that range
- `monthSummary(YearMonth)` → filtered `getAssetPathList` with
  `FilterOptionGroup(createTimeCond: DateTimeCond(min,max))` +
  createDate-desc order; returns exact `assetCountAsync` and the first ≤6 asset
  ids (`getAssetListRange(0,6)`). **Lazy per-month — never loads full metadata**,
  honoring "never decode originals for grid cells".
- `monthAssets(YearMonth, page, pageSize)` → paged ids for the full-month screen
- `thumbnail(assetId, ThumbnailSize)` → `AssetEntity.fromId(id)` (cached map) →
  `thumbnailDataWithSize(...)` → `Uint8List?`

Expose `AssetRef { String id; DateTime createdAt }` as the pure projection the
service returns, so the domain/UI never touch `AssetEntity`.

**`paged_assets_notifier.dart`** (CLAUDE.md's "shared pagination base for
Library, Saved") — a generic `PagedAssetsNotifier` holding
`{ List<AssetRef> items, bool hasMore, bool loading }` over an injected
page-fetch callback. Used now by the month-detail screen; reused by Saved in
Phase 3.

### Domain layer — `lib/features/library/domain/` (pure Dart, no plugin imports)
- **`year_month.dart`** — `YearMonth { int year, month }`: ordering, equality,
  `key` (`"2026-07"`, used in the route), `label` (`"July 2026"`), and a static
  `descendingRange(newest, oldest)` enumerator. Fully host-unit-tested.
- **`month_summary.dart`** — `MonthSummary { YearMonth month; int count;
  List<String> previewAssetIds }` (≤6 ids).

### Providers — Riverpod (manual, per conventions)
- `photoLibraryServiceProvider` — **keep-alive**, root service.
- `permissionProvider` — keep-alive `Notifier<PhotoAccess>` where
  `enum PhotoAccess { notDetermined, denied, limited, granted }` maps from
  `PermissionState`. Actions: `request()`, `openSettings()`, `refresh()`.
  A `WidgetsBindingObserver` (in `app.dart`) calls `refresh()` on app resume to
  catch **revoked-mid-session**. Mirrors into a `ValueNotifier` consumed by the
  router `refreshListenable`.
- `libraryMonthsProvider` — `autoDispose` `AsyncNotifier<List<MonthSummary>>`;
  loads candidate months, then lazily fills summaries in batches (skipping empty
  months), exposing `loadMore()` for infinite month scroll. Idle unless access
  is granted/limited.
- `monthAssetsProvider.family(YearMonth)` — `autoDispose` paged notifier built on
  `PagedAssetsNotifier` for the full-month grid.
- `thumbnailProvider.family(ThumbnailRequest{id,size})` — `autoDispose`
  `FutureProvider<Uint8List?>`; overridable in golden/widget tests.

### UI layer
- **`features/onboarding/onboarding_screen.dart`** (`/onboarding`, top-level, no
  tab shell): privacy explainer + "Allow photo access" (→ `request()`); on
  `denied` swaps to "Open Settings" (→ `openSettings()`); on granted/limited the
  redirect sends the user to `/`.
- **Router** (`app_router.dart`): add top-level `/onboarding` and
  `/month/:key` routes; add a `redirect` reading `permissionProvider` +
  `refreshListenable` — not-granted → `/onboarding`, granted-on-onboarding → `/`.
- **`features/library/library_screen.dart`** — replace `PlaceholderView`. App
  bar (title + inert search icon retained). Body via `AsyncValue.when`:
  loading / error / **empty** ("No photos yet") / data = scrollable list of
  **month sections** (section-label header → 6-thumbnail preview grid →
  "View all (N)" button → `/month/:key`). A **limited-access banner**
  ("You've allowed access to some photos — Select more") calling
  `presentLimited()` shows when `PhotoAccess.limited`. `loadMore()` on scroll.
- **`features/library/month_grid_screen.dart`** (`/month/:key`) — full paged
  grid for one month via `monthAssetsProvider`; parses/validates the key,
  loading/empty/error states; cells inert (Phase 3 wires detail).
- Shared widgets in `lib/widgets/`: `asset_thumbnail.dart` (watches
  `thumbnailProvider`, `gaplessPlayback`, muted placeholder box),
  `month_section_header.dart`, `limited_access_banner.dart`.

**Invoke `/frontend-design:frontend-design` before building onboarding, the
month section/preview grid + view-all control, the full-month grid, and the
limited-access banner.**

### Platform permission config
- **Android** `android/app/src/main/AndroidManifest.xml`: `READ_MEDIA_IMAGES`
  (API 33+), `READ_MEDIA_VISUAL_USER_SELECTED` (API 34 limited),
  `READ_EXTERNAL_STORAGE` `maxSdkVersion=32`. Re-verify the **release** merged
  manifest still has no `INTERNET`/`READ_PHONE_STATE`/`c2dm` (Definition of
  Done #5).
- **iOS** `ios/Runner/Info.plist`: `NSPhotoLibraryUsageDescription` +
  `PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES`.

---

## Tests (all tiers — see CLAUDE.md Test strategy)

**Unit (host):**
- `YearMonth`: descending enumeration incl. year boundary, `key`/`label`
  round-trip, ordering/equality.
- `PhotoAccess` mapping from every `PermissionState`.
- Providers via `ProviderContainer` + a **fake `PhotoLibraryService`**:
  permission transitions (request → denied/granted/limited, resume-refresh),
  `libraryMonthsProvider` load + `loadMore` + empty, `monthAssetsProvider`
  paging + `hasMore`.

**Widget (host, mocked providers):**
- Onboarding: notDetermined → grant CTA; denied → open-settings CTA.
- Library: loading / error / empty / data (section renders header, ≤6 previews,
  view-all with count) / limited-banner visible.
- Month grid: loading / data / empty.
- **Golden (alchemist)** — add alchemist tooling (deferred from Phase 1) and
  cover the new design-system widgets (`month_section_header`, view-all control,
  `limited_access_banner`, `asset_thumbnail` placeholder) in light + dark.

**Integration (on-device, patrol) — add patrol tooling now:**
- Permission matrix driving native dialogs: **granted · limited · denied ·
  denied→granted via Settings · revoked mid-session** (background → revoke →
  resume → onboarding reappears).
- **Real-path grid smoke** satisfying the fake-pairing rule: seed deterministic
  assets, grant access, assert month sections render and a view-all opens the
  month grid. Seed per CLAUDE.md:
  ```
  adb push test_assets/ /sdcard/Pictures/SoloGalleryTest/
  adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
    -d file:///sdcard/Pictures/SoloGalleryTest/
  ```
  (Note the CLAUDE.md gotcha: Flutter is invisible to uiautomator; use patrol's
  Flutter finders for in-app assertions, native driver for the OS dialogs.)

---

## Files (representative)
- `lib/services/photo_library_service.dart` (extend), `paged_assets_notifier.dart` (new)
- `lib/features/library/domain/{year_month,month_summary}.dart`
- `lib/features/library/{library_providers,library_screen,month_grid_screen}.dart`
- `lib/features/onboarding/onboarding_screen.dart`
- `lib/services/permission_provider.dart`
- `lib/widgets/{asset_thumbnail,month_section_header,limited_access_banner}.dart`
- `lib/core/router/app_router.dart` (redirect + routes), `lib/app.dart` (resume observer)
- `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`
- `pubspec.yaml` (+`patrol`, +`alchemist` dev deps)
- `test/**` mirrors; `integration_test/**` (patrol); `test_assets/` seed set

---

## Verification (Definition of Done)
1. `tool/check.sh` — analyze clean, codegen, all unit+widget+golden tests pass.
2. `flutter test integration_test -d 46121FDAS008AA` (patrol) — permission
   matrix + real-path grid smoke pass on the Pixel 9 Pro XL.
3. Manual on-device: fresh install → onboarding → grant → months render, scroll
   loads more, view-all opens month grid; limited access shows banner; revoke in
   Settings + resume → onboarding returns. Debug via
   `adb logcat -s flutter:V SoloGallery:V` (no screenshots).
4. Release merged manifest re-verified network-free (`./gradlew
   :app:processReleaseManifest` + grep).
5. No schema change this phase (skip migration test). CLAUDE.md Known gotchas
   updated if anything surprising surfaces (e.g. limited-access asset-set
   behavior).
6. Copy this plan to `docs/plans/phase2-permissions-gallery.md` and mark
   complete; update the project-status memory.

## Sequencing (suggested)
1. Platform manifest/plist + `photo_manager` permission methods in the service
   → verify request/grant on device early.
2. `permissionProvider` + router redirect + onboarding screen.
3. Domain (`YearMonth`) + service queries + `libraryMonthsProvider` + Library
   grid (frontend-design pass).
4. `paged_assets_notifier` + month grid screen + `/month/:key`.
5. Tests: unit → widget/golden (alchemist) → patrol matrix + seeded smoke.
