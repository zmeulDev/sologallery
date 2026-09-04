# Performance audit — 2026-07-22

**Status:** implementation complete for groups A–G, and the last open item
(G-deferred) **measured and skipped** on 2026-07-22 — see the G-deferred
bullet below and `docs/plans/perf-profiling-2026-07.md`. G shipped P6 only
(bytes-over-SendPort; the UI isolate does zero per-asset file I/O); the
cross-asset `upsertIndexed` batching + stream `.distinct()` it was bundled
with was deferred, then profiled on-device: a live backfill scroll is within
noise of an idle scroll (build-thread p95 ~1–3 ms in both; jank is raster
thumbnail-decode, not the stream-fire rebuilds), so the batching is not worth
the risk to the calibrated face pipeline + Drift reactivity. Revisit only if
a much-larger library shows build-thread p95 climbing. The audit is
**complete**; the next track is animation removal (Part 1).

**Scope:** performance-only. Does **not** include the animation-removal work
(see `docs/plans/remove-animations-and-performance.md` Part 1, approved but
not started). Several findings below are flagged *Part 1 A\** — they disappear
when that lands, so don't fix them in isolation if Part 1 is imminent.

**Device:** Pixel 9 Pro XL `46121FDAS008AA`, Android 17.

---

## Findings (ranked; cross-cutting first)

### Cross-cutting — highest leverage

1. **Drift `.watch()` over-fires during ML backfill.** `upsertIndexed`
   (`index_dao.dart:141`) wraps each asset in its own transaction; every commit
   re-runs every active `photo_assets`-reading stream (`watchMonthPreviews`/
   `watchYearPreviews`/`watchOlderPreviews`/`watchRecentSince`/
   `watchMonthCounts`/`watchPersonSummaries`) and Drift emits a fresh `List`
   even when rows are identical → every Library section + People strip rebuilds
   per asset indexed. Three compounding fixes:
   - batch `upsertIndexed` across assets in one txn (model: `upsertMetadata`'s
     500-row `batch`);
   - content-dedup preview streams (`Stream.distinct()`; `PersonSummary`
     needs `==`/`hashCode`);
   - add the missing index (item 2).
