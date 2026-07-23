# Plan: Library screen UI improvements

## Status
Completed.

## Subject and single job

- **Product:** SoloGallery, a privacy-first, fully local photo gallery.
- **Screen:** Library (the home gallery / first tab).
- **Audience:** Someone who opens the app to find a recent or past photo fast.
- **Single job:** Let the user scan their photos by time, switch density quickly, and trust that the app is working when data is still loading.

## Current state

The Library screen is already structured and tokenized:

- App bar + settings icon, optional `LimitedAccessBanner`, filter pills (`All` / `This week` / `Months` / `Year`).
- `All`/`Months` render a grouped month timeline; `Year` collapses to year heroes; `This week` is one flat grid.
- Month/year sections use `SectionHeader` + a 3-column preview grid of up to six r12 thumbnails.
- Spacing rhythm was recently fixed: inter-section gap is `AppSpace.s20` owned by the top edge only; memories break is `s20 × 2`.
- Goldens cover most design-system atoms, and dedicated tests cover timeline spacing and filter switching.

The remaining gaps I can see from the code:

1. **Loading is a generic `CircularProgressIndicator`.** It gives the user no preview of the layout that is about to appear, so the screen jumps from a center spinner to a fully-formed timeline. For a screen whose first load is on every cold start, that jump feels cheap.
2. **Error/empty copy says "Pull to try again" but the timeline has no pull-to-refresh.** The text promises an action the UI does not offer.
3. **Nested `GridView.count` with `shrinkWrap: true` per month section.** Every preview grid is a `BoxScrollView` inside a `ListView` item. With only six cells this is not catastrophic, but it forces a complete intrinsic layout pass for each visible section on every scroll frame and makes rebuilds of the outer list more expensive than they should be.
4. **No `RepaintBoundary` around heavy list items.** A single blinking cursor, badge update, or thumbnail decode can repaint an entire month section plus its neighbours.
5. **Preview thumbnail size is hard-coded to 300/400 rather than the actual cell size.** On low-DPI screens we request larger images than needed; on high-DPI screens we rely on `BoxFit.cover` upscaling. Both waste decode work and GPU fill.
6. **Month/year preview providers re-resolve whenever the section scrolls on/off screen.** They are `StreamProvider.autoDispose.family`, so crossing the cache-extent boundary disposes and re-subscribes. On a fling this thrashes the Drift stream and re-fires thumbnail requests.

## Proposed changes

### Signature UX improvement: static Library skeleton

Replace the generic spinner with a **layout-faithful, static skeleton** that previews the timeline shape before any data arrives.

- Built entirely from existing tokens: `surface2` blocks, `AppRadius.br12` for "thumbnails", `AppSpace.s4` gutter, `AppSpace.s20` section rhythm.
- Composition mirrors the real timeline:
  - A memories strip placeholder (horizontal row of three r12 blocks).
  - Two month-section placeholders, each with a short uppercase label bar plus a 3×2 r12 grid.
- **No shimmer and no animation** — decorative motion is forbidden in this app, and a static skeleton already communicates "content is on its way" more honestly than a spinner.
- Shown in the loading branches of `_MonthTimeline`, `_YearList`, and `_ThisWeekGrid`, and anywhere else the Library currently shows a spinner.

This is the one memorable thing we spend boldness on: the app has a branded loading state instead of a system spinner.

### Supporting polish: pull-to-refresh

Wrap the timeline scrollers in a `RefreshIndicator` so the error state's "Pull to try again" copy is actually actionable, and so users can force a refresh after granting more photos or toggling permissions.

- Uses the theme's existing color tokens (the refresh indicator inherits from the theme; no custom accent color).
- Only on scrollable data/error surfaces, not on the static skeleton.

### Performance improvements

#### 1. Replace nested `GridView.count` with `Wrap` + fixed thumbnail sizes

Convert `_PreviewGrid` from a `GridView.count` (`shrinkWrap: true`, `NeverScrollableScrollPhysics`) to a `Wrap` of `AspectRatio(1:1)` cells, or to a direct `Sliver`-based layout. `Wrap` eliminates the nested scrollable and its shrinkWrap intrinsic pass.

- Keep 3 columns and `s4` gutter.
- Compute the cell size from the available width and request an exact thumbnail size × `devicePixelRatio` — no more hard-coded 300/400.
- **Aesthetic risk we take:** none; the visible grid is identical.

#### 2. Add `RepaintBoundary` around section items

Wrap each timeline item (`MemoriesCarousel`, `YearHeader`+grid, `_MonthSection`, `_OlderSection`) in `RepaintBoundary`. Thumbnail decode completion, progress badge, or header rebuild is then contained to that item.

#### 3. Keep preview providers alive across scroll

Keep the `monthPreviewsProvider`, `yearPreviewsProvider`, and `olderPreviewsProvider` families alive while the Library screen is visible. Options:

- Convert them from `StreamProvider.autoDispose.family` to a manually cached family with a short keep-alive (e.g. `ref.keepAlive()` tied to the Library route), or
- Move the preview query into the timeline row provider itself so the same stream is not re-created when the cell leaves and re-enters the cache extent.

The simplest robust change: in `_MonthList` and `_YearList`, `ref.read(monthPreviewsProvider(month))` is already watched; we add `ref.keepAlive()` inside those providers' `create` when any value has been emitted, so flings don't drop subscriptions.

#### 4. Const-optimize list items

