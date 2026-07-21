# Memory player — preload the story ahead

**Status:** DONE — steps 1 and 2 implemented and tested; step 3 stays cut.

Reported: tapping to advance a memory sometimes lands on the spinner for
about a second.

---

## What's actually slow

The spinner is `PhotoPage`'s `_Loading` branch, so what hasn't finished is
`detailImageProvider(id)` — one `previewImage(assetId, 2048)` platform
round-trip. Not the decode (a decode stall would flash black, not spin).

Three things make the warm-up lose the race:

1. **The window is one photo wide.** `MemoryPlayerScreen` builds
   `PrecacheAdjacent(index: _index - 1, radius: 1)`, so photo N+1 only
   starts fetching when photo N becomes current. The 3s clock covers that;
   a tap doesn't. Two quick taps and you are always ahead of the fetch.
2. **Half the window is spent backwards.** `adjacentIds` is symmetric, so
   at radius 1 one of the two warmed slots is N-1 — a photo the viewer has
   already seen and, in a story, almost never returns to.
3. **Each warm-up serializes two platform calls.** `PrecacheAdjacent` does
   `ref.watch(isVideoProvider(id)).value` and only starts
   `detailImageProvider(id)` once that answers `false`. So every warm-up
   waits out a full `AssetEntity` resolve *before* the fetch that matters
   even begins. In the memory player the gate buys nothing anyway — the
   player renders `PhotoPage` for every entry regardless of type.

## Plan

### 1. Asymmetric warm window (`adjacentIds`)

`adjacentIds(ids, index, {int ahead = 1, int behind = 1})`, keeping the
existing nearest-first ordering (N+1, N-1, N+2, N-2, …) so the most likely
next page still starts fetching first. `radius` goes away; the detail
viewer passes `ahead: 1, behind: 1` (unchanged behaviour — a swipe is
genuinely two-way), the player passes `ahead: 3, behind: 1`.

Because the player's cursor sits at `_index - 1`, the title card counts as
position -1 and `ahead: 3` warms photos 0, 1 and 2 *while the title card is
still up* — the story opens with three photos already in hand.

### 2. Stop serializing the video check

In `PrecacheAdjacent`, `if (isVideo == false)` becomes `if (isVideo !=
true)`. The bytes then start fetching immediately and are dropped only once
the asset is *known* to be a video, instead of every still waiting on a
resolve first. Costs a wasted poster-frame fetch for a video neighbour;
saves a round-trip on every still, in both callers.

### 3. Not proposed: decode-ahead

`precacheImage(MemoryImage(bytes))` would warm the same `ImageCache` entry
`Image.memory` reads, so it is available if the paint ever proves to be the
hitch. Leaving it out: a decoded 2048px frame is ~12 MB, so holding three
ahead is ~36 MB of bitmap for a problem the evidence says is the fetch.
Revisit only if a spinner-free advance still stutters on the first frame.

## Cost

Held at once: 4 warmed previews + the current page, as JPEG bytes capped at
2048px (roughly 1–2 MB each, not decoded bitmaps). `detailImageProvider` is
`autoDispose` and the window is the only thing keeping entries alive, so
photos falling out the back are released as the story runs.

## Tests

- `adjacent_ids_test.dart` — asymmetric cases, ordering still nearest-first,
  `index: -1` (the title card) still yields the first photos, out-of-range
  positions still dropped rather than clamped.
- `precache_adjacent_test.dart` — a neighbour whose `isVideoProvider` has
  not resolved yet is warmed anyway; one known to be a video is not.
- `memory_player_screen_test.dart` — on the title card, the first three
  photos are subscribed.
- On-device: play a memory and tap through it fast; no spinner.

## Outcome

- [x] **1 — asymmetric window.** `adjacentIds(ids, index, {ahead, behind})`
      replaces `radius`; `PrecacheAdjacent` takes the same two. Detail viewer
      keeps 1/1 (defaults, behaviour unchanged), player passes `ahead: 3`.
- [x] **2 — no serialized video check.** `isVideo != true` in
      `PrecacheAdjacent`, so the bytes start on the first frame and are
      released once the asset is known to be a video.
- [x] Tests: `adjacent_ids_test.dart` (asymmetric ordering, forward-only, the
      title card's `index: -1` opening run), `precache_adjacent_test.dart`
      (warms without waiting on the video check; a known video is dropped),
      `memory_player_screen_test.dart` (the title card warms `a0,a1,a2`).
- [ ] **3 — decode-ahead: still cut.** Revisit only if an advance with no
      spinner still stutters on the first painted frame.

Two notes worth keeping:

- `precache_adjacent_test.dart` has to override `isVideoProvider` with an
  **async** create. A sync override resolves before the widget's first build,
  which hides the exact behaviour under test (a still being warmed while the
  video answer is still in flight) and makes the change look like a no-op.
- The test's old `renders nothing` assertion (`getSize(...) == Size.zero`)
  was failing before this work: under a tight-constrained parent a
  `SizedBox.shrink()` is forced to full size. It now sits under a `Center`,
  so the assertion means what it says.

## Next step

Built and installed on the Pixel 9 Pro XL. The remaining check is the one
only a person can make: play a memory and tap through it fast — no spinner.
Not yet signed off.
