# Faces missing on first run + broken People avatars

**Status:** complete — A, B, B2, B3 implemented, host suite green, verified on
the Pixel 9 Pro XL.
**Branch:** `feature/metadata-search`
**Next step:** none for this task. One follow-up is recorded at the bottom
(cluster fragmentation) — it is a separate defect, not part of this work.

Two independent bugs, both reproduced/confirmed on the Pixel 9 Pro XL
(`46121FDAS008AA`) against the live app database.

---

## Bug A — no faces after first-run consent

### Symptom
On first run the user granted search + memories + faces. Analysis completed,
Memories appeared, People stayed empty. Toggling face detection off→on in
Settings populated People.

### Root cause (confirmed by reading the code, not inferred)

`ConsentNotifier.record()` (`lib/features/settings/consent_provider.dart:61-65`)
writes the three flags as three separate awaited round trips to the Drift
**background isolate**, and each one self-kicks a pass:

| call | side effect | `start()` |
|---|---|---|
| `setSearchEnabled(true)` | writes `search_enabled` | `indexing_service.dart:223` — **runs** |
| `setMemoriesEnabled(true)` | writes `memories_enabled` | `:243` — dropped, `_running` |
| `setFacesEnabled(true)` | writes `faces_enabled` + `resetMlPending()` | `:263` — **dropped**, `_running` |

`start()` no-ops whenever `_running` is true (`indexing_service.dart:151-153`),
and `_run()` reads all three consent flags **once, at the top of the pass**
(`indexing_service.dart:310-315`).

So the single pass that actually executes is the one kicked by
`setSearchEnabled`, and it reads `faces_enabled` while that row has not been
written yet → `facesEnabled == false`. The pass still runs (`needsMl` is true
because search is on), labels every asset, and `_indexOne` stamps `indexed_at`
for every asset **regardless of which features ran**. Every asset is now
"indexed" with zero faces, and `IndexDao.pendingMlIds()`
(`WHERE indexed_at IS NULL`) will never return it again.

`setFacesEnabled`'s own `resetMlPending()` *does* clear `indexed_at` for the
whole cache — but its paired `start()` was swallowed by the `_running` guard, so
nothing ever consumes that pending queue. The app sits with
`faces_enabled = true` and a full pending queue that nobody drains.

The Settings toggle works because it runs in isolation: `_running` is false, so
`resetMlPending()` + `start()` both take effect and `_run()` reads a
long-since-committed `faces_enabled = true`.

This is deterministic, not a flaky race — Dart drains the microtask queue before
handling the next isolate message, so `record()` always advances to the next
flag before the in-flight pass's read is answered.

### Fix A
1. Write all three flags in **one transaction, before any pass is kicked** — add
   `SettingsDao.setConsent({search, memories, faces})` and have
   `ConsentNotifier.record()` call it, then apply the data-deletion/re-queue side
   effects, then kick a single `start()`.
2. Make `start()` **not silently drop** a request that arrives mid-pass: set the
   existing `_dirty` flag instead of returning, so the `do/while` in `_run()`
   picks up another round. This closes the general case (any flag flipped while
   a pass is in flight), not just the onboarding ordering.
3. Re-read the consent flags at the top of **each `do/while` iteration** in
   `_run()`, so a re-loop triggered by `_dirty` sees the new flags.

---

## Bug B — People avatars blank / clipped / cropped off the face

### Symptom
Screenshot of `/people`: several avatars render as an empty circle, one renders
as a clipped half-circle, and most of the rest show a shoulder, hair, gravel or
a wine barrel instead of a face.

### Root cause — the analysis thumbnail is aspect-**fill**, not aspect-fit

`FaceAvatar` rescales the stored box from the write-time analysis thumbnail into
the read-time avatar thumbnail using the **long** edge
(`lib/features/people/widgets/face_avatar.dart:105-109`):

```dart
final longEdge = thumb.width > thumb.height ? thumb.width : thumb.height;
final k = longEdge / _analysisEdge;   // _analysisEdge = 512.0
```

That assumes `photos.thumbnail(id, 512, 512)` (`indexing_service.dart:594`)
returns an image whose **long** edge is 512 — which is what the CLAUDE.md gotcha
currently claims ("a portrait comes back ~384×512").

**The live database disproves it.** Stored boxes are raw pixel coordinates in
that thumbnail, and they exceed 512:

```
asset_id     max_right  max_bottom  faces
1000004078   683        427         11      <- 683 ≈ 512 × 4/3
1000004075   661        414         12
1000002698   512        656          1
1000004072   506        604         20
```

8 of the 26 assets with faces prove a dimension > 512. `683 × 512` is a 4:3
landscape **covering** a 512×512 box. So the analysis thumbnail has **short edge
512, long edge > 512** — aspect-fill. The read-side 1024 request behaves the
same way (short edge 1024).

Therefore for a 4:3 asset the code computes `k = 1365/512 = 2.67` where the
correct factor is `1024/512 = 2.0` — every box is scaled **~33% too large** and
its centre pushed ~33% too far from the origin. That single error produces all
three observed symptoms: the crop lands down-and-right of the actual face
(shoulders/hair/gravel), and for faces near the right or bottom edge the
computed placement moves the image far enough that it no longer covers the
circle (clipped half-circle, or fully empty).

### Fix B (recommended: remove the assumption entirely)
Stop storing raw pixels in an implicit coordinate space. Store the box
**normalised to 0..1** against the analysis thumbnail's real decoded dimensions,
at write time in `ml_service._embedFace` / `FacesDao.insertFaces`. Then
`FaceAvatar` multiplies by the avatar thumbnail's real width/height with no
scale factor and no constant — correct for any aspect ratio, any thumbnail size,
and any future change in photo_manager's resize semantics.

