# Detail viewer — chrome rearrangement + gesture completion

Status: **implemented; tests written but deliberately not run**
Next step: run `tool/check.sh`, regenerate the `detail_action_bar` golden
(`flutter test --update-goldens test/features/detail/detail_goldens_test.dart`),
then the on-device pass. `flutter analyze` is clean across `lib/`, `test/` and
`integration_test/` as of this writing; nothing else has been executed.

---

## Goal

Rework the photo detail viewer (`/photo/:id`) so the chrome is split by
frequency-of-use rather than by "everything at the bottom", and so every
gesture a user expects from a photo viewer is present.

### Final chrome layout (confirmed with user)

```
TOP     [←]                        [＋]  [↥]
        back                  add-album  share

BOTTOM       [♥]          [ⓘ]          [🗑]
          favorite       info        delete
```

- Top bar: `back` · `add-to-album` (`Icons.add_rounded`) · `share`
  (`Icons.ios_share_rounded`) — favorite leaves the top bar.
- Bottom bar: `favorite` · `info` (`Icons.info_outline_rounded`) · `delete`.
  Share and add-to-album leave the bottom bar; the bar drops 4 → 3 items.
- The `_SwipeUpHint` ("SWIPE UP FOR DETAILS" + grab handle) is **removed**.

### Gesture set (target)

| Gesture | Action | Status today |
|---|---|---|
| Swipe left / right | next / previous photo | ✅ `PageView` |
| Swipe down | close the viewer | ✅ `DismissiblePhoto` |
| Swipe up | show details sheet | ✅ `DismissiblePhoto` → `showExifSheet` |
| Pinch | zoom in / out | ✅ `InteractiveViewer` (min 1, max 5) |
| **Double tap** | **zoom to 2× at the tap point / back to fit** | ❌ **new** |
| Single tap | toggle chrome | ✅ (behaviour changes, see D2) |

### Preloading

`PrecacheAdjacent` goes from `ahead: 1, behind: 1` to `ahead: 3, behind: 3`.

### Location

Already implemented end-to-end and golden-covered — verify only, no new code.
`PhotoLibraryService.assetDetail` reads `entity.latlngAsync()`
(`photo_library_service.dart:559`), normalises `0,0` → `null`, and
`formatCoordinates` (`domain/asset_detail_display.dart:59`) renders the
`Location` chip at 4 decimals when both values are present. A place name or a
map tile would be a network call — forbidden by the Absolute rules.

---

## Design notes

Working inside the locked Design system (CLAUDE.md), so this is composition,
not a new visual language. Three deliberate choices:

1. **The split is by reach, not by category.** The top bar now carries the two
   *outbound* actions (send this photo somewhere: an album, another app); the
   bottom bar carries the two *state* actions on the photo itself (favorite,
   delete) plus the one that opens more information. Back stays alone on the
   left. That reads as a rule rather than an arbitrary shuffle.
2. **Removing the swipe-up hint is what earns the info button.** The hint
   existed *because* the gesture was the only way in and was undiscoverable
   (its doc comment says exactly that). A permanent, labelled affordance
   replaces it, so the caption is now noise sitting over the photo. The
   gesture stays as a shortcut for people who learn it. Net: less chrome over
   the image, more discoverability — the two usually trade against each other.
3. **`Icons.info_outline_rounded`** — outline weight matches the existing
   `add_to_photos_outlined` / `delete_outline_rounded` in the bar; the filled
   `info_rounded` would read as a selected state next to the filled heart.

Metrics unchanged: `_ActionButton` stays a 26 px `AppOverMedia.glyph` icon with
`splashRadius: 24` over the `scrimHeavy` gradient; `spaceEvenly` re-spreads the
three remaining items with no code change.

---

## Decisions

### D1 — Double-tap is resolved in the existing raw `Listener`, not a new `GestureDetector`

