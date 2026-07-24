# Plan: Make every Library section header tappable with a count pill

## Status

Implemented and verified (2026-07-23). Host checks for the touched area pass; integration test passes on Pixel 9 Pro XL after granting media permissions. Awaiting manual visual confirmation from the user for the final on-device checks.

## Subject and single job

- **Product:** SoloGallery.
- **Screen:** Library home and its time-filter variants (`All` / `This week` / `Months` / `Year`).
- **Single job:** Every section header must show a clear "view all" affordance — a count pill with an arrow — and tapping it opens the full grid for that time bucket.

## Current state

- `All`/`Months` already render `MonthHeader` with the count and a chevron, but the count is plain caption text, not a pill.
- `Year` renders `YearHeader` with the year in the display face and a plain count; it is **not** tappable and there is no full-year grid route.
- `This week` renders day sections with `SectionHeader` + count; the header is **not** tappable and there is no full-day grid route.
- The "Older" section already routes to `/older`, using `SectionHeader` with a separate trailing count and chevron.
- Full-month and full-Older grids exist (`MonthGridScreen`, `OlderGridScreen`) with corresponding DAO methods and `WatchedAssetsNotifier` providers.

## Proposed changes

### 1. Shared count pill widget

Create `lib/features/library/widgets/section_count_pill.dart`:

- A visual (non-interactive) pill using `colors.surface2` and a `StadiumBorder`.
- Contains the count in `caption`/`textSecondary` plus `Icons.chevron_right_rounded` in `textMuted`.
- Uses `itemCountLabel(count)` because a time bucket can contain both photos and videos.
- Sits at the trailing end of section headers; the **whole header row** remains the tap target, so the pill is only an affordance, not a separate button.

### 2. Update `MonthHeader`

- Keep the sentence-case month label on the left.
- Replace the plain count/chevron with the new `SectionCountPill`.
- The whole row stays tappable via `HitTestBehavior.opaque` and `Semantics(button: true)`.
- When `onTap` is non-null the pill shows the arrow; when null it shows just the count (used only in isolated golden/widget tests).

### 3. Update `YearHeader`

- Add an optional `VoidCallback? onTap`.
- Keep the large display year on the left.
- Show the count pill on the right; make the whole row tappable when `onTap` is set.
- Switch the count label from `photoCountLabel` to `itemCountLabel` so it matches `MonthHeader` and the actual bucket contents (still + video).

### 4. Replace `SectionHeader` usage for day/older sections

In `library_screen.dart`, replace `_LibrarySection`'s use of `SectionHeader` with a small local header that:

- Renders the uppercase section label in `sectionLabel` style.
- Uses the same `SectionCountPill` for the count + arrow.
- Makes the whole row tappable and routes to the full grid.

This avoids `SectionHeader` automatically adding a second chevron outside the pill.

### 5. Full-year grid

- **DAO:** add `IndexDao.watchYearAssets(int year, {required int limit})` — the year-range mirror of `watchMonthAssets`.
- **Provider:** `lib/features/library/year_assets_provider.dart` with `YearAssetsNotifier extends WatchedAssetsNotifier` and `yearAssetsProvider` keyed by year.
- **Screen:** `lib/features/library/year_grid_screen.dart` (analogous to `MonthGridScreen`).
- **Route:** `/year/:year` in `app_router.dart`.

### 6. Full-day grid

- **DAO:** add `IndexDao.watchDayAssets(DateTime day, {required int limit})` for the calendar-day window `[start, start+1 day)`.
- **Provider:** `lib/features/library/day_assets_provider.dart` with `DayAssetsNotifier extends WatchedAssetsNotifier` keyed by calendar day.
- **Screen:** `lib/features/library/day_grid_screen.dart`.
- **Route:** `/day/:date` using ISO date (`2026-07-23`) in `app_router.dart`.

### 7. Wire taps on the Library home

- `_MonthSection`: `MonthHeader.onTap` → `context.push('/month/${month.key}')` (already wired).
- `_YearSection`: `YearHeader.onTap` → `context.push('/year/${entry.year}')`.
- `_DaySection`: local header onTap → `context.push('/day/${day.toIso8601String().split('T').first}')`.
- `_OlderSection`: local header onTap → `context.push('/older')` (already wired).
- `Months` filter year heroes also get `onTap` so a year hero opens that year’s full grid, not only its month sections.

## Files to change

