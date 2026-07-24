# Plan: Search screen usability refactor — phase 2

## Status

Approved 2026-07-23. Implementing Option A with the decisions below.

- Person-name matching: **include now** (filtered PeopleStrip under results).
- Idle title treatment: **compact subtitle only** above the field; no large page title.
- Facet pills on idle: **same visual treatment as results**.

This is a follow-up to the completed `search-screen-redesign.md` (recency-first, lower field, no auto-focus).

---

## Context

- The current Search tab already has the recency-first idle layout and the lowered search field.
- Search supports: capture-date text (`"June 2026"`), media type, favorites, album-name matching, and — when enabled — on-device ML labels/OCR.
- Shared widgets we will reuse: `FilterPill`, `SectionHeader`, `CoverRow`, `PeopleStrip`, `AssetGrid`, `AppCard`, `RecentlyViewedRow`.
- Design-system tokens stay unchanged (`AppColors`, `AppTextStyles`, `AppSpace`, `AppRadius`). No new palette or typeface.

---

## Single job of this screen

Help the user find a specific photo, album, or person fast, without guessing which search mode is active.

---

## What still feels hard (observed from current code + user report)

1. **The search field moves.** On idle it sits below "Recently viewed"; on results it snaps to the top. The user loses the anchor they just tapped.
2. **Filters are invisible until after the user commits.** A person who wants to search "favorite videos" has no hint that media-type or favorites pills exist before typing.
3. **Album matches bury photos.** Matching albums render as full-height rows above the photo grid, so common album names push the actual photos off screen.
4. **People / labels / albums are browse-only on idle.** Once the user starts typing, those entry points vanish — you cannot pivot from a text query into "people matching this" or "albums matching this" without leaving Search.
5. **Content-search capability is hidden in hint text.** The user only learns whether ML labels are enabled by reading the placeholder.
6. **Two disjoint scroll surfaces.** Idle is a `ListView`; results is a `Column` with an inner `AssetGrid`. The transition between them is a full layout swap.

---

## Design options

### Option A: Anchored command bar + grouped results (recommended)

Keep one persistent search field at the top on **both** idle and results. Everything below it scrolls as a single surface.

**Idle state wireframe (vertical scroll):**

```
┌─────────────────────────────┐
│  Search                     │  <- AppBar title only, no field here
├─────────────────────────────┤
│  🔍 [Search field…]         │  <- Fixed first body row, both states
├─────────────────────────────┤
│  [All] [Photos] [Videos] [★]│  <- Facet pills, visually quiet when idle
├─────────────────────────────┤
│  Recently viewed ──▶        │  <- Horizontal ribbon, hides if empty
├─────────────────────────────┤
│  People  [See all] ──▶      │  <- PeopleStrip, unchanged
├─────────────────────────────┤
│  On-device labels            │
│  [dog] [beach] [city] …     │  <- Browse chips
├─────────────────────────────┤
│  Privacy note card          │
└─────────────────────────────┘
```

**Results state wireframe (same scroll):**

```
┌─────────────────────────────┐
│  Search                     │
├─────────────────────────────┤
│  🔍 [query              ✕]  │
├─────────────────────────────┤
│  [All] [Photos] [Videos] [★]│  <- Same pills, now active
├─────────────────────────────┤
│  Albums (2) ─────────────▶   │  <- SectionHeader, horizontal CoverRow list
│  [cover] [cover]            │
├─────────────────────────────┤
│  People (1) ─────────────▶   │  <- Optional: PeopleStrip filtered by query
├─────────────────────────────┤
│  Photos (N+)                │
│  □ □ □                      │  <- AssetGrid
│  □ □ □                      │
└─────────────────────────────┘
```

**Changes:**
- Move the search field to the top of the body in both states. Remove the large "Search" page header from idle, or keep it as a compact subtitle above the field.
- Show the facet pill row on idle in a visually quieter form so the mental model is the same. Pills are technically active even without a query? That is ambiguous; better: always show them, but when idle they are presented as "search will use these filters once you type". If all/default, they read as scopes.
- Convert matching albums from a vertical list to a horizontal `CoverRow` scroller under a `SectionHeader`, like the People strip. Saves vertical space.
- Add a filtered `PeopleStrip` to results if the query matches person display names (new data path, but small).
- Unify idle and results into one scrollable body so the field never jumps.

**Pros:**
- One anchor; no layout teleport.
- Filters are discoverable before typing.
- All result types coexist in a scannable, grouped list.
- Reuses existing widgets almost exclusively.

**Cons:**
- Idle screen becomes slightly busier because of the visible filter row.
- Matching-people path is net-new data work.

---

### Option B: Scope tabs below the field

Add a `SegmentedControl` under the search field with scopes: **Photos · Albums · People**. The default scope is Photos. Each scope runs the same query against a different data source.

**Wireframe:**

```
┌─────────────────────────────┐
│  Search                     │
├─────────────────────────────┤
│  🔍 [query              ✕]  │
├─────────────────────────────┤
│  [ Photos | Albums | People ]│
├─────────────────────────────┤
│  [All] [Photos] [Videos] [★]│  <- only under Photos
├─────────────────────────────┤
│  (results for chosen scope) │
└─────────────────────────────┘
```

**Changes:**
- Add a scope segment control.
- Keep the field at the top.
- Remove the mixed results list; each scope has its own list.

**Pros:**
- Very clear mental model: "what kind of thing am I looking for?"
- No vertical competition between albums and photos.

