# People screen: the same person appears as several "people"

Status: **Phases 1 and 2 shipped and verified end-to-end in the running app.**
Phases 3–4 not started. **The reported bug is reduced, not closed.**

Verified by driving the real app through onboarding on the Pixel and letting it
index all 231 assets (not by calling the pipeline from a test):
**130 "people" → 48**, faces 223 → 180, singletons 100 → 18, and the reporting
user went from **6 entries to 2**.

**He still appears twice** — 47 photos, and 10 more wearing sunglasses. A dog's
nose (5 photos) and a plant (4) also still have their own entries. Confirmed by
looking at the People screen, not inferred.

Next step, in order:
1. Decide on `clusterMergeThreshold` 0.45 → 0.40, which merges the sunglasses
   cluster (see the sweep below). Blocked only on repeating the Phase 1 visual
   merge inspection against the *current* gated embeddings — the bleed metric
   used so far cannot see two non-tracked people fusing with each other.
2. Phase 3 (landmark-aligned, margined crop) for the dog/plant detections and as
   the precondition for re-testing `FaceDetectorMode.accurate`.

⚠️ **A verification-metric trap, worth reading before trusting any number here.**
Phase 2's success was measured as "how many of his 48 reference faces cohere into
one cluster" → 46/47, which read as a fix. That reference set came from Phase 1's
cluster 21 and by construction contained *no sunglasses faces* (those were
cluster 34), so the metric was literally true and structurally unable to detect
that he still shows up as two people. **Measure "how many People entries are this
person", not "how well does this face set cohere".** Same shape as the
`accurate`-mode trap below: a metric improving while the user-visible bug stays.

## Symptom

User report: "on People I see myself multiple times, pictures are not grouped
correctly."

## Evidence (Pixel 9 Pro XL `46121FDAS008AA`, live app DB)

DB pulled with `adb exec-out run-as com.zmeul.sologallery cat
/data/data/com.zmeul.sologallery/app_flutter/sologallery.sqlite`.

| Fact | Value |
|---|---|
| faces stored | 223 |
| persons | **130** |
| one-face "persons" | **100** |
| `faces_at_last_recluster` | 223 → the global `clusterAll` **did** run; this is its output, not incremental drift |
| embeddings | 192-d, already L2-normalized (norm 1.000 for all 223) |
| pairwise cosine | max 0.878, p99 0.732, p95 0.538, median 0.113 |

Faces were cropped out of their originals (orientation-corrected) and inspected.
Verified by eye:

- **person 21 (34 faces), person 3 (4), person 64, 65, 85, 111 are all the same
  man** — 42 faces split across 6 "people". This is the reported bug.
- person 14 (14 faces, the 2nd-largest cluster) is **junk**: dog faces, extreme
  profiles, a sky/cloud crop, blurry side views.
- Other false positives being embedded as "people": a **line drawing** of a face,
  a **plant**, a **wrist/watch**.
- person 84 (4 faces) and person 98 (7) are clean, correct clusters.

## Root causes

### 1. `clusterAll` compares against a *running-mean centroid* and never merges

`lib/features/people/domain/face_clustering.dart:51`. Greedy single pass in face-id
order; a face joins the nearest centroid ≥ 0.65 or starts a new cluster. Two
failure modes, both observed:

- **Centroid dilution.** As cluster 21 grew to 34 diverse faces its mean drifted
  away from every individual face. Singleton person 65 scores **0.688** and person
  64 **0.655** against a *member* of cluster 21 — both above the 0.65 threshold —
  yet each stayed a one-face "person" because the *centroid* similarity fell below
  it. Recall gets worse the more photos of you there are.
- **No merge step.** Person 3 was created early (face id 3); cluster 21 formed
  later. Cross-cluster mean similarity 21↔3 is **0.60**, max **0.80** — versus
  cluster 21's own internal cohesion of 0.685. They are obviously the same person
  and nothing in the algorithm can ever join them.

