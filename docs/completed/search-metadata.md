# Search (metadata) — Phase 4

Status: **COMPLETE** (2026-07-18). `tool/check.sh` green (145 host tests incl. a
new FilterPill alchemist golden); `integration_test/search_test.dart` 3/3 green
on the Pixel 9 Pro XL (real `RequestType` + capture-date filters). No schema
change, no new dependency, manifest still network-free.
Next step: none. Remaining manual check is the UI tap-through on device (the
service path + screen logic are already covered by the integration + widget
tests). Follow-up: extend to content search when ML/indexing lands — the screen
and `searchAssetsProvider` are structured to take an added label source.

## Context

The Library app-bar has a disabled search button (`library_screen.dart:30–34`,
`onPressed: null, // wired in the search phase`). Search is the next feature per
`docs/plans/CHECKPOINT.md`, and it comes *before* ML/indexing — so there is no
`photo_asset`/`photo_label` index and no content signals (labels/OCR/faces) to
search yet. Confirmed scope with the user: **metadata search now** over what is
queryable today, with content search added later when ML lands.

Searchable metadata available now:
- **Date** (capture date) — via `photo_manager` filtered path queries.
- **Media type** (photos / videos) — `photo_manager` `RequestType`.
- **Album name** — Drift `Albums.name` (`albumSummariesProvider`).
- **Favorites** — Drift `Favorites` (`FavoritesDao.watchAll`).

Outcome: a pushed `/search` screen reached from the Library app bar. A text
field parses **date phrases** ("June 2026", "2026", "2026-06") to window the
photo results and matches **album names**; media-type and favorites pills refine
the photo results. Reuses the existing grid, providers, and pagination base.

## Approach

### 1. Domain — date-phrase parser (pure Dart, unit-tested)
`lib/features/search/domain/search_date.dart`:
- `class DateWindow { final DateTime start; final DateTime endExclusive; }`
- `DateWindow? parseDateQuery(String raw)` supporting (case-insensitive, trimmed):
  - year: `"2026"` → Jan 1 2026 .. Jan 1 2027
  - month + year: `"june 2026"`, `"jun 2026"` → that month window
  - ISO-ish: `"2026-06"`, `"2026/06"` → that month window
  - else `null`.
- Month lookup table (full names + 3-letter abbreviations). No Flutter imports.
- `enum MediaTypeFilter { all, photos, videos }` lives here too (pure; the
  service maps it to `photo_manager` `RequestType`).

### 2. Service — `PhotoLibraryService` (`lib/services/photo_library_service.dart`)
- Thread an optional media type through the existing path helper: `_path(PMFilter
  filter, {RequestType type = RequestType.common})` — currently hardcodes
  `RequestType.common` at line 165. `_darwinFilter`/`_androidWindow` already
  accept `min`/`max` and are media-type-agnostic (type is a path-level concern),
  so they are reused unchanged.
- Add `Future<List<AssetRef>> searchAssets({DateTime? min, DateTime? max,
  required MediaTypeFilter type, required int page, required int pageSize})` —
  builds the platform filter via the existing `_isDarwin ? _darwinFilter :
  _androidWindow` split (null min/max ⇒ whole library, newest-first), resolves
  the path with the mapped `RequestType`, returns a page of `AssetRef`s. Mirrors
  `monthAssets` (line 273).
- Add `Future<List<AssetRef>> resolveFavoriteMatches({required List<String>
  ids, DateTime? min, DateTime? max, required MediaTypeFilter type})` — resolves
  each id via the existing cached `_entity` (line 329), filters by type
  (`entity.type`) and capture-date window (`entity.createDateTime`), returns
  refs sorted newest-first. Bounded by the favorites count; entities are cached.
- Map `MediaTypeFilter` → `RequestType` in a small private helper (keeps
  `photo_manager` out of the domain).

### 3. Providers — `lib/features/search/search_providers.dart`
- `searchQueryProvider` — `StateProvider<String>` (raw text, debounced by the
  screen before it is written; see §4).
- `searchTypeProvider` — `StateProvider<MediaTypeFilter>` (default `all`).
- `searchFavoritesOnlyProvider` — `StateProvider<bool>` (default false).
- `searchAlbumsProvider` — `Provider.autoDispose<List<AlbumSummary>>` that
  `ref.watch`es `albumSummariesProvider` (reuse — albums are few, filter
  client-side) and returns name-substring matches; empty when the query is blank.
- `searchAssetsProvider` — `AsyncNotifierProvider.autoDispose<SearchAssetsNotifier,
  List<AssetRef>>` extending the existing `PagedAssetsNotifier`
  (`lib/services/paged_assets_notifier.dart`). In `build()` it `ref.watch`es the
  three facet providers (so any facet change resets to page 0). `fetchPage`
  branches:
  - favorites **off** → `service.searchAssets(min,max,type,page,pageSize)` (true
    pagination).
  - favorites **on** → page 0 resolves the favorite ids (one-shot
    `favoritesDaoProvider.watchAll().first` is unsafe under FakeAsync — read via
    the dao's `watchAll` current value using `ref.read(savedFavoritesProvider.future)`
    then `resolveFavoriteMatches(...)`, cache the filtered list on the notifier;
    later pages slice the cached list).
  - "empty search" guard: when the query has no parseable date **and** type is
    `all` **and** favorites is off, return `[]` (nothing to search on) so the
    screen shows the idle hint rather than the whole library.

