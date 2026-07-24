# UI mockup alignment

Bring the shipped UI in line with the six reference mockups in `docs/screens/`.

**Status:** Phases 0–6 implemented; tests written but **not yet run** (the user
asked for tests without a run). `flutter analyze` is clean across `lib/` and
`test/`.
**Next step:** run `tool/check.sh`. Expect two goldens to fail and need a
deliberate regen — `memory_card` (gained the kind kicker) and
`theme_mode_picker` (pill row → `SegmentedControl`). Five new goldens have no
baseline yet and must be generated: `section_header_tappable`, `app_card`,
`circle_icon_button`, `segmented_control`, `app_button_compact`. Then the
on-device pass in Phase 7.

---

## Source of truth

| Mockup file | Screen |
|---|---|
| `Screenshot 2026-07-21 at 09.25.46.png` | Library |
| `Screenshot 2026-07-21 at 09.25.53.png` | Search (idle) |
| `Screenshot 2026-07-21 at 09.25.59.png` | Saved |
| `Screenshot 2026-07-21 at 09.26.07.png` | Albums |
| `Screenshot 2026-07-21 at 09.26.20.png` | Detail |
| `Screenshot 2026-07-21 at 09.26.52.png` | Settings |

The mockups are rendered on an iOS frame. They define **layout, hierarchy, and
component anatomy** — not platform chrome. The existing palette, type scale,
spacing, radius and motion tokens in CLAUDE.md's Design system stay authoritative
where the two disagree on a value.

### Wireframes only — no invented data

**The mockups are wireframes. Every value in them is placeholder.** Nothing in
this task adds a table, a column, a derived field, or a hardcoded string that
stands in for data. If the mockup shows content the schema cannot produce, the
element does not ship — it is not faked, defaulted, or filled with a placeholder.

Concretely, all of the following are mockup fiction and must never appear in code
or tests as content: `Anna` / `Leo` / `Mara` / `Sam`, `Kyoto 2026` / `Family` /
`Lisbon` / `Screenshots`, `Camera` / `Downloads`, the `dog` / `sunset` / `food` /
`architecture` / `portrait` / `garden` chip set, `4,750` / `232` / `12`,
`On this day` / `Kyoto` / `Dogs`, `July 2026` / `12 items`, `6 favorites`,
`1.0.0`. Every one of these already has a real source:

| Mockup content | Real source |
|---|---|
| People names | `PersonSummary.displayName` (**nullable**) |
| Label chips | `MemoryBuilder.presentableLabels` allowlist |
| Album names / counts | `AlbumSummary` |
| Folder names / counts | `DeviceFolder` |
| Memory kicker / title / subtitle | `MemorySummary.kind` / `.title` / `.subtitle` |
| Month label / count | `YearMonth.label` / `MonthCount` |
| Saved count | `savedFavoritesProvider` length |
| Settings stats | `libraryTotalsProvider`, `peopleCountProvider`, `indexingStatusProvider` |
| Version | `appVersionProvider` |

Empty and null states are **first-class outcomes**, not gaps to paper over: a
person with no `displayName` renders no caption, a month with no previews renders
none, a library with no memories renders no carousel. This is the existing
behaviour throughout the app and it stays.

---

## Decisions locked (from planning Q&A — do not re-litigate)

1. **Detail:** keep the bottom `DetailActionBar` exactly as-is. The top bar is
   restyled to the mockup's three circular scrim buttons (back · add-to-album ·
   favorite). Favorite therefore appears in two places; both drive the same
   provider, so state stays in sync. Accepted tradeoff.
2. **Library month sections:** the spec wins over the mockup's cell count — six
   previews plus a "view all" affordance stay. Only the header is restyled: the
   trailing `AppButton.quiet("View all 12", chevron)` becomes a quiet `12 items`
   count, and the **whole header row** becomes the tap target to `/month/:key`.
3. **Search:** the facet pill row (All/Photos/Videos/Favorites) is hidden while
   idle and appears only once there is a query or an active facet. The Folders
   list is removed from Search — Albums is the one place folders are browsed.
