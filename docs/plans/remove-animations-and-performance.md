# Remove all animation + performance pass

Status: **Part 2 (performance) COMPLETE and verified on device.
Part 1 A1 (router & Hero teardown) shipped and on-device verified.
Part 1 A2 (retire `EntranceFade` + migrate memory-player scene motion off
`AppMotion`) shipped and on-device verified.
Part 1 A3 (widget-by-widget deletion — every remaining animated widget
converted to an instant state change; `Pressable` deleted) shipped and
on-device verified.
Part 1 A4 (drag-dismiss + double-tap zoom in `dismissible_photo.dart` →
instant; `detail_screen` chrome drag-fade + `AnimatedOpacity` removed;
`detail_stage` 1080 underlay retired; `app_motion.dart` deleted) SHIPPED and
host-verified — on-device + human-eye E2E still pending.**
Branch: `feature/metadata-search` (consider branching `feature/no-motion` for Part 1)
Next step: on-device patrol run of `hero_dismiss_test` + `detail_actions_test`
+ `nav_shell_test` on Pixel 9 Pro XL (`46121FDAS008AA`), one file per run,
re-granting permissions between runs per CLAUDE.md. Then human-eye manual E2E:
does the no-feedback drag-dismiss and the instant double-tap zoom read as
*snappy* vs *broken*? If the drag-dismiss reads as broken, the documented
escape hatch is to keep the `Transform` (direct manipulation, zero
time-based motion) and drop only the opacity — decide on device, not here.

## Part 2 completion record (2026-07-22)

Shipped P1, P2, P3 (reworked), P5. P4 partly obsoleted, P6-P8 deferred.

| Item | Outcome |
|---|---|
| P2 thumbnail gate | `lib/services/thumbnail_gate.dart` — LIFO queue, cap 6, cancels queued requests whose provider was disposed. Wired via `PhotoLibraryService.thumbnail(..., cancelled:)` and `thumbnailProvider`'s `ref.onDispose`. `previewImage` deliberately **not** gated so the detail viewer never queues behind a grid fling. |
| P1 FolderList | Now a **sliver** (`SliverPadding` + `SliverGrid`), mounted directly in the Albums `CustomScrollView`. Was a `shrinkWrap`ped `GridView` in a `SliverToBoxAdapter`, so it built and 18-sigma-blurred every folder cover up front. **Breaking widget-API change** — it must never go back inside a `SliverToBoxAdapter`. |
| P3 avatar edge | **The original finding was wrong** and was not implemented as written. `FaceAvatar` renders a *zoomed crop*, so comparing full-image pixels to the 64pt circle understated the requirement — 1024 is roughly right for a face filling ~15% of the frame, and dropping to 256-384 would have visibly softened group-photo avatars. Implemented instead: `avatarThumbEdge()` derives the edge from the face box's own normalized extent and snaps to buckets `[256, 384, 512, 768, 1024]`. Large faces get 256-384; small faces keep the 1024 ceiling. |
| P5 cacheExtent | `kPhotoGridCacheExtent` in `asset_grid.dart`, applied to `AssetGrid`, Saved, Library timeline, People. Uses `ScrollCacheExtent.viewport(1)` — `cacheExtent` is **deprecated** in this Flutter (use `scrollCacheExtent`), and a viewport multiple beats a pixel count on tablets. Safe only because P2 bounds the requests it generates. |
| P4 RepaintBoundary | Deferred. Most of the cost was the dial's `TweenAnimationBuilder`, which **Part 1 A3 deletes anyway**. Re-measure after Part 1; add the boundary then if anything remains. |
| P6-P8 | Deferred as planned (isolate temp-file I/O, derived thumbnail sizes, `itemExtent`). |

### Verification
- `tool/check.sh` green: analyze clean, 648 host tests, goldens byte-identical.
- New host tests: `test/services/thumbnail_gate_test.dart` (6), `avatarThumbEdge` group in `test/features/people/face_avatar_test.dart` (8).
- New device test: `integration_test/thumbnail_gate_test.dart` (5) — the fake-pairing counterpart. Proves against real `photo_manager` that a 24-request burst through a cap of 6 fully resolves, that cancellation skips exactly the cancelled half without starving the rest, that no slot leaks, and that **aspect-fill holds at every bucket** (short edge == requested).
- Device (Pixel 9 Pro XL): `folders_ui`, `nav_shell` (×3), `saved_albums`, `detail_actions`, `cache_live_update`, `search`, `thumbnail_gate` all pass.

### `nav_shell_test` traversal rewrite — read this before touching that test
"Scrolled to the end, Library clears the nav capsule" started failing under the
larger cache extent. It was **not** a padding regression; the test was measuring
the wrong thing in two ways, and the bigger extent only exposed it.

1. It measured the lowest of *all* matching widgets. A scroller pre-builds
   children past the viewport, so with a screenful of cache extent those sit
   below the capsule by construction. Now filtered to widgets actually inside
   the viewport, and it asserts at least one qualified (or it proves nothing).