`DismissiblePhoto` deliberately uses a raw `Listener` rather than a
`GestureDetector`, because `InteractiveViewer`'s scale recognizer can win the
gesture arena and then do nothing, silently starving a sibling recognizer
(CLAUDE.md gotcha; cost two on-device debugging rounds). Adding a
`DoubleTapGestureRecognizer` into that same arena re-opens exactly that risk.

Instead, tap and double-tap are resolved from the pointer stream we already
track: `_onPointerDown` already records `_pointerStart`, and `_onPointerEnd`
already computes travel, axis intent and velocity. A tap is simply
"`_verticalIntent` never resolved, travel < `kTouchSlop`, duration <
`kLongPressTimeout`". No new arena members, no new failure mode.

### D2 — The single tap is delayed by `kDoubleTapTimeout` (300 ms)

To fire a *double*-tap you must not have already acted on the first tap.
Two options:

- **(a) Delay the chrome toggle 300 ms** — chosen. Clean end state, no visual
  artefact. This is what iOS Photos does.
- (b) Toggle chrome immediately and revert it if a second tap arrives —
  instant, but every double-tap-to-zoom flashes the full top+bottom chrome in
  and back out (`AppMotion.medium` = 180 ms fade, so the flicker is clearly
  visible). Rejected: a visible flicker on a routine gesture reads as a bug.

This is a real regression against "instant taps" for the chrome toggle
specifically, taken knowingly. **Under reduced motion the delay still applies**
— it is a gesture-disambiguation window, not an animation, so it must not be
routed through `AppMotion.of`.

The pending toggle timer is cancelled by: a second tap, a drag starting, and
`dispose()`.

### D3 — Zoom target: 2× centred on the tap point

Chosen by the user. `minScale` stays 1, `maxScale` stays 5, so a pinch can
still go further. A double-tap while *already* zoomed by any amount (pinch or
double-tap) returns to identity — "the second double-tap always gets you back
to fit" is the predictable rule.

### D4 — Zoom is animated by a second `AnimationController` in `DismissiblePhoto`

The `TransformationController` lives there already (it is what gates the
drag-dismiss off while zoomed). `Matrix4Tween` driven over
`AppMotion.of(context, AppMotion.short)` — 150 ms; `AppMotion.medium` is for
content reveals and 450 ms `long` would feel sluggish on a zoom.

`SingleTickerProviderStateMixin` → `TickerProviderStateMixin` (two controllers).
Both controllers are created **unconditionally in field initialisers /
`initState`**, never `late final` behind a conditional read — CLAUDE.md gotcha:
a `late final AnimationController` first touched in `dispose()` throws.

### D5 — Videos ignore the double-tap

`DetailStage` passes `transformController: null` for video and `VideoPage` has
no `InteractiveViewer`. A double-tap on a video resolves as two single taps'
worth of nothing; it must **not** fall through to a chrome toggle either (that
would make the play/pause tap target ambiguous). Gate on `widget.isVideo`.

### D6 — The zoom matrix is pure-Dart and unit-tested

New `lib/features/detail/domain/zoom_transform.dart`, no Flutter import
(`package:vector_math/vector_math_64.dart` only), so it is testable on the
host per the architecture rule:

```dart
Matrix4 zoomedAt(double focalX, double focalY, {required double scale});
```

Returns `translate(-focal * (scale - 1)) * scale`, which keeps the child point
under the focal point pinned. Because `PhotoPage`'s child fills the viewport
(`Image.memory(width: infinity, height: infinity, fit: contain)` inside a
`Center`), child size == viewport size, so a focal point inside the viewport
always yields a translation inside `InteractiveViewer`'s implicit
`boundaryMargin: EdgeInsets.zero` bounds. No clamping needed, and no risk of
setting `transformationController.value` out of bounds (which
`InteractiveViewer` would not correct until the next gesture).