4. **Saved:** two-column masonry, hand-rolled. No new package. Cell aspect ratios
   come from `photo_assets.width`/`.height`, which are **already cached** — no
   schema change, no migration, no `SchemaVerifier` work.

---

## Open items (defaults chosen; say so if you disagree, work isn't blocked)

- **Memory card kicker vs. segments.** The mockup adds an uppercase kicker above
  the title and shows **no** segment row at the top. CLAUDE.md documents the
  segment row as a deliberate motif shared with the player's progress bar.
  *Default:* add the kicker, keep the segments. Revisit on device if the card
  reads as busy. (The kicker's content is `MemorySummary.kind`, which is already
  persisted — verified.)
- **`PeopleStrip` "See all".** Neither mockup shows it, but it is the only route
  to `/people`. *Default:* keep it.

---

## Phase 0 — Shared primitives

These are extracted first because four screens consume them; building them inline
per screen is how the app ends up with three dialects of the same card.

- [x] **0.1 `lib/widgets/app_card.dart` — `AppCard`.** Surface fill,
  `AppRadius.br12`, hairline `colors.border`, `clipBehavior: Clip.antiAlias`,
  optional hairline-divided children. Lift verbatim from `settings_screen.dart`'s
  private `_Card` (lines 310–337) and delete the private copy.
  *Consumers:* Settings groups, Search privacy note, Albums folder rows.
- [x] **0.2 `lib/widgets/circle_icon_button.dart` — `CircleIconButton`.** A glyph
  on a circular disc, two named constructors:
  - `.overMedia` — `AppOverMedia.scrim` disc, `AppOverMedia.glyph` icon (Detail).
  - `.surface` — `colors.surface2` disc, `scheme.onSurface` icon (Library app bar).

  40 px disc, 20 px glyph, `Tooltip` + `Semantics(button: true)`, `InkResponse`
  ink clipped to the circle.
- [x] **0.3 `lib/widgets/segmented_control.dart` — `SegmentedControl<T>`.**
  Full-width `surface2` track at `AppRadius.br12`, equal-width segments, selected
  segment painted `scheme.surface` with a hairline border, sliding on
  `AppMotion.short` / `AppMotion.curve` via `AnimatedAlign` over the track.
  Replaces the `FilterPill` row inside `ThemeModePicker`.
- [x] **0.4 Rename `MonthSectionHeader` → `SectionHeader`**
  (`lib/widgets/month_section_header.dart` → `section_header.dart`). It already
  labels Memories, People, Albums, Folders and Browse-labels — the name is a lie.
  Add an optional `onTap` (Phase 2 decision) that makes the whole row a target and
  renders a trailing `Icons.chevron_right_rounded`. Mechanical rename across ~8
  call sites plus tests and golden keys.

**Gate:** `flutter analyze` clean, goldens for 0.2/0.3 written and reviewed before
any screen consumes them.

---

## Phase 1 — Library (`lib/features/library/`)

- [x] **1.1** App-bar settings action becomes `CircleIconButton.surface` wrapping
  `Icons.settings_rounded`.
- [x] **1.2** `_LibrarySection` header: replace the
  `AppButton.quiet('View all $count', chevron: true)` trailing with a quiet
  `photoCountLabel(count)` caption in `colors.textSecondary`, and pass
  `onTap: onViewAll` to `SectionHeader` so the whole row navigates.
  `_OlderSection` and `_YearSection` follow the same shape.
- [x] **1.3** `_PreviewGrid` metrics: gutter `AppSpace.s2` → `AppSpace.s4`,
  section horizontal inset `AppSpace.s16` → `AppSpace.s8`, to match the mockup's
  near-edge-to-edge grid. **This changes a documented token role** — CLAUDE.md's
  Spacing line ("s2 photo-grid gutter") must be updated in Phase 7, and
  `AssetGrid` / `_SavedGrid` must be checked for the same rhythm.