2. It walked to the end with `position.jumpTo(pixels + 1000)`, capped at 200
   iterations — about 150,000px of travel needed on this library, so it simply
   ran out and measured mid-list. Worse, `jumpTo` leaves the position wherever
   it is put: two runs ended with `pixels` **greater than** `maxScrollExtent`
   (37,337 of 36,688), an overscroll a real fling resolves ballistically and a
   jump never does. Replaced with `fling` + a bounded settle pause per
   iteration, which also lets the growing-window pagination and the thumbnail
   decodes keep up — the behaviour actually worth testing.
3. The fling must target the **vertical** scroller via `find.byWidget(state.widget)`.
   `find.byType(Scrollable).first` is the Library's horizontal filter bar, and a
   vertical fling on it moves nothing, so the walk "finished" at pixel 0.

The walk now ends only when the position has stopped moving **and**
`maxScrollExtent` has stopped growing — either alone is a false finish, because
paging in more rows pushes the end away exactly as the position lands on it.
Three consecutive clean runs.

---

## Goal

1. Strip decorative motion from the app so the UI is instant everywhere.
2. Land the performance fixes the same audit turned up (independent of 1).

## Scope decisions (locked by the user, do not re-litigate)

| Decision | Choice |
|---|---|
| Strategy | **Physical deletion.** Delete the animated widgets and retire `AppMotion`/`EntranceFade`. Not a runtime kill switch — CLAUDE.md forbids leaving dead scaffolding. |
| Hero flights | **Remove.** All 7 `Hero` sites + the `HeroMode` branch gating go. |
| Drag-dismiss visual feedback | **Remove.** The photo no longer visibly tracks the finger. Gesture itself stays. |
| Material defaults (dialogs, sheets, snackbars) | **Keep.** `showDialog` / `showModalBottomSheet` / `SnackBar` keep Flutter's built-in transitions. No `PageTransitionsTheme` override. |
| Memory-player scene transitions | **Keep.** The 320 ms cross-slide between story photos stays. |

Because `sceneChange` + `curve` survive, `AppMotion` is deleted with those two
values **inlined as private consts in `memory_player_screen.dart`**, along with
a local `MediaQuery.disableAnimations` check to preserve today's
reduced-motion behaviour (jump-cut instead of slide).

## What is NOT animation (do not touch)

The audit found five things that read as motion but are gesture or state.
Deleting any of them removes a feature:

- `DismissiblePhoto`'s raw `Listener` gesture path — axis lock, tap/double-tap
  disambiguation, dismiss threshold. Only its *visual* output is in scope.
- The detail `PageView` (swipe prev/next) and its fling physics.
- `InteractiveViewer` pinch-zoom.
- The memory player's 3-second auto-advance `Timer` (`pageDuration`).
- Every `CircularProgressIndicator` and `VideoProgressIndicator` — these convey
  real state. (Note the CLAUDE.md gotcha: they are also why `pumpAndSettle`
  hangs on loading branches. That trap does not go away.)

---

# Part 1 — Animation removal

## Inventory (28 sites audited; 20 files)

### A1. Router & Hero teardown — do this first, it is the riskiest
- [x] `lib/core/router/fade_through_page.dart` — **deleted.** Both
      helpers collapse to `NoTransitionPage` (confirmed present in
      go_router 17.3.0, `custom_transition_page.dart:166`).
- [x] `lib/core/router/app_router.dart:70,79,88,97,108,122,140` — seven
      `fadeThroughPage(...)` → `NoTransitionPage(key: state.pageKey, child: …)`.
- [x] `app_router.dart:155,174` — two `heroMediaPage(...)` → `NoTransitionPage`.
      Safe: `heroMediaPage` already returned the child untouched and opaque, so
      there is no white-frame bleed to reintroduce (see that gotcha in CLAUDE.md
      — it stays true, the fade was never there).
- [x] `app_router.dart:244-266` — deleted `HeroMode` from `_BranchContainer`; the
      `IndexedStack`/`StackFit.expand` rebuild stays (load-bearing for branch
      state). Deleted the HeroMode doc-comment blocks.
- [x] Deleted `Hero` wrappers at `asset_grid.dart`, `library_screen.dart`,
      `saved_screen.dart`, `album_detail_screen.dart`, `detail_stage.dart`,
      `memory_card.dart`, `memory_player_screen.dart` (and the stale clip/Hero
      comments around them).
- [x] Deleted `lib/widgets/asset_hero_tag.dart` and
      `lib/features/memories/memory_hero_tag.dart` (no callers remain).
