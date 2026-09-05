# Swiss UI refactor — implementation plan

**Status:** Phase 0 built and reviewed clean (branch
`worktree-swiss-ui-refactor-phase0`, commits `e624faa`..`3d6c6c8`). Phases
1-6 remain planning only.
**Source:** a research spike (not committed to the repo) comparing the current
design system against International Typographic Style principles, with
mockups covering nine screens: Onboarding (access + consent), the nav shell,
Library, Search, Saved, Albums, Memories player, Detail/EXIF, and Settings.
The direction landed on **black / white / one spot red**, red scoped strictly
to *state* (never decoration), with `AppRadius` completely unchanged.

**Next step:** review Phase 0's branch/PR and decide how to land it (see the
"Rulings" carried into decision #1 and the Phase 0 Definition of Done below —
in particular the WCAG contrast pre-condition and the time-boxed
unused-symbol exception). Once merged, start a fresh session for **Phase 1**
— see "Phasing" below for why phases are separate sessions/PRs.

---

## What this changes, in one paragraph

SoloGallery's design system is already close to Swiss International
Typographic Style — no accent colour, a strict 4pt spacing module, functional
uppercase micro-type, a mathematically regular photo grid. This refactor: (1)
adds exactly one new colour token, `AppColors.accent`, used only for real
state (an active filter, a favourited photo, an "on" toggle, the live
indexing ring, the memory player's current segment); (2) collapses
`AppTextStyles` from four weights to two (400 / 700); (3) rebuilds `ExifSheet`
as a flush-left table instead of a wrapped chip cloud; (4) documents the
existing s8-bleed-past-s16-margin grid pattern as a stated rule instead of a
per-file comment. `AppRadius` (r2/r4/r12/r20/r30) and every `StadiumBorder`
pill/button shape are **untouched** — confirmed against every widget below,
including two corrections the research spike got wrong (see "Corrections").

---

## Corrections from the research spike

The spike's mockups were illustrative HTML, not code, and got two shapes
wrong. Fixing these here so the plan doesn't propagate the mistake:

1. **`AppButton` (primary/secondary) is `StadiumBorder`, not `AppRadius.r12`.**
   The spike's onboarding "Continue" and Albums "New" buttons were mocked
   with a 12px rounded rect. The real widget
   (`lib/widgets/app_button.dart:88-90,134-136`) is a pill, same family as
   `FilterPill` and the nav capsule. **No radius change needed on any
   button anywhere** — they're already a shape outside the `AppRadius` scale,
   same as pills.
2. **`SegmentedControl`'s track is genuinely `AppRadius.r12`**
   (`lib/widgets/segmented_control.dart:57`, confirmed) — the spike
   approximated this with a CSS guess and got it right by luck.

---

## Absolute-rule check

Read against `AGENTS.md` §Absolute rules: none apply here (no network, no
photo duplication, no Drift schema, no ML, no isolate work touched). The one
rule that *does* govern this work is the non-functional requirement in
`PRD.md` §4: **"no information carried by colour alone."** Every use of
`accent` below has a non-colour cue riding with it — see the "Accent usage"
table.

---

## Accent usage — the only places red appears

Every row must ship with its non-colour cue, or don't ship the row.

| Location | Red marks | Non-colour cue |
|---|---|---|
| `FilterPill` (active) | this facet is selected | bold weight (700) vs regular; pill shape unchanged |
| `ConsentSwitch` (on) | this capability is enabled | thumb position (Material `Switch` default) |
| `SegmentedControl` (selected) | this is the current choice | bold weight (inherited from the `button` role, already 700); thumb kept, see decision #3's resolution below |
| `NavPillBar` knob | current destination | position (which slot) |
| `IndexingDial` ring | analysis actively running | the ring only exists/animates while indexing; disc is otherwise empty |
| `ExifSheet` favourite mark | this photo is favourited | filled vs. outline heart shape (existing Material convention) |
| Saved-grid heart badge | this photo is favourited | same filled-heart convention |
| Memories player current segment | this is the live segment | **also** slightly taller than a played segment (see Phase 3) |

Explicitly **not** accent, corrected from the spike itself:
`count-pill` text (Library year/older counts — just data), the old
per-section "index dot" (was decorative, cut during the spike already).

---

## Decisions this plan is making (flag if you disagree)

1. **Accent colour:** `Color(0xFFEB0000)` (the red used throughout the
   spike), identical value in `AppColors.light` and `AppColors.dark`. One
   colour, not two — red reads fine on both a white and a near-black ground.
   *Verify contrast (WCAG AA against both `surface` values) during Phase 0
   before merging.*
   **Contrast verified during Phase 0's final review (2026-09-05):**
   `#EB0000` passes 3:1 (non-text/UI use — border, ring, switch track, knob)
   against every surface in both themes, but **fails** 4.5:1 text contrast
   against every ground except pure-white light `surface`. Phase 0 ships
   `accent` unused, so no live accessibility issue ships today. **Hard
   pre-condition for Phase 1:** decisions #2 and #3 below use `colors.accent`
   as *text* colour (FilterPill selected text, SegmentedControl selected
   label) — bold 12sp does not qualify as WCAG "large text," so this literal
   cannot be reused for that text without re-solving contrast first (a
   different value, a heavier weight/size that qualifies as "large text," or
   a conscious documented exception). Do not carry this value into Phase 1's
   text-colour usage without addressing this.
   **Resolved during Phase 1 planning (2026-09-05):** no single red value can
   hit 4.5:1 against both a near-white ground and a near-black ground, so a
   text-safe accent must vary by theme. Rather than add per-widget variants
   (`FilterPill` sits on `scheme.surface`; `SegmentedControl`'s label, if the
   thumb were removed as originally drafted, would sit on `colors.surface2` —
   a *different* ground with its own pass/fail profile), decision #3 below is
   reversed: `SegmentedControl` **keeps its thumb**, so both widgets' selected
   text sits on the same ground (`scheme.surface`). That collapses the fix to
   one new token, `AppColors.accentText`, varying only by theme:
   - `light: Color(0xFFEB0000)` — identical to `accent`; already 4.63:1
     against white (script-verified, see Phase 1 Task 0).
   - `dark: Color(0xFFFF3B30)` — a brighter red; 4.81:1 against dark
     `scheme.surface` (`#1C1C1A`), script-verified.
   Non-text accent uses (border, ring, switch track, nav knob) are unaffected
   and keep plain `colors.accent` (`#EB0000`, both themes) — Phase 0 already
   verified those pass the 3:1 non-text threshold everywhere. See Phase 1
   Task 0 for the exact contrast-ratio unit test that locks this in.
2. **`FilterPill` active state:** keeps its `StadiumBorder` shape (per the
   corrections above, shape stays put). Change is: selected fill goes from
   `colors.pillActiveBg` to transparent/`scheme.surface`, selected border and
   text go from ink to `colors.accent`, weight goes to 700. This is a refinement
   on the spike's mockup, which dropped the pill shape entirely — dropping
   it isn't necessary once buttons/pills are confirmed exempt from the radius
   conversation, and keeping it is the smaller, safer diff.
3. **`SegmentedControl` selected state:** ~~drop the raised thumb
   (`_thumbRadius`, `scheme.surface` fill) and instead colour the selected
   label `colors.accent` + bold, on the plain recessed track.~~ **Reversed
   during Phase 1 planning (2026-09-05)** — see decision #1's resolution:
   the thumb stays exactly as-is (`scheme.surface` fill, `colors.border`
   border), so the selected label's ground matches `FilterPill`'s. Only the
   selected label's colour changes: `scheme.onSurface` → `colors.accentText`.
   No weight override needed here — `styles.button` (what this label already
   uses) is already `w700` post-Phase-0, unlike `FilterPill`'s `filterPill`
   role which stayed `w400` and needs a per-call override.
4. **Memory player's third progress state** (Phase 3) is a small logic
   change, not a pure style pass — it introduces a real "is this segment
   currently playing" concept the code doesn't have today. Kept as its own
   phase so it can be reviewed/shipped independently of the visual rollout.
5. **Onboarding's poster treatment** (Phase 4) is the single biggest visual
   departure — it's the only place introducing a new graphic element (the
   red ring) rather than recolouring/reweighting something that already
   exists. Recommend building it behind a `flutter-add-widget-preview`
   preview first so it can be reviewed in isolation before wiring into the
   real onboarding flow.

---

## Phasing — why this isn't one PR

Nine screens, ~15 files with existing golden tests, and a widget whose
rebuild (`ExifSheet`) touches real layout logic is too large for one
reviewable change, and `AGENTS.md`'s Definition of Done requires goldens
(light **and** dark) plus an on-device integration pass *per touched area*.
Per the session-hygiene rule in `CLAUDE.md`, later phases should be their own
conversations/PRs, each starting from this doc.

- [x] **Phase 0 — Foundation** (built 2026-09-04/05, reviewed clean)
- [x] **Phase 1 — Shared widgets** (built and reviewed 2026-09-05, branch
      `worktree-swiss-ui-refactor-phase1`, Tasks 0-7 executed via
      `superpowers:subagent-driven-development`. The final whole-branch
      review found 5 issues invisible to the per-task reviews — most notably
      `accentText.light` (`#EB0000`) failing WCAG AA text contrast against
      `FilterPill`'s *real* ground (`scaffoldBackgroundColor`, not
      `scheme.surface` as Task 0's test assumed) — all fixed in one
      dedicated fix pass; see Phase 1's Definition of Done below for what
      that pass covered.)
- [x] **Phase 2 — `ExifSheet` rebuild** (Tasks 0-3 built and clean, commits
      `716600c`..`2675cd1`; Task 4 on-device pass — both the automated
      `detail_actions_test.dart` run and the manual no-EXIF/GPS checks —
      completed 2026-09-05 on Android)
- [x] **Phase 3 — Memories player third state** (Task 0 built and clean,
      commit `f992cf0`; Task 1 on-device manual pass completed 2026-09-05
      on Android)
- [x] **Phase 4 — Onboarding poster treatment** (built and reviewed clean
      2026-09-05, branch `worktree-swiss-ui-refactor-phase4`, Tasks 0-3
      executed via `superpowers:subagent-driven-development`; on-device
      manual pass completed 2026-09-05 on Android)
- [x] **Phase 5 — Remaining screens** (built and clean 2026-09-05, commits
      `7c803cd`..`82f98e8` — Saved heart badge recolored, 4+1 residual
      `FontWeight.w600` collapses, Library/Search/Albums/Settings verified
      clean, no code change needed there)
- [ ] **Phase 6 — Docs**: fold the grid-bleed rule, the accent token, and the
      two-weight rule into `docs/design-system.md`.

---

## Phase 0 — Foundation

**Files:**
- `lib/core/theme/app_colors.dart` — add `accent` field to `AppColors`
  (required in constructor, `copyWith`, `lerp`), add to `.light` and `.dark`
  with the same `Color(0xFFEB0000)`.
- `lib/core/theme/app_text_styles.dart` — collapse weights:
  - `sectionLabel`: `w600` → `w400`
  - `button`: `w600` → `w700`
  - `exifValue`: `w600` → `w400`
  - `filterPill`: `w500` → `w400` (the *selected* look now comes from colour
    + a per-call weight override in `FilterPill`, not from the shared role —
    see Phase 1)
  - `display`, `pageTitle`: already `w700`, no change
  - `body`, `exifKey`, `caption`: already `w400`, no change
  - Update the doc comments above each field (they currently state the old
    weight, e.g. "11 / 600" → "11 / 400").

**Tests:**
- `test/widgets/design_goldens_test.dart` — every design-system golden will
  shift (text now renders at different weights). Regenerate; review the diff
  screen by screen rather than blindly accepting — a weight change should be
  visually obvious per widget, not a wall of uniform pixel drift.
- `test/features/detail/detail_goldens_test.dart` — same; `exifValue`
  weight change touches this screen.
- Add a unit test asserting `AppColors.light.accent` and
  `AppColors.dark.accent` are both defined and equal (locks decision #1
  above; if a reviewer changes one without the other, the test catches it).
- Confirm the exact golden-regeneration invocation for this repo's
  `alchemist` setup before running — not listed in `AGENTS.md`'s verification
  commands, so check `test/widgets/design_goldens_test.dart` or `alchemist`'s
  README for the update flag/env var.

**Definition of Done for this phase:**
- [x] `tool/check.sh` passes.
- [x] Every golden diff reviewed manually — **caveat found during review:**
      this repo's CI goldens render with the Ahem font + `obscureText: true`
      (alchemist's `CiGoldensConfig` default), so they cannot visually show a
      font-weight change at all. All 6 PNGs that got byte-different on
      regeneration were verified pixel-identical (RGBA diff) — pure
      re-encode churn, zero content change. Satisfied instead via a
      code-level trace of every `AppTextStyles` consumer plus the new
      weight-invariant unit test (see Tests above). **Carry this forward:**
      Phase 1's colour changes (unlike Phase 0's weight changes) *will* show
      up in these same CI goldens, so goldens regain real value starting
      there.
- [x] No screen using `AppTextStyles` regressed to 3+ visually distinct
      weights on one view — spot-check Library ("all" filter) and Search
      results, the two screens flagged in the spike as exceeding three
      hierarchy levels. **Result:** `AppTextStyles` itself is now clean on
      both screens (400/700 only). A residual `FontWeight.w600` persists on
      both screens via **10** pre-existing hardcoded overrides outside
      `AppTextStyles` (not introduced by this phase, not fixable without
      touching widget/feature files outside Phase 0's scope) — full list and
      phase assignment under Phase 1 and Phase 5 below.
- [x] This plan doc checked off through Phase 0, "Next step" line updated to
      point at Phase 1.

**Additional notes from Phase 0's implementation and review (kept here as
durable context, not pruned — later phases depend on these):**
- `AppColors.accent` ships **unused** in `lib/` at the end of Phase 0 (no
  consumer until Phase 1). This is a deliberate, time-boxed exception to
  `AGENTS.md`'s "no unused symbols" absolute rule, consumed by Phase 1 —
  same shape as the existing `EditInstructionsDao` exception, not an
  indefinite one. Flagged explicitly rather than silently merged.
