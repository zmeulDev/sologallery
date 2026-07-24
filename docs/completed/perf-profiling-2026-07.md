# Profiling to decide G-deferred — 2026-07-22

**Status:** COMPLETE. Verdict: **skip G-deferred; proceed to Part 1.**
Measured on the Pixel 9 Pro XL `46121FDAS008AA` (~723-asset real library).
All profiling harness code has been reverted; the shipped app is untouched.

**Question:** Is `G-deferred` worth doing now, or do we skip it and proceed to
Part 1 (animation removal)?

`G-deferred` = cross-asset `upsertIndexed` batching + `.distinct()` on the
Drift `photo_assets` watch streams + `PersonSummary` `==`/`hashCode`. The
performance-audit plan deferred it three times: the v9 index (Group A1) already
made each watch over-fire re-run a *cheap index scan*, so the query cost is
gone; the only remaining cost is the **per-asset Riverpod/widget rebuild** that
each stream fire triggers, N times during a first-run backfill. The audit says
"revisit only if profiling shows real jank on a large library." This task gets
that evidence.

**Non-goal:** implementing G-deferred. This is measurement only. Any code
added is temporary and reverted before commit.

**Device:** Pixel 9 Pro XL `46121FDAS008AA`, ~207 camera-roll images.
Caveat: 207 is modest, not the "1k-asset" benchmark. It is enough to measure
*per-tick jank severity* (per-tick rebuild cost is bounded by visible
sections/rows, not library size — confirmed by the recon: `_MonthTimeline`
watches `watchMonthCounts` + `watchOlderCount`, `buildTimelineRows` is
O(months×months) under the `months` filter, both bounded by the calendar not
the asset count). Only the *count* of jank frames scales with library size, so
a clean run at 207 is strong evidence the problem is bounded; a janky run at
207 will be *worse* at scale. I will not over-seed the library (no `ffmpeg`;
duplicating 207× would risk MediaStore pollution). If 207 is inconclusive I
will say so rather than extrapolate.

---

## What causes jank during a backfill (two confounds)

A backfill scroll has two independent CPU sinks, and G-deferred only addresses
one:

1. **Stream-fire rebuilds** (what G-deferred fixes) — every `upsertIndexed`
   tx writes `photo_assets`, re-firing `watchMonthCounts`,
   `watchMonthPreviews`/`watchOlderPreviews` (per visible section),
   `watchYearCounts`, `watchOlderCount`, `watchRecentSince`. With no
   `.distinct()` and no value-equality on the returned `List`s, every tick is
   a new identity → `_MonthTimeline`/`_YearList` rebuild per asset.
   `watchPersonSummaries` does **not** fire on `upsertIndexed` (it joins
   `persons`+`face_embeddings`, not `photo_assets`), so it is only relevant
   during the face-clustering phase, not the label backfill.
2. **ML worker + thumbnail decode load** (what G-deferred does *not* fix) —
   the background isolate + the indexing thumbnail pool burn CPU/IO during the
   same window. Jank from this sink is not G-deferred's to solve.

So a naive "backfill scroll vs idle scroll" comparison over-attributes. The
plan uses a **freeze-streams knockout** (Tier 2) to separate the two: if
freezing the Library watch streams removes the jank, the rebuilds are the
cause; if it doesn't, the worker/decode load is, and G-deferred won't help.

Note: `.distinct()` alone is a *weak* fix for the active month — during
backfill the month being indexed genuinely changes each tick (count++,
preview gains an id), so `.distinct()` dedups the ~11 other months (cheap
anyway) but not the active one. The real lever in G-deferred is **batching**
(one tx per K assets → K× fewer fires), not `.distinct()`. The freeze
experiment approximates the *upper bound* of what batching achieves; if freeze
doesn't help, batching won't either.

---

## Harness (all temporary, gated behind `--dart-define`)

Nothing committed stays on by default. Three `String.fromEnvironment` flags,
read in `main.dart`, all default off:

- `SOLO_PERF` — enables the frame-timing tracker (below) and auto-triggers
  `indexingService.rebuild()` on first frame (so a backfill starts without
  tapping Settings by coordinate — CLAUDE.md discourages coordinate taps).
- `SOLO_PERF_IDLE` — enables the tracker only; no auto-rebuild. Baseline:
  scroll with no backfill.
- `SOLO_PERF_FREEZE` — enables the tracker + auto-rebuild, AND makes the
  `photo_assets` watch streams emit their first result then never re-emit
  (one-line edit in each `IndexDao.watch*` method: `.watch()` →
  `.watch().then((l) => [l]).expand(identity).take(1)`… simpler: wrap with a
  helper that returns `Stream.value(firstResult)`). The grid won't update
  during the backfill (acceptable for a measurement run). This is the
  knockout.

