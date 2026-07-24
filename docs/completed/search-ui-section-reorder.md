# Plan: Search screen section reorder + bigger recently-viewed carousel

## Status

Implemented 2026-07-23. Tests written but not run per user request.

Supersedes the layout decisions in `docs/plans/search-ui-refactor-v2.md` (the v2 refactor is already implemented in `lib/features/search/search_screen.dart`). This plan keeps the v2 widgets and data paths, only changing the vertical order of the idle/results sections and the treatment of the recently-viewed ribbon.

### Implementation notes

- Added bottom padding around `_RecentlyViewedStrip` in the results body so the carousel clears the floating nav capsule; the idle ListView already pads by the capsule height.

### Verification completed

- `flutter analyze lib/features/search/search_screen.dart lib/features/search/widgets/recently_viewed_row.dart test/features/search/search_screen_test.dart` — zero issues.

### Verification pending

- `flutter test test/features/search/search_screen_test.dart` — user asked not to run tests yet.
- On-device integration / manual end-to-end.

---

## Context

- The Search tab was recently refactored in v2: anchored search field, visible facet pills on idle, person-name matching in results, horizontal album chips.
- The user now wants a different vertical hierarchy:
  1. Facet pills at the very top.
  2. **On-device labels** section.
  3. **People** section.
  4. **Search** section (field + results).
  5. **Recently viewed** at the bottom, bigger and as a 2-row horizontally scrolling grid.
- The privacy note card should be removed from the idle screen.
- Design stays inside the existing app theme only (`AppColors`, `AppTextStyles`, `AppSpace`, `AppRadius`). No new palette, typeface, or accent.

## Single job of this screen

Help the user find a specific photo, album, or person fast. The new order treats browsable entry points (labels, people) as the primary discovery layer, search as the active lookup, and recency as a persistent shortcut at the bottom.

---

## New layout

### Idle state

```
┌─────────────────────────────┐
│  Search                     │  <- AppBar title only
├─────────────────────────────┤
│  [All] [Photos] [Videos] [★]│  <- Facet pills, topmost
├─────────────────────────────┤
│  ON-DEVICE LABELS           │
│  [dog] [beach] [city] …     │
├─────────────────────────────┤
│  People  [See all] ──▶      │  <- PeopleStrip
│  ○ ○ ○                      │
├─────────────────────────────┤
│  Find photos, dates…        │  <- Compact subtitle above field
│  🔍 [Search field…        ✕] │  <- Search field
├─────────────────────────────┤
│  RECENTLY VIEWED            │  <- Bigger 2-row horizontal grid
│  ┌──┐┌──┐┌──┐               │
│  │  ││  ││  │  → scroll →   │
│  └──┘└──┘└──┘               │
└─────────────────────────────┘
```

### Results state

```
┌─────────────────────────────┐
│  Search                     │
├─────────────────────────────┤
│  [All] [Photos] [Videos] [★]│
├─────────────────────────────┤
│  People (filtered by query) │  <- hidden if no matches
├─────────────────────────────┤
│  🔍 [query              ✕]  │
├─────────────────────────────┤
│  Albums (N) ──▶             │  <- horizontal cover chips
│  Photos (N+)                │  <- results grid
├─────────────────────────────┤
│  RECENTLY VIEWED            │  <- still at the bottom
└─────────────────────────────┘
```

Notes:
- **On-device labels** only appear on idle; once the user types, the browse chips are hidden because the query is now the active search.
- **People** appears in both states: all people on idle, filtered by query in results.
- **Search field** sits below People and above its own results.
- **Recently viewed** is always visible at the bottom when data exists.
- **Privacy note** is removed from idle.

---

## Design decisions