- WCAG AA contrast on `#EB0000` was verified (see decision #1 above): fine
  for non-text/UI use (3:1), fails text-contrast (4.5:1) on every ground but
  pure-white light `surface`. **Phase 1 must resolve this** before using
  `colors.accent` as text colour (FilterPill/SegmentedControl selected
  labels) — see decision #1's update for detail.

---

## Phase 1 — Shared widgets

**Status:** planning complete, concrete tasks below, not yet started.
Executed as one branch/PR; tasks are ordered by dependency (Task 0 first,
everything else consumes its `accentText` token or is independent of it).
Per `AGENTS.md`, run `tool/check.sh` after every task, not just at the end.

**Golden-regen command — unresolved gap, verify in Task 0:** no command is
recorded anywhere in this repo (`AGENTS.md`, `docs/gotchas.md`,
`tool/check.sh`, no CI config, no `alchemist.yaml` all checked, none found).
The candidate, guessed from `alchemist` 0.14.0's convention seen elsewhere,
was `UPDATE_GOLDENS=true flutter test test/widgets/design_goldens_test.dart`
(goldens live at `test/widgets/goldens/ci/`) — **this turned out to be
wrong**; the real invocation, confirmed in Task 0 and now recorded in
`docs/gotchas.md`, is the standard Flutter flag: `flutter test
test/widgets/design_goldens_test.dart --update-goldens`. **Task 0 must
confirm this actually regenerates a golden before the rest of the phase
relies on it**, then record it in `docs/gotchas.md` per `AGENTS.md`'s
"maintain the docs" rule — this closes a
gap Phase 0 could not close (its changes were invisible to these Ahem-font
CI goldens; Phase 1's colour changes will not be).

---

### Task 0 — `accentText` token + contrast lock

**Files:**
- Modify: `lib/core/theme/app_colors.dart:53-142` — add `accentText` field
  (required in constructor, `copyWith`, `lerp`, alongside `accent`):

  ```dart
  /// Text-safe variant of [accent] — same red, but chosen so it clears WCAG
  /// AA's 4.5:1 text-contrast threshold against the specific ground each
  /// consumer paints it on (`scheme.surface`: FilterPill and
  /// SegmentedControl's selected label). [accent] itself only clears 3:1
  /// (non-text/UI-component contrast) on some grounds — use [accentText],
  /// never [accent], whenever this red becomes the colour of *text*.
  final Color accentText;
  ```

  Add to `.light` (`Color(0xFFEB0000)` — same literal as `accent`) and
  `.dark` (`Color(0xFFFF3B30)`).
- Test: `test/core/theme/app_colors_test.dart` (create if it doesn't exist —
  check first; Phase 0 added a unit test locking `accent` equality across
  themes, likely in this same file).

**Steps:**
1. Write the failing contrast test. `Color.computeLuminance()` already
   implements the exact WCAG relative-luminance formula, so no hand-rolled
   math is needed:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:flutter_test/flutter_test.dart';
   import 'package:sologallery/core/theme/app_colors.dart';
   import 'package:sologallery/core/theme/app_theme.dart';

   double _contrastRatio(Color a, Color b) {
     final lA = a.computeLuminance();
     final lB = b.computeLuminance();
     final lighter = lA > lB ? lA : lB;
     final darker = lA > lB ? lB : lA;
     return (lighter + 0.05) / (darker + 0.05);
   }

   void main() {
     test('accentText clears 4.5:1 against scheme.surface in both themes', () {
       // Light scheme.surface is pure white; dark is #1C1C1A — see
       // app_theme.dart:22,30. FilterPill and SegmentedControl (Phase 1)
       // both paint accentText as text directly on scheme.surface.
       expect(
         _contrastRatio(AppColors.light.accentText, const Color(0xFFFFFFFF)),
         greaterThanOrEqualTo(4.5),
       );
       expect(
         _contrastRatio(AppColors.dark.accentText, const Color(0xFF1C1C1A)),
         greaterThanOrEqualTo(4.5),
       );
     });

     test('accent and accentText are both defined and equal across themes '
         'for accent (non-text)', () {
       expect(AppColors.light.accent, AppColors.dark.accent);
     });
   }
   ```

2. Run: `flutter test test/core/theme/app_colors_test.dart` — expect FAIL
   (`accentText` getter doesn't exist yet).
3. Add the `accentText` field and the two literals above.
4. Run the same test again — expect PASS. If it fails on the dark-theme
   assertion (e.g. a reviewer nudges the literal), the fix is to darken/
   brighten `Color(0xFFFF3B30)` until the ratio clears 4.5 — do not weaken
   the test.
5. Confirm the golden-regen command: run `flutter test
   test/widgets/design_goldens_test.dart --update-goldens` with **no other
   changes staged**, then `git status` — if no golden PNGs under
   `test/widgets/goldens/ci/` changed, the command is a no-op and the real
   mechanism needs finding (check the `alchemist` package source under
   `~/.pub-cache/hosted/pub.dev/alchemist-0.14.0/` for its actual env var/API
   name). **Confirmed:** the standard Flutter `--update-goldens` flag is the
   real mechanism, not an `UPDATE_GOLDENS` env var — recorded in
   `docs/gotchas.md`.
6. `flutter analyze` — zero warnings.
7. Commit: `git add lib/core/theme/app_colors.dart test/core/theme/app_colors_test.dart && git commit -m "feat: add accentText token for WCAG-safe accent-as-text"`.

---

### Task 1 — `FilterPill` selected state

**File:** `lib/widgets/filter_pill.dart` (60 lines, full file read during
planning).

**Change** (`build`, currently lines 32-59):
- `color: selected ? colors.pillActiveBg : colors.surface2` (line 36) →
  `selected ? Colors.transparent : colors.surface2`.
- `side: BorderSide(color: selected ? colors.border.withAlpha(0) : colors.border)`
  (line 39) → `selected ? colors.accent : colors.border` — selected now needs
  a *visible* stroke, so the `withAlpha(0)` transparent-border trick goes
  away entirely for the selected branch.
- `style: styles.filterPill.copyWith(color: selected ? colors.pillActiveText : colors.textSecondary)`
  (lines 52-54) →
  `styles.filterPill.copyWith(color: selected ? colors.accentText : colors.textSecondary, fontWeight: selected ? FontWeight.w700 : null)`
  — the weight override is per-call because the shared `filterPill` role
  itself stayed flat `w400` in Phase 0 (see the role's own doc comment,
  `app_text_styles.dart:33`, which already anticipates this: "the *selected*
  look now comes from colour + a per-call weight override in `FilterPill`").
- Update the class doc comment (lines 6-9): replace "Active inverts to the
  ink fill (`pillActiveBg`)" with something like "Active shows a transparent
  fill with an accent border and label — the ink fill is gone; state now
  reads through colour, not inversion."

**Tests:**
- `test/widgets/design_goldens_test.dart:174-186` — existing `'FilterPill —
  selected and unselected'` golden already covers both states side by side;
  regenerate with the Task 0-confirmed command and review the diff (selected
  pill should now show transparent fill + red border + red bold text,
  unselected unchanged).
- Add a plain (non-golden) widget test asserting the selected `Text` widget's
  resolved `TextStyle.color == colors.accentText` and `.fontWeight ==
  FontWeight.w700` — the golden alone can't distinguish "red because
  `accentText`" from "red because someone typo'd a hex," same rationale
  Phase 3 already uses for its three-state test.

**Commit:** `git add lib/widgets/filter_pill.dart test/widgets/design_goldens_test.dart <new test file> && git commit -m "feat: recolor FilterPill selected state to accent"`.

---

### Task 2 — `SegmentedControl` selected label

**File:** `lib/widgets/segmented_control.dart` (115 lines, full file read
during planning). Per decision #3's reversal: **the thumb stays**, only the
label recolors.

**Change** (`build`, lines 93-101):
```dart
style: styles.button.copyWith(
  color: index == selectedIndex
      ? colors.accentText   // was: scheme.onSurface
      : colors.textSecondary,
),
```
No shape change, no weight override (`styles.button` is already `w700`), no
`Stack`/`Positioned` restructuring — this is a one-line colour swap.

**Tests:**
- `test/widgets/design_goldens_test.dart:203-208` — existing `'ThemeModePicker
  — system selected'` golden (the only `SegmentedControl` consumer with a
  golden) — regenerate, review (thumb unchanged, selected label now red).
- Widget test asserting the selected label's resolved colour is
  `colors.accentText` (same rationale as Task 1).

**Commit:** `git add lib/widgets/segmented_control.dart test/widgets/design_goldens_test.dart <new test file> && git commit -m "feat: recolor SegmentedControl selected label to accentText"`.

---

### Task 3 — `ConsentSwitch` active track

**File:** `lib/widgets/consent_switch.dart` (38 lines, full file read during
planning).

**Change** (line 31): `activeTrackColor: colors.pillActiveBg` →
`colors.accent`. Leave `activeThumbColor: colors.pillActiveText` (line 30)
and everything else unchanged — script-verified contrast of `pillActiveText`
against `accent` is ≥4:1 in both themes (thumb-vs-track is a non-text UI
pairing, 3:1 threshold), so no new token is needed here, just confirm via
the test below rather than trust the arithmetic blind.

**Tests:**
- `test/widgets/design_goldens_test.dart:213-225` — existing `'ConsentSwitch
  — on and off'` golden — regenerate, review (on-state track now red).
- Add a widget test asserting `activeTrackColor` resolves to `colors.accent`
  for both the `value: true` light and dark cases (a `Switch`'s
  `activeTrackColor` is a plain `Color?`, not a `WidgetStateProperty`, so this
  is a direct property read, no `resolve()` needed).

**Commit:** `git add lib/widgets/consent_switch.dart test/widgets/design_goldens_test.dart <new test file> && git commit -m "feat: recolor ConsentSwitch active track to accent"`.

---

### Task 4 — `NavPillBar` knob

**File:** `lib/widgets/nav_pill_bar.dart` (191 lines, full file read during
planning).

**Change:**
- Knob (`build`, lines 87-94): `color: colors.pillActiveText` →
  `colors.accent`.
- Selected glyph colour (the `_NavItem` constructed in the `Row` at lines
  96-109): `activeColor: colors.pillActiveBg` (line 104) → `Colors.white`.
  **Decision:** hardcode white rather than reuse a theme-flipped token.
  Before this change, `pillActiveBg` deliberately flipped per theme so the
  selected glyph always matched the *capsule's* ink colour (an inverted-
  cutout effect against a knob that was itself `pillActiveText`, also theme-
  flipped). Now the knob is `colors.accent` — identical in both themes — so
  the glyph on it should be too, rather than reintroducing a theme-dependent
  swap against a theme-independent ground. Script-verified: `Colors.white`
  against `accent` (`#EB0000`, L≈0.177) is ≈4.6:1, clears 3:1 (icon/non-text)
  comfortably in both themes (this only needs to beat 3:1, not 4.5:1 — icons
  are graphical objects under WCAG 1.4.11, not text).
- `inactiveColor` (line 105-106, `colors.pillActiveText.withValues(alpha:
  _inactiveOpacity)`) is unchanged — only the *selected* glyph and the knob
  move.

**Tests:**
- `test/widgets/design_goldens_test.dart:197-201` — existing `'NavPillBar —
  Search selected'` golden — regenerate, review (knob red, selected glyph
  white in both themes now, versus previously flipping ink colour).
- Widget test asserting the selected `Icon`'s resolved `color ==
  Colors.white` and the knob `Container`'s `BoxDecoration.color ==
  colors.accent`.

**Commit:** `git add lib/widgets/nav_pill_bar.dart test/widgets/design_goldens_test.dart <new test file> && git commit -m "feat: recolor NavPillBar knob to accent"`.

---

### Task 5 — `IndexingDial` ring + residual weight

**File:** `lib/widgets/indexing_dial.dart` (141 lines, full file read during
planning). Two independent changes landing together per the original plan's
note (same file, same review pass):

- Ring colour (`_Dial.build`, line 90): `color: colors.pillActiveText` →
  `colors.accent`, passed into `IndexingRingPainter`. Only while indexing is
  active — the widget already returns `const SizedBox.shrink()` when idle
  (`IndexingDial.build`, line 54), so there's no "resting red" state to
  guard against separately. Disc background (line 84, `colors.pillActiveBg`)
  and the remaining-count text colour (line 99, `colors.pillActiveText`) are
  unchanged — script-verified the red ring clears 3:1 against the disc
  background in both themes (≈3.65:1 light, ≈4.0:1 dark).
- Residual weight (line 100, **not line 126 as originally scoped** — verified
  against the live file during planning): `fontWeight: FontWeight.w600` →
  `FontWeight.w700`. Rationale for 600→700 rather than dropping the override
  entirely: this is a small numeric readout against a busy disc background,
  where the emphasis was clearly intentional (matches the "residual weight
  cleanup" rationale applied identically to Task 6's five files below) —
  collapsing to the design system's one bold value (`700`) rather than
  erasing the emphasis keeps it inside the two-weight system Phase 0
  established, rather than leaving a third, unsanctioned weight in place.

**Tests:**
- `test/widgets/design_goldens_test.dart:564-577` — existing `'IndexingDial —
  a pass three quarters done'` golden — regenerate, review (ring red instead
  of ink-coloured, count text weight visually unchanged since these CI
  goldens can't show weight — see the standing Ahem-font caveat).
- Widget test reading `IndexingRingPainter.color` (already public per its own
  doc comment, "so a widget test can read the fraction") — assert it equals
  `colors.accent` when the dial is built with an active `IndexingStatus`.

**Commit:** `git add lib/widgets/indexing_dial.dart test/widgets/design_goldens_test.dart <new test file> && git commit -m "feat: recolor IndexingDial ring to accent, fix residual weight"`.

---

### Task 6 — Residual `FontWeight.w600` cleanup (shared-widget half)

Five files hardcode `FontWeight.w600` bypassing `AppTextStyles` entirely —
a third weight the two-weight system (400/700) was supposed to eliminate.
Same rationale as Task 5's `indexing_dial.dart` line: each of these is
clearly emphasis-bearing text (a title, a name, a CTA, a duration overlay),
so the fix is `w600` → `w700` in place, not dropping the override. The
remaining 4 files with the same finding are feature-screen code, assigned to
Phase 5.

| File | Line | Context |
|---|---|---|
| `lib/widgets/asset_thumbnail.dart` | 126 | `DurationBadge`'s "▶ m:ss" label — inline `const TextStyle`, not an `AppTextStyles` role (it hardcodes its own contrast since it overlays media) |
| `lib/widgets/empty_state.dart` | 56 | `EmptyState` title, `styles.body.copyWith(...)` |
| `lib/widgets/limited_access_banner.dart` | 45 | "Select more" CTA `TextButton.textStyle`, `text.filterPill.copyWith(...)` |
| `lib/widgets/folder_list.dart` | 116 | Folder-name label inside `_FolderChip`, `styles.body.copyWith(...)` |
| `lib/widgets/people_strip.dart` | 186 | Person-name caption inside `_PersonTile`, `styles.caption.copyWith(...)` |

**Change:** in each, replace `FontWeight.w600` with `FontWeight.w700`
in-place (a one-line diff per file; the surrounding `.copyWith(...)` and
`color:` arguments are untouched).

**Tests:**
- `asset_thumbnail.dart` — golden exists: `test/widgets/design_goldens_test.dart:80-94`,
  `'DurationBadge — short and long clips'` (`duration_badge` PNG) —
  regenerate, review (weight invisible in CI goldens per the standing
  caveat, so this is really validated by the code-level `FontWeight.w700`
  read, same as Phase 0).
- `empty_state.dart` — golden exists: lines 400-420, `'EmptyState — title
  with detail and CTA, and note'` — regenerate, review.
- `limited_access_banner.dart` — golden exists: lines 188-192,
  `'LimitedAccessBanner'` — regenerate, review.
- `people_strip.dart` — golden exists: lines 584-628, `'PeopleStrip — carded
  row of circular faces, one named'` — regenerate, review.
- `folder_list.dart` — **no existing golden** (pre-existing gap, not
  introduced by this task) — add a plain widget test asserting the
  folder-name `Text`'s resolved `fontWeight == FontWeight.w700`. Adding a
  full `alchemist` golden for `FolderList` is out of scope here (a layout
  golden, not a weight-only fix) — flag it as a follow-up if a reviewer wants
  one.
- For the four files with existing goldens, also add a plain widget test per
  file asserting the specific `Text`'s resolved `fontWeight ==
  FontWeight.w700` — same "golden can't show weight" rationale as above,
  applied consistently.

**Commit:** one commit for all five, or one per file — reviewer's call, but
if bundled: `git commit -m "fix: collapse residual FontWeight.w600 to w700 (shared widgets)"`.

---

### Task 7 — Golden regeneration pass + on-device verification

Run once, after Tasks 0-6 land, not per-task, so the golden diff review
happens against the full accumulated change rather than six separate noisy
diffs:

1. `flutter test test/widgets/design_goldens_test.dart --update-goldens`
   (Task 0 will have already confirmed this is the right command/flag).
2. `git diff --stat test/widgets/goldens/ci/` — expect exactly: `filter_pill.png`,
   `theme_mode_picker.png`, `nav_pill_bar.png`, `indexing_dial.png`,
   `consent_switch.png`, `duration_badge.png`, `empty_state.png`,
   `limited_access_banner.png`, `people_strip.png` changed. Anything else
   changing is a regression to investigate before committing. **Known-good
   exception found during the final whole-branch review:** `segmented_control.png`
   is *also* a legitimate change here — there's a distinct `SegmentedControl`
   golden scenario in `design_goldens_test.dart` (separate from
   `ThemeModePicker`, which consumes the same widget but isn't the same
   golden) that this original enumeration missed. Don't treat it as a
   regression.
3. Open each changed PNG and review manually, screen by screen — per Phase
   0's Definition of Done, don't blindly accept a wall of diffs.
4. `tool/check.sh` — must pass clean (analyze + build_runner + all tests).
5. On-device pass (Pixel 9 Pro XL, per `AGENTS.md` environment): tap through
   all four `NavPillBar` destinations (knob should show solid red, white
   glyph, both themes), toggle a Search facet pill (instant, non-animated red
   border+text swap — this is exactly the "fake-pairing" rule's territory,
   per Phase 0's carried-forward note), flip a `ConsentSwitch` in Settings,
   open Settings' `ThemeModePicker` and switch modes, and — if a library scan
   is running or can be triggered — confirm the `IndexingDial` ring reads red
   while active.
6. Commit the regenerated goldens: `git add test/widgets/goldens/ci/ && git commit -m "test: regenerate goldens for Phase 1 accent rollout"`.

**Definition of Done for this phase:**
- [x] `tool/check.sh` passes.
- [x] Every regenerated golden diff reviewed manually (Task 7, step 3) —
      including the fix-wave regeneration triggered by darkening
      `accentText.light` to `#D80000` (`filter_pill.png`,
      `theme_mode_picker.png`, `segmented_control.png`, `consent_switch.png`;
      byte-size deltas were all small, no dimension changes, consistent with
      a colour-only repaint).
