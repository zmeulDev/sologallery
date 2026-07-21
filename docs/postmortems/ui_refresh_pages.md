# Instructions — Search, Saved (Favorites) & Albums refresh

**Audience:** Claude Opus 4.8 in Claude Code, inside the `sologallery` Flutter
repo. **Status: implemented (code + host tests written, not yet run on device).**

## Progress log

- **§2 Saved — done.** `saved_screen.dart`: `_CountLabel` app-bar tally
  (singular/plural, hidden at zero); `_HeartBadge` (top-left `AppOverMedia.scrim`
  circle + `favorite_rounded` glyph) stacked over each cell. Sequence contract
  untouched. Tests added: badge count + tally + singular.
- **§1 Search — done.** Shared `PeopleStrip`/`FolderList` now used here.
  `_BrowseLabels` wrap of `FilterPill`s from `MemoryBuilder.presentableLabels`
  (alphabetized `_browseLabels`), gated on `searchEnabledProvider`, order People
  → Labels → Folders. `_search()` commits a chip immediately (no debounce) and
  mirrors into the field. Query restored from `searchQueryProvider` in
  `initState`. `_ResultCount` trailing tally on the Photos header (`+` when
  `hasMore`). No `IndexDao.countContent` added — used loaded count (no
  build_runner). Tests: count header, chip gating, chip→content-search, restore.
- **§3 Albums — done.** Sectioned `CustomScrollView`: Albums `SliverGrid` (or
  `_NoAlbumsNote` stand-in) → `PeopleStrip` (gated `facesEnabledProvider` &&
  clusters) → `FolderList`. Full `EmptyState` only when albums+people+folders
  all empty. Create/delete unchanged. Shared widgets extracted to
  `widgets/people_strip.dart` + `widgets/folder_list.dart` (no copy-paste).
  Tests: folders section, People gating (on/off), compact-note stand-in.

**Verification done:** `flutter analyze` clean (whole project). No schema
change, no `build_runner`.

**Next step:** run `tool/check.sh` (host tests), then manual device pass on all
three tabs — verify heart badges over real photos, label-chip content search
returns photos on an indexed library, and Albums sections scroll as one.

---

_Original instructions below._

These bring three existing tabs up to the prototype. **Do not** change the
design system (monochrome `AppColors`, tracked-uppercase `MonthSectionHeader`,
`FilterPill`, dot nav, radii/motion tokens) or add colors, packages, or
`shared_preferences`. Reuse existing widgets/providers named below. Keep
`tool/check.sh` green and the release manifest network-free. Album membership
stays asset-id references (`AlbumEntries`) — never copy originals.

Each screen is an independent commit. All three touch **presentation only** —
no schema changes, so no `build_runner` unless you add a DAO query (§1c is the
only place that might).

---

## 1. Search — `features/search/search_screen.dart` (+ providers)

Current state: full-bleed `AppBar` `TextField`, a `_FilterBar`
(All/Photos/Videos + Favorites via `FilterPill`), idle view = People strip +
device Folders, results = matching albums rows over an `AssetGrid`. Keep all of
that. Deltas:

**1a. Person + label browse chips in the idle view.**
Above `Folders` in `_IdleView`, when content search is enabled
(`searchEnabledProvider`), add a **"Browse labels"** wrap of `FilterPill`s from
a curated allowlist of on-device labels. Reuse the `presentableLabels` set
referenced in `memories-section.md` (import it; do **not** re-derive). Tapping a
label sets `searchQueryProvider` to that text (routes through the existing
`_contentSearch` path in `SearchAssetsNotifier`). Keep People strip first, then
labels, then Folders.

**1b. Persist the query field text across the widget rebuild.**
`_controller` already holds it; ensure switching tabs and returning restores the
field from `searchQueryProvider` (set `_controller.text` in `initState`/`didChangeDependencies`
if the provider is non-empty) so a query survives the branch rebuild in
`StatefulShellRoute.indexedStack`.

**1c. "X results" count header.** Above the `_Results` photo grid replace the
bare `MonthSectionHeader(label: 'Photos')` with a header whose trailing shows
the count (`items.length`, plus `+` when `hasMore`). Read from the already-watched
`searchAssetsProvider` data — no new query. (If you want an exact total instead
of the loaded-page count, add `IndexDao.countContent(...)` mirroring
`searchContent` and regen `.g.dart`; otherwise use the loaded count and the
`hasMore` affordance.)