Focal point is obtained in `DismissiblePhoto`'s own coordinate space via
`(context.findRenderObject() as RenderBox).globalToLocal(event.position)`. That
box is co-extensive with the `InteractiveViewer` while `_dismiss.value == 0`,
which is guaranteed for a tap (a drag would have set `_verticalIntent`).

### D7 — `PrecacheAdjacent` at 3/3 is a bytes cost, not a decode cost

`detailImageProvider` yields encoded `Uint8List` capped at
`kDetailImageMaxEdge = 2048`; decoding happens only when a page actually
renders `Image.memory`. Six neighbours ≈ 6 encoded JPEGs ≈ 10–15 MB resident,
not ~50 MB of decoded bitmaps. Videos are already skipped once known. Safe.
`adjacentIds` already handles wider windows nearest-first and is already tested
for it — only the two default arguments at the call site change, plus the
`ahead`/`behind` doc comment which currently argues for 1.

---

## Implementation phases

### Phase 1 — Chrome rearrangement

**`lib/features/detail/widgets/detail_action_bar.dart`**
- Props: drop `onShare`, `onAddToAlbum`; add `onInfo`.
- Row: `favorite` · `info` (`Icons.info_outline_rounded`, tooltip `Details`) ·
  `delete`.
- Update the class doc comment (it names the old four).

**`lib/features/detail/detail_screen.dart`**
- `_TopBar`: drop `isFavorite`/`onFavorite`, add `onShare`; row becomes
  back · `Spacer` · add-to-album · `s8` · share.
- Delete `_SwipeUpHint` and the `SizedBox(height: AppSpace.s16)` above the
  action bar; the bottom `_Chrome` child collapses from a `Column` to the
  `DetailActionBar` alone.
- Wire `DetailActionBar(onInfo: _onExif)`.
- Prune imports that fall dead (`app_radius.dart`, `app_text_styles.dart`, and
  `app_colors.dart` if nothing else in the file uses `AppOverMedia`) — verify
  with `flutter analyze`, which is zero-warning.
- Update the `PhotoDetailScreen` class doc (it describes the old bar).

**`lib/features/detail/detail_providers.dart`** — unchanged. `_onShare`,
`_onAddToAlbum`, `_onExif` all already exist on the screen state; only their
call sites move.

### Phase 2 — Double-tap zoom

**New `lib/features/detail/domain/zoom_transform.dart`** — `zoomedAt` per D6,
plus `const kDoubleTapZoomScale = 2.0`.

**`lib/features/detail/widgets/dismissible_photo.dart`**
- `SingleTickerProviderStateMixin` → `TickerProviderStateMixin`.
- New prop `onTap` (chrome toggle, passed down from the screen).
- New state: `_zoom` (`AnimationController`, duration `AppMotion.short`),
  `_zoomAnimation` (`Animation<Matrix4>`), `_lastTapUp` (`Offset?`),
  `_lastTapTime` (`Duration?` from `event.timeStamp`), `_singleTapTimer`
  (`Timer?`).
- `_onPointerDown`: cancel `_singleTapTimer`; also stop `_zoom` if running.
  Keep the existing `if (_zoomed) return` guard for the *drag*, but let a
  **tap** through while zoomed — that is how a double-tap zooms back out.
  (Concretely: record tap-tracking state before the `_zoomed` early-return.)
- `_onPointerEnd`: after the existing vertical/horizontal handling, add a tap
  branch — travel < `kTouchSlop` and `_verticalIntent == null` and elapsed <
  `kLongPressTimeout`:
  - if a prior tap is within `kDoubleTapTimeout` and `kDoubleTapSlop` → cancel
    `_singleTapTimer`, clear tap state, `_handleDoubleTap(localPosition)`;
  - else → record the tap and arm `_singleTapTimer =
    Timer(kDoubleTapTimeout, () => widget.onTap())`.