- [x] The golden-regen command confirmed and recorded in `docs/gotchas.md`
      (Task 0, step 5) — closes the gap Phase 0 could not close. Confirmed
      mechanism: `flutter test test/widgets/design_goldens_test.dart
      --update-goldens` (the standard Flutter flag, not an env var).
- [x] On-device pass complete (Task 7, step 5) — **done 2026-09-05**,
      Samsung SM-S938B (Android 16, API 36, `RZGYB1E58CV`). Automated half:
      `nav_shell_test.dart` (NavPillBar knob + IndexingDial, 5/5) and
      `consent_flow_test.dart` (Settings `ConsentSwitch` toggle, 5/5) both
      passed clean via `patrol test`. Visual half: the user confirmed by eye
      on the installed debug build — NavPillBar knob solid red with a white
      glyph across all 4 tabs, Search facet pill selected state shows a
      transparent fill with red border + bold red text, Settings consent
      switch track and theme-picker selected label both read red. Code-level
      trace also confirms every widget wires `colors.accent`/
      `colors.accentText` exactly per Tasks 1-5 above (`filter_pill.dart:37,50`,
      `segmented_control.dart:97`, `consent_switch.dart:35`,
      `nav_pill_bar.dart:91`, `indexing_dial.dart:90`) — nothing has changed
      here since Phase 1 landed.
- [x] `AppColors.accentText` and `AppColors.accent` both consumed in `lib/` —
      the Phase 0 "unused symbol" exception is now moot, nothing further to
      do (the exception lived in this plan doc, not as literal text in
      `AGENTS.md`).
- [x] This plan doc checked off through Phase 1, "Next step" line updated to
      point at Phase 2.

---

## Phase 2 — `ExifSheet` rebuild

**Status:** planning complete, concrete tasks below, not yet started.
**Files:** `lib/features/detail/widgets/exif_sheet.dart` (111 lines, full file
read during planning) · `test/features/detail/widgets/exif_sheet_test.dart`
(existing behavioural test, extended, not replaced) ·
`test/features/detail/detail_goldens_test.dart` (existing golden, extended).
Per `AGENTS.md`, run `tool/check.sh` after every task.

**Favourite-mark feasibility, resolved during planning:** trivially
available — `ExifSheet` is already a `ConsumerWidget` and already imports
`../detail_providers.dart` (for `assetDetailProvider`), which also declares
`isFavoriteProvider` (`StreamProvider.autoDispose.family<bool, String>`,
`detail_providers.dart:62`). No new prop needed: `ExifSheet.build` can watch
`isFavoriteProvider(assetId)` directly, the same provider
`PhotoDetailScreen`'s bottom-chrome `Consumer` already watches
(`detail_screen.dart:179-180`). **This phase is not dropping the favourite
mark.**

**Test-scaffolding gotcha found during planning, resolved differently during
execution:** neither `exif_sheet_test.dart` nor `detail_goldens_test.dart`
overrode `databaseProvider` before this phase — fine, since `ExifSheet` never
touched the database. The moment it watches `isFavoriteProvider`, it
transitively reads `favoritesDaoProvider` → `databaseProvider`, whose default
(`database_provider.dart:16-20`) opens a **real** `driftDatabase(name:
'sologallery')` (`app_database.dart:190-192`, `drift_flutter`,
platform-channel file paths) — not safe to touch unmocked in a host
`flutter_test`; confirmed during execution as a `MissingPluginException` on
`getTemporaryDirectory` when a goldenTest scenario was left unoverridden.

The plan's original draft (below, in Task 1) copied
`detail_screen_test.dart`'s fix for the same provider chain — override
`databaseProvider` with `AppDatabase(NativeDatabase.memory())`. That works for
`PhotoDetailScreen` (whose favorite state is a real, mutable, ongoing concern
across its tests) but turned out to be the wrong tool here: a real Drift
`watch()` stream doesn't complete on its own, so every `ExifSheet` test needed
`detail_screen_test.dart`'s `settleTeardown` dance (unmount the tree, pump a
extra frame) to avoid `flutter_test`'s end-of-test "Timer is still pending"
invariant — and that invariant check runs *before* any `tearDown`/
`addTearDown` hook, so it can't be hoisted into a shared helper; it has to be
the last line of every test body. Worse, `goldenTest` scenarios don't expose
a hook to run that cleanup at all, so the golden file hit the
`MissingPluginException` above.

**What actually shipped instead:** override `isFavoriteProvider('x')`
directly with `Stream.value(bool)` — a single-emission stream, not a live
query, so it completes and disposes with nothing left pending. No
`databaseProvider`, no `AppDatabase`, no Drift import, no `settleTeardown`, in
either test file. This is simpler than the plan's original approach, not just
a workaround for the goldenTest limitation — `ExifSheet`'s rendering doesn't
care *how* favorite state gets resolved, only that it does, so exercising it
through the narrowest provider in the chain (`isFavoriteProvider`, not
`databaseProvider`) is the more precise test double regardless. Task 1/2/3
below are updated to reflect this.

**Layout decisions this plan is making:**
- **Row shape:** one `Row` per field — `SizedBox(width: _labelColumnWidth)`
  (label, `exifKey` role, `colors.textMuted`, unchanged from today) then
  `AppSpace.s16` gap then `Expanded` (value, `exifValue` role,
  `scheme.onSurface`, unchanged from today), `crossAxisAlignment:
  CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic`. This
  swaps the chip's current *stacked* key-over-value for a *side-by-side*
  key-then-value — that's what "two-column table" means here, not just a
  narrower `Wrap`.
- **`_labelColumnWidth`:** no existing precedent for a fixed label-column
  width anywhere in `lib/`, so this is a new widget-local constant, not an
  `AppSpace` token (same category as `app_sheet.dart`'s raw `36`/`18`/`10`
  grab-handle literals — a component dimension, not a spacing-rhythm value).
  Start at `88.0` (comfortably fits `exifKey`'s 9sp/uppercase/0.72-tracking
  style for the longest real label, `DIMENSIONS`/`RESOLUTION`) and tune from
  the Task 3 golden review if anything clips.
- **Row dividers:** `Divider(height: 1, color: colors.border)` between rows
  only (`if (i > 0)`), matching the existing convention in `app_card.dart:50`
  and `add_to_album_sheet.dart:76` — none above the first row, none below the
  last.
- **Long-value handling:** wrap, don't truncate. A fixed-width table can't
  reflow horizontally like the old `Wrap` did, but nothing in `PRD.md`
  licenses silently dropping EXIF data — so the value `Text` gets no
  `maxLines`/`overflow: ellipsis`, and the row's height is allowed to grow.
  Task 2/3 verify this doesn't produce a `RenderFlex` overflow, not that it
  fits on one line.
