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
- [ ] **Phase 2 — `ExifSheet` rebuild** (Tasks 0-3 built and clean; Task 4
      on-device pass outstanding — needs a physical device)
- [ ] **Phase 3 — Memories player third state** (separate session, has a
      logic component)
- [ ] **Phase 4 — Onboarding poster treatment** (separate session, highest
      subjectivity — consider a preview/checkpoint before wiring in)
- [ ] **Phase 5 — Remaining screens** (Albums, Saved, Settings, Search,
      Library apply Phase 0/1 tokens — mostly inherited automatically, spot
      verify each)
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
- [ ] On-device pass complete (Task 7, step 5) — **not done**; requires a
      physical device, out of scope for an in-worktree fix pass.
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

**Definition of Done for this phase:**
- [ ] `tool/check.sh` passes.
- [ ] Every golden diff reviewed manually (Task 3, step 6).
- [ ] `integration_test/detail_actions_test.dart` passes on-device (Task 4,
      step 1).
- [ ] Manual no-EXIF and GPS device checks done (Task 4, steps 2-3).
- [ ] This plan doc checked off through Phase 2, "Next step" line updated to
      point at Phase 3.

---

## Phase 3 — Memories player third state

**File:** `lib/features/memories/widgets/progress.dart`.

Today: `i <= index` → `AppOverMedia.glyph` (opaque white), else
`AppOverMedia.segmentOff`. Change to three states: `i < index` (played) stays
`AppOverMedia.glyph`; `i == index` (current) → `colors.accent`, height bumped
from 2 to 3 (the non-colour cue from the accent-usage table); `i > index`
(upcoming) stays `segmentOff`. Note `AppOverMedia` is deliberately
theme-invariant consts (media is always the background, not the chrome), but
`colors.accent` is a `ThemeExtension` value — this widget will need access to
`Theme.of(context).extension<AppColors>()!` if it doesn't already, since it's
mixing a theme-variant token into an otherwise theme-invariant file. Note
this explicitly in the diff/PR description since it's a small architectural
wrinkle worth a reviewer's eyes.

**Tests:** widget test asserting the three-state colour/height mapping
directly (a golden alone won't distinguish "red because state" from "red
because I fat-fingered a hex"). Manual on-device pass playing a memory to
confirm the segment reads correctly in motion, not just as a static frame.

---

## Phase 4 — Onboarding poster treatment

**Files:** `lib/features/onboarding/widgets/access_step.dart`,
possibly a new `lib/features/onboarding/widgets/access_ring.dart` for the
graphic element.

This is the only phase introducing new decoration rather than recolouring
existing structure — treat it accordingly:
- Build the ring as an isolated widget with its own preview
  (`dart-flutter:flutter-add-widget-preview`) before wiring it into
  `access_step.dart`, so it can be reviewed on its own.
- The headline (`text.display`, currently 34/700) growing larger and the
  ring bleeding off-screen both need to be checked against real device
  widths, not just the phone-frame mockup's fixed aspect ratio — verify on
  both a small and a large device in the simulator/emulator matrix
  (`docs/gotchas.md` / `AGENTS.md` environment section for device details).
- Reduced-motion/accessibility: the ring is static (no motion at all), so
  this should be a non-issue, but confirm no implicit animation gets pulled
  in by whatever draws it (e.g. avoid `AnimatedContainer` for a shape that
  never changes).

**Tests:** widget test for `access_step.dart` (loading/denied/first-run
states per the existing `access_step.dart` branching), golden for the new
ring widget in isolation, light and dark.

---

## Phase 5 — Remaining screens

Library, Search, Saved, Albums, Settings mostly *inherit* Phase 0/1 changes
automatically (they consume `AppTextStyles`/`AppColors`/`FilterPill`/
`SegmentedControl` rather than hand-rolling styles). This phase is a
verification pass, not a rewrite:
- [ ] Library — confirm "all" filter view reads as ≤3 simultaneous hierarchy
      levels post-weight-collapse (the spike's own gap #2).
- [ ] Search — confirm facet pills and the People card (r30, unchanged)
      render correctly together.
- [ ] Saved — heart badge already uses a scrim disc; swap to `colors.accent`
      fill (`saved_screen.dart:234-254`, the `_HeartBadge` widget).
- [ ] Albums — no colour change needed (New button is a pill, untouched;
      AlbumCard is r30, untouched) — verify only.
- [ ] Settings — `ThemeModePicker` inherits the `SegmentedControl` change
      from Phase 1 automatically; verify only.
- [ ] **Residual weight cleanup (from Phase 0's review), feature-screen
      half:** 4 files have a hardcoded `FontWeight.w600` bypassing
      `AppTextStyles` — `lib/features/people/people_screen.dart:309-310`,
      `search/widgets/albums_result.dart:91`,
      `albums/widgets/album_card.dart:74`,
      `memories/widgets/memory_card.dart:113`. See Phase 1 for the other 6
      (shared-widget) files in the same finding.
- [ ] **Additional residual `FontWeight.w600` found during Phase 1's
      whole-branch review:** `lib/core/theme/app_theme.dart`'s `_textTheme`
      builds `titleMedium` as `s.body.copyWith(fontWeight: FontWeight.w600,
      ...)` — a latent third weight baked into the `TextTheme` itself, not a
      widget-level override like the ones above. No current consumer in
      `lib/` reads `titleMedium` (checked during Phase 1's fix pass), so it
      isn't visibly regressing anything today, but it should still collapse
      to `w700` (or be reconsidered) so the two-weight system stays true if
      something starts consuming it later. Not urgent; tracked here so it
      isn't lost.

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
passing, commits `716600c`..`dba52c8` plus the Task 2/3 work landing next);
Task 4 (on-device pass) is outstanding, needs the physical device. See the
Phase 2 section above for the full record, including two corrections found
during execution (both already folded into the task text, not left as
separate addenda): the favourite-mark test scaffolding switched from a
`databaseProvider`/in-memory-Drift override to directly overriding
`isFavoriteProvider` with `Stream.value(bool)`, after the original approach
hit both a "Timer still pending" hang in widget tests and a
`MissingPluginException` in goldens.
current as each lands.
