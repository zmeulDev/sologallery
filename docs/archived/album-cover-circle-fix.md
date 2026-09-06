# Fix: album cover thumbnail isn't a proper circle

## Bug

On the Albums screen, under the "ALBUMS" section, each album card's cover
thumbnail (`AlbumCard`) is meant to read as a circular avatar (matching the
People row's circular avatars right below it) but doesn't look properly
circular on device.

## Root cause

`AlbumCard` (`lib/features/albums/widgets/album_card.dart:52-61`) clips its
56×56 cover with:

```dart
ClipRRect(
  borderRadius: AppRadius.br30,          // BorderRadius.circular(30)
  child: SizedBox(
    width: _coverSize,   // 56
    height: _coverSize,  // 56
    child: cover == null ? _EmptyCover(colors) : AssetThumbnail(...),
  ),
),
```

`AppRadius.r30` (`lib/core/theme/app_radius.dart:18-20`) is documented as
existing to match the *outer* floating nav capsule's corner radius, and the
outer `AppCard` around the whole row legitimately uses it for that (a wide,
~72dp-tall row, where 30 is a modest rounded-rect radius, nowhere near a
circle). Reusing that same fixed 30dp constant for the *inner* 56×56 cover is
a different thing entirely: it's coincidentally close to half of 56 (28), so
it currently reads as roughly circular, but:

- It's not an intentional circle — nothing in the code ties the 30 to
  `_coverSize`. If `_coverSize` (already called out in its own doc comment as
  a candidate for tuning — "kept compact so dense album libraries fit two
  columns comfortably") ever changes, the shape silently degrades to a
  rounded square.
- It doesn't match the codebase's existing, deliberate pattern for a
  guaranteed circular avatar: `FaceAvatar`
  (`lib/features/people/widgets/face_avatar.dart:213-214`) uses `ClipOval`
  specifically so the People grid/strip avatars are a perfect circle
  independent of size:
  ```dart
  return borderRadius == null
      ? ClipOval(child: clipped)
      : ClipRRect(borderRadius: borderRadius!, child: clipped);
  ```

The People avatars sitting directly below the album cards on the same screen
are visibly correct circles (via `ClipOval`), which is what makes the album
covers' near-miss noticeable side by side.

## Fix

Swap the inner cover's `ClipRRect(borderRadius: AppRadius.br30)` for
`ClipOval`, matching `FaceAvatar`'s pattern — guarantees a perfect circle
regardless of `_coverSize`, with no dependency on a fixed radius constant
happening to be close to half the box size. The outer `AppCard`'s own
`AppRadius.br30` (the actual navbar-echo, on the whole row) is untouched.

```dart
ClipOval(
  child: SizedBox(
    width: _coverSize,
    height: _coverSize,
    child: cover == null
        ? _EmptyCover(colors)
        : AssetThumbnail(assetId: cover, size: 256),
  ),
),
```

## Test plan

- `test/widgets/design_goldens_test.dart` has an existing `'AlbumCard —
  populated and empty'` golden (`fileName: 'album_card'`). Regenerate it after
  the change (`flutter test --update-goldens
  test/widgets/design_goldens_test.dart` or the project's usual golden-update
  command) and visually confirm the cover is now a clean circle in the
  updated PNG.
- `test/features/albums/album_card_test.dart` has no shape assertion today;
  no new assertion is planned since Flutter widget tests can't easily assert
  "is visually circular" beyond the golden — the golden is the real coverage
  here.
- No DB/provider-level test needed; this is pure presentation.

## Steps

- [x] Change `ClipRRect(borderRadius: AppRadius.br30)` to `ClipOval` around
      the cover `SizedBox` in `album_card.dart`; updated the class doc
      comment to match.
- [x] Regenerate the `album_card` golden — **zero byte diff**. See "Important
      finding" below.
- [x] Found and fixed a second file this change broke:
      `test/widgets/thumbnail_radius_test.dart` has a deliberate invariant
      test ("one radius for every photo in the app", written to catch a past
      regression where some grid cells had no clip at all) that asserted the
      album cover's nearest `ClipRRect` ancestor is `br30`. Swapping to
      `ClipOval` made that ancestor walk find nothing (the exact shape of the
      historical bug the test guards against). Updated the test
      (`'AlbumCard covers clip to br30'` → `'AlbumCard cover clips to a
      circle'`) to assert a `ClipOval` ancestor instead of a `br30`
      `ClipRRect`, preserving the "every thumbnail is deliberately clipped"
      invariant while reflecting the real new shape.
- [x] Run `tool/check.sh` — analyze, drift codegen, full test suite (incl.
      both updated tests) all pass.
- [x] Visually confirm on a connected device/simulator — skipped by user
      decision (2026-09-06): trusting the code fix as correct/robust rather
      than re-checking on device, since the golden proves the geometry was
      already a perfect circle pre-change anyway.

## Important finding — the golden proves this specific change has *zero*
## pixel effect at the current size

Before touching the golden, `flutter test test/widgets/design_goldens_test.dart`
(no `--update-goldens`) was run against the **already-changed** code and it
*passed* — the `ClipOval` render matched the previously-committed golden PNG
(rendered with the old `ClipRRect(borderRadius: Radius.circular(30))`)
byte-for-byte. Regenerating with `--update-goldens` confirmed it again: `git
diff --stat test/widgets/goldens/` shows no change at all.

This means: at the current exact `_coverSize = 56` with radius 30, Flutter's
`ClipRRect` was **already** rendering a mathematically perfect circle —
30 exceeds the maximum non-overlapping corner radius for a 56×56 box (28 =
56/2), and Flutter/Skia scales oversized corner radii down proportionally
(the same mechanism people rely on when they write `BorderRadius.circular(999)`
as a "make it a pill" hack). So the old code and the new code are pixel-
identical in this deterministic host-rendered test.

**What this means for the original complaint:** the `ClipOval` change is
still worth keeping — it makes the circle *intentional and robust* (not
dependent on 30 happening to be ≥ half of whatever `_coverSize` is, which the
class's own doc comment flags as a candidate for future tuning), and it now
matches the codebase's established `ClipOval` pattern for guaranteed circles
(`FaceAvatar`). But it does **not explain** why the shape looked off on the
user's real Samsung phone, since the geometry was already a perfect circle
before this change, at least in a synthetic render.

Best remaining guesses, unverified:
- **Optical illusion from photo content.** The two real album covers seen on
  device (`Tokyo…`, a photo of a dog on a strongly patterned brick/paver
  path; `Fiat`, a car interior with straight structural lines) both have
  strong straight/diagonal lines crossing near the circle's edge — a classic
  setup for a circle to *look* slightly egg-shaped or skewed to the eye even
  when it's geometrically perfect (compare: the People avatars below it on
  the same screen, which are also circles but tend to have softer/rounder
  photo content near their edges, and read as "obviously circular").
- Something in the real GPU rendering path (anti-aliasing, device pixel
  ratio rounding) that a software-rendered host golden can't surface.

## Next step

Done. Code and tests are complete and passing. The user opted to trust the
`ClipOval` fix as correct/robust without a fresh on-device visual check,
given the golden proved the on-screen geometry was already a perfect circle
before this change. If the original visual complaint recurs, it isn't a
shape-math bug (already ruled out) — start from the "optical illusion from
photo content" theory above instead of more clip-radius changes.