- `_handleDoubleTap(Offset local)`: no-op when `widget.isVideo`; otherwise
  animate `_transformController.value` via `Matrix4Tween` to
  `Matrix4.identity()` if `_zoomed`, else `zoomedAt(local.dx, local.dy,
  scale: kDoubleTapZoomScale)`. Driven by a listener on `_zoom` writing
  `_zoomAnimation.value` into `_transformController` (which already fires
  `_onTransformChanged` → `_zoomed`, so the drag gate stays correct for free).
- `dispose()`: cancel `_singleTapTimer`, dispose `_zoom`.
- Extend the class doc with the tap/double-tap resolution and *why* it is not a
  `GestureDetector` (D1) and why the single tap is delayed (D2).

**`lib/features/detail/detail_screen.dart`**
- Remove the `GestureDetector(onTap: _toggleChrome)` wrapping the `PageView`;
  pass `onTap: _toggleChrome` down through `_DetailPage` → `DismissiblePhoto`.
  (Tap must be resolved where the transform controller lives; leaving an outer
  detector as well would double-handle it.)

### Phase 3 — Preload window

**`lib/features/detail/detail_screen.dart`** —
`PrecacheAdjacent(assetIds: _ids, index: _index, ahead: 3, behind: 3)`.

**`lib/widgets/precache_adjacent.dart`** — update the `ahead`/`behind` doc
comment; the default stays 1 for the memory player, which is a different job.

### Phase 4 — Location verification

No code. Confirm on device that a GPS-bearing photo shows the `Location` chip
(the `test_assets/` "JPEG with GPS EXIF" is the seed).

---

## Tests

Written in this task; **not run** (per the request). They will need
`flutter analyze` + `flutter test` and a golden regeneration before this is
Done.

### Unit — new `test/features/detail/domain/zoom_transform_test.dart`
- `zoomedAt` scales by exactly the requested factor on both axes.
- The focal point is a fixed point: transforming `(focalX, focalY)` returns
  itself (top-left focal, centre focal, bottom-right focal).
- Translation stays within `[-(s-1)·edge, 0]` for focal points inside the
  viewport (the boundary-safety argument in D6).
- `scale: 1` returns the identity matrix.

### Widget — `test/features/detail/detail_screen_test.dart` (edit)
Existing cases to change:
- `renders the action bar and top-bar affordances` → assert back /
  `Add to album` / `Share` on top and `Favorite` / `Details` / `Delete` at the
  bottom, and assert `Share` and `Add to album` appear exactly **once** each.
- Delete `the swipe-up hint advertises the details gesture`; replace with
  `no swipe-up caption sits over the photo` (`find.textContaining('Swipe up')`
  → `findsNothing`).
- Delete `favorite from the top bar toggles the heart and persists`; keep and
  extend `favorite from the action bar toggles the same state`.

New cases:
- `the info button opens the details sheet` — tap `Icons.info_outline_rounded`,
  expect the `DETAILS` sheet label and a formatted chip.
- `swiping up still opens the details sheet` — keep the existing raw-pointer
  `swipeUp` helper case, renamed; the gesture is a shortcut now, not the only
  route.
- `share is only in the top bar` / `add to album is only in the top bar` —
  guards against a future re-add.
- `add to album from the top bar creates an album and confirms` — the existing
  add-to-album case retargeted at the top-bar disc.

Bounded pumps only (a `TextField` in the add-to-album sheet and the
`CircularProgressIndicator` loading branch both forbid `pumpAndSettle`), and
every case that builds the screen keeps the
`pumpWidget(SizedBox()) + pump(1s)` dispose-tree teardown **in the test body**.

### Widget — `test/features/detail/widgets/dismissible_photo_test.dart` (edit)
Existing seven drag cases stay (they must keep passing — the tap branch must
not disturb axis-locked drags). New cases:
- `a single tap toggles the chrome after the double-tap window` — tap, pump
  `kDoubleTapTimeout + 1ms`, expect `onTap` fired once.
