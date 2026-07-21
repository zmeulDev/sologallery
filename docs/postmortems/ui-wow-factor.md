# UI Wow-Factor Pass

**PLAN COMPLETE** (2026-07-20). All five phases landed; `flutter analyze`
clean, 370 host tests green, `build_runner build` clean. Four real bugs
found and fixed — three via on-device patrol testing, one via the user's
own hands-on feel-check post-completion (all recorded in CLAUDE.md Known
gotchas — see "Bugs found" below for the short version). Seven on-device
checks passed (2× `detail_actions_test.dart`, 2× `hero_dismiss_test.dart`,
3× crash-free boot scans). Remaining "does it actually feel good" judgment
is the user's per the note below — see "Remaining for user" at the bottom.

## Post-completion fix (user feedback, same day)

User reported the drag-dismiss felt laggy: "app turns black and after an
animation moves the picture back to the grid." Root cause was **not**
performance — it was `_onPointerEnd`'s commit branch running its own
`_dismiss.animateTo(1, ...)` (shrink+fade to fully invisible, ~450ms) and
only calling `widget.onDismissed()` in `.whenComplete()` — i.e., pop
*after* the drag's own exit animation finished. Since the route's
`fadeThroughPage` + Hero pop transition then runs *on top of* an
already-invisible screen, the user saw: photo fades to nothing (screen
goes black) → pause → a *second*, seemingly unrelated animation flies the
photo back into the grid. Two sequential ~450ms animations, not one.

Fix: on commit, call `widget.onDismissed()` immediately instead of
animating first — hands off directly to the route's own Hero return-flight
from wherever the drag left off, so there's exactly one motion instead of
two. (Two smaller, real perf micro-optimizations landed in the same pass
while investigating — combined two nested `Transform` widgets, each
forcing its own compositing layer, into one composed-matrix `Transform`;
and stopped re-querying `MediaQuery.sizeOf` on every raw pointer-move
event, caching screen height once per drag instead. These were legitimate
cleanups but turned out not to be the actual cause of what the user was
seeing.) Verified: `test/features/detail/widgets/dismissible_photo_test.dart`
updated (dismiss now asserts immediately, no pump needed — previously
needed ~500ms), all 370 host tests still green,
`integration_test/hero_dismiss_test.dart` re-verified on-device with half
the previous pump budget (one ~450ms wait instead of two), confirming only
one animation now runs. A profile-mode build (not debug — debug Flutter
carries real overhead unrelated to code quality, and all earlier
verification this session was necessarily debug-mode) was built and
installed for the user to feel-check directly.

## Status

- [x] **Phase 0 — tokens:** `AppMotion.long` (450ms, hero/dismiss) and
  `AppMotion.stagger` (40ms/item offset) added to
  `lib/core/theme/app_motion.dart`.
- [x] **Phase 1 — Route transition layer: DONE.** `tool/check.sh`-equivalent
  green (360 host tests, `build_runner` clean).
- [x] **Phase 2 — Library entrance polish: DONE.** 364 host tests green
  (360 + 4 new `entrance_fade_test.dart`), analyze clean, on-device
  crash-free boot verified (Pixel 9 Pro XL, existing onboarded install).
- [x] **Phase 3a/3b — Grid ↔ Detail hero + interactive dismiss: DONE**
  (see notes below; two real gotchas found and fixed, verified on-device).
- [x] **Phase 3c — Memories cover Hero: DONE.** New
  `lib/features/memories/memory_hero_tag.dart` (`memoryHeroTag(int id)`);
  `MemoryCard`'s cover and `_TitleCard`'s cover both wrapped in
  `Hero(tag: memoryHeroTag(memory.id))` (only when a cover exists — no
  cover means no card-side Hero, matched by the same unmatched-tag
  fallback validated in 3a). `_TitleCard` gained a `memoryId` param.
  `/memory/:id` bumped to `base: AppMotion.long` in `fadeThroughPage`
  (was the Phase-1 default `medium`), matching `/photo/:id`'s room to
  travel. Verified: 367 host tests green (unchanged count — reuses the
  already-tested Hero mechanism, no new gesture logic), analyze clean,
  on-device crash-free boot with the memories carousel + new Hero code
  in the tree (Pixel 9 Pro XL).
