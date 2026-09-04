# Plan — UI refresh (Library filters, swipe-up details, memory tap + preload)

**Audience:** Claude Opus 4.8 running in Claude Code, inside the `sologallery`
Flutter repo.

**Status: all four sections implemented, none verified.** Host tests are
written but **have not been run** — the user asked for tests to be written,
not executed. `dart analyze` is clean (via the IDE analysis server) and that
is the *only* check performed so far.

**Next step:** run `tool/check.sh`. Expect the new goldens to need generating
(`--update-goldens`) on first run — `year_header` has no committed baseline.
Then the on-device pass and the release-manifest re-verify.

| § | Change | Code | Host tests | Run |
|---|---|---|---|---|
| 2 | Swipe up → details sheet | ✅ | ✅ written | ❌ |
| 4 | Preload adjacent images | ✅ | ✅ written | ❌ |
| 3 | Memory tap-advance | ✅ | ✅ written | ❌ |
| 1 | Library time filters | ✅ | ✅ written | ❌ |

### Open question for the user

**Year sections have no "View all".** The plan specified a year hero plus a
six-photo preview grid and no year grid screen, so a year is currently only
ever six photos deep with no way in. Month sections have `/month/:key`. Either
that's an accepted thinness, or `Year` wants a `/year/:year` screen mirroring
`MonthGridScreen` (a `watchYearAssets` growing-window query alongside the
existing `watchMonthAssets`). Not built — it's beyond what the plan scoped.

### Decisions taken during implementation

- **§2 extends `DismissiblePhoto`'s existing raw `Listener`** rather than
  adding `onVerticalDragEnd` as the plan's first option suggested. The plan
  anticipated this ("if binding `onVerticalDragEnd` here steals the downward
  drag…") and the gesture-arena gotcha in CLAUDE.md makes it a certainty: a
  sibling recognizer gets starved by `InteractiveViewer`'s scale recognizer.
  One axis lock now resolves both directions — down dismisses, up opens
  details — so the two can't compete. Threshold: `velocity < -300` (per plan)
  **or** a deliberate drag past 15% of screen height.
- **§4 is a provider warm-up, not `precacheImage`.** The plan assumed an
  `ImageProvider`; this codebase renders detail bytes from
  `detailImageProvider` (a `FutureProvider.autoDispose.family` over
  `previewImage`) via `Image.memory`. The expensive part is that platform
  round-trip, and `precacheImage` would warm a cache the stage never reads.
  `widgets/precache_adjacent.dart` holds `ref.watch` subscriptions for the
  neighbours instead — which, `autoDispose` being what it is, *is* the
  mechanism that keeps their bytes alive until the swipe. Neighbour math is
  pure in `features/detail/domain/adjacent_ids.dart`.
- **§3 skipped the optional left-quarter tap-back.** The plan gated it on the
  player having no back affordance; the `PageView` already swipes both ways,
  so it would only add a way to mis-tap. `onTap` reuses `_advance` verbatim,
  so tap and clock share one end-of-story path.
- **§4's memory-player cursor sits at `_index - 1`** (page 0 is the title
  card). `adjacentIds` therefore accepts an out-of-range index and still
  returns the neighbours that are in range — on the title card that warms the
  opening photo, which is the highest-value warm-up in the story.
- **§1's filter state is a `Notifier`, not the `StateProvider` the plan named.**
  `search_providers.dart` already carries the comment "(not `StateProvider`)
  to match the project's Riverpod conventions", and in this Riverpod version
  `ref.watch` on a `StateProvider` infers `dynamic`, which broke exhaustiveness
  checking on the `switch (filter)`. It is deliberately **not** `autoDispose`,
  so switching tabs and returning doesn't reset the filter under the user.
- **§1's timeline flattening lives in `domain/library_timeline.dart`**, not in
  the screen. Year heroes have to interleave with month sections under one
  `ListView.builder`, which needs a stable index → row mapping — an "insert a
  header when the year changes" check inside the builder can't provide one,
  since the builder may be asked for rows in any order. Making the rows a
  public sealed type is also what makes the grouping host-testable without
  pumping a widget.
- **§1 reuses `AssetGrid` for This week** rather than a new grid, and the year
  total in the `Months` heroes is summed from the month counts already in hand
  — no second query.
- **Year hero design:** the year in the display face (34sp) with its count
  trailing in caption grey, and nothing else. The scale jump against the 11sp
  uppercase month labels is the entire hierarchy; a rule or fill behind it
  would be decoration. Golden: `year_header` (light + dark).

**Save location:** `docs/plans/ui_refresh.md`.

This refresh is a **behavioural + interaction** pass on screens that already
exist. It does **not** touch the design system (monochrome tokens, tracked
uppercase section labels, dot nav, pill/sheet radii) — that landed in
`ui-system-refresh.md` and is authoritative. Reuse existing tokens
(`AppColors`, `AppTextStyles`, `AppSpace`, `AppRadius`, `AppMotion`) and existing
widgets; add no new colors and no `shared_preferences`.