- `a single tap does not fire before the double-tap window` — tap, pump 100 ms,
  expect not yet fired.
- `a double tap zooms to 2x at the tap point and never fires onTap` — two taps
  inside the window; assert the `TransformationController` reaches
  `zoomedAt(...)` after pumping `AppMotion.short`, and `onTap` count is 0.
- `a second double tap returns to fit` — assert `Matrix4.identity()`.
- `a double tap on a video does nothing` — `isVideo: true`, no transform
  change, no `onTap`.
- `a drag cancels a pending single tap` — tap, then start a drag inside the
  window; `onTap` never fires.
- `the pending tap timer is cancelled on dispose` — pump the tree away inside
  the window; no pending-timer teardown failure. (This one is the regression
  guard for the `FakeAsync` pending-timer invariant.)

Taps go through the same raw `startGesture` / `up()` sequence the existing
tests use — **not** `tester.tap`, which coalesces down+up and has hidden this
class of bug before (CLAUDE.md gotcha).

### Widget — `test/widgets/precache_adjacent_test.dart` (edit)
- New case: `warms three each way when asked` — `ahead: 3, behind: 3` on a
  9-item list at index 4 warms exactly ids 1,2,3,5,6,7 and not 4.
- New case: `a 3/3 window clamps at the front edge`.

### Golden — `test/features/detail/detail_goldens_test.dart` (edit)
- `DetailActionBar — favorited and not, over black` now renders three items;
  `test/features/detail/goldens/ci/detail_action_bar.png` **must be
  regenerated** (`flutter test --update-goldens
  test/features/detail/detail_goldens_test.dart`) — flagged, not done here.
- `ExifSheet — populated metadata` unchanged; it already covers the `Location`
  chip (`latitude: 37.7749, longitude: -122.4194`), so location rendering stays
  golden-locked.
- No golden for the top bar today. Add
  `_TopBar`-equivalent coverage only if it is extracted into a public widget —
  it is private, so **not** in scope; the widget test covers it.

### Integration — `integration_test/detail_actions_test.dart` (edit)
- Line 43's `find.byIcon(Icons.info_outline_rounded)` is currently **stale and
  would fail on device** (no such icon exists in `lib/` today). Phase 1 makes
  it correct — no edit needed there, but it must be re-run.
- New case: `double tap zooms in and back out` — double-tap the stage, assert
  the photo's `InteractiveViewer` transform is non-identity, double-tap again,
  assert identity. Patrol finders only, no coordinate driving.
- New case: `a GPS photo shows its location` — open the seeded GPS JPEG, tap
  info, `find.textContaining('LOCATION')` / a coordinate string.

Run one file per `flutter test integration_test/...` invocation with the
permission pre-grant loop (CLAUDE.md gotcha).

---

## Risks

1. **The 300 ms tap delay is a felt regression** on chrome toggling. If it
   reads badly on device, the fallback is D2(b) — revert-on-second-tap — or
   dropping double-tap zoom entirely and leaning on pinch. Decide on device,
   not on host.
2. **`InteractiveViewer` does not re-clamp a directly-set matrix.** D6 argues
   the 2× translation is always in bounds given child == viewport. If the
   `PhotoPage` layout ever changes so the child is *not* viewport-sized, this
   silently breaks. The unit test on translation bounds is the tripwire; the
   assumption is written into `zoom_transform.dart`'s doc.
3. **`_zoomed` gating the drag-dismiss now has a second writer.** The zoom
   animation writes the controller each frame, so `_onTransformChanged` fires
   throughout — correct, but it means the drag gate flips mid-animation. A
   pointer landing mid-zoom-out is the edge case; `_onPointerDown` stopping
   `_zoom` handles it.
4. **Goldens must be regenerated**, and per CLAUDE.md the icon glyphs will not
   change in them (Alchemist obscures fonts) — only the item count / layout
   will. A byte-identical result after removing an item would mean the
   regeneration did not happen.