This is a schema change → per DoD #4 it needs a committed schema dump and a
migration test. Existing `face_embeddings` rows cannot be converted (the source
dimensions were never recorded), so the migration drops them and the next pass
re-derives — acceptable, this is derived data.

Rejected alternative: switch `k` to the **short** edge ratio. One-line, no
schema change, but it just swaps one undocumented assumption about
photo_manager's resize mode for another — and this bug is precisely what that
kind of assumption costs. (CLAUDE.md's existing gotcha was written from the
fit assumption and is wrong; it must be corrected either way.)

### Fix B2 — avatar picks an arbitrary face, not the curated cover
`FacesDao.coverFace` (`lib/core/database/daos/faces_dao.dart:262-277`) orders by
`id DESC LIMIT 1` — "newest inserted face row". It ignores `Person.coverAssetId`,
which clustering deliberately chooses and preserves across re-clusters
(`face_clustering.dart:147-151`, `faces_dao.dart:196-198`). `PersonSummary.coverAssetId`
is populated but never read by any widget. Consequence: a person's avatar changes
to a different photo as indexing progresses. Make `coverFace` resolve the face row
belonging to `Person.coverAssetId`, falling back to newest only if absent.

### Fix B3 — junk one-face "people"
48 persons for 82 faces; 42 of them have a single face. The smallest stored box
is **15×15 px** in a ≥512 px thumbnail — noise, not a face. Add a minimum face
size threshold (proportional to the thumbnail's short edge, ~5%) before
persisting, so the People grid isn't flooded. Applies to Bug B's symptom set
(the gravel/barrel avatars) but is a separate, independent defect.

---

## Verification plan
- Unit: `faceAvatarPlacement` cases for 4:3 landscape and 3:4 portrait
  thumbnails — currently only square-ish cases are covered.
- Unit: `SettingsDao.setConsent` writes all three atomically; `IndexingService`
  re-loops when a flag flips mid-pass (`_dirty`).
- Migration test for the normalised-box schema bump (v_N → v_N+1).
- Integration (device, deterministic — no app-data wipe needed): drive
  `ConsentNotifier.record(search: true, memories: true, faces: true)` from a
  clean settings table and poll until the pass settles, asserting
  `face_embeddings` is non-empty. This reproduces Bug A without destroying the
  user's library state, and fails on today's code.
- Manual: relaunch on device and re-screenshot `/people` — avatars must be
  centred on faces, none blank, none clipped.

## CLAUDE.md follow-ups
- Correct the thumbnail gotcha: `thumbnail(id, N, N)` returns an image whose
  **short** edge is N (aspect-fill / cover), not whose long edge is N. Record the
  DB evidence above. — **done**
- Add: consent flags must be written atomically before any indexing pass is
  kicked; `start()` must never silently drop a request. — **done**

---

## What was actually built

| Fix | Change |
|---|---|
| A | `SettingsDao.setConsent` (one transaction, all three flags + the answered marker); `IndexingService.applyConsent` as onboarding's single entry point; `ConsentNotifier.record` delegates to it; `start()` sets `_dirty` instead of dropping a mid-pass request; `_run()` re-reads the flags every round |
| B | `face_embedding` box columns `int` → `real`, normalized `[0,1]`, written by `ml_service._embedFace` against the analyzed image's own dimensions; `faceAvatarPlacement` resolves fractions against the decoded thumbnail; schema v7 + migration |
| B2 | `FacesDao.coverFace` prefers the face on `Person.coverAssetId`, falling back to newest |
| B3 | `faceIsLargeEnough` (≥5% of the image's short edge) gates embedding in `_embedFace` |

### One thing the plan missed
The mid-pass regression test failed on the first attempt, and correctly so.
`applyConsent` calls `resetMlPending()`, but when it lands *while* a pass is
mid-flight, the remaining assets in that round re-stamp `indexed_at` straight
over the reset — so the extra `_dirty` round found nothing pending and derived
no faces. Fixed in `_run()`: it tracks the flags the previous round ran with and
re-queues at the top of a round in which a feature switched on. That is the only
point where the reset cannot be undone by a round still in progress.

## Verification (done)
- `tool/check.sh`: analyze clean, build_runner clean, **346 host tests pass**.
- Migration: 7 cases incl. `v6 → v7` and a data case asserting the pixel-space
  faces and their clusters are dropped and the assets re-queued.
- New tests: `faceAvatarPlacement` scale-invariance across aspect-fill sizes;
  `coverFace` stability (5 cases); `faceIsLargeEnough` (6 cases);
  `applyConsent` mid-pass / persistence / decline-deletes (3 cases).
- **Device (Pixel 9 Pro XL, real migration over the v6 install):** all 106 assets
  re-indexed; every stored box within `[0,1]` with **zero** out-of-range rows;
  faces 82 → 62 (20 sub-threshold junk boxes now rejected); all 48 persons
  resolve their curated cover asset.
- **Device visual:** `/people` re-screenshotted — avatars are centred on faces
  and fill their circles. None blank, none clipped, none showing a shoulder or
  gravel. (Before: several blank, one clipped to a half-circle, most off-target.)

## Follow-up — not this task
Clustering still fragments: 62 faces spread over **48** persons, 42 of them
singletons. The min-size gate removed junk *boxes* but the People grid is still
cluttered by real faces that failed to group — a clustering-threshold /
embedding-quality problem in `face_clustering.dart`, independent of everything
above. Worth its own task with its own evidence.