`IncrementalClusterer` (`:169`) has the identical centroid flaw.

### 2. No detection-quality gate

`FaceDetector(options: FaceDetectorOptions())` (`ml_service.dart:215`) is all
defaults: `fast` mode, no landmarks, no classification, and nothing downstream
checks head pose or detection quality. Only `faceIsLargeEnough` (5% of the short
edge) filters anything. So dog faces, drawings, plants and 90°-profile faces get
embedded, and each becomes a "person".

### 3. Crops are unaligned, tight and aspect-squashed

`_embedFace` (`ml_service.dart:280`) crops the raw ML Kit box and `copyResize`s it
to 112×112. MobileFaceNet/ArcFace expects a landmark-aligned crop with margin; a
tight, non-square, unrotated box costs a lot of accuracy. Visible in the contact
sheets as chins/foreheads cut off and horizontally stretched faces. This is why
same-person similarity tops out at 0.878 instead of the ~0.95 an aligned pipeline
reaches.

### 4. Every cluster is shown, including 100 singletons

`watchPersonSummaries` (`faces_dao.dart:213`) returns every person with ≥1 face and
`PeopleScreen` renders all of them. Even with perfect clustering the grid would be
flooded with one-photo strangers.

### 5. Global re-cluster runs on the UI isolate

`_maybeGlobalRecluster` (`indexing_service.dart:527`) does the clustering inline.
Cheap today (223 faces) but any O(n²) algorithm at 10k faces would block the UI —
against the Absolute rule.

## Measured fix: average-linkage agglomerative

Candidate algorithms run against the real 223 embeddings. Ground truth: the 42
verified same-man faces (`M`), plus three verified-distinct clusters as
contamination probes.

| Algorithm | clusters | singletons | M recall | M split into | bleed |
|---|---|---|---|---|---|
| greedy-centroid 0.65 (**current**) | 130 | 100 | 34/42 (81%) | **6** | none |
| greedy-centroid 0.55 | 72 | 41 | 38/42 (90%) | 4 | none |
| mutual-kNN k=8 th=0.55 | 47 | 33 | 33/42 (79%) | 3 | none |
| single-linkage 0.60 | 65 | 54 | 42/42 | 1 | **chains** — 129-face blob incl. dogs |
| agglo-average 0.50 | 74 | 37 | 36/42 (86%) | 4 | none |
| **agglo-average 0.45** | **60** | **27** | **41/42 (98%)** | **2** | **none** |
| agglo-average 0.40 | 47 | 16 | 42/42 (100%) | 1 | none |

Average linkage at **0.45** recovers the man as essentially one person with zero
contamination from the probe clusters, and cuts singletons from 100 to 27. 0.40
is better still on this data but is only 3 negatives away from being unvalidated —
start at 0.45.

## Plan

### Phase 1 — clustering algorithm ✅ done

1. ✅ `clusterAll` is now **average-linkage agglomeration** at
   `clusterMergeThreshold = 0.45`, merging every reciprocal-nearest cluster pair
   per round until nothing clears the threshold.
   No similarity matrix is needed: for L2-normalized embeddings the average of
   all cross-pair cosine similarities is exactly the dot product of the two
   cluster *mean* vectors, so a cluster carries only a running sum and a count.
   That dot product must stay **un-normalized** — re-normalizing the means is
   centroid linkage again. Best-partner results are cached and only invalidated
   for clusters whose best was just merged (a merged mean is a weighted average
   of its children's, so a merge can never make a cluster a *better* partner for
   an outsider).
2. ✅ `IncrementalClusterer` scores against a person's **stored exemplar faces**
   (max similarity, `incrementalAssignThreshold = 0.62`, ≤12 exemplars kept per
   person, evicting the more redundant half of the closest pair) instead of a
   centroid. `FacesDao.clusteredCentroids` → `clusteredExemplars`; `Centroid` is
   gone.