**Cons:**
- Extra tap to switch scope; slow for the "I don't know if it's an album or a photo" case.
- People search requires display-name matching, which we don't have today, and unnamed clusters dominate.
- Cross-type discovery is lost (e.g., searching a trip name should show both the album and the photos).
- Adds navigation chrome the design system otherwise avoids.

---

### Option C: Filter sheet + minimal grid

Keep the search field and a results grid. Move all facets (media type, favorites, date, people, albums) behind a single "Filters" button that opens an `AppSheet`.

**Wireframe:**

```
┌─────────────────────────────┐
│  Search              [Filter]│
├─────────────────────────────┤
│  🔍 [query              ✕]  │
├─────────────────────────────┤
│  □ □ □                      │
│  □ □ □                      │
└─────────────────────────────┘

(Filter sheet opens)
┌─────────────────────────────┐
│  Media   [All|Photos|Videos]│
│  Favorites [toggle]           │
│  Date  [Any|Pick range]       │
│  People  [Pick person]        │
│  Albums  [Pick album]         │
└─────────────────────────────┘
```

**Changes:**
- Replace `_FilterBar` with a trailing filter button.
- Build a new filter sheet using existing `FilterPill`, `AppSheet`, toggles.
- Album results no longer auto-surface; user must open filter sheet and pick album.

**Pros:**
- Main screen is very clean.
- Can expose richer filters (date range, person picker) without clutter.

**Cons:**
- Filters are hidden behind an extra tap — contradicts "instant taps" and discoverability.
- Albums stop being searchable by name from the search field.
- Reorganizes the whole screen around a sheet, which is a larger interaction cost.

---

## Recommendation

**Option A: Anchored command bar + grouped results.**

It solves the four biggest pain points (field jump, hidden filters, albums burying photos, lost people/labels affordance) while keeping the screen a single scrollable surface. It also fits the design system's preference for snap state changes, pill filters, and section headers. The only net-new data path is person-name matching, and even that can be deferred to a follow-up because Option A works without it (the People section simply won't render under results until we add the match).

---

## Implementation sketch (if approved)

### Files to change

| File | Change |
|------|--------|
| `lib/features/search/search_screen.dart` | Reorder idle body so field is first; unify idle/results scroll; add filtered-people section in results; convert album results to horizontal `CoverRow` list; remove large idle title or keep as compact subtitle. |
| `lib/features/search/search_providers.dart` | Add `peopleQueryMatchesProvider` (optional, gated by approval). Keep existing providers. |
| `lib/core/database/daos/faces_dao.dart` | Add `searchPersonsByName(String query, {int limit})` if person-name section is included. |
| `lib/features/search/search_screen_test.dart` | Update idle layout tests; add grouped-results tests; add album horizontal-scroll tests. |

### No schema change required

Phase 2 does not touch the database unless we add person-name matching. If that is deferred, there is no migration work.

### Implementation decisions recorded

- Search field is now the first body child in both idle and results; app bar carries the compact title "Search".
- Idle screen shows the compact subtitle + field + facet pills + recency ribbon + People strip + label chips + privacy note.
- Results screen shows the same field + facet pills, then horizontal album chips, then a filtered People strip, then the Photos grid.
- Person-name matching is implemented client-side by filtering the existing `personSummariesProvider` stream via a new `searchPeopleProvider`.
- Album matches were converted from a vertical list to a horizontal scroller of compact cover chips, so they no longer push the photo grid off screen.

## Verification completed

- `flutter analyze` — zero issues.
- `dart run build_runner build` — no changes needed (no schema change).
- `test/features/search/search_screen_test.dart` — 24/24 pass, including new tests for visible idle pills, anchored title/subtitle, idle People strip, and person-name matching in results.
- `integration_test/search_test.dart` on Pixel 9 Pro XL (`46121FDAS008AA`) — 3/3 pass.

## Verification blocked

`tool/check.sh` does not finish clean because of **pre-existing failures unrelated to this refactor**:
- `test/widgets/thumbnail_radius_test.dart`: `AlbumCard covers clip to br12`
- `test/widgets/design_goldens_test.dart`: `AlbumCard — populated and empty`
- `test/features/albums/album_detail_screen_test.dart`: `shows the album name, latest entry as cover, and rounded cells`
- `test/services/indexing_service_test.dart`: `folder exclusions changing exclusions resets derived data...`
- `test/features/settings/folder_picker_sheet_test.dart`: `returns the selected exclusion set` (times out)

The Search-specific layer is green; the remaining failures are in AlbumCard radius/golden, Album detail, indexing, and folder-picker code paths that were not touched here. They will need to be resolved before `tool/check.sh` passes for the repo as a whole.

## Manual end-to-end

Pending physical interaction on the device: open Search, confirm the field sits at the top on both idle and results, confirm tapping a filter pill on idle reveals matching results, confirm album matches appear as a horizontal row above photos, confirm a person-name query surfaces the People strip.

---

## Open questions before implementation

1. **Person-name matching in results?** It is the only new data path. Should we include it now, or ship Option A without it and add later?
2. **Idle title treatment?** Remove the large "Search" header entirely (rely on AppBar title) or keep a smaller subtitle above the field?
3. **Facet pills on idle:** Should they be visually distinct from results (e.g., outline-only) so they don't feel like they're filtering an empty list?

---

## Next step

Approve Option A and answer the open questions, or pick a different option. Once direction is locked, this plan becomes the implementation spec.
