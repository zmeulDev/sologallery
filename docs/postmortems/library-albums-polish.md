# Library / Albums / People polish

Six reported defects, one pass.

**Status: §1–§6 implemented, §7 tests written, §8 CLAUDE.md updated.
`flutter analyze` is clean. Tests have NOT been run — the user asked to
hold.**

**Next step:** run `tool/check.sh` (the golden run needs
`--update-goldens` once for the new `indexing_banner` golden, and the
Library/Saved/Albums goldens the radius + spacing changes touch will need
regenerating). Then DoD #2/#3: on-device integration + manual verification of
all six fixes.

§9's open decision was taken as recommended: `AssetGrid` gutter `s2 → s4`.

---

## Reports → root causes

| # | Report | Root cause |
|---|---|---|
| 1 | Too little space between Memories and the grid | Carousel bottom pad `8`; first section top pad `s16` → 24px, same order as the inter-section gap |
| 2 | Gap between month sections too big | `_LibrarySection` pads top `s16` **and** bottom `s20` → the gap is a *sum*: 36px |
| 3 | "This week" thumbs have no rounded corner, Months' do | `AssetGrid` cells have no `ClipRRect` at all; `_PreviewGrid` uses `br8`; Saved uses `br12` — three different answers |
| 4 | No indication that analysis is running | `_IndexingNote` is private to `search_screen.dart`; every other screen is silent |
| 5 | Device folders should be 2-up and bigger | `FolderList` is a `Column` of full-width `AppCard(CoverRow)` rows |
| 6 | "Merged" banner never goes away, on any screen | **`SnackBar.persist` defaults to `action != null`** (`snack_bar.dart:303`). `ScaffoldMessengerState.build`'s timeout callback does `if (snackBar.persist) return;` (`scaffold.dart:~590`) — an Undo snackbar has **no timeout**. It lives on the root messenger, above the Navigator, so it also outlives the People route |

---

## 1 + 2 — Library vertical rhythm

### The real cause of the big month gap (found on device, after §2 shipped)

The padding arithmetic in §2 was correct but was **not** what the user was
seeing. `_PreviewGrid` was the one scroll view in the app with **no explicit
`padding`**, and `BoxScrollView.build` auto-absorbs `MediaQuery.padding` on its
main axis when `padding == null` (`scroll_view.dart:901`). Inside the shell,
`Scaffold(extendBody: true)` reports the nav capsule's height as
`padding.bottom`, so **every month's preview grid appended a capsule-sized band
under itself**.

Fixed with `padding: EdgeInsets.zero` on `_PreviewGrid`. Measured control on a
`FakeViewPadding(bottom: 96)` view: **52.0px before, 20.0px after** — exactly
the 32 logical px (96 ÷ 3 DPR) being absorbed.

Two things had to be got right for the regression test to mean anything:

1. The default 800×600 test surface is too short for two month sections, and
   the timeline builds lazily — the second month was never built.
   `setSurfaceSize(800, 2400)`.
2. **The first version of the test passed against the unfixed code**, because
   it measured from `find.byType(GridView)`'s rect — which *includes* the
   padding the grid absorbed. It now measures from the last `AssetThumbnail`.
   Without running that control the test would have been decoration.

Make the gap **single-sided** so it stops being a sum of two paddings.

- `_LibrarySection`: `fromLTRB(s8, s16, s8, s20)` → `fromLTRB(s8, s20, s8, 0)`
- `_YearSection`'s grid pad: `fromLTRB(s8, s4, s8, s20)` → `fromLTRB(s8, s4, s8, 0)`,
  and the year header carries the `s20` top instead (same rule: top owns the gap)
- `MemoriesCarousel`: `EdgeInsets.only(bottom: 8)` → `bottom: AppSpace.s20`

Result: **20px** between month sections (was 36), **40px** between the
carousel and the first section (was 24). One rhythm, one deliberate 2× break
where the content type changes. `ListView` keeps its `top: s4` and its
bottom nav inset.

## 3 — One thumbnail radius: `br12`

Every asset tile clips to `AppRadius.br12`. The `ClipRRect` stays **outside**
the `Hero` everywhere (it already is in Library/Saved) — moving it inside
would round the photo mid-flight while the detail viewer's destination is
unrounded.