3. ✅ `_maybeGlobalRecluster` runs `clusterAll` inside `Isolate.run`.
4. ✅ `cluster_algo_version` in `app_settings` (now `'2'`). An install that has
   clustered before (a `faces_at_last_recluster` baseline exists) but carries a
   different/absent stamp re-clusters on its next pass regardless of the
   baseline; a fresh install just reaches the threshold normally.
5. ✅ **`_clusterNewFaces` + `_maybeGlobalRecluster` moved out of the
   `if (todo.isNotEmpty)` branch.** They only ran when a pass had new assets to
   index — so on a fully indexed library (the exact case needing the upgrade
   heal) neither ever ran again. Both open with a cheap DB check and return
   immediately when idle, like the memories refresh next to them.

Tests: average-linkage reunion (a split a greedy pass cannot heal), a chaining
case single linkage would fail, conservation of faces, determinism;
exemplar-vs-mean assignment, exemplar capacity/eviction; the DAO exemplar query;
the algorithm-upgrade re-cluster on a fully indexed install.

#### Verified on device (Pixel 9 Pro XL, existing install upgraded in place)

| | before | after |
|---|---|---|
| persons | 130 | **60** |
| one-face persons | 100 | 27 |
| faces | 223 | 223 |
| the reported man | **6 clusters** | **1 cluster of 48** holding 41 of his 42 faces |

The 7 faces the re-cluster newly pulled into his cluster were checked by eye —
all him, no false merges. His 42nd face sits in a separate 8-face cluster which
is **him wearing sunglasses**; the two clusters score 0.437 average linkage,
just under the 0.45 cut.

#### Why the threshold stays at 0.45

Lowering to 0.40 does merge the sunglasses cluster (47 clusters, 16 singletons),
but inspecting all 11 groups it additionally fuses shows one of them merging a
9-face and a 5-face cluster of **visibly different women**. The earlier
"no contamination at 0.40" reading came from only three probe clusters and did
not cover this. 0.45 stands; the sunglasses split is an embedding-quality
limitation and belongs to Phase 3 (alignment), not to the threshold.

### Phase 2 — detection quality gate (kills the junk clusters) — code done

