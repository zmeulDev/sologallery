# Swiss UI refactor — implementation plan

**Status:** planning — not yet approved. Nothing in this doc has been built.
**Source:** a research spike (not committed to the repo) comparing the current
design system against International Typographic Style principles, with
mockups covering nine screens: Onboarding (access + consent), the nav shell,
Library, Search, Saved, Albums, Memories player, Detail/EXIF, and Settings.
The direction landed on **black / white / one spot red**, red scoped strictly
to *state* (never decoration), with `AppRadius` completely unchanged.

**Next step:** get this plan approved, then execute **Phase 0** only in this
session/PR. Later phases are separate follow-ups — see "Phasing" below for why.

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
| `SegmentedControl` (selected) | this is the current choice | bold weight; **decision needed**, see below |
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
2. **`FilterPill` active state:** keeps its `StadiumBorder` shape (per the
   corrections above, shape stays put). Change is: selected fill goes from
   `colors.pillActiveBg` to transparent/`scheme.surface`, selected border and
   text go from ink to `colors.accent`, weight goes to 700. This is a refinement
   on the spike's mockup, which dropped the pill shape entirely — dropping
   it isn't necessary once buttons/pills are confirmed exempt from the radius
   conversation, and keeping it is the smaller, safer diff.
3. **`SegmentedControl` selected state:** for consistency with `FilterPill`,
   drop the raised thumb (`_thumbRadius`, `scheme.surface` fill) and instead
   colour the selected label `colors.accent` + bold, on the plain recessed
   track. This is the one place a shape actually goes away — flag if you'd
   rather keep the thumb and only recolour the text on it (smaller diff,
   less consistent with the pill).
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

- [ ] **Phase 0 — Foundation** (this session, if approved)
- [ ] **Phase 1 — Shared widgets** (separate session)
- [ ] **Phase 2 — `ExifSheet` rebuild** (separate session)
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
- [ ] `tool/check.sh` passes.
- [ ] Every golden diff reviewed manually (list which screens changed and why
      in the commit message).
- [ ] No screen using `AppTextStyles` regressed to 3+ visually distinct
      weights on one view — spot-check Library ("all" filter) and Search
      results, the two screens flagged in the spike as exceeding three
      hierarchy levels.
- [ ] This plan doc checked off through Phase 0, "Next step" line updated to
      point at Phase 1.

---

## Phase 1 — Shared widgets

**Files:**
- `lib/widgets/filter_pill.dart` — selected state: fill →
  `Colors.transparent` (or `scheme.surface`), border colour → `colors.accent`
  (replace the `withAlpha(0)` transparent-border trick — selected now needs a
  *visible* border), text colour → `colors.accent`, text weight → override to
  `FontWeight.w700` at the call site (since the shared `filterPill` role is
  now flat 400). Update the doc comment (it currently says "inverts to the
  ink fill" — that's no longer true).
- `lib/widgets/consent_switch.dart` — `activeTrackColor`: `colors.pillActiveBg`
  → `colors.accent`. `activeThumbColor` can likely stay
  `colors.pillActiveText`/white — verify contrast against the new track.
- `lib/widgets/segmented_control.dart` — per decision #3: remove the
  `Positioned` thumb (`_thumbRadius`, the `scheme.surface` `DecoratedBox`),
  colour the selected label `colors.accent` + `FontWeight.w700` instead of
  `scheme.onSurface`. Simplifies the `Stack` to just the `Row` of labels.
- `lib/widgets/nav_pill_bar.dart` — the knob
  (`colors.pillActiveText` circle, lines ~56-94 per the spike's research) →
  `colors.accent`. Selected glyph colour, currently rendered in
  `pillActiveBg` so it reads atop the knob, needs to stay legible atop a red
  knob — likely switches to white/`pillActiveText` rather than
  `pillActiveBg`. Verify against both themes.
- `lib/widgets/indexing_dial.dart` — the `IndexingRingPainter` stroke colour
  (`colors.pillActiveText`) → `colors.accent`, **only while indexing is
  active** (it already renders `SizedBox.shrink()` when idle, so there's no
  "resting red" state to worry about).

**Tests:**
- Existing/new goldens for `filter_pill`, `theme_mode_picker` (per the
  existing code comment naming these two specifically), `nav_pill_bar`,
  `indexing_dial` — light and dark, selected and unselected/active and idle
  states.
- `consent_switch` golden if one exists, else a widget test asserting
  `activeTrackColor` resolves to `colors.accent`.
- Contrast check: white icon glyph on the red knob, in both themes.

**Definition of Done:** same shape as Phase 0 — `tool/check.sh`, goldens
reviewed, plan doc updated, plus one on-device pass tapping through nav tabs
and toggling a Search facet to confirm the instant (non-animated) state swap
still holds — this is exactly the kind of change the "fake-pairing" rule
exists for.

---

## Phase 2 — `ExifSheet` rebuild

**File:** `lib/features/detail/widgets/exif_sheet.dart`.

Replace the `Wrap(spacing: 28, runSpacing: 18)` of `_ExifChip`s
(`exif_sheet.dart:60-80`) with a flush-left two-column table: one row per
field, label column fixed-width, value column flexible, hairline row
dividers (`colors.border`), baseline-aligned. `exifKey`/`exifValue` roles
already exist and already carry the right weights post-Phase-0 — this phase
is layout only, not new tokens.

Also add the favourite-state mark from the spike (a small `♥ Favourited`
indicator using `colors.accent`) **only if** `PhotoDetailScreen` already
tracks favourite state at the point `ExifSheet` is built — check before
adding a new prop; don't thread new state through for a cosmetic add. If it's
not trivially available, drop this part of the phase and note it as a
follow-up rather than blocking the layout rebuild on it.

**Tests:** `test/features/detail/detail_goldens_test.dart` — this is a
layout change, so add explicit cases for: no-EXIF asset (existing empty-state
requirement in `PRD.md` §3.3), a full field set, and a long location string
(the old `Wrap` could reflow around long strings; a fixed-width table needs
to be checked for truncation/overflow handling).

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

---

## Phase 6 — Docs

Update `docs/design-system.md`:
- Add `accent` to the Colors table (`AppColors`), one row, noting it's the
  only colour token with semantic meaning tied to state, not surface.
- Update the Typography table's weight column for `sectionLabel`,
  `filterPill`, `button`, `exifValue`.
- Add a line to the Radius section or a new "Grid" section stating the
  s8-bleed-past-s16-margin pattern as a rule, not a per-file comment
  (currently scattered across `month_timeline.dart`, `library_section.dart`
  per the spike's citations).
- Add a short "Accent usage" note pointing at the rule this plan enforces:
  state only, never decoration — future contributors need this stated
  somewhere more durable than this plan doc, which gets pruned per
  `AGENTS.md`'s "prune task-scoped notes" rule once the work lands.

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

Get this plan approved. If approved, execute **Phase 0 only** in this
session — add the `accent` token and collapse the four weights, update the
two golden test files, and stop there for review before Phase 1 starts.
