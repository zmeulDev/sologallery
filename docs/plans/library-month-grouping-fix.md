# Fix: Library month grouping (DATE_TAKEN vs DATE_ADDED) + "Older" bucket

Status: **COMPLETE** (2026-07-18). Fix implemented, host suite + on-device
integration test green on the Pixel 9 Pro XL.
Next step: none. Follow-up (optional): seed EXIF-dated `test_assets/` so the
integration test can run against deterministic capture≠added photos in CI
rather than the device's live library.

## Symptom

Library shows a single "July 2026 · View all 62" section; opening it reveals
June-captured photos, and no June (or older) section ever appears.

## Root cause (confirmed against photo_manager 3.10.0 source)

The month-window filter and the grouping axis use **different Android columns**:

- Ordering + the `createDateTime` the app groups by → `DATE_TAKEN` (capture
  date), falling back to `DATE_ADDED` when `DATE_TAKEN == 0`
  (`CursorExtensions.kt` `getDateCommon`).
- `FilterOptionGroup.createTimeCond` (what `_imagesPath(min,max)` uses) →
  **hardcoded to `DATE_ADDED`** (`CommonFilterOption.kt:152`), i.e. when the
  file landed on the device.

June photos were *captured* in June (`DATE_TAKEN`) but *added* in July
(`DATE_ADDED`). So:
- `monthSummary(July)` filters `DATE_ADDED`∈July → matches all 62 → count 62,
  previews sorted by capture date.
- `monthSummary(June)` filters `DATE_ADDED`∈June → 0 → returns null → June
  section dropped.
- Inside July's grid → same July-added set ordered by capture date → June
  photos appear.

iOS is unaffected: `creationDate` is used for filtering, ordering, and the
reported date, so the axes already agree.

## Decision (chosen: Option B + "Older" bucket)

Filter each month window on the **same column used for ordering**
(`DATE_TAKEN`), via `AdvancedCustomFilter` (the classic `createTimeCond` cannot
retarget the column). Assets with no capture date (`DATE_TAKEN` null/0 →
`createDateTime` falls back to `DATE_ADDED`) do **not** match any capture-month
window; collect them into a single trailing **"Older"** section instead of
letting them pollute the added-month bucket or vanish.

Platform split: Android uses the new `AdvancedCustomFilter` path; iOS keeps the
existing `FilterOptionGroup`/`createTimeCond` path (already correct). "Older" is
Android-only in practice (iOS `creationDate` is effectively always present) and
will simply be empty on iOS.

### Verified photo_manager API (no hallucinated symbols)

- Path/count/range methods accept `PMFilter?`; `AdvancedCustomFilter extends
  CustomFilter extends PMFilter` ✓ (`photo_manager.dart:132`,
  `custom_filter.dart:28`).
- `DateColumnWhereCondition(column: CustomColumns.android.dateTaken, operator:
  '>=' | '<', value: DateTime)` — for `dateTaken` on Android it emits
  **milliseconds** (`advance.dart:414` `isSecond = column != dateTaken`).
- `CustomColumns.android.dateTaken == 'datetaken'`, `.createDate ==
  'date_added'` (`custom_columns.dart`).
- Null/zero capture date → raw `TextWhereCondition('datetaken IS NULL OR
  datetaken = 0')` (date columns reject `ColumnWhereCondition`; use text).
- `.addOrderBy(column: ..., isAsc: false)` for newest-first.

## Design

### 1. `PhotoLibraryService` (Android branch)
- Add a private `_monthWindowPath({DateTime? min, DateTime? max})` that on
  Android builds an `AdvancedCustomFilter` (dateTaken window + `addOrderBy`
  dateTaken desc) and on iOS delegates to the existing `_imagesPath`. Route
  `monthSummary`, `monthAssets`, and the span query through it.
- `monthsInLibrary()`: compute the span from **dated** assets only. On Android,
  the span path filters `datetaken > 0` (a `DateColumnWhereCondition` `>` epoch
  0, or text `datetaken > 0`) so an undated asset can't stretch the range.
- New `olderSummary()` → count + up to 6 preview ids of undated assets
  (`datetaken IS NULL OR datetaken = 0`), ordered by `date_added` desc. Returns
  null / empty on iOS or when none.
- New `olderAssets({page, pageSize})` for the Older grid.

### 2. Domain / providers
- Keep `MonthSummary` (calendar months) unchanged.
- Add `olderSummaryProvider` (autoDispose `AsyncNotifier` → count + preview ids,
  nullable/empty) and `olderAssetsProvider` (a `PagedAssetsNotifier` subclass
  like `MonthAssetsNotifier`, no family).