## Absolute rules (unchanged, restated because this plan touches viewers)

- **Never duplicate originals.** Album membership stays asset-id references in
  `AlbumEntries`; edits stay non-destructive in `EditInstructions`.
- **Drift for all persistence.** No new tables are needed for this plan.
- **100% on-device, zero network.** No new dependencies; `tool/check.sh` must
  stay green and the release manifest network-free.
- Pure display/grouping logic goes in host-testable `domain/` files (no Flutter
  imports), mirroring `library/domain/year_month.dart` and
  `detail/domain/asset_detail_display.dart`.

## Scope — four independent changes

1. **Library time filters** — `All · This week · Months · Year`, with a
   year-grouped timeline when `Months`/`Year` is active.
2. **Detail: swipe-up opens the details (EXIF) sheet** — in addition to the
   existing info-button entry point.
3. **Memory player: tap advances** to the next photo (keep auto-advance).
4. **Preload the next/neighbour full-res image** in the detail viewer and the
   memory player.

Each is shippable on its own; land them as four commits.

---

## 1. Library time filters + year timeline

**Files:** `features/library/library_screen.dart`,
`features/library/library_providers.dart`,
`core/database/daos/index_dao.dart` (+ `.g.dart` regen),
new `features/library/domain/library_filter.dart`,
new `features/library/widgets/library_filter_bar.dart`.

### 1a. Filter model (host-testable)
- New `library/domain/library_filter.dart`:
  `enum LibraryFilter { all, thisWeek, months, year }` with a `String get label`
  (`'All'`, `'This week'`, `'Months'`, `'Year'`). Pure Dart, no imports.

### 1b. Filter state
- Add `libraryFilterProvider` (a `StateProvider<LibraryFilter>`,
  default `all`) in `library_providers.dart`. Screen-local UI state; **not**
  persisted (do not add it to `AppSettings`).

### 1c. Filter bar widget
- New `LibraryFilterBar` in `features/library/widgets/`: a horizontally
  scrollable `Row` of pill chips built from `LibraryFilter.values`. Active chip
  uses `colors.pillActiveBg` / `pillActiveFg`; inactive uses the neutral surface
  swatch (`AppColors` step-2 / `textSecondary`) — same anatomy as existing pills.
  Chip height/padding from the pill tokens already used elsewhere. Tapping sets
  `libraryFilterProvider`.
- Mount it in `LibraryScreen.build` as a **non-scrolling** band directly under
  the `AppBar`, above the `Expanded` list (a `Column` child, `flex: none`).

### 1d. Grouping — reuse month counts, add week + year
The Library home already reads `libraryMonthCountsProvider` (→
`indexDao.watchMonthCounts()`) and renders `_MonthSection`s with lazy
`monthPreviewsProvider`. Extend without rewriting that machinery:

- **`all`** — current behaviour verbatim (month sections newest-first, no year
  hero, trailing `Older`).