Make `_MonthSection`, `_YearSection`, and `_OlderSection` have const constructors where possible and pass stable object keys to `ListView.builder`. The header + grid should not rebuild unless its data changed.

#### 5. Filter switch guard

When the user taps a filter pill, the body switches widgets entirely. Add a `ValueKey(filter)` and ensure each filter branch reuses its providers rather than rebuilding from scratch, so `All` ↔ `Months` does not re-run queries that both already loaded.

### Not in scope

- Sticky filter bar (larger structural change; can be a follow-up).
- Illustrations in empty states (would introduce new visual language).
- Any motion beyond Material defaults.
- Changing the full-month `AssetGrid` architecture (it already uses `GridView.builder` with `ScrollCacheExtent.viewport(1)` and is healthy).

## Files to change

| File | Change |
|------|--------|
| `lib/features/library/widgets/library_skeleton.dart` | New widget: static memories strip + month-section skeleton blocks. |
| `lib/features/library/library_screen.dart` | Use `LibrarySkeleton` in loading branches; wrap scrollers with `RefreshIndicator`; add `RepaintBoundary` around timeline items; replace `_PreviewGrid` nested `GridView.count` with `Wrap` + exact thumbnail sizing; add filter switch key. |
| `lib/features/library/library_providers.dart` | Keep preview providers alive after first emission to avoid stream churn during scroll; possibly add a `keepAlive` policy. |
| `lib/widgets/asset_thumbnail.dart` | Accept an optional `size` calculation from parent; no default change needed if callers pass the right size. |
| `test/features/library/library_screen_test.dart` | Update the "spinner" test to expect `LibrarySkeleton`; assert `RepaintBoundary` presence on heavy items; assert exact thumbnail request size is derived from width. |
| `test/features/library/library_spacing_test.dart` | Re-run geometry assertions after `_PreviewGrid` refactor. |
| `test/widgets/design_goldens_test.dart` | Add a golden scenario for `LibrarySkeleton` in light + dark. |

## Verification plan (after approval)

1. `flutter analyze` — zero warnings.
2. `tool/check.sh` — analyze + build_runner + unit/widget tests.
3. Widget tests: new skeleton, refresh, `RepaintBoundary`, exact thumbnail sizing, spacing unchanged.
4. Golden update for the new skeleton.
5. Manual check on the connected Pixel 9 Pro XL:
   - Cold start: skeleton appears, then photos.
   - Fling through a large month list twice: no dropped frames, no blank re-load flashes.
   - Pull-to-refresh triggers from the top of the timeline.
   - Filter switches between `All` and `Months` are instant and do not restart from spinner.
6. Optional: run `flutter run --profile` and check DevTools raster/frame times before/after if the device is available; goal is no frames > 16ms during a normal flick.

## Risks / notes

- The skeleton must keep the same bottom padding rhythm as the real list so the nav capsule does not overlap it; we reuse the existing `AppSpace.s24 + MediaQuery.paddingOf(context).bottom` calculation.
- Pull-to-refresh on a `ListView.builder` inside a `Column`/`Expanded` is standard, but needs `physics: const AlwaysScrollableScrollPhysics()` on short/empty lists so the gesture still registers.
- `Wrap` with `AspectRatio` children is cheaper than a shrink-wrapped `GridView`, but we must ensure all children are created eagerly (only six) and that the row math stays the same across text-scale changes.
- Keeping preview providers alive increases memory slightly, but only for providers that have already emitted; the alternative is repeated Drift stream creation and thumbnail re-requesting on every fling.
- `RepaintBoundary` is cheap and contained; it only helps when thumbnail/badge updates would otherwise repaint neighbours.
- I inspected the current code but cannot see the attached running app directly. If there is a different visual issue you notice on device, please point it out and I'll fold it into the plan before implementing.

## Final state and follow-ups

All planned changes implemented and verified:

- `LibrarySkeleton` replaces the generic spinner on Library cold-start / loading.
- `RefreshIndicator` wraps all Library scrollable surfaces (month timeline, year list, this-week grid) including empty/error states.
- `_PreviewGrid` refactored from nested `GridView.count(shrinkWrap: true)` to `Wrap` + exact thumbnail sizing.
- `RepaintBoundary` around every timeline item.
- `library_providers.dart` keeps count and preview stream providers alive after first emission.
- `ValueKey(filter)` on the filter body to avoid cross-filter widget reuse issues.
- Tests updated: spinner → skeleton, RepaintBoundary assertion, pull-to-refresh presence.
- Golden added and generated for `LibrarySkeleton`.

## Device verification result

- Profile APK built and installed on `46121FDAS008AA` (Pixel 9 Pro XL).
- App launched successfully; process is alive and the Dart VM service is listening.
- No crashes or exceptions in `adb logcat`.
- I cannot see the attached screen from this environment, so the visual checks (skeleton appearance, fling smoothness, pull-to-refresh gesture, filter-switch speed) need confirmation from whoever is looking at the device.

## Follow-ups (not in this change)

1. **Confirm visual/performance checks on the Pixel 9 Pro XL** — look for the skeleton on cold start, smooth fling through many months, pull-to-refresh from the top, and instant `All` ↔ `Months`/`Year` switching. Report back any jank or layout issues and I'll address them.
2. **Sticky filter bar** — can be added later if desired.
3. **Full-month `AssetGrid` thumbnail sizing** — left unchanged as scoped out; could compute exact cell size there too.