- [x] **1.4** `MemoryCard` gains an uppercase kicker line above the title, styled
  `sectionLabel` in `AppOverMedia.glyphSoft`, rendering **`MemorySummary.kind`**
  (confirmed present — `memories_dao.dart:25`, persisted as `MemoryKind.name`).
  Map the enum name to display text in the widget; add no new field and no
  fallback string — a row always has a kind.

---

## Phase 2 — Search (`lib/features/search/search_screen.dart`)

The largest structural change. Current shape: the `TextField` **is** the app-bar
title. Target: a normal `Search` page title, with the field in the body.

- [x] **2.1** App bar becomes `AppBar(title: Text('Search'))`, matching Library and
  Saved.
- [x] **2.2** New `_SearchField` in the body: `surface2` fill at `AppRadius.br12`,
  leading `Icons.search_rounded` in `colors.textMuted`, `AppSpace.s16` screen
  inset, trailing clear button when non-empty. Hint copy stays consent-aware (the
  existing "promise only what is enabled" logic is correct and must survive) —
  `Photos, places, people, text…` when content search is on, the date/album
  wording when it is off.
- [x] **2.3** `_FilterBar` renders only when `!idle`.
- [x] **2.4** `_IdleView` becomes: `PeopleStrip` → `_BrowseLabels` → privacy note.
  Remove `FolderList` and the `deviceFoldersProvider` watch from this screen.
- [x] **2.5** `_BrowseLabels` header string `Browse labels` → `On-device labels`.
- [x] **2.6** Privacy note: an `AppCard` at 16 inset holding
  *"Search runs entirely on this device. Labels, text (OCR) and faces are indexed
  locally and never leave your phone."* in `styles.body` / `colors.textMuted`.
- [x] **2.7** `_IdleHint` fallback survives for the nothing-to-browse case, but the
  privacy note now shows unconditionally.

**Focus behaviour:** the `searchTabActiveProvider` listener currently focuses the
app-bar field. It must now target the body field's `FocusNode` — verify the
autofocus-on-tab-switch still works, and remember the CLAUDE.md gotcha that any
screen with a focused `TextField` never settles (bounded pumps only, never
`pumpAndSettle`).

---

## Phase 3 — Saved (`lib/features/saved/`)

- [x] **3.1 Data.** Add `IndexDao.watchFavoriteAssetsInCache()` returning
  `({String assetId, int width, int height})` rows — the existing
  `watchFavoritesInCache` join plus the two dimension columns, same ordering
  (newest-favorited first), same cache join so pruned assets drop out.
  New provider `savedFavoriteAssetsProvider`; retire `savedFavoritesProvider`
  once nothing reads it.
- [x] **3.2 Domain — `lib/features/saved/domain/masonry_layout.dart`.** Pure Dart,
  no Flutter import:

  ```
  List<MasonryTile> layoutMasonry({
    required List<({int width, int height})> items,
    required int columns,
    required double totalWidth,
    required double gutter,
  })
  ```

  Greedy shortest-column placement; each tile's height is
  `columnWidth * (height / width)`, clamped to a sane aspect range so a
  pathological panorama can't produce a 4000 px cell. Returns
  `MasonryTile(column, top, height)` plus the resulting total extent.
- [x] **3.3 Rendering — stay lazy.** Feed the computed geometry into a
  `SliverGrid` with a custom `SliverGridDelegate`/`SliverGridLayout` whose
  `getGeometryForChildIndex` returns the precomputed `SliverGridGeometry`, and
  whose `getMin/MaxChildIndexForScrollOffset` bound the visible window. The
  arithmetic runs over all items (cheap — cached ints), but child *building*
  stays lazy. Do **not** fall back to a `Row` of two `Column`s; favorites are
  bounded but not small.
- [x] **3.4 Cell chrome.** `AppRadius.br12` clip, `AppSpace.s8` gutter,
  `AppSpace.s16` screen inset, heart badge moves top-**left → top-right** and
  grows to a ~28 px `AppOverMedia.scrim` disc with a 14 px glyph. Hero tags
  (`assetHeroTag`) and the `PhotoViewerArgs` sequence are unchanged.