- **`months`** — same month sections, but insert a **year hero header** (large
  numeral, `AppTextStyles` display size on `onSurface`) before the first month
  of each year as the list is built. Detect the boundary in `_MonthList`
  (compare `counts[i].month.year` to the previous entry's) and emit a
  `_YearHeader(year)` sliver/tile ahead of the section. No new query.
- **`year`** — collapse to one section per year. Add
  `Stream<List<({int year, int count})>> watchYearCounts()` to `IndexDao`
  (a `GROUP BY strftime('%Y', created_at)` over `photo_asset`, mirroring
  `watchMonthCounts`), exposed as `libraryYearCountsProvider`. Each year renders
  a `_YearHeader` + a preview grid; add
  `watchYearPreviews(int year)` (six newest ids in the year) as the family
  provider `yearPreviewsProvider`, mirroring `monthPreviewsProvider`.
- **`thisWeek`** — a single section titled `This week`. Add
  `watchRecentSince(DateTime cutoff)` to `IndexDao` returning the ids captured
  on/after the cutoff (bounded, `ORDER BY created_at DESC`), exposed as
  `thisWeekAssetsProvider` computing `cutoff = now - 7 days`. Render one grid of
  those ids (not capped at six — show all, scrolling). Empty week → the existing
  `EmptyState` with copy `No photos in the last 7 days.`

- `_MonthList` becomes a small `switch (filter)` that chooses which
  section-builder to run; `MemoriesCarousel` stays index 0 **only for `all`**
  (hide it under the time filters so they read as pure time navigation).

**DoD:** switching filters reflows without a full reload; `Months`/`Year` show
year heroes in a timeline; `This week` respects the rolling 7-day cutoff;
`watchYearCounts`/`watchRecentSince` have host unit tests over an in-memory
Drift db (empty, single-year, multi-year, week-boundary at local midnight).

---

## 2. Detail: swipe-up opens the details sheet

**File:** `features/detail/detail_screen.dart` (only).

Today `_onExif()` (→ `showExifSheet`) is reachable only from the info button in
`_TopBar`. Add an **upward drag** on the stage as a second entry point; keep the
button.

- In `_PhotoDetailScreenState.build`, wrap the `PageView`'s `GestureDetector`
  (the one that currently does `onTap: _toggleChrome`) so it also handles
  `onVerticalDragEnd`: if `details.primaryVelocity < -300` (fling up) **and**
  the current page is not zoomed (guard with the existing
  `TransformationController`/`panEnabled` signal that `DetailStage` already
  forwards — do not open the sheet mid-zoom or mid-pan), call `_onExif()`.
- Do not intercept downward drags — `DismissiblePhoto` owns drag-to-dismiss.
  Only bind the vertical-drag callback such that an **upward** gesture opens
  details and a **downward** gesture still reaches the dismiss handler (verify
  the gesture arena: if binding `onVerticalDragEnd` here steals the downward
  drag, instead add a slim bottom "grab" affordance or a `VerticalDragGestureRecognizer`
  in a `RawGestureDetector` that yields to the child dismiss recognizer). The
  acceptance test is: swipe up = details, swipe down = dismiss, both still work.
- The sheet itself is unchanged (`ExifSheet`, label `DETAILS`, real formatters
  in `asset_detail_display.dart`).

**DoD:** widget test — pump the viewer, `fling` up, assert `ExifSheet` shown;
`fling` down, assert route pops; pinch-zoom then fling up does **not** open the
sheet.

---

## 3. Memory player: tap advances

**File:** `features/memories/memory_player_screen.dart`.

The story player auto-advances on a timer. Add manual forward:

- Wrap the player body in a `GestureDetector` `onTap` that advances to the next
  photo and **resets the auto-advance timer** (so a tap doesn't cause a double
  step). On the last photo, tap closes the player (`Navigator.pop`), matching
  auto-advance end-of-story behaviour.
- Keep the close (✕) button and progress segments as-is; the tapped-forward
  index must drive the same segment fill state.
- Optional (only if the current player has no back affordance): a tap on the
  **left ~25%** goes to the previous photo, right/center advances — standard
  story control. If added, keep it behind the same timer reset.

**DoD:** widget test — tap advances index by one and the active progress segment
moves; tapping on the last photo pops the route.

---

## 4. Preload the next full-res image

**Files:** `features/detail/detail_screen.dart`,
`features/memories/memory_player_screen.dart`. Prefer a tiny shared helper
`widgets/precache_assets.dart`.

- Helper: `void precacheAdjacent(BuildContext, List<String> ids, int index)`
  that resolves the **full-res** image provider used by `PhotoPage`/`DetailStage`
  (the `size: 1080` provider, not the 300 thumb) for `index±1` and calls
  `precacheImage`. Guard bounds; skip video ids (`isVideoProvider`) since they
  don't decode as a still. Use the existing `AssetThumbnail`/photo image provider
  so the cache key matches what the viewer will request (a mismatched key
  re-decodes and defeats the preload).
- **Detail viewer:** call it from `onPageChanged` (after `_index` updates) and
  once in `initState`/first build for the initial neighbours.
- **Memory player:** on each advance (auto or tapped), precache the next
  photo's full-res provider.
- Keep it best-effort: swallow errors, never block the UI, and rely on Flutter's
  `ImageCache` (do not hand-roll a cache or hold `ImageProvider`s in fields
  beyond the frame).

**DoD:** on a mid-library photo, swiping to the neighbour shows the full image
with no thumb-to-full cross-fade flash (manual on-device check); helper has a
unit/widget test asserting `precacheImage` is invoked for `index+1` and skipped
for a video neighbour and at list ends.

---

## Out of scope (already shipped — do not rebuild)

- Design-system visuals, dot nav (`widgets/dot_nav_bar.dart`), Settings screen
  and theme persistence (`features/settings/…`, `AppSettings` schema v5),
  add-to-album picker (`showAddToAlbumSheet`), the EXIF sheet itself, month
  grouping (`year_month.dart`, `IndexDao.watchMonthCounts`), memories generation
  (`memories/domain/memory_builder.dart`, `MemoryKind`).

## Verification (all four)

1. `dart format .` and `dart analyze` clean.
2. `dart run build_runner build --delete-conflicting-outputs` after the
   `IndexDao` query additions (regenerates `index_dao.g.dart` /
   `app_database.g.dart`); commit the generated files.
3. `tool/check.sh` green, including the new host tests in §1–§4.
4. No new schema version (no table changes) — confirm the schema dump is
   unchanged.
5. Manual device pass: filter switching + timeline heroes; swipe-up details vs
   swipe-down dismiss; memory tap-advance and end-of-story close; neighbour
   photos appear without a decode flash.
6. Release manifest re-verified network-free.

## Suggested commit order

1. `feat(detail): swipe up opens details sheet` (§2) — smallest, no query.
2. `perf(detail,memories): precache adjacent full-res images` (§4).
3. `feat(memories): tap to advance the story` (§3).
4. `feat(library): time filters with year timeline` (§1) — largest; DAO + regen.