2. **No secondary index on `photo_assets`.** Schema v8 has five indexes, none
   on the hottest table. Every Library query filters `is_dated` + ranges/sorts
   `created_at` → full scan + filesort, multiplied by the over-fire above.
   Fix: `@TableIndex(name: 'photo_asset_dated_created', columns: {#isDated, #createdAt})`
   → **schema v9** (dump + `SchemaVerifier` paths v1→9…v8→9, DoD #4).
3. **Detail viewer holds 1080-edge underlay whole session + dup-decodes.**
   `detail_stage.dart:82-86` `AnimatedOpacity(opacity: _revealed?0:1, child:
   AssetThumbnail(size:1080))` keeps the child built (subscription + ~6 MB
   image resident × 3–5 pages ≈ 30 MB invisible) and double-decodes every open
   (1080 gated + 2048 `detailImage`). Fix: stop building the base once
   `_revealed` (conditional, not opacity 0) / `Visibility(visible:false)`.
   *Part 1 A1 deletes this; live today.*
4. **Lifecycle pause doesn't reach sweep/memories/recluster.** `_paused`
   checked only in `_kickResweep` + per-asset ML loop
   (`indexing_service.dart:381,450`). `_sweepMetadata` page loop (`:504`),
   post-todo sections (`:474-489`), `_clusterNewFaces`/`_maybeGlobalRecluster`/
   `_maybeRegenerateMemories` only check `_cancelled` → first-run metadata
   sweep + daily memories/recluster run to completion after backgrounding.
   Violates Absolute rule. Fix: shared `await _awaitNotPaused()` at each await
   boundary + section entry.
5. **P6 confirmed: ML temp-JPEG file I/O on UI isolate.** `_indexOne`
   (`indexing_service.dart:711-786`) does per asset on the main isolate: two
   `thumbnail()` round-trips, two `writeAsBytes(flush:true)` fsyncs, path
   hand-off to worker, 4 cleanup ops. ~8,000 main-isolate file ops on a 1k
   first run. Fix: send `Uint8List` over SendPort, worker writes its own temps
   (or `InputImage.fromBytes` + `entity.width/height/orientation`). Own task.

### Scrolling / thumbnails / memory

- **MED** `imageCache` unconfigured (100 MB/1000 default) + never cleared on
  `paused`/memory-pressure. 2048 detail previews evict grid thumbs; ~100 MB
  pinned while backgrounded. Raise `maximumSizeBytes` ~200–256 MB; clear on
  `paused`. (`main.dart`)
- **MED** `photo_library_service.dart:541` `_entity()` (platform
  `AssetEntity.fromId`) fetched inside the gate slot → cuts decode concurrency
  on cold fling. Move before `_thumbnailGate.run`.
- **MED** `_entityCache` (`:512`) unbounded, pruned only on delete → slow
  session-long handle leak. Cap with LRU.
- **MED-LOW** Duplicate decodes same asset across sizes (300/400/500/1080/2048);
  native cache per-size. Bucket grid sizes or derive from cell width × DPR
  (plan P7).
- **LOW-MED** `previewImage` ungated + `PrecacheAdjacent` ±3 → up to 7
  concurrent 2048 decodes on fast swipe; `thumbnailDataWithOption` not
  cancellable. Second `ThumbnailGate` (cap ~3) for preview with `cancelled`.
- **LOW** `folder_list.dart:127` cover thumb defaults 256 (underfetches ~2×,
  masked by blur). Pass 384.

### Riverpod / rebuilds

- **HIGH** `permissionProvider.refresh()` sets state unconditionally
  (`permission_provider.dart:34-40`) → every resume rebuilds all
  Library/Memories/Onboarding watchers. `if (access != state) state = access`.
- **HIGH** `AlbumsScreen.build` (`albums_screen.dart:32`) watches 4 wide
  streams at top → any `personSummariesProvider` tick rebuilds album grid +
  PeopleStrip + FolderList; `SliverChildBuilderDelegate` lacks
  `findChildIndexForOffset`. Split per-section `Consumer`s + `RepaintBoundary`.
- **HIGH** `_MonthTimeline` (`library_screen.dart:93`) watches 3 wide Drift
  streams; `buildTimelineRows` (`library_timeline.dart:53`) allocates fresh
  list every emission. Dedup streams + memoize rows by `counts` identity.
- **MED** `PhotoDetailScreen` (`detail_screen.dart:135`) watches
  `isFavoriteProvider` at top → whole PageView/Stage rebuilds per favorite
  tick. Push into `Consumer` around `DetailActionBar` only.
- **MED** `IndexingService._emit` per asset (`indexing_service.dart:461`) →
  `IndexingDial` + Settings `_LibraryGroup` rebuild per asset. Throttle ~250 ms
  + final.
- **MED** `MonthGrid/OlderGrid/FolderDetail` re-watch paged stream at top →
  full Scaffold rebuild per page load + cache tick.
- **MED** `personSummariesProvider` (`people_providers.dart:27`) not
  `autoDispose`; `_clusterNewFaces` assigns one face at a time → N emissions.
  Batch writes in one txn.
- **MED** Search `_SearchScreen.build` (`search_screen.dart:91`) watches 4
  providers at top → whole body + `_SearchField` rebuilds per keystroke. Wrap
  `_SearchField` in `Consumer` watching only `searchEnabledProvider`.
- **LOW** `appVersionProvider` `autoDispose` re-runs `PackageInfo` every
  Settings open. Drop autoDispose.

### Widget build / paint (besides #3)

- **HIGH** `album_detail_screen.dart:45-67` `_Grid` missing
  `scrollCacheExtent` (P5 missed this screen) + no bottom-inset padding. Use
  `AssetGrid` or add both.
- **HIGH** `dismissible_photo.dart:331-345` full-screen `Opacity(opacity:1-t)`
  saveLayer per drag frame. *Part 1 A4 removes; live today. Escape hatch: drop
  Opacity, keep Transform.*
- **MED** `detail_screen.dart:58,148` `_toggleChrome` `setState` rebuilds
  whole viewer. `ValueNotifier<bool>` + `ValueListenableBuilder` around chrome.
- **MED** `video_page.dart:91-98` play-glyph rebuilds per playback tick;
  only depends on `isPlaying`. `ValueNotifier<bool>` on transitions.
- **MED** `people_screen.dart:69-75,130` selection `setState` rebuilds whole
  grid; `_SelectedRing` (`:275`) `AnimatedOpacity` composites layer per card at
  opacity 0. `ValueNotifier<Set<int>>`; ring conditional `Visibility`.
- **MED** `asset_thumbnail.dart:61` `AnimatedSwitcher` + `AppMotion.of` in
  every cell → every MediaQuery change rebuilds all. *Part 1 A3 deletes.*
- **MED** `library_screen.dart:174,209` `EntranceFade` per section during fling.
  *Part 1 A2 deletes.*
- **LOW** `asset_thumbnail.dart:68` `videoDurationProvider` watched for every
  cell (even stills). Gate behind `isVideoProvider`.
- **LOW** `memory_player_screen.dart:229` `_Progress` rebuilds full segment row
  per page change. `ValueListenableBuilder` on `_currentIndex`.
- P4 (IndexingDial `RepaintBoundary`) + P8 (itemExtent/prototypeItem) still
  deferred per the no-motion plan.

### Indexing / ML (besides #4, #5)

- **MED** Indexing thumbnails share the grid's 6-slot gate
  (`indexing_service.dart:725,732`) → grid starved to 5 during a pass. Separate
  pool/bypass for indexing.
- **MED** `_clusterNewFaces` (`:547`) loads all clustered exemplars onto the
  UI isolate and clusters there (~38 MB on 50k-face lib), no `Isolate.run`
  (unlike `clusterAll`). Move to `Isolate.run`.
- **MED** `_planMemories` (`:651`) materializes up to 20k rows + up to 50 JOIN
  queries on the UI isolate daily. Push queries into worker or batch
  `assetsForLabels(Set)`/`assetsForPeople(Set)`.
- **LOW** `Isolate.run` spawns fresh isolate each recluster/memories-regen
  (~30–100 ms). Reuse a long-lived isolate / fold into ML worker.
- **LOW** `applyConsent` (`:252`) separate DAO transactions for cleanup where
  one `db.transaction` would be atomic. *(Atomicity nit.)*

### Audited clean (no action)
- Startup (DB lazy, indexing on postFrameCallback), ML isolation (worker
  reused, tflite bytes on main, messenger init), consent atomicity, `_run`
  yield between assets, no duplicate stamping, resweep debounce, no
  `Timer.periodic`. `thumbnailProvider`/`videoDurationProvider` family caching.
  Shipped P1/P2/P3/P5 verified correctly wired.

---

## Implementation order

Grouped into independently-shippable, verifiable commits. Each commit must
pass `tool/check.sh`; schema commit additionally needs migration test + dump;
touched-area device tests run on the Pixel 9 Pro XL.

- [x] **A1. Schema v9: compound index on `PhotoAssets (is_dated, created_at)`** —
      item 2. Single highest-leverage change: every Library query stops
      full-scanning + filesorting, so the `.watch()` over-fire (item 1) becomes
      a batch of cheap index scans instead of a batch of full scans.
      **Verified on device:** v8→v9 upgrade ran on the real DB
      (`46121FDAS008AA`): `user_version` 8→9, `photo_asset_dated_created`
      created, row counts unchanged (226/1489/180 — non-destructive),
      `EXPLAIN QUERY PLAN` on the month-preview shape now reads
      `SEARCH photo_assets USING INDEX photo_asset_dated_created
      (is_dated=? AND created_at>? AND created_at<?)`.
- [x] **A2. Batch the per-label inserts inside `upsertIndexed`** — clean its own
      N+1 (5–15 `await insert` per asset → one `batch.insertAll`). Contained in
      the existing per-asset transaction, so no change to the watch fan-out.
- [ ] **A-deferred. Cross-asset `upsertIndexed` batching + stream `.distinct()`**
      — the rest of item 1. Deferred to Group F: it requires restructuring
      `_indexOne` to separate ML compute from the DB write, which is the same
      surgery P6 (worker-protocol temp-file I/O) needs. Doing both once in
      Group F is cleaner than touching `_indexOne` twice. The index (A1) already
      makes each over-fire re-run cheap, so this is an acceptable interim.
- **A tests:** migration paths updated v1→9…v8→9 + new v8→v9 case with an
  index-existence positive control (`customSelect` on `sqlite_master`).
  `tool/check.sh` green: analyze clean, codegen clean, 649 host tests
  (was 634).
- [x] **B. Lifecycle `awaitNotPaused`** — item 4. Added a shared
      `_awaitNotPaused()` helper and gated the `_sweepMetadata` page loop,
      `_clusterNewFaces` (entry + per-face), `_maybeGlobalRecluster` (entry),
      and `_maybeRegenerateMemories` (entry) on `_paused` as well as
      `_cancelled`. **Unit test:** `pausing mid-pass halts the ML loop until
      resume` — pauses the pass exactly when asset 0's worker call begins (via
      `FakeMlWorker.beforeAnalyze`), releases it, asserts exactly 1 asset is
      labelled and no more land while paused, then resume → 5 labelled.
      `tool/check.sh` green (650 host tests). **Device:** rebuilt + installed
      over the v9 DB, boots clean (pid 14968), no crashes. (The pause/resume
      behavior itself is the unit test's domain — our `logger` doesn't reach
      `adb logcat` per the gotcha, so a device drive of backgrounding wouldn't
      surface the halt; the boot smoke confirms the edits compile and the
      indexing loop still runs on a real isolate.)