5. ✅ The worker's detector is `FaceDetectorOptions(performanceMode: accurate,
   enableLandmarks: true)`, and a pure `faceIsUsable({yawDegrees, rollDegrees,
   hasLeftEye, hasRightEye, hasNoseBase})` in `ml_service.dart` drops a detection
   before the thumbnail is decoded when any eye/nose anchor is missing, the pose
   is unknown, or `|yaw| > maxFaceYaw (35°)` / `|roll| > maxFaceRoll (25°)`.
   Unit-tested next to `faceIsLargeEnough`.
6. ❌ **Rejected: `minFaceFraction` 0.05 → 0.08.** The plan asserted the small
   boxes were unusable smears; measuring says otherwise. The junk boxes that
   survive the pose gate are ~4% of image width and the smallest *genuine* faces
   are 6–7% — too little separation to cut between, the more so because
   `minFaceFraction` is measured against the short edge while those figures are
   against width, so the verdict flips with orientation. Left at 0.05.

#### Final Phase 2 result (device, `fast` + landmarks + pose gate, threshold 0.45)

Real worker over the 95 face-bearing assets, every produced face matched back by
IoU to the clusters labelled by eye after Phase 1:

| | before Phase 2 | after |
|---|---|---|
| faces stored | 223 | **181** |
| the reported man | 48 | **47** kept, **46 of them in one 47-face cluster** |
| junk cluster | 23 | **6** |
| four verified-distinct control people | 9 / 10 / 5 / 9 | 9 / 10 / 5 / 7 |
| clusters | 60 | **47** |
| singletons | 27 | **17** |

No contamination of his cluster by any control person. The junk cluster turned
out to be mostly *profiles* rather than non-faces, which is why the pose gate
removes 17 of its 23 faces without `accurate` mode's false-positive handling.

**Threshold stays 0.45, not 0.40.** 0.40 does reach 47/47 in one cluster, but the
bleed metric only detects contamination *into* the tracked person's cluster — it
would not notice two control people fusing with each other, which is exactly what
0.40 did to two groups of different women on ungated embeddings in Phase 1. The
remaining upside at 0.40 is one face plus his separate sunglasses cluster; not
worth an unvalidated threshold. Revisit after Phase 3.

`enableLandmarks: true` was checked for the box-shifting failure mode that sank
`accurate`: the fast-mode sweep reproduces Phase 1's clustering behaviour, so the
geometry did not move.

#### Measured with `accurate` mode (temporary probe, since deleted, 61 assets)

Re-detected the assets behind the two clusters labelled by eye — the 23-face junk
cluster and the 48-face cluster of the most-photographed person — matching each
stored box back to a fresh detection by IoU.

| | kept by gate | dropped by gate | no longer detected at all |
|---|---|---|---|
| junk (23) | **3** | 10 | **10** |
| the man (48) | **47** | 1 | 0 |

- **Yaw does all the work, and 35° is in a real gap:** the most frontal junk
  profile is at 42°, the most turned genuine face at 32°. The one genuine face
  dropped is a 49° profile — a face MobileFaceNet cannot match anyway.
- **`accurate` mode, not the landmark check, is what killed the false positives.**
  Every *matched* detection had a full eye/nose landmark set, so that clause never
  fired. The 10 "no longer detected" junk faces are the dogs, the beer glass and
  the sky: they were `fast`-mode artifacts and `accurate` does not report them.
  The landmark requirement stays as the precondition Phase 3's aligner needs.
- **Roll is not load-bearing here** — worst genuine tilt is 20°, and every
  roll-offending junk face was already yaw-rejected.
- **Cost:** accurate 5592 ms vs fast 4201 ms over 61 assets (92 vs 69 ms/asset,
  +33%), and it finds *more* real faces (208 vs 197). Acceptable against a
  pipeline that also does labels, OCR and embedding per asset.

**Do not run any other `flutter` command while an on-device integration test is
running** — doing so aborted a `consent_test.dart` run mid-way (all remaining
tests "did not complete", app force-stopped and uninstalled, no crash in logcat).

#### ⚠️ `FaceDetectorMode.accurate` was tried and reverted — it undid Phase 1

The first cut of Phase 2 also switched the detector to `accurate`. Its
false-positive behaviour is genuinely better (the dog faces, beer glass and sky
patch are `fast`-mode artifacts it does not report at all: junk 23 → 3), and the
aggregate looked like a clear win — 161 faces instead of 223, 33 people instead
of 60, 12 singletons instead of 27.

**The aggregate was hiding a regression.** Tracking the reported person's 48
verified faces individually showed him split across six clusters again
(24 + 16 + 3 + 1 + 2 + 1), i.e. straight back to the bug this whole task exists
to fix. Cause: `accurate` returns *different, tighter* boundary boxes, so every
crop and therefore every embedding changes — and `clusterMergeThreshold = 0.45`
was calibrated against `fast`-mode embeddings. Changing the detector silently
invalidated that calibration.

Re-tuning cannot rescue it. Sweeping the threshold over the `accurate`
embeddings, with four verified-distinct people as contamination controls:

| threshold | his faces in the biggest cluster | split into | contamination |
|---|---|---|---|
| 0.45 | 24/47 | 6 | none |
| 0.40 | 24/47 | 5 | none |
| 0.35 | 24/47 | 5 | none |
| 0.30 | 46/47 | 2 | **3 other people, 92-face cluster** |
| 0.20 | 47/47 | 1 | 4 other people, 145-face cluster |

There is no setting between "split six ways" and "one blob with three strangers
in it" — a strictly worse embedding distribution than `fast` (which reached
41/42 in one clean cluster at 0.45). So the detector stays on `fast` with
`enableLandmarks: true`, and Phase 2's value is the **pose gate alone**.

**Lesson, and it generalises:** the detector, the crop and
`clusterMergeThreshold` are one calibrated system. Any change to how a face is
detected or cropped invalidates the threshold and has to be re-measured
end-to-end *per known person*, never on cluster counts alone. Worth re-testing
`accurate` once Phase 3 lands a margined, landmark-aligned crop — the tight-box
weakness that sank it here is exactly what alignment removes.

7. ✅ **`face_pipeline_version`** (`app_settings`, now `'2'`), checked once at the
   top of a pass's first round. On a mismatch an install that has already indexed
   gets `resetMlPending()`, so every asset is re-analyzed and its stale pre-gate
   embeddings are regenerated; a fresh install is stamped without a pointless
   re-analysis. Deliberately separate from `cluster_algo_version`: a clustering
   change can be healed from the embeddings already stored, a *pipeline* change
   cannot — only re-analyzing the images recovers it. Bump this whenever the
   detector options, the quality gate or the crop change.

   Note the consequence: re-analysis calls `insertFaces`, which **replaces** an
   asset's faces. Two existing clustering tests started failing because the fake
   worker returns no faces, so the seeded clusters were wiped — correct
   production behaviour, so those tests now stamp the current pipeline to stay
   focused on clustering.

#### Still to do for Phase 2
- Nothing. `ml_indexing_test.dart` passes on device; `consent_test.dart` is the
  last run in flight.

### Phase 3 — crop quality (raises the ceiling for everything above)
7. Align the crop with the eye landmarks: rotate so the eye line is horizontal,
   scale so inter-ocular distance hits the ArcFace canonical value, crop a square
   112×112 around the face centre with margin. Removes both the aspect squash and
   the in-plane rotation.
8. Re-embed existing faces once (schema/settings flag), since old embeddings are
   not comparable with aligned ones.

### Phase 4 — People grid presentation
9. `watchPersonSummaries` takes a `minFaceCount` (default 2); one-face clusters are
   hidden behind a "Show all" / "Other people" affordance rather than deleted.

### Verification
- `tool/check.sh`.
- New on-device integration test: run the real worker over the bundled fixtures,
  cluster, assert the man's faces land in one person.
- Manual: re-index on the Pixel and confirm the People grid shows one entry for the
  user. Re-run the DB pull + contact-sheet script to compare before/after.

**Pre-existing test failures, unrelated to this work** — 15 tests were already
red on `feature/metadata-search` before any change here (verified by stashing):
9 `design_goldens_test` / `detail_goldens_test` CI-variant goldens, 4
`library_screen_test` time-filter cases, 2 `albums_screen_test` cases. The
failure set after Phase 1 is byte-identical to that baseline. They need their own
task.

### Method notes (for whoever picks up Phase 2/3)

Reproducing the analysis: pull the DB with `adb exec-out run-as`, then crop each
stored face out of its original for eyeballing. The boxes are normalized `[0,1]`
against the **orientation-corrected** image, so crop from the original after
applying the MediaStore `orientation` column — and note that `photo_assets`
stores the *pre*-rotation dims, so "decoded aspect disagrees with the stored
pair" is how you tell rotation is already baked into the file. HEIC originals
need `sips -s format png` first; the Dart `image` package cannot decode them.

## Separate bug found while investigating (not the People bug)

`photo_library_service.dart:468,578` reads `entity.width` / `entity.height`.
On Android those are the **pre-rotation** MediaStore values: asset `1000004169` is
stored 2448×1376 with `orientation=90`, i.e. it displays as 1376×2448, and
`photo_assets` records the landscape pair. 151 of the 223 face-bearing assets are
affected. photo_manager 3.10.0 exposes `orientatedWidth` / `orientatedHeight` /
`orientatedSize` for exactly this. Anything using the stored dimensions for aspect
ratio — the Saved masonry (`layoutMasonry`) most obviously — gets rotated photos
laid out with a transposed aspect. Worth its own task.