**DoD:** typing a label chip returns content-search photos; the results header
shows the count; leaving and re-entering Search preserves the query; idle view
order is People → Labels → Folders; `dart analyze` clean.

---

## 2. Saved / Favorites — `features/saved/saved_screen.dart`

Current state: one 3-column `GridView` of favorites (newest-favorited first) via
`savedFavoritesProvider`, tap opens the detail viewer across the favorites
sequence, empty state present. Deltas:

**2a. Count in the app bar.** Show the favorite count as a quiet subtitle or
trailing text in the `AppBar` (`'${rows.length} favorites'`), styled with
`AppTextStyles.caption` / `textSecondary`. Hide when zero (the empty state
covers that).

**2b. Heart overlay affordance on each cell.** Add a small translucent heart
badge (top-right, `AppOverMedia` scrim circle + glyph) on each grid cell so the
grid reads as "favorites" at a glance, matching the prototype. Presentation
only; unfavoriting still happens in the detail viewer (do not add inline
unfavorite here — it fights the "unfavorite flows back through detail" model
documented on `SavedScreen`).

**2c. Keep the sequence contract.** The tap already passes
`PhotoViewerArgs(assetIds, i)`; leave it — an unfavorite in detail must reflow
this grid via the reactive `savedFavoritesProvider`.

**DoD:** count shows and hides correctly; heart badges render over thumbnails
without shifting layout; tap-through and reactive reflow still work; empty state
unchanged.

---

## 3. Albums — `features/albums/albums_screen.dart` (+ People/Folders)

Current state: 2-column grid of `AlbumCard`s from `albumSummariesProvider`, `+`
creates (`showAppTextInputDialog` → `albumActionsProvider.create`), long-press
deletes, empty state present. The prototype's Albums tab also surfaces **People**
and **Device folders** below the album grid. Deltas:

**3a. Sectioned scroll body.** Replace the single `GridView` with a
`CustomScrollView`/`ListView` of three sections, each led by a
`MonthSectionHeader`:
  1. **Albums** — the existing `_AlbumsGrid` (as a `SliverGrid` or shrink-wrapped
     grid inside the scroll view; keep `crossAxisCount: 2`, the `0.82` aspect
     ratio, create/delete actions unchanged).
  2. **People** — a horizontal avatar strip reusing `_PeopleStrip`'s pattern
     from `search_screen.dart` (source `personSummariesProvider`,
     `FaceAvatar`, links to `/person/:id` and `/people`). Only when clusters
     exist **and** `facesEnabledProvider` is on.
  3. **Device folders** — `CoverRow`s from `deviceFoldersProvider` (same as the
     Search idle view), linking to `/folder`.
Do not duplicate People/Folders widgets — **extract** `_PeopleStrip` and the
folder-`CoverRow` list into small shared widgets (e.g.
`widgets/people_strip.dart`, `widgets/folder_list.dart`) and use them from both
Search and Albums.

**3b. Keep `+` and long-press** on the Albums section exactly as they are;
create/delete confirm dialogs and `albumActionsProvider` are unchanged.

**3c. Empty handling.** If there are no albums but People/Folders exist, show the
People/Folders sections with a compact "No albums yet — tap + to make one" note
in place of the album grid (not the full-screen `EmptyState`). Keep the
full-screen `EmptyState` only when albums, people, and folders are all empty.

**DoD:** albums grid + People strip + Folders list scroll as one; People hidden
when face detection is off or no clusters; extracted widgets used by both Search
and Albums (no copy-paste); create/delete unchanged; `dart analyze` clean.

---

## Verification (all three)

1. `dart format .` and `dart analyze` clean.
2. `dart run build_runner build --delete-conflicting-outputs` **only if** you
   added `IndexDao.countContent` (§1c); commit regenerated `.g.dart`.
3. `tool/check.sh` green, including new host/widget tests: label-chip → content
   search (Search), heart-badge render + reactive reflow (Saved), sectioned
   body with People gated on `facesEnabledProvider` (Albums).
4. No schema version bump (no table changes).
5. Manual device pass on each tab.

## Commit order

1. `feat(saved): favorite count + heart badges` (smallest).
2. `feat(search): label browse chips + results count + query restore`.
3. `refactor(albums,search): shared People/Folders widgets; Albums sectioned body`.