- **Favourite mark:** shown only when `isFavoriteProvider(assetId)` resolves
  true (mirrors `IndexingDial`'s "only exists while active" pattern from
  Phase 1) — a `Row` of a 16px `Icons.favorite_rounded` in `colors.accent`
  plus a `Text('Favorited', style: styles.caption.copyWith(color:
  colors.textSecondary))`, placed above the table with an `AppSpace.s16` gap
  below it. **Spelling:** "Favorited" (US), matching
  `DetailActionBar`'s existing label exactly (`detail_action_bar.dart:57`),
  not the session brief's British "Favourited" — this codebase is
  consistently US-spelled. **Colour placement:** only the heart glyph gets
  `colors.accent` — the label text stays `colors.textSecondary` (no
  `accentText` needed, since text colour isn't the state cue here; filled-vs-
  outline shape is, per the Accent-usage table's own row for this widget).
  This also sidesteps a fourth `accentText`-contrast case entirely.

---

### Task 0 — `_ExifTable`/`_ExifRow` layout rebuild

**File:** `lib/features/detail/widgets/exif_sheet.dart`. Replace
`_Chips`/`_ExifChip` (lines 54-110) with `_ExifTable`/`_ExifRow` per the
layout decisions above. Same field list/order/conditionals as today's
`_Chips.build` (lines 60-78) — this task changes layout only, not which
fields render or their formatted values.

```dart
class _ExifTable extends StatelessWidget {
  const _ExifTable({required this.detail});
  final AssetDetail detail;

  static const _labelColumnWidth = 88.0;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Taken', formatTakenDate(detail.createdAt)),
      ('Dimensions', formatDimensions(detail.width, detail.height)),
      ('Resolution', formatMegapixels(detail.width, detail.height)),
      if (formatDuration(detail.videoDuration) case final v?) ('Duration', v),
      if (formatFileSize(detail.sizeBytes) case final v?) ('Size', v),
      if (formatType(detail.mimeType) case final v?) ('Type', v),
      if (formatCoordinates(detail.latitude, detail.longitude) case final v?)
        ('Location', v),
    ];
    final colors = Theme.of(context).extension<AppColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: colors.border),
          _ExifRow(label: rows[i].$1, value: rows[i].$2),
        ],
      ],
    );
  }
}

class _ExifRow extends StatelessWidget {
  const _ExifRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: _ExifTable._labelColumnWidth,
            child: Text(
              label.toUpperCase(),
              style: text.exifKey.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Text(
              value,
              style: text.exifValue.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
```

Update `ExifSheet.build`'s data branch (lines 38-48) to build `_ExifTable`
instead of `_Chips` (identical call shape, just the type name changes) and
the class doc comment (lines 20-22, currently "design-system EXIF chips
(uppercase key over a heavier value)") to describe the table instead of the
chip cloud.

**Steps:**
1. Run `flutter test test/features/detail/widgets/exif_sheet_test.dart
   test/features/detail/detail_goldens_test.dart` first — confirm both pass
   on the current `Wrap`-based code (baseline before touching anything).
2. Make the change above.
3. Run the same two test files again — expect the behavioural test
   (`exif_sheet_test.dart`) to **still pass unchanged** (it asserts on
   rendered text content, not layout, and the field list/values didn't
   change). Expect the golden (`detail_goldens_test.dart`) to still *run*
   (it doesn't auto-fail on a visual diff unless goldens are already
   committed and mismatched — regeneration is Task 3).
4. `flutter analyze` — zero warnings, confirms no unused `_Chips`/`_ExifChip`
   left behind.
5. Commit: `git add lib/features/detail/widgets/exif_sheet.dart && git commit -m "feat: rebuild ExifSheet as a two-column table"`.

---

### Task 1 — Test scaffolding: direct `isFavoriteProvider` overrides

**As executed** (superseding the original `databaseProvider`/in-memory-Drift
draft — see the gotcha note above): no scaffolding commit of its own. Task 2
adds `isFavoriteProvider('x').overrideWith((ref) => Stream.value(bool))`
inline, alongside the existing `assetDetailProvider('x').overrideWith(...)`,
in both `exif_sheet_test.dart`'s `pumpSheet` helper and each ExifSheet-related
`goldenTest` in `detail_goldens_test.dart`. No new imports, no `setUp`/
`tearDown`, no shared `db` variable — folded directly into Task 2 below since
it's a one-line addition per call site, not a separable diff.

---

### Task 2 — Favourite-state mark

**File:** `lib/features/detail/widgets/exif_sheet.dart`.

**Steps (TDD — failing test first):**
1. In `exif_sheet_test.dart`, give `pumpSheet` an `isFavorite` parameter and
   override `isFavoriteProvider` with it:
   ```dart
   Future<void> pumpSheet(
     WidgetTester tester,
     AssetDetail? detail, {
     bool isFavorite = false,
   }) async {
     await tester.pumpWidget(
       ProviderScope(
         overrides: [
           assetDetailProvider('x').overrideWith((ref) => detail),
           // A single-emission stream, not a live query — no favoritesDao/
           // Drift needed to test this widget's rendering, and nothing to
           // cancel at teardown (unlike a real watchIsFavorite() stream).
           isFavoriteProvider('x').overrideWith((ref) => Stream.value(isFavorite)),
         ],
         child: MaterialApp(
           theme: AppTheme.light,
           home: const Scaffold(body: ExifSheet(assetId: 'x')),
         ),
       ),
     );
     await tester.pumpAndSettle();
   }
   ```
   then add the two new tests:
   ```dart
   testWidgets('favorited asset shows the Favorited mark', (tester) async {
     await pumpSheet(tester, fullRecord(), isFavorite: true);

     expect(find.text('Favorited'), findsOneWidget);
     expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
   });

   testWidgets('unfavorited asset shows no mark', (tester) async {
     await pumpSheet(tester, fullRecord());

     expect(find.text('Favorited'), findsNothing);
     expect(find.byIcon(Icons.favorite_rounded), findsNothing);
   });
   ```
2. Run: `flutter test test/features/detail/widgets/exif_sheet_test.dart` —
   expect the two new tests to FAIL (no such text/icon rendered yet), the
   three pre-existing ones to keep passing.
3. Implement in `exif_sheet.dart`:
   ```dart
   // In ExifSheet.build, alongside the existing `final detail = ...`:
   // Synchronously-composed flag — see AGENTS.md's Riverpod conventions.
   final isFavorite = ref.watch(isFavoriteProvider(assetId)).value ?? false;
   ```
   and in the data branch, wrap `_ExifTable` with the mark:
   ```dart
   data: (d) => d == null
       ? const AppSheetNote('Details aren\'t available for this photo.')
       : Padding(
           padding: const EdgeInsets.fromLTRB(
             AppSpace.s20, AppSpace.s8, AppSpace.s20, AppSpace.s24,
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               if (isFavorite) ...[
                 const _FavoriteMark(),
                 const SizedBox(height: AppSpace.s16),
               ],
               _ExifTable(detail: d),
             ],
           ),
         ),
   ```
   ```dart
   class _FavoriteMark extends StatelessWidget {
     const _FavoriteMark();

     @override
     Widget build(BuildContext context) {
       final colors = Theme.of(context).extension<AppColors>()!;
       final styles = Theme.of(context).extension<AppTextStyles>()!;
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           Icon(Icons.favorite_rounded, color: colors.accent, size: 16),
           const SizedBox(width: AppSpace.s8),
           Text(
             'Favorited',
             style: styles.caption.copyWith(color: colors.textSecondary),
           ),
         ],
       );
     }
   }
   ```
4. Run the same test again — expect PASS, all five.
5. `flutter analyze` — zero warnings.
6. Commit: `git add lib/features/detail/widgets/exif_sheet.dart test/features/detail/widgets/exif_sheet_test.dart && git commit -m "feat: show a Favorited mark in ExifSheet when the photo is favorited"`.

---

### Task 3 — Golden + overflow-safety test coverage

**Files:**
- Modify: `test/features/detail/detail_goldens_test.dart` — the existing
  `'ExifSheet — populated metadata'` golden also needs
  `isFavoriteProvider('x').overrideWith((ref) => Stream.value(false))` added
  to its `overrides` (it now reaches the real, unmocked provider chain the
  same as any other `ExifSheet` instance — see the gotcha note above), plus
  two new `goldenTest` blocks with the same override.
- Modify: `test/features/detail/widgets/exif_sheet_test.dart` — add the
  overflow-safety assertion (a golden PNG alone can't assert "no
  `RenderFlex` overflow exception was thrown").

**Steps:**
1. Add `isFavoriteProvider('x').overrideWith((ref) => Stream.value(false))`
   to the existing `'ExifSheet — populated metadata'` golden's overrides.
2. Add the no-EXIF golden (mirrors `exif_sheet_test.dart`'s `emptyRecord()`
   shape — PRD.md §3.3 "assets with no EXIF render correctly"):
   ```dart
   goldenTest(
     'ExifSheet — no EXIF data',
     fileName: 'exif_sheet_no_exif',
     builder: () => themedGroup(
       (_) => ProviderScope(
         overrides: [
           isFavoriteProvider('x').overrideWith((ref) => Stream.value(false)),
           assetDetailProvider('x').overrideWith((ref) => AssetDetail(
                 id: 'x',
                 width: 800,
                 height: 600,
                 createdAt: DateTime(2026, 3, 1, 9, 5),
                 orientationDegrees: 0,
                 isVideo: false,
               )),
         ],
         child: const ExifSheet(assetId: 'x'),
       ),
     ),
   );
   ```
3. Add the long-location golden. `formatCoordinates` always formats to four
   decimal places (`asset_detail_display.dart:59-61`), so realistic GPS
   values can't produce a long string — feed a deliberately out-of-range
   pair purely to stress the fixed-width value column, same technique the
   "long location string" requirement calls for (checking the table's
   robustness to length, not simulating real device data):
   ```dart
   goldenTest(
     'ExifSheet — long location value',
     fileName: 'exif_sheet_long_location',
     builder: () => themedGroup(
       (_) => ProviderScope(
         overrides: [
           isFavoriteProvider('x').overrideWith((ref) => Stream.value(false)),
           assetDetailProvider('x').overrideWith((ref) => AssetDetail(
                 id: 'x',
                 width: 6048,
                 height: 8064,
                 createdAt: DateTime(2026, 7, 12, 14, 33),
                 orientationDegrees: 0,
                 isVideo: false,
                 // Deliberately out-of-range magnitude — stresses the fixed
                 // value column's wrap behaviour; not a real coordinate.
                 latitude: 123456789.1234,
                 longitude: -987654321.5678,
               )),
         ],
         child: const ExifSheet(assetId: 'x'),
       ),
     ),
   );
   ```
4. In `exif_sheet_test.dart`, add the overflow-safety test using the same
   out-of-range values:
   ```dart
   testWidgets('a very long location value wraps without overflowing', (
     tester,
   ) async {
     await pumpSheet(
       tester,
       AssetDetail(
         id: 'x',
         width: 100,
         height: 100,
         createdAt: DateTime(2026, 1, 1),
         orientationDegrees: 0,
         isVideo: false,
         latitude: 123456789.1234,
         longitude: -987654321.5678,
       ),
     );

     expect(tester.takeException(), isNull);
   });
   ```
5. Confirm the golden-regen command (Phase 1 Task 0 already locked this in):
   `flutter test test/features/detail/detail_goldens_test.dart
   --update-goldens`. **Gotcha hit here on the first pass:** forgetting step 1
   (the override on the *existing* golden) surfaces as a `MissingPluginException`
   on `getTemporaryDirectory` "after the test had completed" — the real
   `AppDatabase()`/`driftDatabase` path from the gotcha note above, reachable
   because nothing overrode `isFavoriteProvider` for that scenario. All three
   `ExifSheet` goldens need the override, not just the two new ones.
6. `git diff --stat test/features/detail/goldens/ci/` — expect
   `exif_sheet.png` changed (new table layout, 402×360 → 736×360) and two new
   files, `exif_sheet_no_exif.png` and `exif_sheet_long_location.png`.
   Anything else changing is a regression to investigate.
7. Open all three PNGs (light + dark each) and review manually — check the
   label column doesn't clip `DIMENSIONS`/`RESOLUTION`, the long-location
   scenario doesn't produce a visible overflow indicator, and dividers sit
   flush between rows. **Result:** full record shows 6 rows (Taken/
   Dimensions/Resolution/Size/Type/Location), no-EXIF shows 3 (Taken/
   Dimensions/Resolution only), long-location shows 4 (adds Location) — all
   correct against each scenario's field set. These CI goldens render with
   Ahem + `obscureText: true` (the standing Phase 0 caveat), so they can't
   visually confirm real-font wrapping behaviour either way — that assurance
   comes from step 4's widget test instead, which passed on the first try
   with real fonts.
8. Run `flutter test test/features/detail/widgets/exif_sheet_test.dart
   test/features/detail/detail_goldens_test.dart` — expect all pass.
9. `tool/check.sh` — must pass clean.
10. Commit: `git add test/features/detail/widgets/exif_sheet_test.dart test/features/detail/detail_goldens_test.dart test/features/detail/goldens/ci/ && git commit -m "test: add ExifSheet golden and overflow coverage for the table rebuild"`.

---

### Task 4 — On-device verification

Per `AGENTS.md`'s Definition of Done (integration pass + manual end-to-end).
`integration_test/detail_actions_test.dart`'s first test already exercises
this exact path — favorite the photo, then open EXIF — so no new
integration test file is needed; Phase 2 rides the existing one instead of
duplicating it.

1. `PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
   ~/.pub-cache/bin/patrol test -t
   integration_test/detail_actions_test.dart -d 46121FDAS008AA` — confirm
   `'open a photo → favorite, view EXIF, add to album'` still passes (the
   sheet still opens, `'DETAILS'` still renders, and — since the photo was
   just favorited two lines above — this exercises the new `Favorited` mark
   on a real device for free).
2. On the connected device, open a photo known to have no EXIF (seed
   `test_assets/no_exif.jpg` if not already on the device — same fixture
   `exif_sheet_test.dart`'s docstring already references) and confirm the
   sheet renders the always-present fields only, no blank rows, no crash.
3. Open a photo known to have GPS (`test_assets/gps_exif.jpg`) and confirm
   the Location row renders and doesn't clip.
4. Note in this doc whether the label column width (`88.0`) needed
   adjustment from what device rendering showed, distinct from the desktop
   golden review.

**Attempted 2026-09-05 on the iPhone 17 simulator instead of the Pixel — did
not work, not a Phase 2 issue.** Booted the sim, seeded it with
`gps_exif.jpg`/`no_exif.jpg` via `xcrun simctl addmedia` and pre-granted
Photos access via `xcrun simctl privacy grant photos`, then `flutter build ios
--debug --simulator` succeeded — but `flutter run -d <sim-id>` failed both
before and after opening `Simulator.app`: "Unable to find a destination
matching the provided destination specifier". `xcodebuild -showdestinations`
confirms this is structural — the `Runner` scheme lists **zero** simulator
destinations at all, only the physical device and placeholders. This is the
same underlying limitation `docs/gotchas.md`'s "iOS: integration_test runs
only on a physical device" entry already recorded for `integration_test`
specifically (now confirmed to also block a plain `flutter run`); addendum
added there 2026-09-05 rather than duplicating it here. **User decision:**
skip the automated on-device pass rather than debug the Xcode scheme
configuration or switch to the physical iPhone — Task 4 stays outstanding,
same status as Phase 1's still-pending manual pass.

**Attempted again 2026-09-05 with a physical iPhone connected via cable
(`iPhone-F70C0WQ33M`, iOS 26.6.1) — still not done, two new (different)
environment blockers found, neither a Phase 2 code issue:**
1. A stray `flutter run -d <this-device>` process, left over from before this
   session's `/clear`, was still alive and holding the device's CoreDevice
   tunnel. It caused `flutter test integration_test/detail_actions_test.dart
   -d <id> --no-uninstall`'s device install step to hang **silently for 59
   minutes** with no error, until the stray process was found (`ps aux | grep
   devicectl`) and killed — see the new `docs/gotchas.md` entry. After that,
   the app actually installed and launched, but then:
2. `patrolTest`-based files **cannot run on iOS at all** via `flutter test
   integration_test/<file>.dart -d <id>`, confirmed with a precise error this
   time (not just "not wired"): `Failed assertion: '_debugInitializedType ==
   null': Binding is already initialized to IntegrationTestWidgetsFlutterBinding`.
   The `flutter test integration_test/*.dart` runner initializes
   `IntegrationTestWidgetsFlutterBinding` itself before `main()`, and
   `patrolTest`'s `PatrolBinding.ensureInitialized()` then fails because a
   binding singleton is already locked in. This is a hard conflict, not
   flakiness — it will reproduce every time. `detail_actions_test.dart` uses
   `patrolTest`, so **this specific test cannot run on iOS at all** until a
   `RunnerUITests` target is wired up (see `docs/gotchas.md`'s updated entry).
   A second attempt with a non-`patrolTest` file (`memories_test.dart`, which
   uses plain `IntegrationTestWidgetsFlutterBinding`) hit a *third*, unrelated
   blocker: the Dart VM Service was never discovered after the app launched
   (timed out at 619s), with Flutter's own hint that Xcode-automation
   (AppleEvents) permission may not be granted to the controlling
   process/terminal (System Settings → Privacy & Security → Automation) —
   not diagnosed further this session; needs the user to check/grant that
   permission before another attempt is worth making.

**Net finding:** on-device *automated* verification for this plan's
`patrolTest`-based files is not just "no device available" (the status since
Phase 1) — it is **structurally blocked on iOS** regardless of device
availability. A manual eyes-on pass (`flutter run -d <id>`, once the Xcode
automation permission is sorted) is the only path left for iOS; Android
(Pixel 9 Pro XL) remains untried this session (`adb devices` not rechecked).

**Definition of Done for this phase:**
- [x] `tool/check.sh` passes.
- [x] Every golden diff reviewed manually (Task 3, step 6).
- [x] `integration_test/detail_actions_test.dart` passes on-device (Task 4,
      step 1) — **done 2026-09-05** on Android (Samsung SM-S938B,
      `RZGYB1E58CV`, iOS's binding conflict doesn't apply here): 3/3 non-
      skipped cases passed via `patrol test`, including "open a photo →
      favorite, view EXIF, add to album" — the exact ExifSheet path (rebuilt
      table + favourite mark). The 2 skips (`share`, `delete`) are pre-
      existing (`skip: true` in the source, unrelated to this plan).
- [x] Manual no-EXIF and GPS device checks done (Task 4, steps 2-3) —
      **done 2026-09-05**. `no_exif.jpg`/`gps_exif.jpg` seeded into the
      Android device's real library (`test_assets/README.md`'s documented
      MediaStore procedure — `adb push` + `MEDIA_SCANNER_SCAN_FILE`, not a
      screenshot). User confirmed by eye on the installed debug build: the
      no-EXIF sheet renders the expected 3-row table with no overflow, the
      GPS sheet's `Location` row wraps cleanly. iOS remains structurally
      blocked per the note above; untried this session (no iOS device
      requested).
- [x] This plan doc checked off through Phase 2, "Next step" line updated to
      point at Phase 3.

---

## Phase 3 — Memories player third state

**Status:** planning complete, concrete tasks below, not yet started.
**File:** `lib/features/memories/widgets/progress.dart` (51 lines, full file
read during planning) · `test/features/memories/widgets/progress_test.dart`
(new — no existing test for this widget; confirmed via `find
test/features/memories -iname '*progress*'` returning nothing). Per
`AGENTS.md`, run `tool/check.sh` after the task.

**Architectural wrinkle — call this out in the diff/PR description, not just
here:** `AppOverMedia` (`lib/core/theme/app_colors.dart:14-47`) is
deliberately a `const`, theme-invariant class — its doc comment says so
explicitly ("media is the background, not the chrome... the values never
flip with brightness"). `colors.accent`, by contrast, is a `ThemeExtension`
value read via `Theme.of(context).extension<AppColors>()!` (same accessor
`IndexingDial` and `NavPillBar` already use for their Phase-1 accent
consumption). `progress.dart` today never touches `Theme.of(context)` at
all — it only reaches for the const `AppOverMedia` fields — so this task
is the first time this file mixes a theme-variant token into an otherwise
theme-invariant widget. Not a problem to solve, just a precedent worth a
reviewer's eyes: the "media supplies the color" rule still holds (the accent
segment is still small, still state-only, still on the theme-invariant
media background), it's just sourced from a different token family than its
neighbours in the same `Row`.

**Change** (`build`, currently lines 30-47):
```dart
final colors = Theme.of(context).extension<AppColors>()!;
return Positioned(
  top: MediaQuery.of(context).padding.top + 10,
  left: AppSpace.s16,
  right: AppSpace.s16,
  child: Opacity(
    opacity: paused ? 0.35 : 1,
    child: Row(
      children: [
        for (var i = 0; i < pages; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: i < index
                    ? AppOverMedia.glyph
                    : i == index
                        ? colors.accent
                        : AppOverMedia.segmentOff,
                borderRadius: const BorderRadius.all(Radius.circular(1)),
              ),
              child: SizedBox(height: i == index ? 3 : 2),
            ),
          ),
        ],
      ],
    ),
  ),
);
```
Three states, replacing today's binary `i <= index`: `i < index` (already
played) keeps `AppOverMedia.glyph`; `i == index` (currently playing) becomes
`colors.accent` **and** grows from height 2 to height 3 — the non-colour cue
the accent-usage table (this doc, "Accent usage" section) already commits
to for this row: *"also slightly taller than a played segment."* `i >
index` (not yet reached) is unchanged, `AppOverMedia.segmentOff`. No import
changes needed — `app_colors.dart` is already imported for `AppOverMedia`
and declares `AppColors` in the same file.

Update the class doc comment (lines 6-7, currently "one segment per page,
filled up to the current one") — that description is the binary behaviour
being replaced; reword to describe the three states (played / current /
upcoming) so the comment doesn't contradict the code the moment this lands.

---

### Task 0 — Three-state segment mapping

**Files:**
- Modify: `lib/features/memories/widgets/progress.dart`.
- Test: `test/features/memories/widgets/progress_test.dart` (create).

**Steps (TDD — failing test first):**
1. Write the test file. A golden can't distinguish "accent because this is
   the current segment" from "accent because of a typo'd hex" — same
   rationale Phase 1/2 already used for every colour-mapping test — so this
   asserts the resolved `BoxDecoration.color` and `SizedBox.height` directly,
   scoped to `Progress` so an unrelated `DecoratedBox`/`SizedBox` elsewhere in
   the tree (e.g. from `MaterialApp`/`Scaffold` chrome) can't be mistaken for
   a segment:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:flutter_test/flutter_test.dart';
   import 'package:sologallery/core/theme/app_colors.dart';
   import 'package:sologallery/core/theme/app_theme.dart';
   import 'package:sologallery/features/memories/widgets/progress.dart';

   void main() {
     Future<void> pump(
       WidgetTester tester, {
       required int pages,
       required int index,
       bool paused = false,
       ThemeData? theme,
     }) async {
       await tester.pumpWidget(
         MaterialApp(
           theme: theme ?? AppTheme.light,
           home: Scaffold(
             body: Stack(
               children: [
                 Progress(pages: pages, index: index, paused: paused),
               ],
             ),
           ),
         ),
       );
     }

     /// The `pages` segment boxes, in on-screen left-to-right order.
     List<DecoratedBox> segments(WidgetTester tester) => tester
         .widgetList<DecoratedBox>(
           find.descendant(
             of: find.byType(Progress),
             matching: find.byType(DecoratedBox),
           ),
         )
         .toList();

     Color colorOf(DecoratedBox box) => (box.decoration as BoxDecoration).color!;
     double heightOf(DecoratedBox box) => (box.child! as SizedBox).height!;

     testWidgets('played, current and upcoming segments map to three states',
         (tester) async {
       await pump(tester, pages: 4, index: 2);

       final colors = Theme.of(tester.element(find.byType(Progress)))
           .extension<AppColors>()!;
       final boxes = segments(tester);
       expect(boxes, hasLength(4));

       // i = 0, 1: played.
       expect(colorOf(boxes[0]), AppOverMedia.glyph);
       expect(heightOf(boxes[0]), 2);
       expect(colorOf(boxes[1]), AppOverMedia.glyph);
       expect(heightOf(boxes[1]), 2);

       // i = 2: current — accent colour, taller.
       expect(colorOf(boxes[2]), colors.accent);
       expect(heightOf(boxes[2]), 3);

       // i = 3: upcoming.
       expect(colorOf(boxes[3]), AppOverMedia.segmentOff);
       expect(heightOf(boxes[3]), 2);
     });

     testWidgets('the first page is current with no played segments yet',
         (tester) async {
       await pump(tester, pages: 3, index: 0);

       final colors = Theme.of(tester.element(find.byType(Progress)))
           .extension<AppColors>()!;
       final boxes = segments(tester);

       expect(colorOf(boxes[0]), colors.accent);
       expect(colorOf(boxes[1]), AppOverMedia.segmentOff);
       expect(colorOf(boxes[2]), AppOverMedia.segmentOff);
     });

     testWidgets('the last page is current with no upcoming segments left',
         (tester) async {
       await pump(tester, pages: 3, index: 2);

       final colors = Theme.of(tester.element(find.byType(Progress)))
           .extension<AppColors>()!;
       final boxes = segments(tester);

       expect(colorOf(boxes[0]), AppOverMedia.glyph);
       expect(colorOf(boxes[1]), AppOverMedia.glyph);
       expect(colorOf(boxes[2]), colors.accent);
     });

     testWidgets('the mapping is unaffected by the paused dim',
         (tester) async {
       // paused only changes the whole bar's Opacity — it must not change
       // which segment is "current" or its colour/height.
       await pump(tester, pages: 3, index: 1, paused: true);

       final colors = Theme.of(tester.element(find.byType(Progress)))
           .extension<AppColors>()!;

       expect(colorOf(segments(tester)[1]), colors.accent);
       expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.35);
     });

     testWidgets('reads in dark theme too', (tester) async {
       await pump(tester, pages: 3, index: 1, theme: AppTheme.dark);

       final colors = Theme.of(tester.element(find.byType(Progress)))
           .extension<AppColors>()!;
       expect(colorOf(segments(tester)[1]), colors.accent);
     });
   }
   ```

2. Run: `flutter test test/features/memories/widgets/progress_test.dart` —
   expect FAIL (today's code only has two states, so the `i == index`
   accent/height-3 assertions fail; the first test's `i < index`/`i >
   index` assertions may already pass by coincidence against the old binary
   logic — that's fine, the point is the accent/height assertions catch it).
3. Make the change in `progress.dart` shown above.
4. Run the same test file again — expect all 5 tests to PASS.
5. `flutter analyze` — zero warnings.
6. Commit: `git add lib/features/memories/widgets/progress.dart test/features/memories/widgets/progress_test.dart && git commit -m "feat: add a third, current-segment state to the memories progress bar"`.

---

### Task 1 — On-device verification

Per `AGENTS.md`'s Definition of Done — this phase has no golden (nothing in
`test/widgets/design_goldens_test.dart` or a feature-level goldens file
currently covers `Progress`, and per Phase 0's standing caveat these CI
goldens render with Ahem + `obscureText: true` anyway, so a static PNG
wouldn't show a 1px height bump or confirm the segment reads correctly *in
motion* — this needs eyes on a real memory playing, not a frame).

1. On the connected device (Pixel 9 Pro XL, primary per `AGENTS.md`
   environment), open Memories and play a memory with at least 3 pages.
   Confirm: segments before the current page are solid white, the current
   segment is visibly red and a hair taller than its neighbours, and
   segments after it are the same dim/translucent off-state as before this
   change.
2. Let the memory auto-advance through several pages — confirm the accent
   segment moves with `index` in real time with no visual glitch (flicker,
   wrong segment lit, size jump beyond the intended 2→3px bump).
3. Hold to pause — confirm the whole bar still dims to the existing 0.35
   opacity with the three-state colouring intact underneath (i.e. the pause
   dim and the current-segment accent are visually distinguishable, not
   fighting for the same "state" reading).
4. If only the iPhone 17 simulator is available this session, expect the
   same structural Xcode-scheme blocker Phase 2's Task 4 hit (`Runner`
   scheme lists zero simulator destinations — see that section and
   `docs/gotchas.md`'s iOS `integration_test` entry). This is a known,
   already-documented environment gap, not a Phase 3 regression — if hit
   again, record the outcome here rather than re-diagnosing it, same as
   Phase 2 did.

**Attempted 2026-09-05 — no device available.** Neither the primary Pixel 9
Pro XL nor any other Android device is connected (`adb devices` returns
empty). The physical iPhone shows as **Offline** in
`xcrun xctrace list devices` (not connected/charging over cable right now).
Only simulators are available, which hit the same structural blocker
recorded under Phase 2's Task 4 and `docs/gotchas.md`'s iOS `integration_test`
entry — not re-attempted here since that limitation is already diagnosed and
unchanged. **Task 1 stays outstanding**, same status as Phase 1's and Phase
2's still-pending manual passes — connect either device in a future session
to close it out.

**Definition of Done for this phase:**
- [x] `tool/check.sh` passes.
- [x] Widget test (Task 0) passing, all 5 cases (commit `f992cf0`).
- [x] On-device manual pass done (Task 1) — **done 2026-09-05** on the
      Samsung SM-S938B (installed debug build, no automated test covers this
      player UI — `memories_test.dart` is service-level only). User confirmed
      by eye: playing a memory with 3+ segments shows the current segment
      reading red and visibly taller than played segments, matching the
      three-state colour/height mapping (widget test, commit `f992cf0`).
- [x] This plan doc checked off through Phase 3, "Next step" line updated to
      point at Phase 4.

---

## Phase 4 — Onboarding poster treatment

**Status:** planning complete, concrete tasks below, not yet started.
**Files:** new `lib/features/onboarding/widgets/access_ring.dart` (the ring
widget + its `CustomPainter`) · `lib/features/onboarding/widgets/access_step.dart`
(138 lines, full file read during planning — wire the ring in) ·
`test/widgets/design_goldens_test.dart` (one new golden entry — this repo
funnels every design-system golden through this single file, no per-widget
golden file convention exists, confirmed during planning) · new
`test/widgets/access_ring_test.dart` · new
`test/features/onboarding/widgets/access_step_test.dart` (no existing test
for this widget — confirmed via `find test/features/onboarding` during
planning, which only turned up `onboarding_screen_test.dart`).

**Open decision — flag at plan approval, not something the code can resolve
on its own:** `docs/design-system.md` (line 8-10) states the app's one
accent colour is "reserved for state, never decoration," and
`AppColors.accent`'s own doc comment says the same. This phase's ring is
*purely decorative* — `AccessStep` doesn't vary it by `denied`/`busy`/
`attempted`, so there's no state it's marking. There's no other red token in
`AppColors` and no decorative-red equivalent in `AppOverMedia` (that group
is all white/black scrims and glyphs). **Proposed resolution:** ship it as
`colors.accent` anyway — this plan doc's own "Decisions this plan is
making" #5 (top of this doc) already frames Phase 4 as "the single biggest
visual departure... the only phase introducing new decoration," and the
uncommitted research spike evidently specified a red ring, so this
exception reads as already accepted when Phase 4 was scoped. Making it
explicit here so it isn't silently inconsistent with `design-system.md`'s
stated rule — Phase 6 (Docs) should add a one-line carve-out once this
ships ("accent is state-only, except the onboarding poster ring, named
here"). **If this doesn't match intent, redirect before Task 0.**

**No mockup available to build against** — the research spike that produced
this plan isn't committed to the repo (see this doc's "Source" line at the
very top), so there's no image to match pixel-for-pixel. Task 0's concrete
widget below (a single thin stroked circle bleeding off the top-right
corner, sized as a fraction of screen width) is this plan's best proposal
from the brief's own language ("ring," "poster treatment," "bleeding
off-screen") — **this is exactly what the isolated preview in Task 0 is
for**: review it via `flutter-add-widget-preview` before Task 1 wires it
in, and adjust diameter/stroke/position then, not by re-guessing now.

**Tooling gap:** no file in this repo uses `flutter-add-widget-preview`
today — confirmed via a repo-wide search during planning: no `@Preview`
usage, no `previews.dart`, no `widget_preview` pubspec dependency, no
preview entrypoint. Task 0 is a first-time bootstrap of this tooling, not
"add one more preview" — expect it to need more hand-holding than a normal
task.

**"Loading/denied/first-run" naming, reconciled against the live file:**
`AccessStep` doesn't have three mutually exclusive branches — it has one
boolean (`denied = attempted && access == PhotoAccess.denied`) plus an
orthogonal `busy` flag that only disables/spins the CTA
(`AppButton.primary(busy: busy, onPressed: busy ? null : ...)`; there's no
separate loading overlay elsewhere in the widget). So the task brief's
"loading/denied/first-run" maps to: **first-run** = `denied: false, busy:
false` (default copy, "Continue" CTA); **denied** = `denied: true` ("turned
off" copy, "Open Settings" CTA); **loading** = `busy: true`, layered on
either of the above (disables the CTA). Task 2's test covers all three
names plus the busy-crossed-with-denied combination, since `busy` isn't
mutually exclusive with `denied`.

---

### Task 0 — `AccessRing` widget + isolated preview

**Files:**
- Create: `lib/features/onboarding/widgets/access_ring.dart`.
- New preview file per the `flutter-add-widget-preview` skill's own bootstrap
  conventions (first use in this repo — invoke the skill and follow its
  setup rather than hand-rolling one).
- Create: `test/widgets/access_ring_test.dart`.
- Modify: `test/widgets/design_goldens_test.dart` — one new `goldenTest`
  entry, following the existing boilerplate (`themedGroup(...)`; no
  `ProviderScope` needed, `AccessRing` reads no provider-backed state).

**Proposed widget** (a starting point — Task 0's preview review may change
the constants below; nothing here is final):

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The onboarding poster's decorative ring — a single stroked circle. Purely
/// decorative (see this phase's plan notes for why it uses [AppColors.accent]
/// despite the design system's "accent is state, never decoration" rule);
/// static, no animation. [diameter] is caller-supplied so [AccessStep] can
/// size it as a fraction of screen width rather than a fixed pixel value.
class AccessRing extends StatelessWidget {
  const AccessRing({super.key, required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(painter: AccessRingPainter(color: colors.accent)),
    );
  }
}

/// Public so a widget test can assert the resolved color without pixel
/// matching — same rationale as `IndexingRingPainter`
/// (`lib/widgets/indexing_dial.dart`).
class AccessRingPainter extends CustomPainter {
  const AccessRingPainter({required this.color});

  final Color color;

  static const double _strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(AccessRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

No `AnimationController`, no `AnimatedContainer`, no `Ticker` — matches
`IndexingRingPainter`'s precedent for a plain `const`-field `CustomPainter`
driven only by rebuild, the established pattern in this codebase for a ring
that doesn't animate.

**Steps:**
1. Create `access_ring.dart` as above (or closer to a mockup if one surfaces
   before this task starts).
2. Invoke `dart-flutter:flutter-add-widget-preview` to bootstrap a preview
   for `AccessRing` — light and dark, a couple of `diameter` values (e.g.
   240 and 420) so the preview itself stands in for "small vs large" at this
   isolated stage.
3. View the preview. This confirms only: the shape renders, colors resolve
   correctly in both themes, the stroke doesn't look wrong at a glance. Do
   not wire into `access_step.dart` yet — that's Task 1, which needs a
   diameter-as-fraction-of-width decision first (Task 1 step 2).
4. Add the golden entry to `test/widgets/design_goldens_test.dart`:
   ```dart
   goldenTest(
     'AccessRing — decorative ring',
     fileName: 'access_ring',
     builder: () => themedGroup(
       const Align(child: AccessRing(diameter: 240)),
     ),
   );
   ```
5. Add `test/widgets/access_ring_test.dart`:
   ```dart
   testWidgets('paints with the theme accent color', (tester) async {
     for (final (name, theme) in [
       ('light', AppTheme.light),
       ('dark', AppTheme.dark),
     ]) {
       await tester.pumpWidget(
         MaterialApp(
           theme: theme,
           home: const Scaffold(body: AccessRing(diameter: 100)),
         ),
       );
       final painter = tester
           .widget<CustomPaint>(find.byType(CustomPaint))
           .painter as AccessRingPainter;
       final colors = Theme.of(tester.element(find.byType(AccessRing)))
           .extension<AppColors>()!;
       expect(painter.color, colors.accent, reason: name);
     }
   });

   testWidgets('is static — no pending ticker/animation after settling', (
     tester,
   ) async {
     await tester.pumpWidget(
       MaterialApp(
         theme: AppTheme.light,
         home: const Scaffold(body: AccessRing(diameter: 100)),
       ),
     );
     await tester.pumpAndSettle();
     expect(tester.binding.transientCallbackCount, 0);
     expect(find.byType(AnimatedContainer), findsNothing);
   });
   ```
6. `flutter test test/widgets/access_ring_test.dart test/widgets/design_goldens_test.dart --update-goldens`
   — confirm the new tests pass and `access_ring.png` (light+dark) appears
   under `test/widgets/goldens/ci/`; review both by eye.
7. `flutter analyze` — zero warnings.
8. Commit: `git add lib/features/onboarding/widgets/access_ring.dart test/widgets/access_ring_test.dart test/widgets/design_goldens_test.dart test/widgets/goldens/ci/access_ring* <preview files> && git commit -m "feat: add AccessRing decorative widget with isolated preview"`.

---

### Task 1 — Wire `AccessRing` into `AccessStep`

**File:** `lib/features/onboarding/widgets/access_step.dart`.

**Change:** wrap the existing `Padding(...)` (currently the sole child of
`SafeArea`, lines 45-135) in a `Stack`, with the ring as a first,
non-interactive, non-semantic layer bleeding off the top-right corner, sized
relative to screen width:

```dart
body: Stack(
  children: [
    Positioned(
      top: -diameter * 0.3,
      right: -diameter * 0.3,
      child: IgnorePointer(
        child: ExcludeSemantics(child: AccessRing(diameter: diameter)),
      ),
    ),
    SafeArea(
      child: Padding(
        // ...unchanged...
      ),
    ),
  ],
),
```

where `diameter` derives from `MediaQuery.sizeOf(context).width` (e.g.
`width * 1.1`) rather than a fixed pixel value — this is what lets the ring
scale instead of clipping identically on every device width, the specific
risk the phase brief calls out. `IgnorePointer` keeps the ring from stealing
taps meant for the content beneath it (nothing is tappable under its
footprint today, but the poster now overlaps the headline/brand row in the
`Stack`'s paint order, so this is a correctness guard, not paranoia).
`ExcludeSemantics` keeps a screen reader from announcing a shape that
carries no information — the same treatment `IndexingDial` reserves for its
disc when idle, applied here since this ring is *always* decoration, never
state.

**Steps:**
1. Make the change above.
2. Run on an emulator/simulator at a **small** width (e.g. iPhone SE class,
   ~375pt, or a small Android AVD ~360dp) and a **large** width (e.g. a
   Pixel Tablet or iPad simulator, or the largest phone AVD available) —
   confirm the ring doesn't visually collide with the growing `text.display`
   headline on either the first-run or denied copy variant, and doesn't get
   clipped in a way that reads as a rendering bug (a *deliberate* off-screen
   bleed is fine; an accidental hard edge/box artifact is not). This is a
   viewport-width check via emulator/simulator resize, distinct from (and no
   substitute for) the physical-device pass in Task 3.
3. Confirm `flutter analyze` is clean (no unused imports left from the
   pre-`Stack` structure).
4. Commit: `git add lib/features/onboarding/widgets/access_step.dart && git commit -m "feat: wire AccessRing into the onboarding poster"`.

---

### Task 2 — `access_step.dart` widget test

**File:** create `test/features/onboarding/widgets/access_step_test.dart`.

**Cover** (per the naming reconciliation above):
- **First-run** (`access: PhotoAccess.notDetermined, attempted: false, busy:
  false`): headline reads "Your photos stay yours.", CTA label "Continue",
  tapping it calls `onRequestAccess` (not `onOpenSettings`).
- **Denied** (`access: PhotoAccess.denied, attempted: true, busy: false`):
  headline reads "Photo access is turned off.", CTA label "Open Settings",
  tapping it calls `onOpenSettings` (not `onRequestAccess`).
- **Loading** (`busy: true`, crossed with both of the above): the CTA is
  disabled — tapping it invokes neither callback, since `busy` guards both
  branches identically in the live code (`onPressed: busy ? null : (denied ?
  onOpenSettings : onRequestAccess)`).
- **`AccessRing` mounts exactly once**, regardless of state —
  `find.byType(AccessRing)` finds one widget in every case above (decoration
  is state-invariant, unlike everything else in this widget).

**Steps:**
1. Write the test file with the cases above, using recorded-callback bools
   (`var requested = false; onRequestAccess: () => requested = true`) —
   check whether `onboarding_screen_test.dart` already uses this pattern and
   reuse its convention rather than inventing a new one.
2. Run: `flutter test test/features/onboarding/widgets/access_step_test.dart`
   — expect PASS if Task 1 already landed; if this task runs first (TDD),
   confirm the ring assertion fails until Task 1 wires it in.
3. `flutter analyze` — zero warnings.
4. Commit: `git add test/features/onboarding/widgets/access_step_test.dart && git commit -m "test: add AccessStep widget test covering first-run/denied/loading branching"`.

---

### Task 3 — Golden regen + device/on-device verification

1. `flutter test test/widgets/design_goldens_test.dart --update-goldens` —
   confirm nothing beyond `access_ring.png` changed (Task 0 already
   generated it; this task's job is to catch anything Task 1's
   `access_step.dart` change accidentally disturbed elsewhere — `AccessStep`
   itself has no golden today and this phase doesn't add a whole-screen one,
   only the isolated ring gets a golden, per the task brief). **Confirmed:**
   `git status --short test/widgets/goldens/` came back empty after
   regenerating — every PNG (including `access_ring.png`) already matched
   what Task 0 committed, no drift from Task 1/2's changes.
2. `tool/check.sh` — must pass clean. **Confirmed:** 874 tests pass, analyze
   clean.
3. Repeat Task 1 step 2's small/large emulator width check once more against
   the final wired-in state, light and dark theme both. **Not done as a
   real visual emulator check** — same environment gap Task 1 hit (no
   small/large simulator *pair*, no Android AVD); this session additionally
   confirmed no Android device at all (`adb devices` empty) and the
   physical iPhone shows **Offline** in `xcrun xctrace list devices`
   (`flutter devices` optimistically lists it as "wirelessly connected,"
   but that couldn't be relied on to actually launch the app — same
   discrepancy Phase 3's session already hit and recorded). The Task 1/2
   widget-test width-substitute (4+ cases at ~375dp/~860dp, both copy
   variants, asserting no render exception and `AccessRing` mounted) is the
   only verification this session could actually run; the visual
   ring-vs-headline collision judgment call is unverified either way.
   **Quantified during the final whole-branch review (2026-09-05):** the
   ring is not a small corner accent — plugging a representative 390pt
   width into the shipped formula (`access_step.dart:45`,
   `diameter = MediaQuery.sizeOf(context).width * 1.1`, ring `Positioned`
   at `top: -diameter * 0.3, right: -diameter * 0.3`,
   `access_step.dart:51-52`) gives `diameter ≈ 429`, so the ring's
   bounding box spans roughly `x ≈ 90..519` (visible left edge ~23% in
   from the screen's left edge, not tucked into the corner) and
   `y ≈ -129..300` — the same vertical band the headline/brand-row content
   occupies after the first `Spacer`. It reads as a dominant graphic
   across the upper-middle of the screen, not a subtle accent. This is
   still safe for *readability*: the `Stack`'s paint order puts the real
   screen content (`SafeArea`/`Padding`/`Column`) on top of the ring, so
   opaque text always wins. What's still unverified is purely aesthetic —
   whether the visible arc of stroke reads as a deliberate poster layer or
   as debris crossing through the copy — and that fraction of the screen
   is width-invariant, but the absolute headline-to-ring proximity is
   tightest at small widths, so the eventual on-device pass should check
   both the first-run and denied copy variants at a **small** width
   specifically, not just "some width."
4. On-device pass (per `AGENTS.md` Definition of Done): open onboarding
   fresh (uninstall/reinstall or clear app data) on the connected device,
   confirm the ring renders correctly, tap "Continue" and confirm the native
   permission dialog still appears (the `Stack`/`IgnorePointer` change must
   not break the tap target), and check the denied → "Open Settings" path.
   Same backlog status as Phases 1-3 if no device is connected this session
   — **not a blocker**, record the outcome here either way. **Not done —
   no device connected this session** (see step 3's device-availability
   findings above); same outstanding backlog item as Phases 1-3's manual
   passes.
5. Commit any final golden/doc updates. **Done:** pulled the
   `docs/design-system.md`/`AppColors.accent` carve-out forward from Phase 6
   rather than leaving the docs inconsistent with the shipped code (commit
   `e7756f9`) — cheap enough not to wait.

**Attempted 2026-09-05 — no device available, same class of gap as Phases
1-3.** `adb devices` (Android) returns empty. `xcrun xctrace list devices`
shows the physical iPhone as **Offline**, despite `flutter devices` listing
it as a "wirelessly connected device" — not reliable enough to attempt a
real `flutter run` against it. Only iOS simulators are available
(including, this session, an iPad pair alongside iPhone 17/17 Pro/Air —
more simulator variety than Phase 2/3 had), but launching a Flutter build
against any of them still needs the same structural Xcode-scheme fix (or a
physical-device workaround) `docs/gotchas.md`'s iOS `integration_test` entry
already documents — not re-diagnosed here, consistent with how Phase 3
handled hitting the same wall. **Small/large-width verification was
substituted with widget tests instead** (Task 1/2, see above) rather than a
real visual pass — this is a different, narrower substitution than Phases
1-3's manual passes (which had no substitute at all), but the *visual*
judgment call (does the ring actually look right against the growing
headline) remains genuinely unverified either way — see step 3 above for
the actual bounding-box geometry that makes this worth checking carefully
rather than a routine "looks fine" glance.

**Definition of Done for this phase:**
- [x] `tool/check.sh` passes.
- [x] Preview reviewed before wiring in (Task 0 step 3) — mechanically only
      (tool discovered all 4 preview instances, scaffold compiled with no
      errors); actual visual rendering in the previewer UI still needs
      human eyes, no display in this sandbox.
- [x] Golden for `AccessRing` in isolation, light and dark (Task 0).
- [x] Widget test for `access_step.dart`'s first-run/denied/loading
      branching, including the ring mounting invariantly (Task 2).
- [x] Small- and large-width verification done — **substituted with widget
      tests** (Task 1/2), not a real emulator/simulator visual check (Task 3
      step 3) — no small/large device pair was available this session; the
      visual ring-vs-headline judgment call is still unverified. Task 3
      step 3 above now quantifies the ring's actual footprint (`x ≈
      90..519`, `y ≈ -129..300` at a 390pt width) — it's a dominant
      upper-middle graphic, not a corner accent, so the still-owed pass
      should check both copy variants at a **small** width specifically.
- [x] No implicit animation confirmed absent (Task 0's ticker/
      `AnimatedContainer` test).
- [x] `docs/design-system.md`'s accent rule updated with the poster-ring
      carve-out — pulled forward here rather than deferred to Phase 6
      (commit `e7756f9`).
- [x] On-device manual pass (Task 3 step 4) — **done 2026-09-05**. A debug
      build was installed fresh on the Samsung SM-S938B (so onboarding, and
      the `AccessRing` poster on it, showed on first launch). User confirmed
      by eye: the ring reads correctly against the headline, no visual
      regression from the ring-vs-headline judgment call flagged at Task 0.
- [x] This plan doc checked off through Phase 4, "Next step" line updated to
      point at Phase 5.

---

## Phase 5 — Remaining screens

**Status:** planning complete 2026-09-05, concrete tasks below, not yet
started. Library, Search, Saved, Albums, Settings mostly *inherit* Phase 0/1
changes automatically (they consume `AppTextStyles`/`AppColors`/`FilterPill`/
`SegmentedControl` rather than hand-rolling styles) — this phase is a
verification pass, not a rewrite. Per `AGENTS.md`, run `tool/check.sh` after
each task.

**Device check for the opportunistic on-device/visual backlog (Phases 1-4),
done during this planning pass:** still blocked, same root causes already on
record. `adb devices` — empty, no Android device connected. iOS: the physical
iPhone 17 Pro Max shows **Offline** in `xctrace list devices`; the iPhone 17
simulator is booted but structurally cannot run `flutter run`/
`integration_test` (`google_mlkit_image_labeling` has no arm64-sim slice —
see `docs/gotchas.md`'s iOS entry and [[testing-device-iphone-17-sim]]). No
change from Phase 4's last check; the four queued manual passes (Phase 1
Task 7 step 5, Phase 2 Task 4, Phase 3 Task 1, Phase 4's on-device pass) stay
outstanding into whatever session next has a connected device.

**Verify-only findings (Library, Search, Albums, Settings) — traced during
planning, no code change needed, ship as confirmed:**
- **Library "all" filter:** `LibraryScreen` routes `all`/`months` through
  `MonthTimeline`, which stacks `MonthHeader` (`pageTitle` role, 18/700) over
  `LibrarySection` (`sectionLabel` role, 400) with `SectionCountPill`
  (`caption` role, 400) trailing. That's two distinct weights (400/700)
  across three roles — reads as ≤3 hierarchy levels, confirming Phase 0's
  finding still holds (nothing in Phases 1-4 touched these three files).
- **Search facets + People card:** `ResultsBody` stacks `FilterBar`
  (`FilterPill`, already recolored in Phase 1 Task 1) → `PeopleStrip` (`r30`
  circular avatars, its own `w600` residual already fixed to `w700` in Phase
  1 Task 6) → `AlbumsResult` → the photo grid. No hand-rolled styling in
  `search_screen.dart`, `filter_bar.dart`, or `results_body.dart` — all three
  consume shared widgets/tokens only. `AlbumsResult`'s own `w600` residual is
  handled in Task 1 below.
- **Albums:** `AlbumsScreen`/`_Sections`/`_NoAlbumsNote` consume `AppButton`
  (pill, untouched), `AlbumCard` (r30, untouched — its `w600` residual is
  Task 1 below), `PeopleStrip`, `FolderList`, `SectionHeader` — no hand-rolled
  colour or weight in the screen file itself.
- **Settings:** `SettingsScreen`'s `_AppearanceGroup` passes straight through
  to `ThemeModePicker`, which is a bare `SegmentedControl<ThemeMode>` with no
  local styling — Phase 1 Task 2's label-colour change applies automatically.

---

### Task 0 — Saved heart badge: scrim disc → `colors.accent` fill

**File:** `lib/features/saved/saved_screen.dart:234-254`, the `_HeartBadge`
widget (full context read during planning — it sits inside `_GridCell`,
positioned top-right over `AssetThumbnail`).

**Current code:**
```dart
class _HeartBadge extends StatelessWidget {
  const _HeartBadge();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: AppOverMedia.scrim,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Icon(
          Icons.favorite_rounded,
          size: 14,
          color: AppOverMedia.glyph,
        ),
      ),
    );
  }
}
```

**Change:** the disc fill becomes `colors.accent` (the Accent-usage table's
own row for this widget: "same filled-heart convention" as `ExifSheet`'s
mark, non-text/icon use, so plain `accent`, never `accentText`). The glyph
stays `AppOverMedia.glyph` (`Colors.white`) — script-verified in Phase 1 Task
4 that white against `accent` (`#EB0000`) is ≈4.6:1, clears the 3:1
icon/non-text threshold in both themes (this colour doesn't flip by theme).
Because the fill now reads a `ThemeExtension`, the widget can no longer be
`const`:

```dart
class _HeartBadge extends StatelessWidget {
  const _HeartBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(
          Icons.favorite_rounded,
          size: 14,
          color: AppOverMedia.glyph,
        ),
      ),
    );
  }
}
```

Add the `AppColors` import (`../../core/theme/app_colors.dart`) if not
already present in the file.

**Tests:** no existing golden covers `SavedScreen` or `_HeartBadge` (checked
`test/widgets/design_goldens_test.dart` and `test/features/screens_test.dart`
— neither references it), so this is a plain widget-test addition, not a
golden regen. `test/features/saved/saved_screen_test.dart`'s existing
`'renders a grid cell per favorite'` test (line 52) already asserts
`find.byIcon(Icons.favorite_rounded)` — add a new test alongside it:

```dart
testWidgets('the heart badge fills with the accent colour', (tester) async {
  await db.indexDao.upsertMetadata([
    (
      id: 'a1',
      createdAt: DateTime(2024),
      isVideo: false,
      width: 1,
      height: 1,
      isDated: true,
    ),
  ]);
  await db.favoritesDao.add('a1', at: DateTime(2024, 1, 2));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(
          FakePhotoLibraryService(),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
    ),
  );
  await tester.pump();

  final badge = tester.widget<DecoratedBox>(
    find.ancestor(
      of: find.byIcon(Icons.favorite_rounded),
      matching: find.byType(DecoratedBox),
    ),
  );
  expect(
    (badge.decoration as BoxDecoration).color,
    AppColors.light.accent,
  );
  await teardownTree(tester);
});
```

Add the `AppColors` import to the test file if not already present.

**Steps:**
1. Run `flutter test test/features/saved/saved_screen_test.dart` — confirm
   the baseline suite passes before touching anything.
2. Add the new test above (it will fail — `DecoratedBox.color` is currently
   `AppOverMedia.scrim`, not `AppColors.light.accent`).
3. Run again — expect FAIL.
4. Make the code change to `_HeartBadge`.
5. Run again — expect PASS, all tests in the file.
6. `flutter analyze` — zero warnings.
7. Commit: `git add lib/features/saved/saved_screen.dart test/features/saved/saved_screen_test.dart && git commit -m "feat: recolor Saved heart badge to accent"`.

---

### Task 1 — Residual `FontWeight.w600` cleanup (feature-screen half)

Four files hardcode `FontWeight.w600` bypassing `AppTextStyles`, the other
half of the finding Phase 1 Task 6 already fixed for shared widgets. Same
rationale: each is clearly emphasis-bearing text (a card title, a name), so
the fix is `w600` → `w700` in place, not dropping the override.

| File | Line | Context (confirmed against the live file) |
|---|---|---|
| `lib/features/people/people_screen.dart` | 310 | `_PersonCard`'s name label — conditional: `person.displayName == null ? FontWeight.w400 : FontWeight.w600` (only the `w600` branch changes) |
| `lib/features/search/widgets/albums_result.dart` | 91 | `_AlbumTile`'s album-name label, `styles.caption.copyWith(...)` |
| `lib/features/albums/widgets/album_card.dart` | 74 | `AlbumCard`'s name label, `styles.caption.copyWith(...)` |
| `lib/features/memories/widgets/memory_card.dart` | 113 | `MemoryCard`'s title over media, `text.body.copyWith(...)` |

**Change:** in each, replace `FontWeight.w600` with `FontWeight.w700`
in-place — a one-line diff per file, surrounding `.copyWith(...)` arguments
untouched.

**Tests:**
- `album_card.dart` and `memory_card.dart` have existing goldens in
  `test/widgets/design_goldens_test.dart` (`'AlbumCard — populated and
  empty'` line 232, `'MemoryCard — titled and untitled cover'` line 325) —
  regenerate with `flutter test test/widgets/design_goldens_test.dart
  --update-goldens` and review the diff. Per the standing Ahem-font/
  `obscureText` CI-golden caveat (Phase 0), the weight change itself won't be
  visible in the PNG — this is validated by the code-level `FontWeight.w700`
  assertions below instead, same as Phase 1 Task 6.
- `people_screen.dart` (`_PersonCard`) and `albums_result.dart`
  (`_AlbumTile`) are private widgets with **no existing golden** (checked —
  pre-existing gap, not introduced by this task, same category as Phase 1
  Task 6's `folder_list.dart` finding) — add a plain widget test per file
  instead:
  - `test/features/people/people_screen_test.dart` — add a test asserting
    the named-person label's resolved `fontWeight == FontWeight.w700` (use
    the existing `displayName: 'Alice'` fixture at line 95) and, separately,
    that the unnamed-person label (`displayName: null`, line 96) stays
    `FontWeight.w400` — locking in that the conditional's untouched branch
    really is untouched.
  - `test/features/search/widgets/albums_result_test.dart` — new file (no
    test currently exercises this widget in isolation); pump `AlbumsResult`
    with one `AlbumSummary` and assert the name `Text`'s resolved
    `fontWeight == FontWeight.w700`.
- For `album_card.dart` and `memory_card.dart`, also add a plain widget-test
  assertion (not just the golden) for the same reason Phase 1 Task 6 did:
  `test/features/albums/album_card_test.dart` and
  `test/features/memories/widgets/memory_card_test.dart` already exist —
  add one `fontWeight == FontWeight.w700` assertion to each.

**Commit:** one commit for all four:
`git commit -m "fix: collapse residual FontWeight.w600 to w700 (feature screens)"`.

---

### Task 2 — Latent `titleMedium` weight in `app_theme.dart`

**File:** `lib/core/theme/app_theme.dart:178` — `_textTheme` builds
`titleMedium: s.body.copyWith(fontWeight: FontWeight.w600, color: primary)`,
a third weight baked into the `TextTheme` itself rather than a widget-level
override. Confirmed during this planning pass: still no consumer of
`titleMedium` anywhere in `lib/` (`grep -rn "titleMedium" lib/` — only this
one definition site), so nothing visibly regresses today, but it should
still collapse to `w700` so the two-weight system stays true if something
starts consuming it later.

**Change:** `FontWeight.w600` → `FontWeight.w700` on that line, no other
change.

**Tests:** no test reads `titleMedium` today (confirmed by the same grep,
run against `test/` too). No new test needed — this is a dead-code-adjacent
correction, not a behavior change; `tool/check.sh` passing is sufficient
confirmation nothing depends on the old value.

**Commit:** `git add lib/core/theme/app_theme.dart && git commit -m "fix: collapse latent titleMedium weight to w700"`.

---

### Task 3 — Full-branch check

Run once, after Tasks 0-2 land:
1. `tool/check.sh` — must pass clean (analyze + build_runner + all tests).
2. `git diff --stat test/widgets/goldens/ci/` — expect exactly `album_card.png`
   and `memory_card.png` changed (Task 1's golden regen). Anything else
   changing is a regression to investigate before committing.
3. On-device pass: still blocked this session (see the device check above) —
   carries forward into the same outstanding backlog as Phases 1-4, not a
   Phase 5 blocker.

**Definition of Done for this phase:**
- [x] `tool/check.sh` passes (879 tests, clean analyze + build_runner).
- [x] Verify-only findings recorded above (Library, Search, Albums, Settings)
      — done during planning, no code change needed.
- [x] `_HeartBadge` recolored to `colors.accent`, test passing (Task 0,
      commit `7c803cd`).
- [x] All 4 feature-screen `FontWeight.w600` residuals collapsed to `w700`,
      each with a passing weight assertion (Task 1, commit `b894d7d`). Golden
      regen for `AlbumCard`/`MemoryCard` confirmed a no-op (Ahem-font CI
      goldens can't show weight, same standing caveat as Phase 0/1) — no PNGs
      changed.
- [x] `app_theme.dart`'s latent `titleMedium` weight collapsed to `w700`
      (Task 2, commit `82f98e8` — confirmed zero consumers via grep before
      and after).
- [x] On-device/visual backlog (Phases 1-4) re-checked this session — still
      blocked, no regression from last check (no Android device, physical
      iPhone Offline, simulator structurally blocked).
- [x] This plan doc checked off through Phase 5, "Next step" line updated to
      point at Phase 6.

---

## Phase 6 — Docs

Update `docs/design-system.md`:
- Add `accent` to the Colors table (`AppColors`), one row, noting it's the
  only colour token with semantic meaning tied to state, not surface.
  (Phase 0's review already pulled forward the intro-line mention of
  `accent` and the 4-row typography weight correction — this phase still
  needs the actual Colors-table row and the rest below.)
- ~~Update the Typography table's weight column for `sectionLabel`,
  `filterPill`, `button`, `exifValue`.~~ Done during Phase 0's final review
  (2026-09-05) — pulled forward because AGENTS.md requires reading this doc
  before any UI work and Phases 1-5 are all UI work.
- Dedupe the "photos supply all the color" rationale — it currently exists
  in two places in `lib/core/theme/app_colors.dart` (the `AppOverMedia` doc
  block, ~line 6-8, and `AppColors`'s own doc comment, ~line 49-51) with
  slightly diverging wording, a residual from Phase 0's fix rounds. Pick one
  home for it (`AppColors`'s own doc comment) and remove/trim the other.
- Add a line to the Radius section or a new "Grid" section stating the
  s8-bleed-past-s16-margin pattern as a rule, not a per-file comment
  (currently scattered across `month_timeline.dart`, `library_section.dart`
  per the spike's citations).
- Add a short "Accent usage" note pointing at the rule this plan enforces:
  state only, never decoration — future contributors need this stated
  somewhere more durable than this plan doc, which gets pruned per
  `AGENTS.md`'s "prune task-scoped notes" rule once the work lands.
- Also add an `accentText` row (new in Phase 1) — a companion text-safe
  variant of `accent`, differing by theme; note that consumers must use
  `accentText`, never `accent`, whenever the red becomes the colour of text.

---

## Definition of Done (whole project, not just Phase 0)

Per `AGENTS.md`:
1. `tool/check.sh` passes on every phase's PR.
2. Integration tests for each touched area pass on the connected device
   (Pixel 9 Pro XL primary; check `nav_shell_test.dart` and any
   `memories`/`detail`/`onboarding` integration tests by name before
   assuming none exist).
3. Each phase manually verified end-to-end on-device before merge.
4. No schema change in this project — N/A for the migration-test requirement.
5. No new Android dependency — N/A for the manifest re-check.
6. `docs/gotchas.md` updated if anything in here turns out to be wrong once
   real code is in front of us (the `IndexingDial`/`AppOverMedia` wrinkle in
   Phase 3 is the most likely candidate).
7. This plan doc marked complete per phase, "Next step" line kept current.
8. Once all phases land, prune this doc to durable decisions only, or archive
   it to `docs/archived/` per the pattern already used for the 2026-09-04
   remediation doc.

---

## Next step

**Session 2026-09-05 (later): full on-device verification closed out on
Android.** A Samsung SM-S938B (Android 16, API 36, `RZGYB1E58CV`) connected
via `adb` — the first Android device available to any session of this plan.
`tool/check.sh` re-run clean (879 tests) as a baseline, then four
`patrolTest`-based integration files ran via `patrol test`, all passing with
zero failures: `detail_actions_test.dart` (3/3, 2 pre-existing unrelated
skips — the ExifSheet favourite/DETAILS path, Phase 2's named outstanding
item), `nav_shell_test.dart` (5/5 — NavPillBar + IndexingDial, Phase 1),
`consent_flow_test.dart` (5/5 — onboarding `AccessStep`/Phase 4 and Settings
`ConsentSwitch`/Phase 1), `saved_albums_test.dart` (2/2 — Phase 5's heart
badge, regression check). A code-level spot check confirmed `filter_pill.dart`,
`segmented_control.dart`, `consent_switch.dart`, `nav_pill_bar.dart`, and
`indexing_dial.dart` still wire `colors.accent`/`colors.accentText` exactly
as Phase 1 documented — nothing had drifted since the prior session's full
code audit (commit `0440cc2`).

The remaining gap after the automated run was the *colour/motion* judgment
`patrol`'s finders structurally cannot make (widget presence/state, not
rendered pixels) — and this session did not use screenshots for it, per the
project's standing rule that screenshots can pollute the real photo library
through MediaStore. Instead: `no_exif.jpg`/`gps_exif.jpg` were seeded into
the device's real library per `test_assets/README.md`'s documented procedure,
a debug APK was built and installed fresh (`flutter build apk --debug` +
`adb install`, landing on a clean onboarding run), and the user walked the
full manual checklist on-device — NavPillBar knob/glyph, Search FilterPill
selected state, Settings ConsentSwitch + theme-picker label, the two seeded
ExifSheet fixtures, a 3+-segment Memories playback, and the onboarding
`AccessRing` poster — confirming all of it **ok**. Every phase's on-device
Definition-of-Done line (Phases 1-4; Phase 5's heart badge covered by
`saved_albums_test.dart`) is now checked off above.

**iOS status unchanged:** still structurally blocked for `patrolTest` files
(binding conflict, see `docs/gotchas.md`) — untried this session, not
expected to matter now that Android covers every `patrolTest` file this plan
depends on, but not formally closed either.

**What's actually left:** Phase 6 — Docs (fold the grid-bleed rule,
`accent`/`accentText`, and the two-weight rule into `docs/design-system.md`;
task list under "Phase 6 — Docs" above, none of it started yet) — and the
still-open question of how to land Phases 1-5 (they've shipped as direct
commits to `main` across separate sessions, unlike Phase 0's worktree/PR;
decide whether that's fine as-is or whether this plan doc should be archived
now that every phase but docs is built, reviewed, and verified on-device).

---

Phase 1 is built and clean (commits `8f76b61`..`2e6eb99` on
`worktree-swiss-ui-refactor-phase1`, Tasks 0-7, plus a final whole-branch
review fix wave that: darkened `accentText.light` to `#D80000` so it clears
WCAG AA text contrast against `FilterPill`'s real ground
(`scaffoldBackgroundColor`, not `scheme.surface`); made `ConsentSwitch`'s
active thumb theme-invariant white, matching `NavPillBar`'s knob-glyph
precedent; rewrote the `accentText` contrast test to check real theme
grounds instead of hardcoded hex; replaced hardcoded hex literals in
`segmented_control_test.dart` with the resolved token; and fixed two stale
comments). Decide how to land it. The on-device manual pass (Task 7, step 5)
still has not happened — it needs a physical device — so do it before or
alongside Phase 2's own device pass, not as a Phase 1 blocker held open
indefinitely.

**Phase 2 — `ExifSheet` rebuild:** Tasks 0-3 are built and clean (`tool/check.sh`
passing, commits `716600c`..`2675cd1`). Task 4 (on-device pass) is
**outstanding by user decision, not a blocker** — an iPhone 17 simulator
attempt (2026-09-05) hit a structural Xcode scheme issue (see Task 4's note
above and `docs/gotchas.md`'s iOS `integration_test` entry) and the user chose
to skip the automated pass rather than debug the simulator or switch to the
physical iPhone. See the Phase 2 section above for the full record, including
two corrections found during execution (already folded into the task text,
not left as separate addenda): the favourite-mark test scaffolding switched
from a `databaseProvider`/in-memory-Drift override to directly overriding
`isFavoriteProvider` with `Stream.value(bool)`, after the original approach
hit both a "Timer still pending" hang in widget tests and a
`MissingPluginException` in goldens.

**Phase 3 — Memories player third state:** Task 0 built and clean (commit
`f992cf0`, `tool/check.sh` passing — five widget tests asserting the
three-state colour/height mapping directly, plus the
`AppOverMedia`-is-const-vs-`colors.accent`-is-a-`ThemeExtension` wrinkle
called out in the code). Task 1 (on-device pass) is **outstanding — no
device connected this session** (Android `adb devices` empty, physical
iPhone shows Offline, simulators blocked by the same Xcode-scheme issue
Phase 2 hit) — same backlog item as Phase 1's and Phase 2's still-pending
manual passes. Next step: connect the Pixel 9 Pro XL (or the physical
iPhone) in a future session, play a memory with 3+ pages, and confirm the
current segment reads red and taller in motion per Task 1's steps above.

**Phase 4 — Onboarding poster treatment:** built and reviewed clean
2026-09-05 (branch `worktree-swiss-ui-refactor-phase4`), Tasks 0-3 executed
via `superpowers:subagent-driven-development` — Task 0 (`AccessRing` widget +
first-time `flutter-add-widget-preview` bootstrap in this repo, 1 fix round:
formatting), Task 1 (wired into `AccessStep`, 1 fix round: the substitute
width-check test didn't actually assert the ring was present), Task 2
(extended that same test file with copy/CTA/callback/busy-loading coverage,
0 fix rounds — also surfaced a real gotcha: `busy: true` renders an
indefinitely-animating spinner, so tests on that branch need a bounded
`pump()` instead of `pumpAndSettle()`), Task 3 (golden regen clean, no
drift; `tool/check.sh` 874 tests passing; pulled the
`docs/design-system.md`/`AppColors.accent` accent-as-decoration carve-out
forward from Phase 6 rather than leaving the docs inconsistent). The
accent-as-decoration exception flagged at planning time was accepted at
plan approval and shipped as documented. No mockup ever surfaced, so Task
0's ring shape (thin stroked circle, top-right bleed) shipped as originally
proposed — reviewed via the widget-preview tool only mechanically (no
display in this sandbox); a real visual pass is still owed. Small/large
device-width verification was substituted with widget tests throughout
(no small/large simulator pair or Android AVD available this session
either) — this covers "does it crash at extreme widths" but not the visual
ring-vs-headline judgment call, which — together with the on-device pass —
remains outstanding, same backlog item as Phases 1-3's still-pending manual
passes. Next step: decide how to land Phase 4, then pick up the four queued
on-device/visual passes (Phases 1-3 plus this phase) opportunistically when
a physical device or a working simulator becomes available — see
`docs/gotchas.md`'s iOS `integration_test` entry for the standing Xcode
scheme blocker.

**Phase 5 — Remaining screens:** built and clean 2026-09-05 (commits
`7c803cd`, `b894d7d`, `82f98e8`), Tasks 0-3 executed directly in-session (no
worktree — small enough diff not to warrant one). Verify-only findings for
Library/Search/Albums/Settings recorded in the phase section above, no
regression found. `tool/check.sh` passes (879 tests). Golden regen for
`AlbumCard`/`MemoryCard` was a no-op PNG-wise, as expected from the standing
Ahem-font caveat. The four-phase on-device/visual backlog (Phases 1-4) was
re-checked and remains blocked — no Android device, physical iPhone Offline,
iOS simulator structurally excluded. Next step: **Phase 6 — Docs** (fold
the grid-bleed rule, `accent`/`accentText`, and the two-weight rule into
`docs/design-system.md`), or decide how to land Phases 1-5 together first —
see the multi-phase branch/PR question this plan hasn't resolved yet (Phase 0
built on its own worktree branch; Phases 1-5 have all landed as direct
commits to `main` in their own sessions).
