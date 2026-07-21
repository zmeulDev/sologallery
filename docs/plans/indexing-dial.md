# Indexing progress: strip → floating dial beside the nav capsule

**Status: complete.** Shipped, verified on device. See "Final state" below.

## Context

Background analysis is an app-wide condition — until it finishes, Search,
People and Memories are all quietly incomplete. That used to be said by
`IndexingBanner`, a full-width strip in `AppShell`'s body above the shell
branch: `Analyzing your photos — 240 left` plus a 2px progress hairline.

The strip sat at the top of the screen, above the app bar, far from where the
eye rests and where the thumb is. The ask: carry the state in a **circular
indicator with the remaining count inside it, floating to the right of the
bottom nav capsule** — visible without claiming a full band of screen, and gone
the moment the pass ends.

Decisions taken (asked and answered):

- The top strip is **replaced**, not duplicated. One statement of the condition,
  in one place — the same rule that keeps Search from repeating it.
- The dial shows the **remaining count**, compacted past 999 (`142`, `1.2k`,
  `12k`), with the ring arc carrying the share already done.
- It floats **beside** the capsule, not inside it. A fifth slot inside would
  grow the capsule 240→300 and re-centre it, sliding every destination ~30px
  sideways when a pass starts and again when it ends — moving tap targets under
  a thumb already reaching for them.

## Design

Same inverted ink as the capsule (`pillActiveBg` fill, `pillActiveText`
content) at 44×44 — it reads as the sliding knob (52) escaped from the capsule
and gone to work, so the bottom chrome stays one family. No new tokens.

```
                                    ring arc = share done
  ╭────────────────╮        ╭───╮  ╱
  │ ◉   ◌   ◌   ◌  │        │142│
  ╰────────────────╯        ╰───╯
  ← capsule, unmoved →   s12 →│
```

- **Ring:** 2.5px arc from 12 o'clock clockwise, `pillActiveText`, over a full
  track at 0.25 alpha, inset 3 from the edge (`IndexingRingPainter`).
- **Count:** `caption` (11sp) at `w600`, `pillActiveText`, via `compactCount`.
  Same `total == 0 → 0.0` divide-by-zero guard the strip had.
- **Motion:** `TweenAnimationBuilder` sweeps the arc over `AppMotion.medium`;
  appear/disappear is an `AnimatedSwitcher` fade+scale over the same, inside a
  fixed 44×44 box so the bar's trailing slot never resizes.
- **Accessibility:** the sentence the strip carried survives as the dial's
  `Semantics` label — `Analyzing your photos — 142 left`, `liveRegion`. Not
  tappable: no destination it would beat the Settings row to.

Clearance: capsule 240 centred, dial 44 at `right: s12` → they touch at a
viewport width of 352, below any target device (Android 360, iOS 375). Pinned
by a test, not by reasoning.

## Final state — what changed

| File | Change |
|---|---|
| `lib/core/format/count_labels.dart` | `compactCount(int)` added |
| `lib/widgets/indexing_dial.dart` | **new** — `IndexingDial` + public `IndexingRingPainter` |
| `lib/widgets/indexing_banner.dart` | **deleted** |
| `lib/widgets/nav_pill_bar.dart` | `trailing` param; capsule extracted to a local, wrapped in a full-width `Stack` inside the same `Align(heightFactor: 1)` |
| `lib/widgets/app_shell.dart` | body is `navigationShell` again; `trailing: const IndexingDial()` |
| `lib/features/search/search_screen.dart` | comment reworded |
| `CLAUDE.md` | core-features nav bullet, project structure, shared-components bullet |

Tests: `test/widgets/indexing_dial_test.dart` (**new**, 10 cases — replaces
`indexing_banner_test.dart`), `count_labels_test.dart` (+5 `compactCount`
cases), `nav_pill_bar_test.dart` (+trailing placement / no-overlap at 360),
`app_shell_test.dart` (two banner cases → dial cases), `design_goldens_test.dart`
(`indexing_banner` → `indexing_dial`, new PNG generated),
`integration_test/nav_shell_test.dart` (+2 patrol cases).

### Notes for whoever is next

- `NavPillBar.trailing` is deliberately a plain `Widget?` — the bar stays
  Riverpod-free, so its golden and its widget tests never need a
  `ProviderScope`.
- `IndexingRingPainter` is public *only* so a widget test can read the fraction
  the ring was drawn at; there is no other observable trace of it.
- The bar's height is unchanged (60 + s12 + safe area), so `extendBody`'s
  reported bottom inset — which every scroller in the shell pads by — did not
  move. Pinned by the existing `the bar sizes to the capsule` test.

## Verification

- `flutter analyze` — clean.
- `flutter test` — every test in the touched area passes (dial, nav bar, shell,
  formatter, the new golden).
- **On device** (Pixel 9 Pro XL `46121FDAS008AA`), `patrol test -t
  integration_test/nav_shell_test.dart`:
  - `the indexing dial rides right of the capsule while analysing` — accepts
    content search, polls to a 3-minute deadline for the dial, then asserts it
    clears the capsule, stays on screen, shares the capsule's baseline and sits
    in the bottom half. **Passed.**
  - `with analysis declined the dial never shows` — the negative control it is
    paired with. **Passed.**

### Pre-existing failures on this branch (not from this work)

`flutter test` on a clean `feature/metadata-search` fails 22 tests; after this
work it fails 21 (the missing `indexing_banner` golden is gone). Untouched here:

- 9 `design_goldens_test.dart` cases — 4 stale PNGs (`cover_row`,
  `duration_badge`, `memory_card`, `theme_mode_picker`) and 6 never generated
  (`app_card`, `circle_icon_button`, `section_header_tappable`,
  `segmented_control`, `year_header`, `app_button_compact`). A
  `--update-goldens` run fixes them, but regenerating unverified goldens is its
  own decision and its own commit — deliberately left alone.
- `nav_bottom_inset_test.dart` ×2 — expectations still assume the old s8 grid
  gutter (expects 34/2, gets 36/4).
- `library_screen_test.dart` time filters ×4, `albums_screen_test.dart` ×3,
  `detail_goldens_test.dart` ×2, `people_screen_test.dart` ×1.
- On device, `scrolled to the end, Library clears the nav capsule` fails — and
  fails identically on a stashed clean tree (verified), so the Library
  scroller's bottom inset is broken independently of this change.