| Site | Now | After |
|---|---|---|
| `AssetGrid` cell (`this week`, month, older, search results, album, folder) | none | `ClipRRect(br12)` |
| `AssetGrid` `_CellPlaceholder` | none | `ClipRRect(br12)` (else placeholders are square) |
| `_PreviewGrid` (Library sections) | `br8` | `br12` |
| `_SavedCell` | `br12` | unchanged |
| `CoverRow` 44×44 cover | `br4` | `br12` |
| `AlbumCard` | `BorderRadius.circular(12)` | `AppRadius.br12` (token, same value) |
| `MemoryCard` | `br12` | unchanged |
| `FaceAvatar`, detail viewer | circle / full-bleed | exempt — not tiles |

**Consequence (recommend accepting):** `AssetGrid`'s gutter is `s2`. At `r12`
adjacent corners nearly touch and the grid reads as damaged rather than
tiled. Raise the `AssetGrid` gutter `s2 → s4` (the value `_PreviewGrid`
already uses) so the radius reads as intentional. This changes the
CLAUDE.md Spacing note — "s2 edge-to-edge photo-grid gutter" becomes s4.

`AppRadius.r4`'s doc comment loses "photo-grid preview cells" and keeps
`DurationBadge`.

## 4 — Global "analyzing" strip

New `lib/widgets/indexing_banner.dart` → `IndexingBanner`, a `ConsumerWidget`
watching `indexingStatusProvider`; renders `SizedBox.shrink()` when
`!isIndexing`, so it can be dropped in unconditionally (same contract as
`FolderList`/`MemoriesCarousel`).

- **Copy:** `Analyzing your photos — 240 left` (`caption`, `textSecondary`).
  Matches Settings' existing verb ("Analyzing… N left") so the app has one
  word for this, not two. Active, specific, no apology.
- **Form:** full-bleed strip on `surface2` with a hairline bottom border, and
  a 2px determinate progress line (`1 - remaining/total`) along the bottom
  edge using `AppRadius.r2` — the token exists for exactly this. That line is
  the only flourish; it turns a static sentence into live feedback.
- **Motion:** height/opacity animated on `AppMotion.medium` so it doesn't
  pop in mid-scroll.

**Mount point: `AppShell`** — body becomes
`Column([IndexingBanner(), Expanded(child: navigationShell)])`.
This is the single insertion point that covers everything the user browses:
the four tabs *and* every branch-navigator push (Settings, month grid, older
grid, album detail, folder grid, People, person detail), because those render
inside `navigationShell`. `/photo/:id` and `/memory/:id` are root-navigator
routes that cover the shell, so the immersive media stages stay clean —
which is what we want, and it falls out for free rather than needing a
route check.

`_IndexingNote` is deleted from `search_screen.dart` (the shell now owns it;
leaving both would say it twice on one screen).

## 5 — Device folders 2-up

`FolderList` becomes a shrink-wrapping 2-column `GridView.count`
(`shrinkWrap: true`, `NeverScrollableScrollPhysics`, gutter `s12`, inset
`s16`) — the same pattern `_PreviewGrid` already uses inside a list.

New `_FolderTile`: square cover (`AssetThumbnail`, `br12`) with a small
scrim'd `folder_rounded` glyph badge bottom-left, then name (`body`) and
count (`caption`, `textSecondary`) underneath — `childAspectRatio: 0.82`,
i.e. the `AlbumCard` metric.

The glyph badge is what stops the section reading as more albums, now that
the geometry matches. `FolderList`'s doc comment currently explains the
carded-row choice — it gets rewritten to state the new rule, or it becomes a
lie about code that no longer exists.

`CoverRow` keeps its other callers; only `FolderList` stops using it.

## 6 — Merge snackbar

Two changes in `_PeopleScreenState`:

1. `persist: false` + `duration: const Duration(seconds: 6)` on the merge
   `SnackBar`. Without `persist: false` the Undo action suppresses the
   timeout entirely — this is the actual bug.
2. Capture the messenger in `didChangeDependencies`, call
   `hideCurrentSnackBar()` in `dispose()`. An Undo affordance for a People
   merge must not survive the People screen; the root messenger otherwise
   carries it into every tab.

`detail_screen.dart:63`'s snackbar has no action → already non-persistent,
no change.

---

## 7 — Tests (write now, run later)

**New**

- `test/widgets/indexing_banner_test.dart` — renders nothing when idle;
  shows `Analyzing your photos — 240 left` at `remaining: 240`; progress
  fraction equals `1 - remaining/total`; `total == 0` doesn't divide by zero.