| File | Change |
|------|--------|
| `lib/features/library/widgets/section_count_pill.dart` | New reusable count + chevron pill. |
| `lib/features/library/widgets/month_header.dart` | Use the pill; keep row tappable. |
| `lib/features/library/widgets/year_header.dart` | Add `onTap`, use the pill, switch count to `itemCountLabel`. |
| `lib/features/library/library_screen.dart` | Wire year/day taps; replace `_LibrarySection` header. |
| `lib/core/database/daos/index_dao.dart` | Add `watchYearAssets` and `watchDayAssets`. |
| `lib/features/library/year_assets_provider.dart` | New `YearAssetsNotifier` + `yearAssetsProvider`. |
| `lib/features/library/day_assets_provider.dart` | New `DayAssetsNotifier` + `dayAssetsProvider`. |
| `lib/features/library/year_grid_screen.dart` | New full-year grid screen. |
| `lib/features/library/day_grid_screen.dart` | New full-day grid screen. |
| `lib/core/router/app_router.dart` | Register `/year/:year` and `/day/:date`. |
| `test/features/library/library_screen_test.dart` | Add routes for `/year/:year` and `/day/:date`; update year count text assertions; add tap-to-navigate tests for year and day headers. |
| `test/features/library/year_grid_screen_test.dart` | New: title, grid, empty, invalid year. |
| `test/features/library/day_grid_screen_test.dart` | New: title, grid, empty, invalid date. |
| `test/features/library/year_assets_provider_test.dart` | New: paging and reactivity for year window. |
| `test/features/library/day_assets_provider_test.dart` | New: paging and reactivity for day window. |
| `test/features/library/library_spacing_test.dart` | Re-run geometry assertions; adjust if the pill changes header metrics. |
| `test/widgets/design_goldens_test.dart` | Regenerate `month_header.png`, `year_header.png`; add `section_count_pill.png` golden. |

## Verification plan

1. `flutter analyze` — zero warnings.
2. `tool/check.sh` — analyze + build_runner + unit/widget tests.
3. Regenerate affected goldens (`month_header`, `year_header`, new `section_count_pill`).
4. Run `flutter test test/features/library/` and `test/widgets/design_goldens_test.dart`.
5. Run one relevant integration test on the connected Pixel 9 Pro XL, e.g. `library_month_grouping_test.dart`, then extend with a quick manual check of year and day routes.
6. Manual end-to-end on device:
   - `All`: tap a month header → full month grid opens.
   - `Months`: tap a year hero and a month header → full year / month grids open.
   - `Year`: tap a year header → full year grid opens.
   - `This week`: tap a day header → full day grid opens.
   - `Older`: tap the Older header → full Older grid opens.
7. Re-check the merged Android release manifest has no `INTERNET` / `READ_PHONE_STATE` / `c2dm` entries (this change does not add deps, but the release manifest check is part of the definition of done).

## Design choice to confirm

The `Year` sections currently say `"5 photos"`. I plan to align them with `MonthHeader` and use `"5 items"` because a year bucket can contain videos too. If you prefer to keep `"photos"` for year sections, let me know before I implement and I’ll leave `YearHeader` on `photoCountLabel`.

## Risks / notes

- The pill adds a filled shape next to the large year display. I will keep it visually quiet (`surface2`, small text, small chevron) so it does not fight the 34sp year headline.
- `SectionHeader` is intentionally left unchanged; only Library time-bucket headers move to the pill affordance, so Search/Albums/Memories headers stay as designed.
- Day route parsing relies on `DateTime.tryParse` for ISO date strings. Malformed dates fall back to a not-found screen, same pattern as invalid month keys.
- No schema or manifest changes are expected. If a test reveals a Drift accessor needs regeneration, we will run `dart run build_runner build` and include the generated file in the commit.

## Final state and verification

- `SectionCountPill` created and used by `MonthHeader`, `YearHeader`, and the day/Older sections in `LibraryScreen`.
- Full-year grid (`/year/:year`) and full-day grid (`/day/:date`) wired through DAO, provider, screen, and router.
- Year count copy changed from `"N photos"` to `"N items"` to match the rest of the Library headers.
- Tests updated:
  - `library_screen_test.dart`: year/day route stubs added, count assertions updated, new tap-navigation tests for year hero, year section, and day header.
  - New `year_grid_screen_test.dart`, `day_grid_screen_test.dart`, `year_assets_provider_test.dart`, `day_assets_provider_test.dart`.
  - Goldens regenerated: `month_header.png`, `year_header.png`; new `section_count_pill.png`. `album_card.png` was also regenerated due to unrelated host rendering drift.
- `flutter analyze` passes with no issues.
- `dart run build_runner build` regenerated the Drift accessor for the new DAO methods.
- `flutter test test/features/library/` — all 83 tests pass.
- `flutter test test/widgets/design_goldens_test.dart test/features/library/library_spacing_test.dart` — all pass.
- Integration test `library_month_grouping_test.dart` passes on `46121FDAS008AA` after granting `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` via adb and using `--no-uninstall`.
- App launches on device without crashes.

## Follow-ups

- Manual visual/UX check on Pixel 9 Pro XL:
  - `All`: tap a month header → full month grid.
  - `Months`: tap a year hero and a month header.
  - `Year`: tap a year header → full year grid.
  - `This week`: tap a day header → full day grid.
  - `Older`: tap the Older header → full Older grid.
- The full `flutter test` suite currently has unrelated pre-existing failures/timeouts in `album_detail_screen_test`, `folder_picker_sheet_test`, `indexing_service_test`, and `thumbnail_radius_test`. These are outside the touched area; I did not address them.