1. **Facet pills at the top.** They scope the whole screen and are discoverable before any query.
2. **Labels above People.** The user explicitly ordered it this way; labels are the broadest discovery entry point.
3. **Search field in the middle.** The compact subtitle stays directly above the field to explain the screen; the field is no longer the first body child.
4. **Recently viewed: 2-row horizontal grid carousel.** Implemented as a horizontally scrolling `GridView` with `crossAxisCount: 2` and larger square cells (proposed 104 px, up from today's 72 px). This satisfies "bigger" and "two rows with horizontal scroll" while keeping every thumbnail clipped to `br12`.
5. **Remove privacy note.** It currently sits at the bottom of idle; per user request it is dropped. The on-device-search claim still lives in Settings and in the search field hint.
6. **Theme-only.** All colors, type, and radius come from the existing design tokens.

---

## Files to change

| File | Change |
|------|--------|
| `lib/features/search/search_screen.dart` | Reorder `_IdleBody` and `_ResultsBody` sections; remove `_PrivacyNote`; move `_SearchSubtitle`/`_SearchField`/`_FilterBar` to their new positions; hide `_BrowseLabels` in results. |
| `lib/features/search/widgets/recently_viewed_row.dart` | Replace single-row `ListView` with a 2-row horizontal `GridView`; increase default cell size; keep the `SectionHeader` and tap-to-detail behavior. |
| `test/features/search/search_screen_test.dart` | Update existing layout tests for the new order; remove privacy-note tests; add tests for facet pills at top, labels above people, field below people, recently-viewed 2-row grid, and removed privacy note. |

## Files unchanged

- `lib/features/search/search_providers.dart` — no new data path.
- `lib/widgets/people_strip.dart` — reused as-is.
- `lib/widgets/filter_pill.dart`, `lib/widgets/section_header.dart` — reused as-is.

---

## Implementation sketch

### `search_screen.dart`

1. `_IdleBody` becomes a `ListView` in this order:
   - `_FilterBar`
   - `_SearchSubtitle`
   - `searchField`
   - `_BrowseLabels` (if labels not empty)
   - `PeopleStrip` (if people not empty)
   - `_RecentlyViewedStrip`
   - `_IdleHint` (when everything else is empty)
2. `_ResultsBody` becomes a `ListView` in this order:
   - `_FilterBar`
   - `searchField`
   - `PeopleStrip` filtered by query (if matches)
   - `_AlbumsResult` (if matches)
   - `_Results` grid
   - `_RecentlyViewedStrip`
3. Remove `_PrivacyNote` and its imports/tests.
4. Keep the existing debounce, focus, and query-restore behavior untouched.

### `recently_viewed_row.dart`

1. Keep `SectionHeader(label: 'Recently viewed')` and horizontal padding.
2. Replace the inner `SizedBox` + `ListView.separated` with a `SizedBox` whose height is `2 * cellSize + gutter` and contains a `GridView.builder`:
   - `scrollDirection: Axis.horizontal`
   - `gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: gutter, crossAxisSpacing: gutter, childAspectRatio: 1)`
   - item builder wraps each asset in a tappable `ClipRRect(br12) + AssetThumbnail`
3. Default `cellSize` raised from 72 to 104; `limit` raised from 12 to 20 (fills 10 horizontal slots × 2 rows).
4. Maintain the existing `PhotoViewerArgs` navigation.

### Tests

- Update layout-order tests to assert vertical position via `getTopLeft`.
- Add/replace recently-viewed tests:
  - renders when ids exist;
  - hides when empty;
  - tap opens detail;
  - uses a horizontal 2-row grid.
- Remove the privacy-note test.
- Keep all existing functional tests (facet pills, date query, album match, people match, label chips, clear button, provider restore).

---

## Verification plan (to run after approval)

1. `flutter analyze` — zero warnings.
2. `dart run build_runner build` — no schema change expected.
3. `flutter test test/features/search/search_screen_test.dart` — must pass.
4. (User asked not to run tests now; verification will be done after implementation.)

---

## Open questions

None — clarified with the user before drafting:
- Scope: idle **and** results.
- Facet pills: **above On Device Labels**.
- Recently viewed: **2-row horizontal grid carousel**, bigger cells.
- Privacy note: **remove**.

---

## Next step

Approve this plan, then implement the three file changes and write the updated widget tests.