- [~] **C. Detail 1080 underlay conditional** — item 3. **Deferred to the
      no-motion plan's Part 1 A1**, which already owns this exact code
      (`detail_stage.dart:38-102`: "with the Hero gone, the two
      `AnimatedOpacity` layers lose their reason to exist. Replace with a
      direct conditional: show the placeholder until the real image resolves,
      then swap"). Doing a separate conditional fix here would duplicate A1
      and risk a reveal/close visual regression for a win A1 removes anyway.
      Not re-litigated — pick up as part of Part 1.
- [x] **D. Cheap Riverpod/memory wins** — `permissionProvider.refresh()`
      now sets `state` only when `access != state` (no more rebuild storm on
      every resume); `imageCache.maximumSizeBytes = 256 MB` in `main.dart`
      (Flutter auto-clears on memory pressure via
      `PaintingBinding.handleMemoryPressure`, so the larger cap is safe — no
      manual `clear` on `paused` needed); `appVersionProvider` dropped
      `autoDispose` → `FutureProvider<String>` (version never changes across a
      session, so re-running `PackageInfo.fromPlatform()` on every Settings
      open was pure waste); `album_detail_screen._Grid` got
      `scrollCacheExtent: kPhotoGridCacheExtent` + the system-gesture bottom
      inset (P5 had missed this one pushed route). **Verified:** analyze clean
      on all four files; 89 host tests across settings/albums/services green
      (incl. `album_detail_screen_test.dart` empty + per-entry cases);
      rebuilt + installed over the v9 DB on `46121FDAS008AA`, boots clean
      (pid 15499), no crash markers, DB still v9 (430 KB, row counts
      unchanged). No new Android dep → no merged-manifest re-verify.
- [x] **E. `Consumer` splits + `_emit` throttle** — shipped the three
      high-confidence, test-verified wins and deferred the rest (see below).
      - **`_emit` throttle** (`indexing_service.dart`): progress now emits at
        most every 250 ms during a pass via `_emitProgress`, plus one
        unconditional `remaining: 0` after the loop so the dial can't linger on
        a throttled mid-pass value through the post-todo cluster/memories work.
        A 1k-asset first run is now ~4 dial rebuilds instead of 1k. **Unit
        test:** `progress emits are throttled, not one per asset` — 60-asset
        fast pass, asserts `emits.length < 60`, that `remaining:0/total:60`
        lands, and the pass ends idle. (Broadcast-stream final emits need a
        50 ms drain before reading — same timing shape as the Drift `.watch()`
        gotcha.)
      - **Detail `isFavorite` → `Consumer`** (`detail_screen.dart`): the
        favorite flag is now watched in a `Consumer` scoped to the bottom
        chrome's `DetailActionBar` alone, so a favorite tick rebuilds only that
        layer instead of the whole `PageView`/Stage.
      - **Search `_SearchField` → `Consumer`** (`search_screen.dart`): the
        field is wrapped in a `Consumer` watching only `searchEnabledProvider`
        (the hint's sole dependency), so a keystroke (which ticks
        `searchQueryProvider`) no longer rebuilds it. The field already mirrors
        the query through its controller.
      - **Deferred to Group F** (entangled with the `_clusterNewFaces`
        `Isolate.run` move there — doing the batch-write restructure now would
        touch `_clusterNewFaces` twice): `personSummaries` batch writes (the
        real People-strip-flicker fix — N per-face emissions → 1 during
        incremental clustering).
      - **Deferred / dropped (low leverage now that A1 made the watch over-fire
        a batch of cheap index scans, and the rebuild cost is mostly cheap
        reconciliation bounded by `RepaintBoundary` + `imageCache` — no
        re-decode/re-paint):** `AlbumsScreen` per-section `Consumer` split
        (also hard to verify on a device with no albums/people and coupled to
        the all-empty full-screen state), `_MonthTimeline` row memoization,
        `MonthGrid`/`OlderGrid`/`FolderDetail` AppBar-out-of-reactive-subtree.
        Revisit if profiling shows real jank on a large library; the index
        change already removed the full-scan multiplier that made these tick.
      **Verified:** `tool/check.sh` green (651 host tests, +1 throttle).
      `integration_test/nav_shell_test.dart` on `46121FDAS008AA` — 5/5 pass,
      incl. "the indexing dial rides right of the capsule while analysing"
      (drives a real pass through the `_emit` throttle path) and the
      bottom-nav/Search-tab transitions (the field + detail `Consumer`s).
- [x] **F. Indexing isolation (partial)** — shipped the two contained,
      test-verified wins; deferred the rest with reasons.
      - **Indexing thumbnail pool** (`photo_library_service.dart`): a separate
        `_indexingGate` (cap 3) for the indexer's own 512/1024 thumbnails,
        selected via a new `thumbnail(..., indexing: bool)` flag. The grid's
        6-slot gate is now reserved for scrolling, so a pass no longer starves
        it to 5. `_indexOne` passes `indexing: true` on both thumbnail calls;
        `FakePhotoLibraryService.thumbnail` updated to match the new signature.
      - **`_clusterNewFaces` batch writes** (`indexing_service.dart` +
        `faces_dao.dart`): the incremental assigner now decides every face's
        person *in memory* (synthetic negative ids for not-yet-minted persons,
        so the clusterer can track them), then applies the whole plan in one
        transaction via a new `FacesDao.applyIncrementalClusters`. One txn →
        one `watchPersonSummaries` emission instead of N per-face writes, so
        the People strip no longer rebuilds once per face during a pass. This
        is the E-deferred `personSummaries`-batch fix, done here because it
        touches `_clusterNewFaces` (the same function the `Isolate.run` move
        would — see the deferred item below). Existing persons are reused
        without touching their name/cover; only new persons mint a row with a
        cover. `assignPersonToFace`/`createPerson` stay as public DAO
        primitives (still used by tests).
      - **Deferred — `_clusterNewFaces` to `Isolate.run`:** the decision phase
        is pure Dart over sendable data (exemplars `Map<int,List<Float32List>>`
        + embeddings), so the move is mechanically safe and result-identical.
        Not done now because (a) `_clusterNewFaces` runs *every* pass, usually
        on a small batch, and `Isolate.run`'s ~30–100 ms spawn overhead would
        dominate the saved compute there — it needs batch-size gating to be
        worth it; and (b) clustering correctness is fragile (the
        detector/crop/threshold are one calibrated system, per Known
        gotchas), so the move deserves its own device verification against
        real embeddings, not a ride-along. Revisit with a size gate +
        `integration_test/ml_indexing_test.dart` extended to assert person
        grouping.
      - **Deferred — `_planMemories` batched queries:** `assetsForLabel`/
        `assetsForPerson` are called per label/person, but bounded
        (`_personCandidateLimit=10`, presentable labels) and the whole planner
        runs at most once a day (or on a 50-asset threshold) — not a per-frame
        cost. Lower priority than the per-pass wins above.
      - **Deferred — cross-asset `upsertIndexed` batching + stream `.distinct()`
        (the rest of cross-cutting item 1):** requires splitting ML compute
        from the DB write inside `_indexOne`, the same surgery P6
        (worker-protocol temp-file I/O) needs. Doing both once in Group G is
        cleaner than touching `_indexOne` twice. The v9 index (A1) already
        makes each over-fire re-run a cheap index scan, so this is an
        acceptable interim.
      **Verified:** `tool/check.sh` green (653 host tests, +2 batch).
      `integration_test/nav_shell_test.dart` on `46121FDAS008AA` — 5/5 pass
      on the Group F build; the "dial rides while analysing" case drives a
      real pass through the new thumbnail pool + indexing loop + batch
      clustering path. DAO-level batch emission proven by two new
      `faces_dao_test` cases (one-batch summary emission; reuse preserves
      name/cover).
      **Note:** on-device integration runs uninstall the app on teardown
      (CLAUDE.md gotcha), so the 226-asset index used for the Group A device
      check was wiped by the Group E `nav_shell_test` run; the photos
      themselves (MediaStore) are untouched and SoloGallery re-indexes on next
      launch after re-grant. Expected consequence of the on-device tests.
- [x] **G. P6 worker-protocol temp-file I/O** — shipped (P6 only; the
      cross-asset `upsertIndexed` batching + stream `.distinct()` deferred
      again — see below). The UI isolate now does **zero** per-asset file I/O.
      `_AnalyzeJob` carries `Uint8List bytes` / `Uint8List? ocrBytes` over the
      SendPort instead of `String path` / `String? ocrPath`; the worker writes
      its own temp from those bytes (`writeAsBytesSync`, no fsync — only needs
      to be readable by ML Kit in-process) and `InputImage.fromFilePath`s it.
      The face-crop decode switched from `File(path).readAsBytesSync()` to
      `img.decodeImage(msg.bytes)` — same bytes, same dimensions, same
      normalized `[0,1]` boxes (the calibrated face system is untouched). The
      `_WorkerInit` spawn payload gains `tempDir` (resolved once on the main
      isolate via `getTemporaryDirectory`). `MlWorker.analyzeFile` →
      `MlWorker.analyze({required Uint8List bytes, Uint8List? ocrBytes, …})`.
      `_indexOne` dropped both `_writeTemp` calls + the `finally` delete
      cleanup; `_writeTemp`, the `tempDir` field/constructor-param, and the
      now-unused `dart:io`/`dart:typed_data`/`path_provider` imports were
      removed from `indexing_service.dart`. `FakeMlWorker` + the three device
      tests (`ml_indexing_test`, `consent_test`, `test_fixtures_test`) moved to
      `analyze(bytes:…)`; `FakePhotoLibraryService.thumbnail` now returns a
      fresh, size-tagged buffer per call so the 512 label/face bytes and the
      1024 OCR bytes are genuinely distinct (a real thumbnail of a different
      size is a different image) — keeps the OCR-wiring `isNot` assertion
      meaningful. `Uint8List` over a SendPort is copied, but at ~30-300 KB per
      thumbnail and sequential worker processing the memcpy is cheap and never
      blocks on disk; `TransferableTypedData` not worth the complexity.
      **Verified:** `tool/check.sh` green (analyze + codegen + 653 host tests;
      the 32 `indexing_service_test` cases incl. the OCR-wiring + pause-via-
      `beforeAnalyze` + consent-gating paths). Device on `46121FDAS008AA`:
      `ml_indexing_test` (real worker labels device photos, content search
      finds them), `test_fixtures_test` 2/2 (synthetic face detected + non-zero
      tflite embedding via the new bytes path; consent gating), `consent_test`
      4/4 (incl. the face-backfill full real pass → embeddings + persons),
      `nav_shell_test` 5/5 (incl. "dial rides while analysing" — a real pass
      through `_indexOne` → `analyze(bytes:…)` while the UI is live). No schema
      change, no new Android dep → no merged-manifest re-verify. The avatar
      crop is byte-identical by design; the `test_fixtures` + `consent` face
      tests are the on-device guard the plan's risk callout asked for.
- [~] **G-deferred. Cross-asset `upsertIndexed` batching + stream `.distinct()`**
      — the rest of cross-cutting item 1. **Measured on device
      2026-07-22 → SKIP.** Profiling harness + verdict in
      `docs/plans/perf-profiling-2026-07.md`. Summary: on the Pixel 9 Pro XL
      (~723-asset library, real camera roll), a live backfill scroll vs an idle
      scroll are within noise. The build thread — where the per-asset stream-
      fire rebuilds that G-deferred targets live — is **`build_p95` ≈ 1–3 ms
      in both regimes**; the occasional jank is in **raster** (thumbnail
      decode/paint), present in both idle and backfill, i.e. the decode sink
      G-deferred does *not* address. Steady-state numbers (backfill / idle):
      total_p95 4–8 / 7–12 ms, jank16 ≈ 1 per ~100 frames in both, jank32 0
      after the cold-start window in both. The only spike is the one-time
      launch/first-decode window (max ~50–84 ms, 1–2 jank32) — identical in
      idle, so not backfill-attributable. The v9 index (A1) already made each
      watch over-fire re-run a cheap index scan, and the build-thread
      reconciliation it triggers is already ~1–3 ms — G-deferred would shave
      that further for no perceptible benefit, at the cost of touching the
      calibrated face pipeline + Drift reactivity. **Revisit only if a future,
      much-larger library shows build-thread p95 climbing** (the per-tick
      rebuild cost is bounded by visible sections/rows, not asset count, so it
      is unlikely to). Mechanically, if ever revisited: restructure `_indexOne`
      to return `(id, meta, analysis)` and have `_run` batch the
      `upsertIndexed` + `insertFaces` writes across N assets in one txn; add
      `==`/`hashCode` to `PersonSummary` and `.distinct()` to
      `watchPersonSummaries` (+ the Library preview streams, which already
      have value equality). Note `.distinct()` alone is a weak fix for the
      *active* month (it genuinely changes each tick); batching is the real
      lever.
- [ ] *Items flagged Part 1 A\**: skip — animation removal handles them.*

## Verification (Definition of Done)

1. `tool/check.sh` green (analyze, build_runner, unit + widget).
2. Schema v9: schema dump committed + migration test (every path to v9).
3. Touched-area integration tests pass on Pixel 9 Pro XL `46121FDAS008AA`,
   one file per run, reinstall + `pm grant` between each (CLAUDE.md gotcha).
4. Manual end-to-end on device: Library scroll during a fresh ML pass (the
   backfill rebuild storm), detail open/close (1080 underlay), Albums scroll,
   app backgrounding during indexing (lifecycle).
5. No schema → no merged-manifest re-verify needed (no new Android dep).

## Next step
All shipped groups (A–G) are verified — `tool/check.sh` green (653 host
tests) and `nav_shell_test` 5/5, `ml_indexing_test`, `test_fixtures_test`
2/2, `consent_test` 4/4 on `46121FDAS008AA`. **G-deferred is measured and
SKIPPED** — on-device profiling (see
`docs/plans/perf-profiling-2026-07.md`) showed a live backfill scroll is
within noise of an idle scroll: the build-thread reconciliation G-deferred
targets is already ~1–3 ms p95 in both, and the only jank is raster
(thumbnail decode), which G-deferred does not address. The audit is
**complete**. The remaining unstarted track is the animation-removal work
(Part 1, `docs/plans/remove-animations-and-performance.md`) — that is the
next thing to pick up.