---

## What actually changed (as built)

Deviations from the plan above, all minor:

- **`vector_math` became a direct `pubspec.yaml` dependency.** `Matrix4` is
  re-exported by Flutter, but importing it that way would have made
  `zoom_transform.dart` a Flutter-importing "domain" file, and importing the
  transitive package without declaring it trips `depend_on_referenced_packages`
  (analyze is zero-warning). Declaring it is the honest fix: pure Dart, already
  locked at 2.2.0 by the Flutter SDK, no platform artifacts — **no merged
  manifest re-verification needed** (DoD #5 does not apply).
- **`_onPointerDown` no longer bails early when zoomed.** It records tap state
  first and only *then* returns before arming the drag, because a double-tap
  while zoomed is how you get back to fit. `_onPointerMove` gained a
  `_velocityTracker == null` guard, which is what now marks "zoomed: this pan
  belongs to `InteractiveViewer`".
- **`_withinDoubleTapWindow` exists** because the second touch's pointer-down
  is what cancels the pending-tap timer, so `isActive` can't be consulted later
  at resolve time. Any non-tap outcome clears the half-finished pair, so
  tap → drag → tap can't be misread as a double-tap.
- **`Matrix4Tween` is exact at t=1** (`Tween.transform` short-circuits and
  returns `end`), so the zoom lands on precisely `zoomedAt(...)` /
  `Matrix4.identity()` rather than a lerp approximation — that is what lets
  `_zoomed` flip cleanly back to false.
- **CLAUDE.md updated**: the Core-features description of the detail view, and
  `add_to_photos_outlined` dropped from the icon list (no longer used anywhere).

### Files touched

| File | Change |
|---|---|
| `lib/features/detail/domain/zoom_transform.dart` | new — `zoomedAt`, `kDoubleTapZoomScale` |
| `lib/features/detail/widgets/detail_action_bar.dart` | `onShare`/`onAddToAlbum` → `onInfo`; 3 items |
| `lib/features/detail/widgets/dismissible_photo.dart` | tap/double-tap resolution, zoom controller, `onTap` prop |
| `lib/features/detail/detail_screen.dart` | bars rearranged, `_SwipeUpHint` deleted, outer `GestureDetector` removed, precache 3/3 |
| `lib/widgets/precache_adjacent.dart` | doc only |
| `pubspec.yaml` | `vector_math` direct dep |
| `test/features/detail/domain/zoom_transform_test.dart` | new — 8 cases |
| `test/features/detail/widgets/dismissible_photo_test.dart` | +8 tap/double-tap cases |
| `test/features/detail/detail_screen_test.dart` | bars, info button, location chips |
| `test/widgets/precache_adjacent_test.dart` | +2 window cases |
| `test/features/detail/detail_goldens_test.dart` | `DetailActionBar` args |
| `integration_test/detail_actions_test.dart` | top-bar targets, +2 device cases |
| `CLAUDE.md` | Core features, icon list |

---

## Definition of Done tracking

- [x] Phase 1 — chrome rearrangement
- [x] Phase 2 — double-tap zoom
- [x] Phase 3 — preload 3/3
- [ ] Phase 4 — location verified on device
- [x] Tests written (unit / widget / golden / integration) — **not run**
- [x] `flutter analyze` clean (lib + test + integration_test)
- [ ] `tool/check.sh` passes
- [ ] Goldens regenerated (`detail_action_bar` **will** differ — 3 items, not 4;
      a byte-identical result means the regen did not happen)
- [ ] Integration tests pass on `46121FDAS008AA` (one file per invocation, with
      the permission pre-grant loop)
- [ ] Manual end-to-end on device (all six gestures + both bars)
- [x] Schema: **unchanged** — no migration needed
- [x] Android deps: **unchanged** (`vector_math` is pure Dart) — no manifest
      re-verification needed
- [ ] Known gotchas updated if anything surprises
