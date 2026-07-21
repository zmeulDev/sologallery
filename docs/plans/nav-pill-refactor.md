# Bottom nav → floating pill

Design-only refactor of the bottom navigation to match
`~/Desktop/bottom_nav_bar.png`. **Navigation behaviour is unchanged**: same four
branches, same order, same `goBranch` + pop-to-root-on-retap semantics, same
Search-tab focus publishing.

**Status: complete.** Shipped as described; no follow-ups outstanding.

---

## Reference, read

A floating capsule sitting above the bottom edge with a margin on all sides.
Near-black fill, no border, no shadow visible. Four white icon-only
destinations spaced evenly. The active one is a large filled circle knob at its
slot, inset a few px inside the capsule, carrying the icon in the capsule's own
ink. Content is visible around and behind the capsule.

## Decisions (locked)

| Decision | Choice | Why |
|---|---|---|
| Placement | **Float over content** (`extendBody: true`) | User choice. Matches the reference; photos run under the pill. |
| Dark mode | **Invert** — pill takes `pillActiveBg` | Reuses the design system's existing "inverted-ink floating pill" language (the snackbar). No new theme-invariant exception, no new token. |
| Indicator | Knob replaces the sliding dot | The dot is the thing the reference replaces. `AppMotion.nav` (260 ms) / `easeOutCubic` carry over unchanged. |
| Widget name | `DotNavBar` → **`NavPillBar`**, file `lib/widgets/nav_pill_bar.dart` | The name describes the dot, which is gone. Only two call sites plus a golden. |

## Token mapping — no new colors

| Part | Token | Light | Dark |
|---|---|---|---|
| Capsule fill | `colors.pillActiveBg` | `#1A1A18` | `#F0F0EE` |
| Knob fill | `colors.pillActiveText` | `#F0F0EE` | `#111110` |
| Active icon | `colors.pillActiveBg` | `#1A1A18` | `#F0F0EE` |
| Inactive icon | `colors.pillActiveText` @ 70% | — | — |
| Shape | `StadiumBorder` per design system | | |

Metrics: capsule 60 high, knob 52 (4 inset top/bottom), icon 22, horizontal
margin `AppSpace.s16`, bottom margin `AppSpace.s12` above the safe-area inset.
Reserved height 72 + inset (was 58 + inset).

## Files

### 1. `lib/widgets/nav_pill_bar.dart` (renamed from `dot_nav_bar.dart`)

- Destination list unchanged (`Library · Search · Saved · Albums`, same
  `IconData` pairs, same comments about the outlined/rounded families).
- Outer `SafeArea(top: false)` → `Padding` (s16 / s12) → `Container` with
  `pillActiveBg` + `StadiumBorder` → `SizedBox(height: 60)` → `LayoutBuilder`.
- Inside: `AnimatedPositioned` knob (left = `slotWidth * currentIndex + inset`,
  top/bottom 4, width `slotWidth - 8`… **no** — knob is a *circle*, so width =
  52 centred in its slot: `left = slotWidth * i + (slotWidth - 52) / 2`) under a
  `Row` of four `Expanded` `_NavItem`s, so the knob paints beneath the icons.
- `_NavItem` keeps `Semantics(button/selected/label)` + `Tooltip`; swaps
  `InkResponse` for a transparent-splash tap (the knob is the feedback) —
  `GestureDetector` + `behavior: opaque` inside the `Expanded`, so the whole
  slot height stays tappable.
- Active/inactive icon colour crossfades over `AppMotion.of(context,
  AppMotion.nav)` so it lands with the knob rather than snapping.

### 2. `lib/widgets/app_shell.dart`

- `Scaffold(extendBody: true, ...)`, `bottomNavigationBar: NavPillBar(...)`.
- `onTap` wiring untouched.

### 3. Bottom padding for every scroller in the four branches

With `extendBody: true` the Scaffold hands the body a `MediaQuery` whose
`padding.bottom` equals the nav bar's height, so each scroller adds
`MediaQuery.paddingOf(context).bottom` to its own bottom padding. Sites:

- `library_screen.dart:146` and `:198` — `ListView.builder`, `bottom: s24`
- `saved_screen.dart:92` — `SliverPadding(EdgeInsets.all(s16))`
- `albums_screen.dart:192` — trailing `SizedBox(height: s16)`
- `search_screen.dart:413` — browse `ListView` (no padding today)
- `widgets/asset_grid.dart:37` — `EdgeInsets.all(s2)`; **shared** with the
  month grid and album detail (pushed routes), where `paddingOf().bottom` is
  the system inset instead, so the same expression is correct in all three.

Empty/loading `Center` states are left alone: they centre in the full body
height, which reads correctly with a transparent pill floating over them.

## Tests — as built

1. **Golden** — `design_goldens_test.dart` case renamed to `NavPillBar — Search
   selected` (`goldens/ci/nav_pill_bar.png`); `dot_nav_bar.png` deleted. Pins
   capsule geometry, knob offset and the inversion in both themes. Icon
   *glyphs* stay invisible to goldens (known gotcha) — layout and colour only.