---

## Phase 4 — Albums (`lib/features/albums/`)

- [x] **4.1** The `+` `IconButton` becomes a compact `AppButton.primary` pill
  labelled `New` with a leading `Icons.add_rounded`, in the app bar's actions
  with `AppSpace.s16` trailing inset.
- [x] **4.2** Album grid metrics verified against the mockup (2 columns, r12
  cover, name at `body`/w600, count caption) — expected to need no change beyond
  confirming `childAspectRatio: 0.82` still avoids the 7 px overflow noted in
  CLAUDE.md's patrol gotcha.
- [x] **4.3** Folders section header `Folders` → `Device folders`.
- [x] **4.4** `FolderList` rows become carded: each `CoverRow` wrapped in an
  `AppCard`, `AppSpace.s8` apart, 16 inset. `CoverRow` gains an optional
  `showChevron` flag (default false, so the Search-album and add-to-album-sheet
  call sites are untouched) rendering a trailing
  `Icons.chevron_right_rounded` in `colors.textMuted`.
- [x] **4.5** `PeopleStrip` picks up names (Phase 5.0) here too.

---

## Phase 5 — People strip + Detail

- [x] **5.0 `PeopleStrip` names.** Each avatar becomes a `Column`: 72 px
  `FaceAvatar`, 6 px gap, name in `styles.caption` / `colors.textSecondary`,
  centered, one line, ellipsized, width-clamped to the avatar. **The strip's
  `SizedBox(height:)` must grow to match** — CLAUDE.md's gotcha is that a
  horizontal `ListView` constrains children tightly on the cross axis, so a stale
  72 will squash the column, not overflow it.

  **`PersonSummary.displayName` is `String?`** (`faces_dao.dart:32`) — clustering
  names nobody automatically. An unnamed person renders the avatar with **no
  caption and no reserved gap**; it does not render `Person 3`, `Unknown`, or an
  index. The mockup's four named faces are wireframe fiction. Since most real
  clusters will be unnamed until naming ships, the strip must look deliberate
  with zero captions — verify that on device, not just in a seeded widget test.
- [x] **5.1 Detail top bar.** `_TopBar` replaces its three `IconButton`s with
  `CircleIconButton.overMedia`: back (left), add-to-album `+` and favorite heart
  (right, `Icons.favorite_rounded` / `favorite_border_rounded` driven by
  `isFavoriteProvider`). The details/info button leaves the top bar — swipe-up and
  the bottom bar both still reach the EXIF sheet.
- [x] **5.2 Swipe-up affordance.** A centered grab handle
  (`AppRadius.r2`, `AppOverMedia.glyphFaint`) above a `SWIPE UP FOR DETAILS`
  caption in `styles.sectionLabel` / `AppOverMedia.glyphSoft`, sitting above the
  action bar. It is chrome: it must fade with both `_chromeVisible` **and**
  `_dragProgress`, i.e. live inside the existing `_dragFadedChrome` /
  `_Chrome` composition rather than in the `PageView`.
- [x] **5.3** `DetailActionBar` unchanged (locked decision 1).

---

## Phase 6 — Settings (`lib/features/settings/`)