- [~] `detail_stage.dart` — the `Hero` wrapper is removed (A1). **The
      `AnimatedOpacity`→conditional-swap + 1080-underlay retirement is DEFERRED
      to A4.** Reason: it is entangled with `DismissiblePhoto`'s double-tap zoom
      animation, whose `_zoom` `AnimationController` is restarted from a
      completed-and-stopped state on the second double-tap. `dismissible_photo
      _test.dart`'s "a second double tap returns to fit" relies on the 1080
      underlay's async thumbnail load (via `ThumbnailGate`) to schedule the
      extra ticker frame that settles that restart; removing the underlay (or
      making it transient via a provider gate) breaks the reset. A4 rewrites the
      zoom to an instant transform write (deleting `_zoom`/`_zoomAnimation`),
      which removes the animation-timing coupling entirely — so the underlay
      retirement folds into A4 cleanly. Verified by isolation: the original
      structure (with 1080) passes; `Stack([PhotoPage])` alone fails; adding
      the 1080 back passes; the failure is timing, not logic. The audit-#3
      memory win (1080 dropped instead of held ~6 MB × live pages) lands with
      A4.

**Consequence shipped:** tapping a photo is a hard cut from grid to fullscreen,
and closing is a hard cut back. `flutter analyze` clean; 653 host tests pass
(goldens byte-identical, `dismissible_photo_test` 16/16, `detail_screen_test`,
`memory_player_screen_test` green). Test edits: `memory_player_screen_test`
dropped its `find.byType(Hero)` assertion; `hero_dismiss_test`'s stale
`fadeThroughPage`/`AppMotion.long` comment updated (its opacity/drag assertions
still hold — `DismissiblePhoto` is A4's domain, untouched here).

**On-device (Pixel 9 Pro XL `46121FDAS008AA`, patrol) — VERIFIED 2026-07-23:**
`hero_dismiss_test` 1/1 ✅ (hard-cut open + drag-dismiss under real touch);
`nav_shell_test` 5/5 ✅ (incl. the previously-flaky "scrolled to the end,
Library clears the nav capsule" — clean this run); `detail_actions_test` 3/3 ✅,
2 skipped (the limited-access/delete + share cases, as expected; incl. "double
tap zooms in on a real photo, and back out", which confirms the zoom toggle the
host test struggled with works fine in production). No A1 regressions. **Still
pending: human-eye manual E2E** — whether tap-to-open reads as *instant* vs
*broken* (the hard-cut open is A1's; the no-feedback drag-dismiss is A4's to
change). That is the user's to judge on the running app, not a test.

### A2. Retire the motion primitives
- [x] `lib/widgets/entrance_fade.dart` — **deleted** (and
      `test/widgets/entrance_fade_test.dart`).
- [x] Removed all `EntranceFade(...)` call sites, unwrapping to the bare
      child: `onboarding_screen.dart` (9 sites: 5 in the access step, 4 in the
      consent step) and `library_screen.dart` (2 sites: `_MonthList` and
      `_YearList` itemBuilders). The `_MonthList` `row is MemoriesRow ? child
      : EntranceFade(...)` collapsed to `return child;` (both branches now
      identical). Imports removed.
- [x] `lib/core/theme/app_motion.dart` — **kept for now**; A3/A4 still
      reference it (filter_pill, pressable, nav_pill_bar, segmented_control,
      asset_thumbnail, indexing_dial, people_screen, video_page, onboarding's
      AnimatedSwitcher, detail_stage, detail_screen, dismissible_photo). Delete
      after A4. Migrated `sceneChange` (320 ms) and `curve` (`Curves.easeOutCubic`)
      into `memory_player_screen.dart` as file-private `_kSceneChange` /
      `_kSceneCurve`, with a `MediaQuery.disableAnimationsOf(context)` guard
      replacing `AppMotion.of` in `_advance`. **Note:** the existing
      `nextPage` curve was `Curves.easeOut`, not `AppMotion.curve` — A2
      standardizes it to `_kSceneCurve` (`easeOutCubic`) per the plan/Design
      system; a negligible change to the one kept motion. The pause-dim
      `AnimatedOpacity` at `_Progress` still uses `AppMotion.medium` — A3
      converts that to a plain `Opacity`.

**A2 shipped & verified (2026-07-23):** `flutter analyze` clean; 649 host
tests pass (goldens byte-identical — entrance-fade removal changes no
post-settle end state). Device (Pixel 9 Pro XL, patrol): `nav_shell_test` 5/5
×2 stable, `hero_dismiss_test` 1/1 — both drive the A2-touched onboarding flow.
The memory-player scene change is host-covered (`memory_player_screen_test`) and
not exercised by `memories_test` (which tests generation, not the player UI), so
no separate device run was added for it.

**Drive-by fix — `nav_shell_test` "scrolled to the end" was flaky, now stable.**
The case failed 3× in a row post-A2 (the plan's earlier "passes on re-run" no
longer held). Root cause is NOT A2: the fling used
`find.byWidget(scrollable.widget)` — an instance-based finder. The Library
timeline is a growing-window watch, so an emission between capturing the
`ScrollableState` and the first fling rebuilds the `ListView` and swaps in a new
`Scrollable` widget instance; the captured-instance finder then matches zero and
`fling` throws. A2 removing `EntranceFade`'s delayed `setState`s only *reduces*
rebuilds, so it can't cause this — it shifted the race window. A type/axis
predicate was too broad (4 vertical Scrollables: the timeline plus the
`NeverScrollable` shrinkWrap preview grids). Fix: fling from the captured
`ScrollableState`'s own render-box centre via `tester.flingFrom` — the state and
its `position` persist across the rebuild (same element, retyped widget), so the
gesture lands on the right viewport with no finder at all. Two consecutive 5/5
runs. Gotcha added to CLAUDE.md.

### A3. Widget-by-widget deletion — COMPLETE
Each becomes an instant state change; the callback/state it wraps is untouched.

| File:line | Delete | Becomes |
|---|---|---|
| `widgets/filter_pill.dart:37-72` | `TweenAnimationBuilder` colour lerp | direct conditional colours. `Material(animationDuration: Duration.zero)` kept — it is now doing the real work, not compensating. |
| `widgets/pressable.dart` | `AnimatedScale` (+ the whole widget) | **`Pressable` deleted.** Once the scale went, the `_pressed` state and `Listener` were dead (nothing consumed press state), so per "no dead code" the widget was removed and its 4 call sites (`album_card`, `memory_card`, `folder_list`, people card) collapsed to plain `GestureDetector(onTap/onLongPress, behavior: opaque)`. |
| `widgets/nav_pill_bar.dart:85-98` | `AnimatedPositioned` knob | `Positioned` — knob teleports. |
| `widgets/nav_pill_bar.dart:188-196` | `AnimatedSwitcher` on the icon | plain `Icon`. The `duration` plumbing through `_NavItem` went with it. |
| `widgets/segmented_control.dart:69-83,97-109` | `AnimatedPositioned` thumb, `AnimatedDefaultTextStyle` | `Positioned` + `DefaultTextStyle`. |
| `widgets/asset_thumbnail.dart:47-65` | `AnimatedSwitcher` reveal | conditional placeholder → `Image.memory` (already had `gaplessPlayback: true`). The `_fillLayout` helper went with the switcher; the placeholder's now-unused `{super.key}` was dropped too (analyze flagged it). |
| `widgets/indexing_dial.dart:56-69` | `AnimatedSwitcher` (fade+scale in/out) | conditional — dial pops in/out, slot still reserved. |
| `widgets/indexing_dial.dart:101-113` | `TweenAnimationBuilder` ring sweep | `CustomPaint` paints `done` directly. The ring still shows true progress; it steps instead of sweeping. |
| `features/people/people_screen.dart:273-280` | `AnimatedOpacity` on `_SelectedRing` | plain `Opacity(opacity: selected ? 1 : 0)` — kept the "always built, never conditional" tree shape (the structural-instability bug class). |
| `features/detail/widgets/video_page.dart:91-98` | `AnimatedOpacity` play glyph | `value.isPlaying ? SizedBox.shrink() : _PlayGlyph()`. |
| `features/onboarding/onboarding_screen.dart:81-93` | `AnimatedSwitcher` step cross-fade | `KeyedSubtree` kept (the re-mount is functional); only the switcher wrapper went. Hard cut between steps. |
| `features/memories/memory_player_screen.dart:234-238` | `AnimatedOpacity` pause dim | `Opacity(opacity: paused ? 0.35 : 1)`. This was the file's last `AppMotion` reference — its import went too (A2 had already inlined the scene consts as `_kSceneChange`/`_kSceneCurve`). |

**A3 shipped & verified (2026-07-23):** `flutter analyze` clean (the one
remaining `info` was a pre-existing `use_build_context_synchronously` in A2's
`nav_shell_test` fling helper — silenced with a targeted `// ignore:` since
the `ScrollableState` is known alive; not introduced by A3). `tool/check.sh`
green: 644 host tests, goldens byte-identical (every golden pins a post-settle
end state, so instant state changes move nothing). Completion oracle —
`grep -rn "AppMotion\|EntranceFade\|Hero(\|HeroMode\|AnimatedSwitcher\|…"
lib/` — returns only `app_motion.dart` itself and the three A4 files
(`detail_screen`, `dismissible_photo`, `detail_stage`); no A3 file retains any
animation reference.

Test edits: deleted `test/widgets/pressable_test.dart` (subject deleted);
`folder_list_test` and `integration_test/folders_ui_test` swapped their
`find.byType(Pressable)` tile-count oracle for `find.byType(ClipRRect)` (each
folder tile is a `ClipRRect`, which `tileAt` already used);
`nav_pill_bar_test` folded the vacuous reduced-motion case into "the knob sits
over the active destination, with no travel" (asserts the knob lands on the
next frame and doesn't drift — the old reduced-motion-only behaviour is now
the only behaviour) and dropped the `reduced` param; `asset_thumbnail_test`,
`onboarding_screen_test`, `indexing_dial_test` had stale `AnimatedSwitcher`/
fade comments updated (the pumps themselves stayed — waiting longer than
needed is harmless, and `pumpAndSettle` is still safe on the onboarding
consent step, which has no spinner).

Device (Pixel 9 Pro XL `46121FDAS008AA`, patrol): `nav_shell_test` 5/5 ✅
(drives the instant nav knob, the onboarding hard-cut, and the indexing dial
that rides on the bar — incl. "the indexing dial rides right of the capsule
while analysing" and "scrolled to the end, Library clears the nav capsule");
`folders_ui_test` 1/1 ✅ (folder tile tap with the new `GestureDetector` +
`ClipRRect` oracle). No A3 regressions. **Still pending: human-eye manual E2E**
on whether the now-instant control changes (pill select, knob teleport,
segmented thumb jump, dial pop) read as *snappy* vs *jarring* — that is the
user's to judge on the running app, not a test. `hero_dismiss_test` and
`detail_actions_test` are A1/A4's domain (A3 did not touch `dismissible_photo`
or the detail chrome) and were not re-run for A3.

### A4. Drag-dismiss visuals — `dismissible_photo.dart` — COMPLETE (host-verified)
This is the most delicate edit in the plan.

- [x] Replace the `_dismiss` `AnimationController` (`:86-89`) with a plain
      `double _progress` field. No ticker, no `vsync` for it.
- [x] Delete the `AnimatedBuilder` + `Opacity` + `Transform` in `build()`
      (`:318-349`). `Listener` → `RepaintBoundary` → `DetailStage` directly.
      The "constant tree shape" gotcha becomes moot — the shape is now trivially
      constant, which is the safest possible outcome for that bug class.
- [x] `:242-244` — the spring-back `animateTo(0, ...)` is gone. On a
      sub-threshold release there is nothing to spring back to (the photo
      never moved), so it just resets `_progress` for the next gesture.
- [x] `:230` — the threshold check (`> 0.3 || velocity > 800`) reads `_progress`
      (captured before the per-gesture reset). **Unchanged behaviour.**
- [x] `_zoom` controller (`:94-97`, `:285-292`): double-tap zoom is an instant
      transform write — `_transformController.value = target` directly. Deleted
      `_zoom`, `_zoomAnimation`, `_applyZoomFrame`, the `Matrix4Tween`/
      `CurvedAnimation`, and `TickerProviderStateMixin`. The *gesture*
      (double-tap zooms to the tap point, second double-tap returns to fit) is
      fully preserved; only the 150 ms travel went. Per the scope rule this is
      time-based decorative motion and was removed (the user said "start" with
      the plan as written).
- [x] `onProgress` (`:63,:71`) deleted from the widget API — its only consumer
      was the chrome drag-fade, which is gone.
- [x] `detail_screen.dart:117-128` — deleted `_dragFadedChrome` and the
      `_dragProgress` `ValueNotifier`; chrome no longer reacts to drag. The
      `_DetailPage.onDragProgress` plumbing went with it.
- [x] `detail_screen.dart:239-252` — `_Chrome`'s `AnimatedOpacity` → plain
      `Opacity(opacity: visible ? 1 : 0)`, kept the
      `IgnorePointer(ignoring: !visible)`.
- [x] Rewrote the class doc-comment. The recognizer-free-gesture rationale
      stayed; the `AppMotion` reference and the "follows the finger, springs
      back, Hero return-flight" wording went.
- [x] `detail_stage.dart` — retired the 1080 base-thumbnail underlay. With
      route transitions gone (A1) and the zoom now instant (A4), the
      `_revealed` cross-fade + `AnimatedOpacity` layers were dead (the underlay
      had been at opacity 0 since A1). Simplified `DetailStage` to a stateless
      page selector; deleted the `_routeAnimation`/`_revealed` state, the
      `AssetThumbnail` 1080 underlay, and the `AppMotion`/`asset_thumbnail`
      imports. Frees the ~6 MB the 1080 underlay held per live page (audit #3).
- [x] Deleted `lib/core/theme/app_motion.dart` and its `export` in
      `app_theme.dart` — no `AppMotion` references remain in `lib/`.

**Drive-by fix — `DismissiblePhoto`'s `Listener` is now
`HitTestBehavior.opaque`.** Retiring the 1080 underlay (A4) also removed the
full-bleed hit surface it gave the stage: the underlay's `AssetThumbnail`
filled the `StackFit.expand` stack, so taps anywhere hit the `Listener`
(`deferToChild`, the default). With the underlay gone, the stage's hit area
is whatever `PhotoPage` paints — a real image's `Image.memory(
width/height: double.infinity)` still fills it, but the broken-image fallback
`_Unavailable` is a 44 px centred icon, so taps off it fell through to nothing
and the drag/tap gesture never saw them. Surfaced by the host test
`dismissible_photo_test`'s "a second double tap returns to fit", whose second
pair taps off-centre — the second `_handleDoubleTap` never fired. Making the
`Listener` opaque makes the whole stage hit-testable regardless of what the
page paints (a strict improvement: tap-to-toggle chrome now works on a missing
image too); in production, where the image fills the stage, it changes
nothing. Gotcha added to CLAUDE.md.

**Known consequence:** dragging down produces no visual response at all until
it crosses the threshold and the route pops. If that reads as broken in manual
testing, the one-line escape hatch is to keep the `Transform` (direct
manipulation, zero time-based motion) and drop only the `Opacity`. Decide on
device, not here.

**A4 shipped & host-verified (2026-07-23):** `flutter analyze` clean;
`tool/check.sh` green (build_runner clean, 643 host tests, goldens
byte-identical — instant state changes move no post-settle end state).
Completion oracle `grep -rn "AppMotion\|EntranceFade\|Hero(\|HeroMode" lib/`
returns **nothing**; `app_motion.dart` is deleted. Test edits:
`dismissible_photo_test` dropped `onProgress`/`disableAnimations` params + the
MediaQuery builder; the "small drag reports progress then springs back" case
became "a small drag below the threshold does not dismiss"; the reduced-motion
case was deleted (vacuous — no animation remains); the double-tap zoom cases
pump one frame instead of 200 ms (the zoom is now an instant transform write).
`hero_dismiss_test` dropped the mid-drag `Opacity` read (the `Opacity`/
`Transform` are gone) and asserts the route pops back to the grid; the test
name/description dropped "Hero" (the **file** name was kept to preserve the
documented `patrol test -t integration_test/hero_dismiss_test.dart` command —
the plan's "renamed" was cosmetic and not worth churning the invocation).
`detail_screen_test` needed no edits — it tests via the public screen and
never asserted on drag-fade.

**On-device (Pixel 9 Pro XL `46121FDAS008AA`, patrol) — VERIFIED 2026-07-23:**
`hero_dismiss_test` 1/1 ✅ (hard-cut open + drag-dismiss past threshold pops
back to the grid under real touch — no in-flight opacity to read anymore);
`detail_actions_test` 3/3 ✅, 2 skipped (the limited-access delete + share
cases, as expected) — incl. "double tap zooms in on a real photo, and back
out", which confirms the instant transform-write zoom and the second-tap
return-to-fit work against a real `InteractiveViewer` + real image (the host
test stubs the image to null); `nav_shell_test` 5/5 ✅ (instant nav knob,
onboarding hard-cut, indexing dial — incl. "the indexing dial rides right of
the capsule while analysing" and "scrolled to the end, Library clears the nav
capsule"). No A4 regressions. **Still pending: human-eye manual E2E** —
whether the no-feedback drag-dismiss and the instant double-tap zoom read as
*snappy* vs *broken* to a person on the running app (the documented escape
hatch if the drag-dismiss reads as broken: keep the `Transform`, drop only the
opacity). That is the user's to judge, not a test.

---

# Part 2 — Performance

Independent of Part 1. Ordered by expected impact.

### P1 — HIGH: `FolderList` builds and blurs every folder up front
`lib/widgets/folder_list.dart:47-67`, mounted at `albums_screen.dart:190`.
A `GridView.builder` with `shrinkWrap: true` + `NeverScrollableScrollPhysics`
inside a `SliverToBoxAdapter` is laid out against infinite extent, so
`RenderSliverGrid` builds **every** child to discover its own height. Each tile
(`:103-119`) additionally runs
`ImageFiltered(ImageFilter.blur(sigmaX: 18, sigmaY: 18))` — a real Gaussian
pass. A typical Android device has 15-40 folders, so opening Albums decodes and
blurs all of them on the first frame.

**Fix:** hoist it into the Albums `CustomScrollView` as a real `SliverGrid` (no
nested shrink-wrap) so only visible tiles build and blur.

### P2 — MED-HIGH: unbounded, uncancellable thumbnail requests
`lib/services/thumbnail_provider.dart:30-37`, `widgets/asset_thumbnail.dart:38-40`.
No concurrency cap, no queue, no cancellation. `FutureProvider.autoDispose`
disposing when a cell scrolls off does **not** cancel the in-flight native
`thumbnailDataWithSize` call — it runs to completion and the result is thrown
away. A fast fling queues dozens of overlapping native decodes for cells that
are no longer on screen, competing with the visible ones for the same native
decode threads.

**Fix:** a semaphore in the service capping concurrent
`thumbnailDataWithSize` calls (start at 6-8), plus a pre-flight check that drops
a request whose provider was already disposed. This is the single most likely
source of fling jank on a large library.

### P3 — MED: People avatars over-fetch by ~8×
`lib/features/people/widgets/face_avatar.dart:22,28` requests `_avatarEdge = 1024`
— per the CLAUDE.md aspect-fill gotcha that returns ≈1365×1024 for a 4:3 source
— to paint a circle displayed at 64 logical px (≤192 px at 3× DPR). Every
visible avatar on People / Albums / Search pays this simultaneously on first
paint.

**Fix:** drop to 256-384. Face boxes are stored normalized `[0,1]` (schema v7),
so any returned size still maps correctly — this is exactly the case that
normalization was introduced to make safe.

### P4 — MED: `IndexingDial` repaints the whole nav bar
`widgets/indexing_dial.dart:101-127` sits as a `Positioned` sibling of the nav
capsule in the same `Stack` (`nav_pill_bar.dart:137-148`) with no
`RepaintBoundary` between them. Its ring re-tweens on roughly every indexed
asset — i.e. continuously, while the user is scrolling — so its paint
invalidation can drag the nav bar (visible on every screen) into repainting on
top of the grid's own scroll repaints.

**Fix:** wrap `IndexingDial` in a `RepaintBoundary`. Note **A3 already deletes
the ring's tween**, which removes most of this cost — do P4 *after* Part 1 and
re-measure; the boundary is still correct but may be all that is left to do.

### P5 — MED-LOW: no `cacheExtent` on any scroll view
`asset_grid.dart:37-77`, `saved_screen.dart:90-113`,
`library_screen.dart:146-153`, `people_screen.dart:118-135`. A fast fling
outruns the default pre-build buffer and shows placeholder flashes.
**Fix:** explicit `cacheExtent` (800-1500) on the photo grids. Do this *with*
P2, not instead of it — a bigger buffer without a request cap makes P2 worse.

### P6 — LOW: file I/O for ML temp JPEGs on the UI isolate
`services/indexing_service.dart:711-750` (`_indexOne`) does
`File.writeAsBytes` / `.exists()` / `.delete()` on the main isolate, once per
asset, for both the 512 label/face thumb and the 1024 OCR thumb. The ML compute
is correctly off-isolate; this surrounding I/O is not, and CLAUDE.md's "never
block the UI isolate" covers it.
**Fix:** hand the worker raw bytes and let it write/delete its own temp files.
Touches the isolate protocol — treat as its own task, not a drive-by.

### P7 — LOW: hardcoded thumbnail sizes, unverified against cell width
`asset_grid.dart:70` (400), `library_screen.dart:416` (300),
`saved_screen.dart:135` (500), `album_card.dart:49` (500),
`memory_card.dart:69` (500). Ballpark-correct today but derived from nothing, so
a future column-count or spacing change silently starts over- or under-fetching.
**Fix:** derive from measured cell width × `devicePixelRatioOf(context)`, or at
minimum add a comment tying each constant to its layout.

### P8 — LOW: `itemExtent`/`prototypeItem` on uniform strips
`memories_carousel.dart:45-58` and `widgets/people_strip.dart:85-98` are
fixed-width horizontal lists that could take the O(1)
`findChildIndexForOffset` fast path. Both are short; minor win.

### Audited clean — no action
- **No N+1 queries.** `index_dao.dart` uses grouped/joined single queries
  throughout; no DAO call inside any `itemBuilder`.
- **Riverpod scoping matches convention** — DB/indexing alive at the root,
  screen-scoped providers `autoDispose`.
- **ML isolation is correct** — messenger init before ML Kit, tflite bytes
  loaded on the main isolate, `clusterAll` and `MemoryBuilder.build` via
  `Isolate.run`.
- **Lifecycle pause/resume is real** — `app.dart:44-57` pauses on
  `inactive`/`paused`/`hidden`/`detached`; `_run()`'s loop polls
  `while (_paused && !_cancelled)` so it genuinely stops mid-pass.
- **Startup is clean** — nothing blocking before first frame, `start()` on
  `addPostFrameCallback`, DB opened lazily on a background isolate via
  `driftDatabase`.
- **`PrecacheAdjacent`** warms encoded bytes only, skips videos, reuses the
  autoDispose cache. Well-designed, leave alone.
- **ClipRRect per cell** — ~15-24 in a viewport, but `Clip.antiAlias` needs no
  `saveLayer` and the r12-on-every-thumbnail rule is a hard design constraint.
  Noted, not actionable.

---

## Test impact

Assume most of a day here; the suite is animation-aware in more places than the
lib is.

**Delete outright**
- `test/widgets/entrance_fade_test.dart` — subject deleted.
- `test/widgets/pressable_test.dart` — both cases (`scales down while the
  pointer is held`, `reduced motion zeroes the duration…`) test only the scale.
  If `Pressable` survives A3 as a tap forwarder, keep one tap test.

**Rewrite**
- `test/features/detail/widgets/dismissible_photo_test.dart` — `a small drag
  reports progress then springs back`, `a drag past the threshold dismisses
  immediately…`, `reduced motion springs back instantly…`. Keep the real
  `startGesture`/`moveBy`/`up()` shape (never `tester.drag` — CLAUDE.md gotcha);
  assert `onDismissed` fires / does not fire, drop every opacity assertion.
- `integration_test/hero_dismiss_test.dart` — rename (no Hero left), drop the
  `currentOpacity().opacity < 1` mid-drag read and the 450 ms `AppMotion.long`
  wait; assert the route pops.
- `test/widgets/nav_pill_bar_test.dart` — `the knob sits over the active
  destination` keeps working; `reduced motion lands the knob with no animation`
  becomes the only behaviour and should be folded into the first test.
- `test/widgets/indexing_dial_test.dart` — `the ring fills by the share already
  done` still valid (reads the painter); `goes away when the pass finishes` no
  longer needs to pump the switcher.
- `test/features/onboarding/onboarding_screen_test.dart` — the bounded pumps at
  ~:87 and ~:165-166 exist to clear `EntranceFade` timers and the step
  cross-fade. Both gone; simplify, keep the pumps bounded (spinners still
  forbid `pumpAndSettle`).

**Verify unchanged**
- `test/features/memories/memory_player_screen_test.dart` — all six cases key
  off `pageDuration` + a 400 ms pump for `sceneChange`. Scene transitions are
  **out of scope**, so these should pass untouched. If they fail, `AppMotion`
  migration in A2 went wrong.
- `test/widgets/design_goldens_test.dart` + `test/features/detail/detail_goldens_test.dart`
  — every golden pins a **post-settle end state**; none captures an in-flight
  frame. Expect **byte-identical** goldens. If any golden changes, that is a
  real regression in an end state, not an expected regen. (Same shape as the
  CLAUDE.md gotcha where the icon-family swap left every golden identical.)
- The `pump(Duration)` calls in `consent_flow_test`, `detail_actions_test`,
  `folders_ui_test`, `nav_shell_test`, `permission_matrix_test`,
  `saved_albums_test` are timing waits around route/shell transitions. They
  should still pass (waiting longer than needed is harmless); tighten later.

**New test required**
- A widget test asserting the detail route builds its content on the **first**
  frame after push, now that there is no Hero flight and no transition to wait
  out. Guards against a regression where the hard cut lands on a blank frame.

---

## Verification (Definition of Done)

1. `tool/check.sh` — analyze clean, build_runner, unit + widget tests.
2. `grep -rn "AppMotion\|EntranceFade\|Hero(\|HeroMode" lib/` returns **nothing**
   except the memory player's local scene consts. This is the completion oracle.
3. Goldens: expect zero image changes. Investigate any that move.
4. On-device (Pixel 9 Pro XL, `46121FDAS008AA`), one integration file per run,
   re-granting permissions between runs per the CLAUDE.md procedure:
   - `integration_test/hero_dismiss_test.dart` (renamed)
   - `integration_test/nav_shell_test.dart`
   - `integration_test/detail_actions_test.dart`
5. Manual end-to-end on device — the thing goldens and host tests cannot judge:
   does tap-to-open read as *instant* or as *broken*? Specifically check the
   grid → detail hard cut and the drag-dismiss with no feedback (A4).
6. No schema change → no dump/migration work.
7. No dependency change → no merged-manifest re-verify.
8. Update Known gotchas if anything surprises; prune this doc's task notes from
   CLAUDE.md when done. The Design system "Motion (`AppMotion`)" table must be
   **deleted from CLAUDE.md** and replaced with a one-line statement that the
   app has no decorative motion, plus the two exceptions (Material defaults,
   memory-player scene change).

## Risks

- **A1 is the load-bearing change.** Hero removal touches the router, seven
  screens and the detail stage at once. Land it as its own commit so it can be
  reverted independently of A3's widget-by-widget work.
- **A4 has a real UX cost** (no drag feedback). Escape hatch documented inline.
- **Reduced-motion tests disappear** — four test files inject
  `disableAnimations` via `MediaQueryData`. Once motion is gone those assertions
  are vacuous. Delete them rather than leave them passing for the wrong reason
  (the CLAUDE.md "positive control" rule).
- **P2 and P5 interact** — do not ship a bigger `cacheExtent` without the
  request cap.

## Suggested commit sequence

1. `perf: bound thumbnail request concurrency` (P2 + P5) — ship first, it is the
   biggest user-visible win and is independent of everything else.
2. `perf: build folder tiles lazily` (P1).
3. `perf: right-size face avatar thumbnails` (P3).
4. `refactor: drop Hero flights and route transitions` (A1).
5. `refactor: remove EntranceFade and AppMotion` (A2).
6. `refactor: make widget state changes instant` (A3).
7. `refactor: drop drag-dismiss and zoom animation` (A4).
8. `test: update suite for zero-motion UI`.
9. `docs: retire the Motion token table` (CLAUDE.md).