- [x] **Phase 4 — Memories player Ken Burns + token cleanup: DONE.** New
  `lib/features/memories/widgets/ken_burns_photo.dart` (`KenBurnsPhoto`,
  scale 1.0→1.08 + `Alignment` drift over the page's dwell duration, drift
  direction alternates per-asset via id hash parity), wired into the
  player's `itemBuilder` in place of a bare `PhotoPage`. New
  `AppMotion.sceneChange` (320ms) token replaces the hardcoded value on
  the auto-advance `nextPage` call (kept the same 320ms — no visual
  reason found to change it). Verified: 370 host tests green (367 + 3 new
  `ken_burns_photo_test.dart`), analyze clean.
- [x] **Phase 5 — Onboarding choreography: DONE.** `OnboardingScreen.build()`
  wrapped in `AnimatedSwitcher` + `KeyedSubtree(key: ValueKey(step))` for a
  cross-fade between the access and consent steps (each keyed by step name,
  so arriving at either always replays its own entrance fresh). Both steps'
  headline block, each row (`_Assurance`/`_ConsentToggle`), and the
  button+caption block wrapped in `EntranceFade` at indices 1–5 (index 0
  deliberately unused here — see decisions). Verified: 370 host tests green
  (unchanged count net — fixed 4 pre-existing consent-step tests' pump
  timing along the way, see decisions), analyze clean, `build_runner`
  clean. **On-device**: re-ran `detail_actions_test.dart` (drives the real
  onboarding tap-Allow → grant → tap-Continue flow before opening a photo)
  — passed clean with the new choreography in place.
  - Decisions: **`EntranceFade`'s index-0 item renders already-visible on
    the first frame with no animation at all** (by design, for list
    sections where the first item shouldn't make the user wait) — wrong
    for a screen where the headline itself should visibly fade in. Onboarding
    starts indices at 1, not 0, so *everything* gets at least the minimum
    stagger delay and therefore actually animates. **Recording consent
    flips `showConsent` back to false** (access stays granted, but consent
    is no longer "needed"), which re-mounts the access step's own
    `AnimatedSwitcher` transition and fresh `EntranceFade` timers — the 4
    existing consent-step tests only pumped a bounded 50ms after tapping
    Continue/toggling a switch, which was already borderline before this
    phase and became a real "Timer still pending" teardown failure once
    the reveal timers existed; switched those to `pumpAndSettle()` (safe
    here — no perpetual spinner/focused TextField on this screen).
- Status: **plan complete**, all five phases done.

## Context

The UI System Refresh (commit `9a9e82a`, plan complete, see
`docs/plans/ui-system-refresh.md`) landed a disciplined minimalist token
system — warm off-white/near-black, no accent color, default typeface,
`AppSpace`/`AppRadius`/`AppMotion`/`AppOverMedia`. The app is correct and
consistent but quiet: nothing about using it feels remarkable. This pass
adds a motion/depth layer so the app has a wow factor, without touching
palette or type.

**Thesis:** in a photo app, the wow is the photos. The signature is
*continuity of the photo as a physical object* — it expands from its grid
cell, floats over a dimmed library, and drags back to exactly where it
lives. Spent across four surfaces: grid↔detail transitions, library
scroll feel, the memories player, and onboarding.

Locked constraints: no accent color/typeface change; 60fps scroll
inviolable, grid cells never get per-cell transforms
(`lib/widgets/pressable.dart:10-12`); every new duration is an `AppMotion`
token, reduced-motion (`MediaQuery.disableAnimations`) collapses to
`Duration.zero`; no new pub dependencies; confident-but-calm boldness
(Apple-Photos-class physicality, not showy).

Full design rationale, phase-by-phase file list, test plan, and risk
mitigations: see the approved plan captured at conversation time — summary
below; this doc is the living tracker, update it phase by phase.

## Phase notes (fill in as each phase lands)

### Phase 1 — Route transitions — DONE
Non-shell pushed routes (`/month/:key`, `/older`, `/settings`, `/people`,
`/person/:id`, `/album/:id`, `/folder`, `/memory/:id`) moved from
`builder:` to `pageBuilder:` + `CustomTransitionPage` (fade-through:
outgoing fades+scales down to 0.96, incoming fades+scales up from 0.96,
`AppMotion.medium`, `easeOutCubic`). Shell tab switches (`indexedStack`)
stay instant — untouched.
- Files: `lib/core/router/app_router.dart`, new
  `lib/core/router/fade_through_page.dart` (`fadeThroughPage<T>` helper).
- Decisions: **`/photo/:id` left on `builder:`** (Phase 3 gives it the
  Hero-driven page instead — fade-through there would be visual noise
  under the flight). **`/onboarding` left untouched** (gate/initial route,
  not a felt "push"). `fadeThroughPage` resolves its duration once via
  `AppMotion.of(context, AppMotion.medium)` at page-build time (not inside
  `transitionsBuilder`) so reduced motion collapses to a true zero-duration
  swap rather than an unanimated page held for `AppMotion.medium`. Each
  route's own `secondaryAnimation` (driven automatically by Flutter when
  another route covers it) supplies the "outgoing" half — no cross-route
  coordination needed since every route uses the same helper.
