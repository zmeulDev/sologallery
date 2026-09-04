# Plan: Move filters below memories, day-group This Week, larger month headers

## Status
Implemented and verified (2026-07-23). Host checks pass; integration test passes on Pixel 9 Pro XL. Awaiting manual end-to-end visual confirmation from user.

## Changes requested

1. **Move the filter bar under the memories carousel.** Currently `LibraryFilterBar` sits above the body. The new order on the `All` filter should be:
   - App bar
   - `LimitedAccessBanner` (if any)
   - `MemoriesCarousel`
   - `LibraryFilterBar`
   - Month timeline

   On `Months`, `Year`, and `This week` the memories carousel is hidden, so the filter bar still sits at the top of the body. This preserves the rule that filters are always visible and immediately above the content they control.

2. **Group `This week` by day.** Instead of one flat grid, render a section per calendar day with a 3×2 preview grid, like the month sections but labelled with the day name and date (e.g. `Today`, `Yesterday`, `Monday, Jul 21`). Each section is tappable and opens that day's full grid (route TBD; for now we keep the section header non-tappable or route to a placeholder).

3. **Make month/year section headers bigger.** Replace the small uppercase `SectionHeader` for months with a larger, sentence-case label like `June 2026`. The count still sits on the same baseline as a quiet caption. Year heroes (`2026`) stay as the existing display face but may need a size/weight adjustment to maintain hierarchy below the new month header.

## Proposed design details

### Filter placement

- Extract the filter bar out of the fixed `Column` at the top of `LibraryScreen` and render it as the first item inside each filter's scrollable body, **except** on `All` where it is rendered immediately after the `MemoriesCarousel`.
- The simplest robust approach: keep `LibraryFilterBar` where it is for non-`All` filters; for `All`, render `MemoriesCarousel` as a pinned/sliver-like header above the filter bar, or move the filter bar into `_MonthList` as the first item when `filter == LibraryFilter.all`.
- Because the carousel collapses to zero height when empty, placing the filter bar after it naturally keeps the timeline flush with the top when there are no memories.

### This Week day grouping

- Add `IndexDao.watchDayCounts(DateTime cutoff)` returning `List<({DateTime day, int count})>` for non-empty calendar days on/after the cutoff, newest first, using SQLite `STRFTIME('%Y-%m-%d', created_at, 'unixepoch', 'localtime')`.
- Add `IndexDao.watchDayPreviews(DateTime day)` returning up to 6 newest ids for that day.
- Add `thisWeekDayCountsProvider` and `dayPreviewsProvider` in `library_providers.dart`.
- Build `_ThisWeekList` using the same `_LibrarySection` + `_PreviewGrid` pattern, with one section per day.
- Day label formatter:
  - Same calendar day as now → `Today`
  - Yesterday → `Yesterday`
  - Otherwise → `Monday, Jul 21` (weekday + short month + day)
  - No year shown because the window is ≤7 days.

### Larger month/year headers

- Create `lib/features/library/widgets/month_header.dart`: a row with the month name in `TextStyle(fontSize: 22, fontWeight: FontWeight.w700)` (same weight as page title, using the existing `display` or `pageTitle` token would be too heavy for a section; we introduce a new token or reuse `pageTitle` at 20sp). Actually the user said "example June 2026" which is sentence case and larger. We can use `AppTextStyles.pageTitle` (22sp/700) directly; it's already a token and reads as a bold header.
- The count sits on the same baseline in `caption`/textSecondary.
- Keep `SectionHeader` for `Older` only (or for any future small-label case).
- Year heroes: keep `YearHeader` but consider reducing its display size if it now competes with the 22sp month header. The existing `display` is 34sp. Hierarchy check: year (34) > month (22) > day/section labels — acceptable.
- The `Months` filter still uses `YearHeader` above its months; `All` uses no year hero.

## Files to change

| File | Change |
|------|--------|
| `lib/features/library/library_screen.dart` | Move filter bar into body; render carousel before it on `All`; update `_ThisWeekGrid` to use new day-grouped list; use `MonthHeader` in `_MonthSection`. |
| `lib/features/library/widgets/month_header.dart` | New widget: large sentence-case month label with count. |
| `lib/features/library/widgets/library_filter_bar.dart` | Minor: add a `padding` variant or keep existing; may need a top/bottom margin tune when living under the carousel. |
| `lib/core/database/daos/index_dao.dart` | Add `watchDayCounts` and `watchDayPreviews`. |
| `lib/features/library/library_providers.dart` | Add `thisWeekDayCountsProvider` and `dayPreviewsProvider`; update keep-alive. |
| `lib/features/library/domain/library_timeline.dart` | Possibly create a day-grouping helper; or build inline in `_ThisWeekList`. |
| `test/features/library/library_screen_test.dart` | Update filter position assertions; add This Week day grouping assertions; update month header text expectations. |
| `test/features/library/library_providers_test.dart` | Add day-count query tests. |
| `test/features/library/library_spacing_test.dart` | Re-measure spacing after header size change and filter move. |
| `test/widgets/design_goldens_test.dart` | Add golden for `MonthHeader` and update `YearHeader` if changed. |

## Verification plan (after approval)

1. `flutter analyze` — zero warnings.
2. `tool/check.sh` — analyze + build_runner + unit/widget tests.
3. Widget tests: filter position, day grouping, larger month headers, spacing preserved.
4. Golden update for `MonthHeader`.
5. Manual check on Pixel 9 Pro XL: filter bar sits under memories; This week shows day sections; month headers are larger and readable.

## Risks / notes

- Moving the filter bar into the scrollable body means it scrolls away with the timeline. This is intentional per the request, but it removes the always-visible filter. If the user wants it sticky, that is a separate change.
- Day grouping for `This week` needs a new DAO query and provider family. Keep it reactive so a new capture today appears instantly.
- The larger month header may change the measured inter-section rhythm in `library_spacing_test.dart`; we will re-measure and adjust.
- I cannot see the running app directly; if the user has a specific size/weight in mind for the month header, describe it before approval.

## Implementation notes

- Filter bar placement: kept the plan's detailed approach — the filter bar is now the first item inside each filter's scrollable body, and on `All` it is rendered immediately after `MemoriesCarousel`. It therefore scrolls away with the timeline; this matches the requested "immediately above the content it controls" rule.
- Day grouping: added `IndexDao.watchDayCounts`/`watchDayPreviews`, `thisWeekDayCountsProvider`/`dayPreviewsProvider`, and `_ThisWeekList` with `_DaySection`. Day headers are non-tappable until a day route is added.
- Month headers: new `MonthHeader` widget uses `pageTitle` sized down to 18sp/700 for the sentence-case month label, count in `caption`/textSecondary on the same baseline. `_MonthSection` uses it; `SectionHeader` remains for `Older` and day sections.
- `buildTimelineRows` now emits a `FilterBarRow` after `MemoriesRow` (when present), so `_MonthList` handles the filter bar alongside other timeline rows.

## Verification completed

1. `flutter analyze` — zero warnings.
2. `tool/check.sh` — analyze + build_runner + unit/widget tests all pass.
3. Widget tests updated for filter position, day grouping, sentence-case month headers, and spacing.
4. Golden files updated (`month_header.png` new, `year_header.png` updated).
5. Integration test `integration_test/library_month_grouping_test.dart` passes on Pixel 9 Pro XL.

## Next step

Manual visual check on device: confirm the filter bar sits under the memories carousel on `All`, `This week` shows day sections, and month headers are larger and readable.