### Frame-timing tracker — `lib/core/profiling/frame_timing_tracker.dart` (new, temp)
- Registers `WidgetsBinding.instance.addTimingsCallback`.
- Per `FrameTiming`, records `buildDuration` + `rasterDuration` (ms).
- Every 1 s of wall-clock, `debugPrint('PERF: window frames=N build_p95 raster_p95 max jank16 jank32')` (jank16 = # frames where build+raster > 16 ms; jank32 = > 32 ms).
- On app exit, `debugPrint('PERF: TOTAL …')`.
- Surfacing via `debugPrint` is deliberate: under `flutter run --profile` it
  reaches `adb logcat -s flutter:V` (the gotcha that `print`/`debugPrint`
  *don't* surface is for `patrol test`/`connectedAndroidTest`, not `flutter
  run`). CLAUDE.md forbids `debugPrint` in **committed** code; this file is
  removed before commit, and the whole thing is dead unless `SOLO_PERF*` is
  set.

### Build / drive
```bash
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
DEV=46121FDAS008AA
flutter build apk --profile --dart-define=SOLO_PERF=1
$ADB -s $DEV install -r build/app/outputs/flutter_apk/app-profile.apk
# profile build re-grants? re-grant to be safe:
for p in READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_VISUAL_USER_SELECTED; do
  $ADB -s $DEV shell pm grant com.zmeul.sologallery android.permission.$p; done
$ADB -s $DEV logcat -c   # clear log
$ADB -s $DEV logcat -s flutter:V | grep PERF   # capture (background)
# drive a reproducible fling on the Library timeline for ~30s while backfill runs:
$ADB -s $DEV shell monkey -p com.zmeul.sologallery -c android.intent.category.LAUNCHER 1
# (wait ~2s for app foreground, backfill auto-starts)
# loop of vertical swipes:
for i in $(seq 1 40); do $ADB -s $DEV shell input swipe 540 1600 540 400 250; done
# then read the PERF lines captured above
```
Swipe-by-coordinate for **scrolling** is fine here (a fling on a scrollable is
position-based, not semantics-dependent; the gotcha's "no coordinate taps"
warning is about tapping *buttons* by coordinate, which can miss/hit the wrong
target — not about scroll swipes). Confirm the app is foreground and not in
the "NO_INPUT_CHANNEL" state (gotcha) before trusting a run: `adb logcat` must
show the swipe producing `PERF` windows with `frames>0`.

### Decision rule (after each tier, stop if decided)

**Tier 1 — screen (baseline vs idle):**
- Run `SOLO_PERF` (backfill + scroll) and `SOLO_PERF_IDLE` (scroll only).
- Compare `jank16%`, `jank32%`, max frame, p95.
- If backfill+scroll is smooth (jank16% < ~5%, no jank32, p95 < ~24 ms) →
  **skip G-deferred; proceed to Part 1.** Done, no Tier 2.
- If materially worse than idle → go to Tier 2.

**Tier 2 — attribute (freeze knockout):**
- Run `SOLO_PERF_FREEZE` (backfill + scroll, streams frozen).
- If freeze jank ≈ idle (the rebuilds were the cause) → G-deferred's batching
  lever is justified; go to Tier 3.
- If freeze jank ≈ baseline-backfill (rebuilds were *not* the cause — it's the
  worker/decode load) → **skip G-deferred; it won't help.** Proceed to Part 1.

**Tier 3 — confirm the fix closes the gap (only if Tier 2 attributes to rebuilds):**
- Prototype the batched `upsertIndexed` minimally: buffer K=10 asset results in
  `_run` and write them in one tx (a local-only `upsertIndexedBatch`), no
  `_indexOne` restructure — just enough to measure fire-reduction. Revert
  after.
- If batched jank ≈ freeze jank → batching is the fix → **do G-deferred**
  (now, or after Part 1 — see sequencing note).
- If batched jank still ≈ baseline → the per-tick cost is elsewhere (e.g.
  `buildTimelineRows` O(months×months) realloc, or the worker load); G-deferred
  as specified is not the answer → **skip, note the real cause** in the audit
  plan, proceed to Part 1.

### Sequencing note (only relevant if the verdict is "do G-deferred")
Part 1 A3 deletes `asset_thumbnail`'s `AnimatedSwitcher`/`AppMotion.of` and
A2 deletes `EntranceFade` per-section rebuilds — i.e. Part 1 *lowers the
per-tick rebuild cost* that G-deferred is fighting. If profiling shows
G-deferred is worth it, the cheaper order is **Part 1 first, then re-measure**:
Part 1 may shrink the per-tick cost enough that G-deferred drops below the bar
again. I will flag this in the verdict rather than silently doing G-deferred.

---

## Files touched (all temporary)

- `lib/core/profiling/frame_timing_tracker.dart` — **new**, temp.
- `lib/main.dart` — read the three dart-define flags; if any set, init the
  tracker; if `SOLO_PERF`/`SOLO_PERF_FREEZE`, call
  `ref.read(indexingServiceProvider).rebuild()` on `addPostFrameCallback`.
- `lib/core/database/daos/index_dao.dart` — (Tier 2 only) the freeze wrapper on
  the `watch*` methods, gated on `SOLO_PERF_FREEZE`.
- (Tier 3 only, local) `indexing_service.dart` + `index_dao.dart` — the
  batched-write prototype. Reverted.

No schema change, no dependency change, no `pubspec` change → no
merged-manifest re-verify, no migration test.

## Definition of Done for this (measurement) task

1. A verdict recorded in `docs/plans/performance-audit-2026-07.md` under
   G-deferred: **do** or **skip**, with the numbers (jank16/32%, p95, max)
   from baseline / idle / freeze(/ batched) and a one-line rationale.
2. All temporary profiling code reverted (`git status` shows no
   `frame_timing_tracker.dart`, `main.dart` clean, no dart-define references).
   `tool/check.sh` still green (no behavior change in the shipped app).
3. If verdict = **skip**: the audit plan's G-deferred bullet updated to
   "measured, skipped — <numbers>", and Next step points at Part 1.
4. If verdict = **do**: a new implementation plan written for G-deferred
   (this measurement task ends; implementation is a separate, approved plan).

## Results (2026-07-22, device `46121FDAS008AA`, ~723-asset real library)

Profiling harness: `lib/core/profiling/frame_timing_tracker.dart` +
`perf_flags.dart` (gated behind `--dart-define=SOLO_PERF*`), wired in
`main.dart` (tracker) and `app.dart` (auto-`rebuild()` on launch for the
backfill runs). Profile APK, `adb install`, re-grant perms, drive 40×
`input swipe` vertical flings, capture `adb logcat -d -s flutter:V | grep PERF`.
Validity confirmed by pulling the DB mid-run: 335/443 indexed during the first
fling → the backfill was genuinely live while scrolling.

Tier 1 only was needed (no freeze knockout): backfill+scroll vs idle scroll
were within noise, and the build-vs-raster split already attributed the jank.

Steady-state (excluding the one-time cold-start/first-decode window):

| metric | backfill + scroll | idle scroll |
|---|---|---|
| build_p95 | 1.2–2.8 ms | 1.6–2.7 ms |
| raster_p95 | 3.4–7.1 ms | 5.5–10 ms |
| total_p95 | 4–8 ms | 7–12 ms |
| jank16 | ~1 per ~100 frames | 1–2 per ~100 frames |
| jank32 (after cold start) | 0 | 0 |

The build thread — where G-deferred's per-asset stream-fire rebuilds live —
is ~1–3 ms p95 in **both** regimes. The occasional jank is in **raster**
(thumbnail decode/paint), present in idle too, i.e. the decode sink G-deferred
does not address. The only spike is the launch/first-decode window (max
~50–84 ms, 1–2 jank32), identical in idle → not backfill-attributable.

**Verdict:** Tier 1 decision rule met (backfill+scroll smooth: jank16% ~1–2%,
jank32 ≈ 0 after cold start, total_p95 < 24 ms) and the build-vs-raster split
does Tier 2's attribution inline → **skip G-deferred**. The v9 index already
made each watch over-fire re-run a cheap index scan, and the build-thread
reconciliation it triggers is already ~1–3 ms; G-deferred would shave that
further for no perceptible benefit, at the cost of touching the calibrated
face pipeline + Drift reactivity. Revisit only if a much-larger library shows
build-thread p95 climbing (per-tick rebuild cost is bounded by visible
sections/rows, not asset count, so unlikely).

## Next step
Recorded the verdict in `docs/plans/performance-audit-2026-07.md` (G-deferred
bullet + Next step + Status header). Profiling harness reverted, `tool/check.sh`
re-run. The audit track is **complete**; the next track is animation removal
(Part 1, `docs/plans/remove-animations-and-performance.md`).