- Verified: 360 host tests green, `build_runner build` clean, `flutter
  analyze lib/core/router/` clean. Manual on-device pass still pending
  (bundle with Phase 2's device check).
- Status: **done**, on-device verification deferred to end of Phase 2.

### Phase 2 — Library entrance — DONE
One-time fade+translate for `_MonthSection`/`_OlderSection`, staggered by
index (capped at 6 → max 240ms), never per-grid-cell, never re-triggered
on scroll-back. New shared `EntranceFade` widget under `lib/widgets/`
(reused by Phase 5), wired in `_MonthList.itemBuilder` (wraps the section
widget it returns, keyed by the section's own `index`, not scroll
position — a fast scroll never leaves a stagger backlog since the delay
is per-widget wall-clock from its own build, not from list position).
Memories carousel scroll-parallax cut from scope up front (no
`CustomScrollView` present; too risky for the payoff).
- Files: `lib/features/library/library_screen.dart`, new
  `lib/widgets/entrance_fade.dart`, new
  `test/widgets/entrance_fade_test.dart`.
- Decisions: **`AppMotion.of` (hence `MediaQuery.of`) must be read in
  `didChangeDependencies`, not `initState`** — calling it in `initState`
  throws ("dependOnInheritedWidgetOfExactType called before initState()
  completed"), caught immediately by the existing
  `library_screen_test.dart` suite once wired in. `_EntranceFadeState`
  guards with a `_scheduled` bool since `didChangeDependencies` can re-fire
  on later inherited-widget changes but the entrance must only ever
  schedule once. `EntranceFade` reuses the exact `TweenAnimationBuilder<double>`-with-only-`end`-set idiom already established by `filter_pill.dart`
  (first build renders at `end` with no animation; only a later `end`
  change animates) rather than a raw `AnimationController`.
- Verified: 364 host tests green (360 + 4 new), `flutter analyze` clean,
  on-device crash-free boot on the already-onboarded Pixel 9 Pro XL
  install (logcat scanned for exceptions — none from the app process).
- Status: **done**.

### Phase 3 — Grid ↔ Detail hero + drag-dismiss (signature)

**3a — DONE.** `Hero(tag: assetHeroTag(id))` (new
`lib/widgets/asset_hero_tag.dart`) on every grid-cell call site
(`lib/widgets/asset_grid.dart`, `library_screen.dart` `_PreviewGrid`,
`saved_screen.dart` `_SavedGrid`, `album_detail_screen.dart` `_Grid`) and a
new `lib/features/detail/widgets/detail_stage.dart` (`DetailStage`) used by
detail's `_DetailPage`.

`DetailStage` design: the Hero's child is a `Stack` — a base
`AssetThumbnail` layer (the literal widget that flies — cover-fit, so it
always fills its rect regardless of the photo's real aspect ratio, avoiding
an un-crop-mid-flight look) that fades OUT once revealed, cross-dissolving
with `PhotoPage`/`VideoPage` (the real, possibly letterboxed contain-fit
content) fading IN — `_revealed` flips via a `ModalRoute.of(context)!
.animation` status listener (added/checked in `didChangeDependencies`, not
`initState`  — see decisions), so the swap happens exactly when the push
flight lands, never mid-flight, and both layers fading (not just one)
avoids the base thumbnail showing through contain-fit letterbox gaps.
`PhotoPage` gained an optional `transformController` param (unused until
3b) so an ancestor can read/gate on live pinch-zoom state without
`DetailStage`/`PhotoPage` needing to coordinate any other way.

`/photo/:id` moved to Phase 1's `fadeThroughPage` (reused, not a new
helper) with `base: AppMotion.long` — the Hero flight itself flies via the
Navigator's overlay independent of `transitionsBuilder`, so the surrounding
chrome's subtle fade+scale doesn't visually compete with it; this also
gives the route reduced-motion compliance for free.

- Decisions: **`AppMotion.of`/`MediaQuery.of` must be read in
  `didChangeDependencies`, same trap as Phase 2's `EntranceFade`** — applies
  wherever a State reads it and DetailStage's route-animation listener setup
  is similarly initState-unsafe (`ModalRoute.of(context)` also requires an
  attached element). **Cut candidate #1 (custom `flightShuttleBuilder`) was
  not needed** — the base-thumbnail-flies / real-content-cross-fades design
  sidesteps the aspect-mismatch problem without one, since the flying
  widget is *always* the same cover-fit square regardless of which asset's
  real aspect ratio it represents. Hero uniqueness is per-route, not
  app-wide, and no screen renders the same asset id twice within one route
  by construction, so no per-tag dedup logic was needed. Video controllers
  are NOT double-instantiated during the flight (Hero re-parents the actual
  subtree/State into the overlay, it doesn't build a second copy) — this
  was worth confirming since it looked like a risk on paper.
- Verified: 364 host tests green (incl. existing `detail_screen_test.dart`
  "a still renders a PhotoPage"/"a video renders a VideoPage" — `_revealed`
  resolves synchronously in `didChangeDependencies` when there's no
  enclosing route animation, e.g. a bare pumped widget, or when the initial
  route's animation is already completed), `flutter analyze` clean.
  **On-device**: ran the existing (unmodified) patrol suite
  `integration_test/detail_actions_test.dart` for real — "open a photo →
  favorite, view EXIF, add to album" passed on the Pixel 9 Pro XL against
  the real photo library, exercising the actual Hero open (grid tap) and
  close (back button, return flight) paths end-to-end, not just widget
  tests. Patrol's teardown uninstalled the app per the usual gotcha; a
  fresh onboarding + permission grant is needed before any further manual
  device check.

**3b — DONE.** Vertical drag-to-dismiss, tracked via raw `Listener`
(`onPointerDown/Move/Up`) rather than a competing `GestureDetector` — see
the two CLAUDE.md gotchas this phase added (AnimatedBuilder tree-shape
must stay constant across a gesture; `InteractiveViewer` can win the arena
over a sibling recognizer even with `panEnabled: false` and then do
nothing). `PhotoPage` gained a `panEnabled` param (default `true`,
harmless now that the dismiss gesture doesn't compete for the arena, but
still correct — nothing to pan at scale 1). Chrome fades via a
`ValueNotifier<double> _dragProgress` in `PhotoDetailScreen`, read by a new
`_dragFadedChrome` wrapper (multiplies the existing visible-driven opacity,
`IgnorePointer`s mid-drag) rather than threading progress through
`setState` (would rebuild the whole screen every drag frame).
- Files: new `lib/features/detail/widgets/dismissible_photo.dart`,
  `lib/features/detail/detail_screen.dart` (`PhotoDetailScreen`
  `_dragProgress`/`_dragFadedChrome`, `_DetailPage`),
  `lib/features/detail/widgets/photo_page.dart` (`panEnabled` param).
- Verified: 367 host tests green (incl. new
  `test/features/detail/widgets/dismissible_photo_test.dart` — small drag
  springs back, past-threshold drag dismisses, reduced motion dismisses
  without waiting), `flutter analyze` clean, `build_runner build` clean.
  **On-device**: new `integration_test/hero_dismiss_test.dart` passed
  against the real photo library and real `InteractiveViewer` (the host
  test alone couldn't have caught either arena bug — it stubs
  `detailImageProvider` to null bytes, so no real `InteractiveViewer` ever
  renders there, and its `onDismissed` was a plain flag, never exercising
  the real `Navigator.maybePop()`). `detail_actions_test.dart` (unmodified)
  re-ran clean too, confirming `panEnabled`/`Listener` didn't regress
  favorite/EXIF/add-to-album.
- Debugging note: `print`/`debugPrint` don't surface anywhere observable
  from `patrol test` (see CLAUDE.md gotcha) — root-caused both bugs via
  deliberate `expect()`/`fail()` messages instead.

### Phase 4 — Memories Ken Burns — DONE
Per-page slow scale (1.0→1.08) + `Alignment` drift via a per-page
`AnimationController` (duration passed in as the player's `pageDuration`,
not imported — avoids a circular dependency between the two files).
Wrapped the hardcoded 320ms `nextPage` transition in the new
`AppMotion.sceneChange` token (kept the 320ms value — no visual reason
found to change it).
- Files: new `lib/features/memories/widgets/ken_burns_photo.dart`,
  `lib/features/memories/memory_player_screen.dart`,
  `lib/core/theme/app_motion.dart` (`sceneChange`), new
  `test/features/memories/widgets/ken_burns_photo_test.dart`.
- Decisions: **the `AnimationController` must be created *unconditionally*
  in `initState()`, never as a `late final` field initializer** — a lazy
  initializer only runs on first access, and the reduced-motion branch of
  `build()` never touches it, making `dispose()` the first access, which
  throws (see CLAUDE.md gotcha). Whether it ever `.forward()`s is decided
  separately in `didChangeDependencies` (`MediaQuery.of` needs a safe
  context, not `initState`). `didUpdateWidget` restarts the drift only if
  the underlying `assetId` changed on the *same* State/Element — a
  defensive guard against `PageView.builder`'s unkeyed item reuse, not
  something exercised by normal swipe-through use.
- Verified: 370 host tests green (367 + 3 new — drift-over-duration,
  reduced-motion static-with-no-dispose-crash, restart on reused-state),
  `flutter analyze` clean.
- Status: **done**.

### Phase 5 — Onboarding choreography — DONE
See the Status entry above for the full writeup (step cross-fade via
`AnimatedSwitcher` + `EntranceFade` at indices 1–5, index 0 deliberately
unused, 4 pre-existing consent-step tests fixed for timer-teardown timing).
- Files: `lib/features/onboarding/onboarding_screen.dart`,
  `test/features/onboarding/onboarding_screen_test.dart`.
- Status: **done**.

## Test plan — outcome

What actually happened, vs. the plan's predictions:

- No new unit tests (held — no new pure-Dart domain logic across all five
  phases).
- Widget tests: the predicted `pumpAndSettle`-vs-continuously-scheduling-
  animation risk materialized, but in a *different* place than expected —
  not Ken Burns (its host tests never used `pumpAndSettle`) but the
  **pre-existing onboarding consent-step tests**, whose short 50ms bounded
  pumps became insufficient once `EntranceFade`'s staggered reveal timers
  existed on that screen (fixed by switching those specific tests *to*
  `pumpAndSettle`, the opposite direction from the original prediction —
  right call here since the screen has no perpetual spinner/TextField).
  New tests landed per phase as planned: `entrance_fade_test.dart` (4),
  `dismissible_photo_test.dart` (3, host — paired with the on-device
  `hero_dismiss_test.dart` per the fake-pairing rule), `ken_burns_photo_test.dart`
  (3, including the reduced-motion case that caught the `late final`
  controller bug). Total: 360 → 370 host tests.
- Goldens: held exactly as predicted — zero new goldens, zero churn on
  existing ones (motion is invisible to a static snapshot).
- Integration/patrol: `hero_dismiss_test.dart` added as planned (tap →
  Hero opens → drag down → dismiss → back on Library), verified on the
  Pixel 9 Pro XL against the real photo library and a real
  `InteractiveViewer` — this is specifically what caught the
  `panEnabled`/arena-competition bug and the sequential-animation pump-
  budget issue, neither of which the host test alone could have surfaced.
  `detail_actions_test.dart` (unmodified) re-verified clean after 3a/3b and
  again after Phase 5's onboarding changes.
- Manual on-device pass: done at crash-free-boot depth per phase (see
  the note below on verification depth) rather than full interactive
  patrol runs every time, given the time cost of each on-device round
  trip (~50s) — the two full patrol runs (`detail_actions_test.dart`,
  `hero_dismiss_test.dart`) covered the interaction-level risk directly.

## Bugs found (all recorded in CLAUDE.md Known gotchas — short version here)

1. **`AnimatedBuilder` tree-shape-must-stay-constant mid-gesture** —
   `DismissiblePhoto`'s original `if (t == 0) return child!;` shortcut
   disposed and reinflated the `GestureDetector` (and its gesture-arena
   membership) the instant a drag started, silently swallowing
   `onVerticalDragEnd`. Caught by a host test doing a real
   `startGesture`/`moveBy`/`up()` sequence.
2. **`InteractiveViewer` can win the gesture arena over a sibling
   recognizer even with `panEnabled: false`, then do nothing** — invisible
   on host tests that stub image bytes to null (no `InteractiveViewer`
   ever renders there). Fixed by tracking the dismiss drag via raw
   `Listener` pointer events instead of a competing `GestureDetector`.
   Only caught on-device, against a real photo.
3. **`late final AnimationController` only initializes on first access** —
   `KenBurnsPhoto`'s reduced-motion branch never touched it, so
   `dispose()` became the first access, unsafely looking up an ancestor
   after deactivation. Caught immediately by a host reduced-motion test.

Plus one process note: `print`/`debugPrint` do not surface anywhere
observable from a `patrol test` run (not the CLI output, not `adb logcat`)
— bugs 1 and 2 above were root-caused via deliberate `expect()`/`fail()`
messages instead, once print-based tracing came up empty twice.

## Risks — how they played out

- Hero + PageView tag tracking: held — Flutter's built-in unmatched-tag
  fallback worked as expected, no custom resolution logic needed.
- Gesture arena conflicts (drag-dismiss vs PageView vs InteractiveViewer):
  the actual highest-risk item, as predicted — but the real failure mode
  (`InteractiveViewer` winning the arena and going silent even with
  `panEnabled: false`) wasn't the dx/dy-disambiguation risk originally
  named; the eventual fix (raw `Listener`) sidesteps arena competition
  entirely rather than trying to out-prioritize it.
- FakeAsync hangs from new controllers: materialized, but on the
  onboarding tests rather than Ken Burns (see Test plan — outcome above).
- video_page dispose-on-deactivate racing dismiss: never actually
  triggered/tested — the drag-dismiss host+device tests both used photo
  assets, not video; worth a follow-up if video drag-dismiss matters.
- Scope cuts taken: custom hero `flightShuttleBuilder` was never needed
  (the base-thumbnail-flies/real-content-cross-fades `DetailStage` design
  sidestepped the aspect-mismatch problem it was meant to solve). Library
  scroll parallax was cut up front in Phase 2 as planned. Ken Burns kept
  both scale *and* a slight `Alignment` pan — not cut, ended up cheap
  enough to include.

## Remaining for user

- **Feel check, on-device.** Everything here is verified for correctness
  (tests, analyzer, two full interaction-level on-device patrol runs) but
  not for *delight* — whether the Hero flight timing, drag-dismiss
  spring-back, Ken Burns speed, and onboarding cadence actually feel right
  is inherently a judgment call. Worth a real hands-on pass: open several
  photos from different grids (library preview, month grid, saved,
  albums), drag-dismiss a few, play a memory through, and step through
  onboarding fresh (`adb uninstall com.zmeul.sologallery` first).
- **Reduced-motion pass.** Every new animated widget has a host test
  proving `Duration.zero`/no-animation behavior, but never confirmed
  end-to-end with the *system* reduced-motion setting toggled on a real
  device (Settings → Accessibility → Remove animations, or equivalent).
- **video_page + drag-dismiss.** Untested combination (see Risks above) —
  open a video from the grid and try the dismiss drag; the pause-on-
  deactivate path should still be fine since it's gated on commit state,
  not drag-in-progress, but it's never been exercised.
- Two follow-up ideas explicitly cut from this pass, not forgotten:
  library/memories-carousel scroll parallax (Phase 2), and a custom Hero
  `flightShuttleBuilder` if the default cross-fade ever looks wrong on an
  unusual aspect ratio in practice.

---

## Follow-up — 2026-07-21: memory player reverted on two of these

The hands-on "feel check" above happened, and two Phase-4 decisions did
not survive it.

- **Ken Burns removed.** `KenBurnsPhoto` and its test are deleted; the
  memory player renders a plain `PhotoPage` again. The drift read as
  restless on a story that already moves every 3s. The `late final
  AnimationController` gotcha it produced (CLAUDE.md) is kept — the
  lesson outlived the widget.
- **`/memory/:id` moved to `heroMediaPage`.** Phase 4 kept the route on
  `fadeThroughPage` because the title card's cover Hero sat behind the
  `memoryAssetsProvider` load and so had no destination on the first
  frame. The fade's partial opacity + 0.96 scale let the light shell
  bleed around the black stage — a visible white frame on open *and*
  close, which is the exact artifact `heroMediaPage` was written to kill
  on `/photo/:id`. Fixed at the source instead: the player now draws its
  title card from the `memoriesProvider` summary (already in memory —
  the carousel is holding it), so the cover Hero is up on frame one and
  the photo list only decides how many pages follow. `_pages` stays 0
  until the photos land, which parks the clock, and `_advance` returns
  early there so a tap on the opening card can't read as end-of-story.
