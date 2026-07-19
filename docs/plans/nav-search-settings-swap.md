# Nav restructure: Search into the bottom nav, Settings into the app bar

**Status: complete (2026-07-19).** `tool/check.sh` green (248 tests);
`patrol test` green on the Pixel 9 Pro XL for `nav_shell_test`,
`saved_albums_test`, `folders_ui_test`. No follow-ups outstanding.

## What shipped (deltas from the plan below)

- The nav bar moved out of `app_shell.dart` into a public
  `lib/widgets/dot_nav_bar.dart` (`DotNavBar`) so it could get the
  design-system golden CLAUDE.md requires (`test/widgets/goldens/ci/dot_nav_bar.png`,
  Search selected, light + dark). `AppShell` is now just the scaffold.
- `StatefulShellRoute.indexedStack` builds branches **lazily**, not eagerly —
  the plan assumed eagerly. Search therefore never grabs focus at boot even
  before the fix, but the `searchTabActiveProvider` handoff is still what makes
  focus return on re-entry and the keyboard leave with the tab.
- Two widget-test traps found and recorded in CLAUDE.md gotchas: nav taps miss
  while the shell's entry transition is still running (pump ~500 ms first), and
  a backgrounded branch is **offstage** (`skipOffstage: false` to assert on it).
- New on-device coverage: `integration_test/nav_shell_test.dart` (destination
  set, focus take/release, Library gear → Settings → back).

## Context

Today the bottom nav is `Library · Saved · Albums · Settings` and Search is a
root-navigator route pushed from a magnifier icon in the Library app bar.
Search is a primary, frequently-used destination while Settings is visited
rarely — the nav is spending a permanent slot on the wrong screen. Target:
bottom nav becomes `Library · Search · Saved · Albums`, and Settings moves to a
gear action in the **Library** app bar (pushed on the root navigator, so it
gets a back button and covers the nav bar).

Decisions taken with the user:
- Settings gear lives in the **Library app bar only** (replaces the search icon).
- Search field **does not** `autofocus`; it takes focus when the Search tab
  becomes active, and releases it when the tab is left.
- Search state (query, filters, results) **persists** across tab switches —
  the branch stays alive in `indexedStack`, matching the other tabs.

## Changes

### 1. Shell + router
- `lib/widgets/app_shell.dart` — `_destinations` becomes
  `Library (photo_library) · Search (search_outlined/search) · Saved (favorite) ·
  Albums (photo_album)`; drop the Settings destination. Update the "four-tab"
  doc comment. `_DotNavBar` already derives geometry from
  `_destinations.length`, so no layout change is needed.
  Convert `AppShell` to a `ConsumerWidget` so it can publish tab activation
  (below).
- `lib/core/router/app_router.dart` —
  - move the top-level `/search` `GoRoute` (currently
    `parentNavigatorKey: _rootNavigatorKey`) into a new `StatefulShellBranch` at
    **index 1**, between `/` and `/saved`;
  - delete the `/settings` branch and re-add `/settings` as a top-level
    `GoRoute` with `parentNavigatorKey: _rootNavigatorKey`, alongside `/people`
    and `/folder`.

### 2. Search focus handoff
Because `StatefulShellRoute.indexedStack` builds every branch eagerly,
`autofocus: true` would steal focus and open the keyboard at app boot on the
Library tab. Replace it with explicit activation state:
- `lib/features/search/search_providers.dart` — add a small
  `searchTabActiveProvider` (`NotifierProvider<..., bool>`, **not** autoDispose;
  it is shell-lifetime state) defaulting to `false`.
- `AppShell` sets it from `navigationShell.currentIndex == 1` on build and on
  `onTap`.
- `lib/features/search/search_screen.dart` — remove `autofocus: true`, add a
  `FocusNode` to the app-bar `TextField`, and `ref.listen` the provider:
  `true` → `requestFocus()`, `false` → `unfocus()` (otherwise the keyboard
  lingers over Library after switching away). Fix the stale
  "`/search`, pushed from the Library app bar" doc comment.
Search's `autoDispose` providers keep their state naturally: the branch widget
is never disposed while the shell lives, so the requirement to persist state
needs no provider-lifetime change.

### 3. Library app bar
- `lib/features/library/library_screen.dart` — replace the
  `Icons.search` → `context.push('/search')` action with
  `Icons.settings_outlined`, tooltip `Settings`, → `context.push('/settings')`.

### 4. UI review
Per CLAUDE.md, invoke `/frontend-design:frontend-design` before reshaping the
nav bar and the two app bars (icon choice for the Search destination, gear
placement/weight in the Library bar).

## Tests

Host (`flutter test`):
- `test/widgets/app_shell_test.dart` — destination set/count assertions
  (`['Library','Search','Saved','Albums']`), rename the "four destinations"
  case, verify the branch-switch tap. **Watch the new eager branch:** the shell
  now builds `SearchScreen` at boot, which watches `indexingStatusProvider`
  (a Drift `.watch()`), so these tests need a
  `databaseProvider.overrideWithValue(inMemoryDb)` and the dispose-tree teardown
  (`pumpWidget(SizedBox()) + pump(1s)` in the test body) per the CLAUDE.md
  Drift/FakeAsync gotchas. Unfocused `TextField` does not blink, so bounded
  pumps stay adequate.
- `test/features/screens_test.dart:49` — Library case now asserts
  `Icons.settings_outlined`, not `Icons.search`.
- `test/features/library/library_screen_test.dart:42` — its local `GoRouter`
  harness needs a `/settings` route so the new action can push.
- `test/features/search/search_screen_test.dart` — no `autofocus`; add a case
  that flipping `searchTabActiveProvider` focuses/unfocuses the field.
- New: nav-bar + dot-indicator golden in
  `test/widgets/design_goldens_test.dart` (light + dark). CLAUDE.md lists this
  as a required design-system golden and it is currently missing — the nav bar
  is exactly what this change reshapes.

Integration (`integration_test/`, on device, one file per run with the
pre-grant loop from CLAUDE.md):
- `integration_test/saved_albums_test.dart:42,59` — tab indices shift by one;
  the `find.byTooltip` taps still resolve, re-run to confirm.
- `integration_test/folders_ui_test.dart:50-54` — reach Search via
  `find.byTooltip('Search')` instead of the Library `Icons.search` action.
- Add coverage for the new Settings path (Library gear → `/settings` → back).

## Docs
- `CLAUDE.md` — line 18 bottom-nav list; the Screens/Route table (add
  `Search → /search`); the "App bar: search" core-feature bullet.
- `docs/spec.md#routing` — branch/route structure.
- `docs/plans/nav-search-settings-swap.md` — living plan/handoff doc, per the
  project workflow.

## Verification
1. `tool/check.sh` (analyze, build_runner, host tests) clean.
2. Integration files above, run **one at a time** on the Pixel 9 Pro XL
   (`46121FDAS008AA`) with the permission pre-grant loop.
3. Manual on device: boot lands on Library with **no keyboard**; tapping Search
   focuses the field and opens the keyboard; typing, then switching to Saved and
   back, restores the query, filters and results with focus returning; the
   Library gear opens Settings full-screen with a working back button and the
   nav bar hidden.