2. **Widget** — `test/widgets/nav_pill_bar_test.dart`: each slot reports its
   index; the knob is circular and its end insets match its top inset; the bar
   sizes to the capsule and sits above the safe-area inset (the `Center`
   regression); reduced motion lands the knob on the first frame with nothing
   pending.
3. **Widget, per-scroller** — the float decision's real risk is a scroller that
   forgot the inset, so each one is pinned where it lives, injecting the inset
   with `tester.view.padding = FakeViewPadding(bottom: 96)` (no harness
   changes needed — the existing `pump` helpers pick it up through
   `MediaQuery.fromView`):
   - `test/widgets/nav_bottom_inset_test.dart` — `AssetGrid`, with and without
     an inset (covers Search results + the pushed month/album grids)
   - `library_screen_test.dart` — timeline `ListView` = `s24 + inset`
   - `saved_screen_test.dart` — masonry `SliverPadding` = `s16 + inset`
   - `albums_screen_test.dart` — trailing spacer = `s16 + inset`
   - `search_screen_test.dart` — browse `ListView` = `inset`
4. **Integration (device, patrol)** — `nav_shell_test.dart` gains "scrolled to
   the end, Library clears the nav capsule": steps the timeline to its true end
   and asserts the lowest thing it renders sits above the capsule's top. The
   assertion takes a *list* of types (`AssetThumbnail`, `SectionHeader`,
   `YearHeader`) because the oldest section can have an empty preview grid,
   leaving its header as the bottom-most thing on screen. All 3 cases pass on
   the Pixel 9 Pro XL.

   **Library only, deliberately.** The assertion needs a scroller with more
   content than fits, or it passes vacuously — so it fails loudly on a zero
   scroll extent. Only Library is guaranteed to qualify: Saved is empty until
   something is favorited and Albums is a handful of rows (it failed exactly
   this way on the first run). Those two are covered by step 3 instead.

## Capsule sizing (revised after review)

First build stretched the capsule edge to edge (s16 margins, four equal slots).
Rejected on sight: at ~430 wide that leaves ~38px of dead ink between the
capsule's end and the outer glyphs. The capsule now **hugs its slots**, each
slot square (`_slotWidth == _pillHeight == 60`), so the whole thing is 240×60
and centres. The knob then clears the capsule's ends by the same 4px it clears
the top and bottom by — the reference's proportions exactly (its pill is 4:1
with a knob the height of the pill). Pinned by `nav_pill_bar_test.dart`, which
asserts the end inset equals the top inset rather than hard-coding either.

## What went wrong on the way

- **The first device run failed against correct code.** `ListView.builder`
  only *estimates* `maxScrollExtent` from the children built so far, so a
  single `jumpTo(maxScrollExtent)` lands mid-list and the extent grows
  underneath it. The helper now jumps until the extent stops moving. Recorded
  in CLAUDE.md.
- **`Center` claimed the entire screen.** Making the capsule compact meant
  centring it, and `Center` takes the *largest* size its constraints allow — so
  the nav bar sized to the full viewport, the capsule floated in the middle of
  the screen, and `extendBody` handed every scroller a screen-sized bottom
  inset. The device test reported it as "reached the end with nothing
  rendered", which reads like a flaky test; I chased it as one for two runs
  before the user reported the capsule sitting mid-screen. `Align(heightFactor:
  1)` sizes to the child. Both the trap and the misleading symptom are in
  CLAUDE.md, and `nav_pill_bar_test.dart` now asserts the bar's own height.
- **`--update-goldens` on the whole file was a mistake.** It rewrote
  `memory_card.png` and `theme_mode_picker.png` and created six goldens that
  were never committed — all reverted; only `nav_pill_bar.png` is new. See
  "Pre-existing failures" below.

## Pre-existing failures (not this task)

`tool/check.sh` reports 15 failures on this branch, and the identical 15 fail
on the commit this work started from — verified by diffing the failing-test
name sets, which came out empty in both directions. They are:

- 8 in `design_goldens_test.dart`: six goldens (`app_button_compact`,
  `app_card`, `circle_icon_button`, `section_header_tappable`,
  `segmented_control`, `year_header`) were never committed, and `memory_card`
  + `theme_mode_picker` mismatch — the tip commit is "Add failure images for
  memory card and theme mode picker tests", so this is someone's open thread.
  Left alone rather than regenerated over.
- 1 in `detail_goldens_test.dart`, 4 in `library_screen_test.dart` (time
  filters), 2 in `albums_screen_test.dart`.

## Definition of Done

1. ✅ `flutter analyze` clean; `tool/check.sh` runs with no new failures
   (15 pre-existing, unchanged — see above)
2. ✅ `nav_pill_bar.png` regenerated; nav widget + per-scroller tests pass
3. ✅ Patrol `nav_shell_test.dart` — 3/3 on the Pixel 9 Pro XL
4. ✅ No schema change, no new Android dependency — DoD 4 and 5 N/A
5. ⬜ **Left for you:** eyeball light/dark and 3-button nav (the taller inset)
   on device. The capsule's `SafeArea` handles it and the patrol test proves
   the geometry, but the *look* of it is a judgement call.