### 3. Library screen
- After the month sections, if `olderSummaryProvider` is non-empty, render one
  more section using `MonthSectionHeader(label: 'Older')` + preview grid, with
  "View all" → `context.push('/older')`.

### 4. Grid screen + router
- Extract the grid body from `month_grid_screen.dart` (`_Grid`) into a shared
  `AssetGrid` widget so both the month grid and a new `OlderGridScreen` reuse it
  (avoids duplication / dead code).
- Add route `/older` → `OlderGridScreen` (title "Older") watching
  `olderAssetsProvider`.

## Tests (Test strategy tiers)
- **Unit (host):** `YearMonth.start/end` window math is already covered; add a
  domain test for any pure helper introduced. The native filter itself can't run
  on host — covered by integration below (Fake-pairing rule).
- **Widget (host):** Library screen renders month sections **plus** an Older
  section when its provider yields data (override providers); Older grid renders
  data/empty. Golden for the Older section header if it introduces new styling
  (it reuses `MonthSectionHeader`, so likely none).
- **Integration (real device, patrol):** seed an asset whose EXIF
  `DateTimeOriginal` (→ `DATE_TAKEN`) is a **prior month** while `DATE_ADDED` is
  push time; assert (a) both its capture-month section and the current month
  appear with correct counts, (b) the capture-month grid contains it, (c) an
  asset with no EXIF date lands in **Older**, not the current month. This is the
  required real-path test — fakes bypass the native column bug.
- Seed via the CLAUDE.md deterministic-assets flow; reuse the GPS-EXIF JPEG
  (has a capture date) and the no-EXIF JPEG (→ Older).

## Step checklist
- [x] 1. Service: Android `AdvancedCustomFilter` month path + dated-span +
      `olderSummary`/`olderAssets`; iOS unchanged.
- [x] 2. Providers: `olderSummaryProvider`, `olderAssetsProvider`.
- [x] 3. Extract shared `AssetGrid`; refactor `MonthGridScreen`.
- [x] 4. Library screen Older section; add `/older` route + `OlderGridScreen`.
- [x] 5. Widget tests (Library + Older grid) + provider tests + fake models
      undated assets.
- [x] 6. Integration test on Pixel 9 Pro XL —
      `integration_test/library_month_grouping_test.dart` asserts every month
      section holds only assets whose `createdAt` is in that month (axes agree),
      sections are disjoint, paged counts match summaries, Older is disjoint.
      Passed against the live device library. (Ran against the real library
      rather than seeded assets — see follow-up.)
- [x] 7. `tool/check.sh` green; on-device integration test green (the DATE_TAKEN
      filter is native, so this is the real end-to-end verification). Gotcha
      added to CLAUDE.md.

## Files touched
- `lib/services/photo_library_service.dart` — `_path`/`_darwinFilter`/
  `_androidWindow`/`_androidUndated`/`_monthPath`, capture-date span,
  `olderSummary`/`olderAssets`.
- `lib/features/library/domain/older_summary.dart` — new `OlderSummary`.
- `lib/features/library/library_providers.dart` — `olderSummaryProvider`.
- `lib/features/library/month_assets_provider.dart` — `OlderAssetsNotifier` +
  `olderAssetsProvider`.
- `lib/widgets/asset_grid.dart` — new shared `AssetGrid`.
- `lib/features/library/month_grid_screen.dart` — uses `AssetGrid`; exports
  `CenteredNote`.
- `lib/features/library/older_grid_screen.dart` — new `OlderGridScreen`.
- `lib/features/library/library_screen.dart` — trailing Older section via
  `_LibrarySection`.
- `lib/core/router/app_router.dart` — `/older` route.
- Tests: `test/support/fake_photo_library_service.dart` (undated assets),
  `library_screen_test.dart`, `older_grid_screen_test.dart`,
  `library_providers_test.dart`, `integration_test/library_month_grouping_test.dart`.

## Notes / gotchas to fold into CLAUDE.md on completion
- photo_manager Android: `createTimeCond` filters `DATE_ADDED`; ordering &
  `createDateTime` use `DATE_TAKEN` (fallback `DATE_ADDED` when 0). To window by
  capture date, filter `CustomColumns.android.dateTaken` via
  `AdvancedCustomFilter` (emits **ms**, not seconds). Undated = `datetaken`
  null/0.