- `test/widgets/thumbnail_radius_test.dart` — cross-cutting: for `AssetGrid`,
  Library `_PreviewGrid`, `_SavedCell` and `CoverRow`, walk to the
  `ClipRRect` ancestor of each `AssetThumbnail` and assert
  `borderRadius == AppRadius.br12`. This is the regression guard for "all
  thumbs, one radius".
- `test/features/library/library_spacing_test.dart` — geometry, not
  constants: with a memories carousel + ≥2 month sections mounted, assert
  `gap(carousel → first header) > gap(header n → header n+1)` and that the
  inter-section gap is 20.

**Updated**

- `test/widgets/app_shell_test.dart` — banner present above the shell body
  when `indexingStatusProvider` reports indexing, absent when idle.
- `test/features/search/search_screen_test.dart` — no in-screen indexing note
  any more (both existing cases already override the provider to `idle()`,
  so they stay green; add one asserting the screen itself never renders the
  note even when indexing).
- `test/widgets/folder_list_test.dart` — two tiles per row (same `dy`,
  different `dx`), tile cover is larger than the old 44px row cover, tap
  still routes to `/folder?id=…`.
- `test/features/albums/albums_screen_test.dart` — folders section still
  finds both folders after the layout change.
- `test/features/people/people_screen_test.dart` — after merge, the
  `SnackBar` has `persist == false` and a finite duration; it is gone after
  `pump(7s)`; and disposing the People route hides it immediately.
- `test/widgets/design_goldens_test.dart` — add `IndexingBanner` (light +
  dark) and the new folder tile; regenerate the Library/Saved/Albums goldens
  the radius and spacing changes touch.

**Integration (device, later)**

- `integration_test/nav_shell_test.dart` — the banner does not eat the
  scrollers' bottom inset and the last grid row still clears the nav capsule.

---

## 8 — CLAUDE.md updates (at the end, per DoD #6/#8)

- Radius table: `r4` → DurationBadge only; `r12` → "cards, banner, filled
  inputs, **all photo thumbnails**".
- Spacing note: photo-grid gutter `s2` → `s4`.
- Shared components list: add `IndexingBanner`.
- New gotcha: **`SnackBar` with an action never times out** —
  `persist` defaults to `action != null` and `ScaffoldMessengerState` skips
  the timeout when it's set; on a root messenger that means the banner
  follows the user across every screen forever. Always pass `persist: false`
  with an explicit `duration`, and hide screen-scoped snackbars in
  `dispose()`.

## 9 — Open decision (resolved)

`AssetGrid` gutter `s2 → s4` (§3): **taken**. `r12` corners at a 2px gutter
read as a rendering fault.

---

## Files touched

**lib**

- `core/theme/app_radius.dart` — r4/r12 doc comments
- `features/library/library_screen.dart` — §1/§2 rhythm, preview `br8 → br12`
- `features/memories/widgets/memories_carousel.dart` — bottom break `8 → s20`
- `widgets/asset_grid.dart` — `br12` on cells *and* placeholders, gutter `s4`
- `widgets/cover_row.dart` — cover `br4 → br12`
- `features/albums/widgets/album_card.dart` — literal 12 → `AppRadius.br12`
- `widgets/indexing_banner.dart` — **new**
- `widgets/app_shell.dart` — mounts the banner above the shell body
- `features/search/search_screen.dart` — `_IndexingNote` deleted
- `widgets/folder_list.dart` — rewritten as a 2-up tile grid
- `features/people/people_screen.dart` — `persist: false` + `dispose()` hide

**test**

- `widgets/indexing_banner_test.dart` — **new** (7 cases)
- `widgets/thumbnail_radius_test.dart` — **new** (5 cases, cross-cutting)
- `features/library/library_spacing_test.dart` — **new** (3 cases, geometry)
- `widgets/app_shell_test.dart` — 2 new cases + `indexing` param on `pumpApp`
- `widgets/folder_list_test.dart` — rewritten for the 2-up layout
- `features/people/people_screen_test.dart` — `mergeBoth` helper + 2 new cases
- `features/search/search_screen_test.dart` — `indexing` param + 1 new case
- `widgets/design_goldens_test.dart` — `IndexingBanner` golden (light + dark)

## Known follow-ups

- The `indexing_banner` golden file does not exist yet — the first run must be
  `flutter test --update-goldens test/widgets/design_goldens_test.dart`.
- Goldens covering `CoverRow`, `AlbumCard` and anything showing a grid cell
  will differ (radius) and need regenerating in the same pass.
- Not yet done: DoD #2 (on-device integration for the touched areas) and
  DoD #3 (manual end-to-end on the Pixel 9 Pro XL).