### 4. Screen — `lib/features/search/search_screen.dart`
Invoke the `/frontend-design:frontend-design` skill before building (CLAUDE.md
UI rule). A `ConsumerStatefulWidget` (owns the `TextEditingController` +
`FocusNode` + debounce `Timer`):
- `AppBar` with an auto-focused `TextField` as the title (hint "Search by date
  or album"), a clear (`×`) action; back arrow pops.
- Below the field: a filter row — a media-type **segmented pill** (All ·
  Photos · Videos) and a **Favorites** toggle pill. New reusable
  `lib/widgets/filter_pill.dart` styled from `AppColors` (`pillActiveBg`,
  `surface2`, `border`) + `AppTextStyles.filterPill`; matches the design system
  (pill filters). Reused later by content-search facets.
- Body (reactive to facets):
  - **Albums** group (when `searchAlbumsProvider` non-empty): a
    `MonthSectionHeader(label: 'Albums')` + a list of album rows reusing
    `AlbumCard` (or a compact row) → tap pushes `/album/:id`.
  - **Photos** group: `searchAssetsProvider.when(...)` → `AssetGrid` (reused,
    with `MonthSectionHeader(label: 'Photos')`), explicit loading / error /
    empty via `CenteredNote`.
  - **Idle hint** when no query and no active facet: a `CenteredNote`-style
    prompt ("Search your library by date, album name, or media type").
- Debounce: `onChanged` starts a ~280 ms `Timer` that writes
  `searchQueryProvider`; the date parse/album match only run after typing settles.

### 5. Routing + Library wiring
- `lib/core/router/app_router.dart` — add `GoRoute(path: '/search',
  parentNavigatorKey: _rootNavigatorKey, builder: … const SearchScreen())`,
  alongside `/month` and `/older` (pushed over the shell).
- `lib/features/library/library_screen.dart` — set the search `IconButton`
  `onPressed: () => context.push('/search')`; remove the stale comment.

## Files
- New: `lib/features/search/domain/search_date.dart`,
  `lib/features/search/search_providers.dart`,
  `lib/features/search/search_screen.dart`, `lib/widgets/filter_pill.dart`.
- Edit: `lib/services/photo_library_service.dart`,
  `lib/core/router/app_router.dart`,
  `lib/features/library/library_screen.dart`.
- Tests (mirror `lib/`): `test/features/search/domain/search_date_test.dart`,
  `test/features/search/search_providers_test.dart`,
  `test/features/search/search_screen_test.dart`,
  `test/widgets/filter_pill_test.dart` (+ alchemist golden, light/dark),
  `integration_test/search_test.dart`.

## Tests (Test strategy tiers)
- **Unit (host):** `parseDateQuery` table-driven — year, "month year", abbrev,
  ISO, invalid, whitespace/case, and a leap/short-month boundary
  (`endExclusive`). `MediaTypeFilter` mapping.
- **Provider (host, `ProviderContainer`):** `searchAlbumsProvider` name-substring
  match (override `albumSummariesProvider`); `searchAssetsProvider` state
  transitions across facet changes using the fake service — media-type filter,
  date window, favorites-on source switch, and the "empty search" `[]` guard.
  Real async, no FakeAsync (per the Drift-stream gotcha).
- **Widget (host):** search screen renders idle hint → results as facets change
  (override the asset/album providers); loading / error / empty branches. Pills
  toggle updates state. **Bounded pumps only** (a focused `TextField` is on
  screen — never `pumpAndSettle`; CLAUDE.md gotcha trap 3). `filter_pill`
  alchemist golden (active/inactive, light + dark).
- **Fake pairing:** the fake `PhotoLibraryService`
  (`test/support/fake_photo_library_service.dart`) gains `searchAssets` /
  `resolveFavoriteMatches`; paired with the on-device integration test below
  (Fake-pairing rule — the native filter path can't run on host).
- **Integration (real device, patrol):** open Library → tap search → type a
  known capture-month ("June 2026") and assert only that window's assets show;
  toggle Videos and assert the grid narrows; type an album name and assert the
  album row appears and pushes its detail; clear returns to the idle hint. Needs
  `~/Library/Android/sdk/platform-tools` on PATH (patrol adb, CHECKPOINT gotcha).

## Verification
1. `tool/check.sh` green (analyze, build_runner, host unit+widget+golden).
2. `flutter test integration_test/search_test.dart -d 46121FDAS008AA` green on
   the Pixel 9 Pro XL.
3. Manual end-to-end on device: date phrase, media-type pill, album-name match,
   favorites toggle, clear/idle.
4. Update `docs/plans/CHECKPOINT.md` (Search ✅, ML/indexing next) and mark this
   plan complete; note the completed month-grouping fix line that's currently
   missing from the checkpoint. No new Android deps → no manifest re-check.

## Decisions / notes
- **Favorites in search** is kept (bounded Drift set, resolved via the cached
  `_entity`, filtered client-side) rather than intersected into the paginated
  `photo_manager` query — avoids a page of 90 yielding 0 favorites. It overlaps
  the Saved tab but composes with date/type ("favorite videos from June").
- **Month-name-alone** ("june", no year) is intentionally *not* parsed in v1
  (ambiguous across years, and a single min/max window can't express it) — it
  falls through to album-name matching. Revisit with content search.
- No schema change, no new dependency.