- [x] **6.1** Private `_Card` deleted; screen imports `AppCard`.
- [x] **6.2** `_Group` section labels restyle from `scheme.onSurface` to
  `colors.textSecondary` (the mockup's labels are muted, not ink).
- [x] **6.3** On-device analysis becomes **three separate cards**, one per toggle,
  `AppSpace.s8` apart — not one hairline-divided card.
- [x] **6.4** `ThemeModePicker` re-implemented on `SegmentedControl<ThemeMode>`.
  Its golden is pinned (see CLAUDE.md's `FilterPill` note) and **will** change —
  regenerate deliberately, don't `--update-goldens` blind.
- [x] **6.5** Hairline divider under the app bar.
- [x] **6.6** The Photo access group has no mockup counterpart but is functionally
  required (limited/denied recovery). It stays, styled like the others.

---

## Phase 7 — Verification

### Unit — written, not run
- [x] `test/features/saved/domain/masonry_layout_test.dart` — column assignment,
  cumulative offsets, zero/one item, all-same-aspect, extreme panorama clamp,
  gutter arithmetic on odd widths.
- [x] `test/core/database/index_dao_test.dart` += `watchFavoriteAssetsInCache`:
  dimensions returned, cache join prunes deleted assets, ordering. Follow the
  CLAUDE.md reactivity rule — await the initial emission before mutating.

### Widget — written, not run
- [x] New: `AppCard`, `CircleIconButton`, `SegmentedControl`, `PeopleStrip` names.
- [x] **No-invented-data guards**, one per surface that the mockup shows
  populated: a person with `displayName == null` renders an avatar and **no**
  caption; a memory renders its real `kind` kicker; a month with zero previews
  renders an empty grid rather than placeholder cells; Settings rows show `—`
  (not `0`) while their provider is unresolved. These pin the wireframe rule so a
  later change can't quietly reintroduce placeholder content.
- [x] Search: facets hidden when idle / shown on query; privacy note present;
  no `FolderList`. **Bounded pumps only** — the body now owns a focused field.
- [x] Saved: N favorites render N cells across 2 columns; heart badge present.
- [x] Library: header row tap navigates to `/month/:key`.
- [x] Detail: top-bar favorite toggles `isFavoriteProvider`; swipe-up hint fades
  with chrome.
- [x] Update the eight already-modified screen tests. Every screen touching a
  Drift `.watch()` needs the dispose-tree teardown **in the test body**
  (`pumpWidget(SizedBox())` + `pump(1s)`), per CLAUDE.md.

### Golden (`test/widgets/design_goldens_test.dart`)
- [x] Add `AppCard`, `CircleIconButton` (both variants), `SectionHeader` with and
  without trailing/chevron; regenerate `ThemeModePicker`. Light + dark.
  Remember: goldens render every `Icon` as a solid box — they pin layout and
  colour only, glyphs are verified on device.

### Integration (device `46121FDAS008AA`, one file per `flutter test` invocation,
re-granting permissions between runs per CLAUDE.md)
- [ ] Library month-header tap → month grid → back.
- [ ] Saved masonry scrolls without a `RenderFlex` overflow (patrol turns an
  overflow into a real failure).
- [ ] Detail top-bar favorite round-trips into the Saved grid.
- [ ] Settings segmented control persists across a restart.

### Housekeeping
- [ ] `tool/check.sh` green.
- [x] CLAUDE.md updated: Core features (header row is the month's tap target;
  the Detail bar split and its deliberate duplicate favorite), Spacing (the
  s2/s4/s8 gutter split by grid kind), Shared components (`AppCard`,
  `CircleIconButton`, `SegmentedControl`, `SectionHeader`, `AppButton.compact`,
  `CoverRow.showChevron`), the grids-differ-by-job note, Project structure
  (`saved/domain`, `saved/widgets`), and two new gotchas — the tight
  cross-axis constraint on horizontal `ListView` children, and never running
  `dart format` on a directory in this repo.
- [ ] No new dependency is introduced, so the release merged-manifest re-verify
  (DoD #5) is **not** triggered. If that changes, run it.

---

## Risk notes

- **Phase 0.4's rename** touches the most files but carries the least risk; do it
  in one commit, alone.
- **Phase 3.3** is the only genuinely novel code. Get `layoutMasonry` unit-green
  before writing the sliver delegate — a wrong `SliverGridLayout` fails as
  overlapping or invisible cells, which is slow to debug through the widget layer.
- **Phase 2.1** moves focus ownership. The `searchTabActiveProvider` listener is
  easy to leave pointing at a disposed node; assert focus in a widget test.
