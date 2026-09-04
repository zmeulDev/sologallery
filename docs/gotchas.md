# SoloGallery — Known gotchas

Hard-won traps, kept verbatim (bold lead-ins preserved so existing `grep`
habits still work) and grouped by area for findability. **Add new ones
here**, not in `AGENTS.md`; `AGENTS.md` keeps only the handful that touch
almost every change. Full postmortems, when a gotcha deserves one, live
alongside the completed plan docs in `docs/plans/`.

Short form only here; long-form incident writeups go in `docs/plans/`.

---

## Drift

- **drift and drift_dev patch versions must match exactly.** With
  `drift 2.34.2` + `drift_dev 2.34.0`, `schema dump`/`schema generate`
  fail to compile (drift_dev's `SchemaVerifier` resolves
  `GeneratedDatabase` from drift's `drift3_preview`, which lacks
  `allSchemaEntities`). Pin `drift` to drift_dev's patch (currently
  `2.34.0`); re-check when bumping either. Note `drift` is pinned exactly in
  `pubspec.yaml` but `drift_dev` still carries a caret (`^2.34.0`), so a
  `pub upgrade` can float it off the pinned patch and reintroduce this.
- **Drift: a column can't reuse a builder name** (`text`, `integer`, `boolean`,
  `real`, `blob`, …). `TextColumn get text => text()()` recurses / conflicts with
  `Table.text` → "conflicting_field_and_method". Name it something else
  (`content`) and map in the DAO.
- **Drift: an aggregate in a joined select must be added to the selected
  columns.** `select(t).join([...])..groupBy([...])` with
  `expr.count()` read via `row.read(count)` throws "This result set does not have
  a column for that expression" unless you `..addColumns([count])` on the query.
- **Drift `column.year`/`.month` datetime extraction runs in UTC.** With the
  default int (unix-seconds) DateTime storage, `photoAssets.createdAt.month`
  emits `strftime('%m', …, 'unixepoch')` — **UTC**, no `'localtime'`. Grouping the
  month grid by it mis-buckets assets near a month boundary in any non-UTC
  timezone (a local-Aug-1 00:00 capture reads as July), disagreeing with
  `YearMonth.fromDate` (local) and the `monthAssets` `[start,end)` window (local
  DateTimes → same absolute instant). Group by a
  `CustomExpression<String>("STRFTIME('%Y-%m', created_at, 'unixepoch', 'localtime')")`
  instead (`YYYY-MM`, so lexical order = chronological). See
  `IndexDao.watchMonthCounts`.
- **Drift migrations: `m.createTable(current)` builds the *current* shape, so a
  table whose columns change after introduction needs an `else if` guard and
  to-current-only validation.** Once `photo_assets` changed in v4, the v1→v2
  `createTable(photoAssets)` branch produced the v4 shape (nullable `indexed_at`
  + `is_dated`), so the v4 `alterTable` must be `else if (from < 4)` (else a
  v1→v4 run double-adds `is_dated`). And `SchemaVerifier.migrateAndValidate(db, k)`
  for an **intermediate** k now fails — `createTable` reflects the live shape, not
  vk's — so validate every path **to the current version** (v1→v4, v2→v4, v3→v4),
  not each step. `TableMigration(t, newColumns: […])` recreates the table (relaxing
  `NOT NULL`→nullable, adding defaulted columns) copying existing rows.
- **Drift + widget tests (`FakeAsync`) — five traps.** (1) `await`ing a
  Drift **stream** `.first` (e.g. `dao.watchAll().first`) inside a
  `testWidgets` body **deadlocks** — the stream needs the fake clock pumped
  but nothing pumps while you await. Assert via a one-shot `.get()`
  (`db.select(db.table).get()`) instead. One-shot Futures are fine;
  `ProviderContainer` tests (real async, no FakeAsync) are also fine. (2)
  Disposing a `ProviderScope` that holds a Drift `.watch()` schedules a
  zero-duration Timer (`StreamQueryStore.markAsClosed`) that trips the
  "A Timer is still pending" teardown invariant — end such tests by disposing
  the tree and elapsing time: `await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));`. **This must run in the test
  *body*, not `addTearDown`** — the pending-timer invariant
  (`_verifyInvariants`) runs *before* `addTearDown` callbacks. (3) Any
  sheet/screen containing a focused `TextField` never settles (cursor-blink is
  periodic) — use **bounded pumps**, never `pumpAndSettle`, once a `TextField`
  is on screen. (4) A screen whose `AsyncValue` **loading** branch shows a
  `CircularProgressIndicator` (any `.when(loading:)` grid) makes `pumpAndSettle`
  **hang forever** (the spinner always schedules a frame) until the stream
  emits — use bounded pumps for title/structure assertions, or emit data first.
  When a screen starts consuming the DB, its existing widget tests must add a
  `databaseProvider.overrideWithValue(inMemoryDb)` or they hang here. (5) A
  `StreamProvider` whose stream **errors** (or whose `overrideWith` create
  throws) stays `AsyncLoading` under fake-async — the error event never
  renders. Force the error state with
  `provider.overrideWithValue(AsyncError<T>(e, StackTrace.empty))` (riverpod
  3.x). `ProviderContainer` tests surface the error fine (real async).
- **Testing Drift `.watch()` reactivity: await the initial emission before
  mutating.** A `.watch()` query emits its current result on subscribe, then
  again on change. If a test mutates the table *before* the initial query
  resolves (both race on the DB executor), the two emissions coalesce and the
  matcher sees only the post-mutation state — `emitsInOrder([before, after])`
  fails with `after` at index 0. Collect emissions with a `listen` and put a
  real `Future.delayed` between the initial read and the mutation (and between
  mutation and assert). The reactive Library grids use a **growing-window
  watch** (`WatchedAssetsNotifier`: `LIMIT` grows on `loadMore`, offset stays 0,
  re-subscribing) — one live subscription stays correct across pages, unlike the
  one-shot offset paging in `PagedAssetsNotifier` (still used by Search).
- **A screen that consumes any Drift `.watch()` needs the dispose-tree teardown
  in every widget test that builds it — including bare "shows its title" smokes.**
  When a screen starts watching a stream (e.g. Settings' stats/theme, or Library
  after the cache work), its existing `screens_test.dart`-style cases start
  tripping the pending-timer invariant unless they end with
  `pumpWidget(SizedBox()) + pump(1s)` (gotcha above). Grep the screen's test
  files when you make a static screen reactive. Also: a scrolling `ListView`
  (Settings) lazily builds — assert off-screen sections/rows only after
  `tester.binding.setSurfaceSize(tall)` (reset with `setSurfaceSize(null)`), else
  `find.text` on a below-the-fold row returns nothing.

---

## photo_manager / Android permissions & manifest

- **ML Kit / tflite deps inject privacy permissions + a push receiver.** The
  Play-Services / Firebase-IID / gms chain behind `google_mlkit_*` and
  `tflite_flutter` merges into the **release** manifest:
  `com.google.android.c2dm.permission.RECEIVE` + a
  `com.google.firebase.iid.FirebaseInstanceIdReceiver` (image_labeling), and
  `READ_PHONE_STATE` + `WRITE_EXTERNAL_STORAGE` (face_detection / tflite) — all
  fail the network/privacy check (Absolute rules / DoD #5) though every model is
  bundled and on-device. `android/app/src/main/AndroidManifest.xml` strips them
  all with `tools:node="remove"` (permissions + the same-named `<receiver>` in
  `<application>`). No `INTERNET` is added. **Re-verify the merged manifest after
  any ML/tflite dep bump.** Feed ML a downsized JPEG **thumbnail** (not the
  original) — bounds memory (HEIC OOM) and avoids HEIC-decode issues. The worker
  isolate must call `BackgroundIsolateBinaryMessenger.ensureInitialized(token)`
  **before** any ML Kit call or platform-channel calls hang; **tflite is FFI and
  runs in the isolate with no messenger** (load the `.tflite` bytes on the main
  isolate via `rootBundle` and pass them to the worker). **Never kill the worker
  isolate while a native ML Kit call is in flight** — `Isolate.immediate` ends
  the Dart side but the native task still completes and tries to reply to the
  dead port, which triggers a fatal `did_send` abort in the engine. Dispose must
  send a shutdown command, wait for the worker to close its models and exit
  naturally, and only force-kill as a last resort after the shutdown ack. Face
  boxes are stored in
  the 512-thumb coordinate space so avatars crop the cached thumbnail. **Labels
  and faces run on the 512 thumbnail; OCR runs on a separate larger (1024)
  thumbnail** (`_ocrEdge`, via `analyzeFile(jpegPath, {ocrPath})`) for small-text
  recall — don't collapse them back to one image (it would move the face-box
  space off 512 and break avatars, or shrink OCR again). Both are still bounded
  thumbnails, never the original. Host tests use fake (undecodable) bytes, so
  avatar geometry only shows on-device — validate people avatars on a real device.
  **At runtime ML Kit's bundled Google `datatransport` (Firelog) keeps trying to
  upload usage telemetry** — logcat shows repeated `W/TransportRuntime: Error
  scheduling event ConnectivityService: Neither user … nor current process has
  android.permission.ACCESS_NETWORK_STATE`. This is *expected and harmless*: the
  SDK attempts it, the manifest strip (no `INTERNET`/`ACCESS_NETWORK_STATE`)
  blocks it, so nothing leaves the device. Treat the line as *proof* the network
  strip is holding, not a bug — don't "fix" it by granting the permission.
- **`thumbnail(id, N, N)` is aspect-*fill*: the returned image's SHORT edge is
  N, the long edge is larger.** A 4:3 photo requested at 512 comes back
  **683×512**, at 1024 comes back 1365×1024 — it is not square, and it is *not*
  bounded by N either. (An earlier version of this note claimed the opposite —
  "a portrait comes back ~384×512", i.e. long edge N — and that error shipped:
  face boxes were stored as thumbnail pixels and rescaled by `longEdge / 512`,
  giving 2.67 where the truth was 2.0, so every People avatar cropped ~33% too
  large and down-and-right of the face, with edge faces pushed clean out of the
  circle.) **Never store a pixel coordinate whose reference dimensions you don't
  also store** — face boxes are now normalized `[0, 1]` fractions at write time
  in `ml_service._embedFace`, so no consumer has to reconstruct the size
  (`FaceEmbeddings`, schema v7). Verify with the DB, not by reasoning about the
  API: `SELECT MAX(right), MAX(bottom) FROM face_embeddings` exceeding the
  requested edge is what proved it.
- **photo_manager Android: month windows must filter `DATE_TAKEN`, not
  `DATE_ADDED`.** `FilterOptionGroup.createTimeCond` filters MediaStore
  `DATE_ADDED` (when a file landed on the device), but ordering and the reported
  `createDateTime` use `DATE_TAKEN` (capture date, fallback `DATE_ADDED` when
  0). A photo captured in June but added in July then lands in July's
  `createTimeCond` window while the grid groups/orders it under June → June
  section vanishes and July shows June photos inside. Fix: window by capture
  date with an `AdvancedCustomFilter` on `CustomColumns.android.dateTaken` (a
  `DateColumnWhereCondition`; for `dateTaken` it emits **milliseconds**, other
  date columns seconds). Undated assets (`datetaken` null/0) never match a
  window — surface them in a separate "Older" bucket
  (`WhereConditionItem.text('(datetaken IS NULL OR datetaken = 0)')`, ordered by
  `date_added`). iOS's `creationDate` is consistent across filter/order/report,
  so it keeps the classic `createTimeCond` path (see
  `PhotoLibraryService._androidWindow`/`_darwinFilter`). Host fakes can't catch
  this — `integration_test/library_month_grouping_test.dart` asserts the axes
  agree on-device.
- **EXIF GPS needs `ACCESS_MEDIA_LOCATION` *and* an opted-in permission
  request, or the Location chip is silently always empty.** Android 10+ strips
  location out of the photo bytes handed to an app that lacks it, so
  `AssetEntity.latlngAsync()` returns nothing for *every* photo — no error, no
  log, just a chip that never appears. Two things are required and neither is
  the default: the permission in `AndroidManifest.xml`, and
  `PermissionRequestOption(androidPermission: AndroidPermission(…,
  mediaLocation: true))` on **both** `getPermissionState` and
  `requestPermissionExtend` — photo_manager skips the permission entirely when
  either is missing (`PhotoLibraryService._permissionOption`). Note MediaStore's
  own `latitude`/`longitude` columns read `NULL` on modern Android whatever you
  do, so querying them is not a way to check this; `detail_actions_test`'s
  coordinate case is. The fixture also needs a `DateTimeOriginal`: MediaStore
  fills `DATE_TAKEN` from it, and without one a seeded asset is *undated* and
  never appears in `libraryMetadataPage(dated: true)` at all.
- **Android has no "not determined" photo-permission state.**
  `PhotoManager.getPermissionState` returns `denied` before the user is
  ever asked (unlike iOS's `notDetermined`). Onboarding must therefore
  offer "Allow" (which triggers the native request) on first run and only
  switch to "Open Settings" *after* a prompt was actually refused — see
  `OnboardingScreen`'s `_attempted` flag.
- **`video_player` (media3) injects network permissions** — `video_player_android`
  declares `INTERNET` **and** `ACCESS_NETWORK_STATE` (for streaming). Both merge
  into the **release** manifest and break the network-free check (Absolute rules /
  DoD #5). `android/app/src/main/AndroidManifest.xml` strips both with
  `tools:node="remove"` (needs `xmlns:tools` on `<manifest>`); media3 degrades to
  no network monitoring for local files. `WAKE_LOCK` is left (screen-on during
  playback, not a privacy concern). Surfacing videos also needs `READ_MEDIA_VIDEO`.
  Re-verify the merged manifest after any video-dep bump. Playback uses local
  `entity.file` only — never a URL.
- **Debug builds inject the `INTERNET` permission** (Dart VM service /
  hot reload) — expected. Verify the **release** merged manifest instead
  (Definition of Done #5): no `INTERNET`/`READ_PHONE_STATE`/`c2dm`.
- **R8 silently breaks ML Kit, and only a *release build on a device* shows it.**
  ML Kit boots via `MlKitInitProvider`, which reflectively instantiates the
  `*Registrar` class each artifact names in its manifest metadata. R8 sees no
  caller, strips the no-arg constructors, and every component fails to
  register — logged only as `W ComponentDiscovery: Invalid component registrar
  … NoSuchMethodException: …FaceRegistrar.<init> []`. **The app does not
  crash**, so labels/OCR/faces would come back empty in production while every
  debug test passed. `android/app/proguard-rules.pro` keeps the
  `ComponentRegistrar` implementors' constructors. Re-run a release build on
  device after any ML/R8/AGP bump and grep logcat for
  `Invalid component registrar`.
- **`run-as` does not work on release builds** (`run-as: package not debuggable`),
  so the pull-the-DB oracle used for debug verification is unavailable there —
  and `isDebuggable = true` on the release buildType does not restore it,
  because the Flutter Gradle plugin forces it back off. For a release smoke,
  filter logcat to the app's own pid (`adb logcat -d | awk -v p=$(adb shell
  pidof <pkg>) '$3==p'`) and assert on codec/registrar activity instead. Beware
  grepping unfiltered logcat for `vision`/`face`: unrelated system chatter
  ("provisioning", "Surface") matches and inflates the count into false
  evidence.
- **`D/HWUI: Failed to create image decoder with message 'unimplemented'` is
  benign** — Android's hardware UI pipeline logs this when its GPU-backed
  decoder path isn't implemented for the requested codec (commonly seen on
  Pixel 9 Pro XL / Android 16+ for HEIC + JPEG swap chains). The renderer
  falls back to the software decoder and the image still draws; the bytes
  count in the matching `[SoloGallery.photos] previewImage(...) bytes=…`
  line is non-zero, and the corresponding `detailImageProvider` /
  `adjacentThumbnailProvider` lines land. Don't grep this as an error, don't
  suppress it (the engine routes the fallback through it), and don't be
  tempted to grant GPU decoder permissions to silence it — there are none to
  grant, and the log is a real-world signal of HWUI's codec-coverage gaps.
  Verified on the 2026-07-27 iOS-asset-id-encoding session with
  `1000005645` (MediaStore id) → 5 of these lines → image still rendered in
  ~951ms.

---

## Indexing / ML / faces

- **`IndexingService.start()` must never drop a request, and consent flags must
  land atomically before any pass is kicked.** `start()` used to `return` when
  `_running`, and `ConsentNotifier.record()` persisted the three consent flags
  one at a time, each self-kicking a pass. So on first run the pass kicked by
  `search_enabled` read `faces_enabled` before it had been written, ran with
  faces off, stamped `indexed_at` on every asset anyway (`_indexOne` stamps
  regardless of which features ran), and `pendingMlIds` — unstamped rows only —
  never offered them again. People stayed empty until the user toggled face
  detection in Settings, which runs in isolation and wins. Now: `SettingsDao
  .setConsent` writes all three in one transaction, `IndexingService
  .applyConsent` is the single onboarding entry point, and `start()` sets
  `_dirty` so a mid-pass request folds into the running pass. **A re-queue that
  lands mid-pass is not enough on its own** — the rest of that round re-stamps
  over it, so `_run()` also tracks the flags each round ran with and calls
  `resetMlPending()` at the top of a round in which a feature switched on.
- **Periodic maintenance work must sit *outside* `_run`'s `if (todo.isNotEmpty)`
  branch.** `todo` is the list of assets still needing ML, so on a fully indexed
  library it is empty on every launch and anything nested inside that branch
  never runs again. Face clustering lived there and so the periodic global
  re-cluster — the only thing that heals a grouping produced by an older
  algorithm — was unreachable on exactly the installs that needed it. The
  memories refresh was already outside for the same reason. Anything gated on its
  own cheap DB check (`_clusterNewFaces`, `_maybeGlobalRecluster`,
  `_maybeRegenerateMemories`) belongs next to it, not inside.
- **Face clustering: compare against *faces*, never a running centroid, and note
  that average linkage over normalized embeddings is just the dot product of the
  cluster means.** A centroid drifts away from every individual member as a
  cluster grows, so a nearest-centroid assigner loses recall precisely on the
  most-photographed people (on a real 223-face library it split one person across
  six "people"; two of his singletons scored 0.688 and 0.655 against a *member*
  of his main cluster, above the 0.65 threshold, while the 34-face mean scored
  below it). A single greedy pass also has no merge step, so once two clusters of
  one person exist nothing can reunite them. `clusterAll` is average-linkage
  agglomeration: because `Σ_{a∈A,b∈B} a·b = (ΣA)·(ΣB)` for L2-normalized vectors,
  the average cross-pair similarity is `meanA · meanB` with **no re-normalization**
  — re-normalizing the means turns it back into centroid linkage. Thresholds are
  empirical and must be validated against pulled real embeddings, not reasoned
  about. Clustering is **two-stage**: `IncrementalClusterer` assigns each fresh
  face to the person holding the single most similar of ≤12 stored *exemplar*
  faces at `incrementalAssignThreshold` **0.62** (deliberately higher — a
  one-face match is weaker evidence than a whole-cluster average, and a
  short-lived duplicate is cheaper to undo than two fused people), and the
  periodic global `clusterAll` re-clusters from scratch at
  `clusterMergeThreshold` **0.45**. Thresholds: 0.45 is right for this
  pipeline, and 0.40 (which looked clean against
  three probe clusters) fuses visibly different people once every merge it adds is
  inspected. Single linkage chains — at 0.60 it produced one 129-face blob
  including dog faces.
- **Resetting the re-cluster baseline without stamping `_clusterAlgoKey` makes
  the next pass treat it as an algorithm change.** `_maybeGlobalRecluster` runs
  when either the face count crossed the threshold *or* the stored algorithm
  version is stale. After manually clearing derived data (folder-scope change,
  consent re-establishment), write both `_reclusterBaselineKey` *and*
  `_clusterAlgoKey` to the current version so the small post-reset face count
  doesn't immediately trigger a global re-cluster.
- **The face detector, the crop and `clusterMergeThreshold` are one calibrated
  system — changing how a face is detected invalidates the threshold.** Switching
  `FaceDetectorOptions` to `performanceMode: accurate` looked like a pure win
  (it does not report `fast`'s outright false positives — dog faces, a beer
  glass, a patch of sky — so junk detections fell 23 → 3, total faces 223 → 161,
  people 60 → 33, singletons 27 → 12). Every one of those aggregates was an
  improvement and every one of them was hiding a regression: `accurate` returns
  *different, tighter* boxes, so every crop and embedding changed, and the
  most-photographed person went straight back to being split six ways
  (24+16+3+1+2+1 of his 47 faces). Re-tuning could not rescue it — sweeping the
  threshold went from "split 5–6 ways" at 0.35 to "one 92-face cluster with three
  other people in it" at 0.30, with nothing usable between. Reverted to `fast`
  with `enableLandmarks: true`; the pose gate alone gets junk 23 → 6 and keeps
  46 of his 47 faces in one cluster. **Never evaluate a clustering change on
  cluster counts, singleton counts or face totals — they all improve when a
  person shatters into several tight clusters. Track a known person's faces
  individually, end-to-end, and carry verified-distinct people as contamination
  controls** (and note that "did anything bleed into X's cluster" does not catch
  two *other* people fusing with each other). **And track the person, not a face
  set:** "46 of his 48 reference faces cohere" scored as a fix while he still
  appeared twice on the People screen, because the reference set was one of his
  old clusters and by construction held none of his sunglasses faces. The metric
  that matches the bug report is *how many People entries are this person*.
- **Two *drawn* synthetic faces embed too close for the real MobileFaceNet to
  tell apart.** `integration_test/people_test.dart` needs a library with two
  distinct people; a second `_syntheticFace()` fixture — varied by colour,
  proportions, in-plane tilt — never dropped below ~0.57 cosine similarity to
  the first (threshold `clusterMergeThreshold` 0.45), and the occluders that
  *did* move it far enough (beard, sunglasses) stopped ML Kit detecting a face
  at all. Synthetic frontal faces collapse into one region of the embedder's
  space — it is trained to be invariant to exactly what a 2-D drawing can vary.
  The second identity is `test_assets/photo_face.jpg`, a StyleGAN
  (thispersondoesnotexist) face: not a real person, no EXIF, but photographic
  enough to embed clear of the drawn one.
- **`IndexingService` toggle methods kick a pass fire-and-forget, so `await
  start()` right after one returns immediately** (`start()` no-ops while
  `_running`). The Settings switch must not block on a full re-index, so
  `setFacesEnabled(true)` calls `unawaited(start())`; a test that then awaits
  `start()` asserts against an unfinished pass and sees empty tables. Poll for
  the outcome with a deadline instead.
- **A face avatar is a zoomed *crop*, so its thumbnail size follows the face box,
  not the circle.** Sizing it from the displayed 64pt circle understates the
  requirement by the zoom factor: a face filling ~15% of the frame needs ~1000px
  of source to fill a 64pt circle at 3x. `avatarThumbEdge()` derives the edge
  from the box's own normalized extent and snaps to `[256, 384, 512, 768, 1024]`
  — buckets so the same face at two sizes shares one decode, and a 1024 ceiling
  because that is what shipped and lowering it softens group-photo avatars.

---

## Patrol / on-device testing

- **Patrol on-device setup:** `patrol` + `integration_test` dev deps, the
  `patrol:` block in `pubspec.yaml`, the JUnit runner at
  `android/app/src/androidTest/.../MainActivityTest.java`, and the
  `testInstrumentationRunner` + orchestrator in `app/build.gradle.kts`.
  Run with `patrol test -t <file> -d <device>` (needs `patrol_cli`). The
  Android-14 *limited*-access flow drives a device-specific system photo
  picker, so that case is left `skip: true` — enable per device.
  **patrol `$('text')` is an *exact* whole-string finder** (not substring):
  for multi-line/partial notes use `find.textContaining(...)`. Also, a
  RenderFlex overflow on device throws and fails the test at the *next*
  expect — that's how the AlbumCard 7px overflow surfaced; layout bugs are
  real failures on-device even though host widget tests may tolerate them.
- **Patrol native selectors: use exact `text:`, never `textContains:`, for a
  dialog button — and a "successful" tap step proves nothing.** Android's
  delete-confirmation dialog is titled "Allow SoloGallery to delete this
  photo?" over `Deny`/`Allow` buttons, so `Selector(textContains: 'Allow')`
  matches the **title** (a non-clickable `TextView`) first. Patrol taps it,
  reports the step ✅, and the dialog just stays up — the run then hangs
  forever with an all-green step trace, which reads like a slow test rather
  than a missed tap. Two corollaries: `PhotoManager.editor.deleteWithIds` goes
  through `MediaStore.createDeleteRequest` on Android 11+, so **any test that
  deletes an asset must be a `patrol` test** (a plain `integration_test` has
  nothing to tap and hangs in teardown — the assertions themselves pass long
  before, and the row still disappears because uninstall takes app-owned media
  with it, so the cleanup *looks* like it worked). And `uiautomator dump`
  returns nothing while patrol holds the UiAutomation connection, so to read a
  stuck dialog you have to kill the run first — the dialog outlives it.
- **On-device integration runs wipe the photo permission — grant it between
  install and run, one file at a time.** `flutter test integration_test/…`
  **uninstalls** the app when the run ends (`dumpsys package` afterwards reports
  "package not found"), and `patrol test` does the same. Any plain
  `integration_test` file asserting `access.canReadLibrary` then fails on the
  *next* invocation, and passing two files to one `flutter test` call fails the
  second (the first file's teardown already uninstalled). There is no native
  dialog to drive from a plain `integration_test`, so pre-grant it:
  ```bash
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  for p in READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_VISUAL_USER_SELECTED; do
    adb shell pm grant com.zmeul.sologallery android.permission.$p; done
  # Face tests only: the fixture is pushed, not bundled (test_assets/README.md).
  adb shell mkdir -p /sdcard/Android/data/com.zmeul.sologallery/files
  adb push assets/test_fixtures/synthetic_face.jpg \
    /sdcard/Android/data/com.zmeul.sologallery/files/
  flutter test integration_test/<one_file>.dart -d <device>   # repeat per file
  ```
  The grant survives `flutter test`'s own reinstall-over-existing, just not the
  teardown uninstall. `patrol test` files don't need this — they drive the real
  dialog via `$.platform.mobile.grantPermissionWhenInUse()`. Symptom of a missed
  grant is a *silent* one: `PhotoManager` returns **empty** lists (zero folders,
  zero assets) rather than throwing, so an under-asserted test passes vacuously.
- **iOS: `integration_test` runs only on a *physical* device, and only as plain
  `flutter test` — not the simulator, not `patrol`.** (1) The **simulator can't
  build at all** on an Apple Silicon Mac: `google_mlkit_image_labeling`'s iOS
  frameworks ship no arm64-simulator slice, so `flutter pub get` writes
  `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64` into `ios/Flutter/Generated.xcconfig`
  and the arm64 sim has no buildable arch (`flutter test -d <sim>` → "Unable to
  find a destination matching…"). (2) **patrol on iOS is not wired** here — no
  `RunnerUITests` target, and the project has SPM enabled so patrol attaches as
  a Swift package to `Runner` only; `patrol_cli` 4.6.1 also forces `--release`
  on a physical device. Run iOS integration tests as
  `flutter test integration_test/<file>.dart -d <id> --no-uninstall`.
- **iOS fixture seeding + a debug build that won't launch.** No `/sdcard`; push
  fixtures into the app data container with
  `xcrun devicectl device copy to --device <id> --domain-type appDataContainer
  --domain-identifier com.zmeul.sologallery --source test_assets/<f> --destination
  Documents` — `fixtureFile()` resolves them from
  `getApplicationDocumentsDirectory()`. `getExternalStorageDirectories()`
  **throws** `UnsupportedError` on iOS (not null) — guard it. The container
  survives a `flutter test` reinstall but **not** `flutter install` (which
  uninstalls first and wipes it); the photo-permission (TCC) grant survives
  both. To grant photo access you need the *real* app, but a **debug** Flutter
  build crashes on a home-screen launch (`EXC_BAD_ACCESS` in
  `-[VSyncClient initWithTaskRunner:callback:]` under `viewDidLoad`) — install a
  **release** build (`flutter run --release`) for the manual grant, then the
  grant persists for the test-runner build.
- **`small_png.png` produces no ML Kit label.** The 64×64 XOR-gradient PNG
  returns zero image labels ≥ 0.6 on device — the README's "labeling fast path"
  billing is aspirational. `no_exif.jpg` (the 800×600 gradient JPEG) reliably
  yields `Pattern` (~0.90) / `Tile` (~0.74); `ml_indexing_test.dart` asserts
  against that.
- **Flutter is invisible to `uiautomator`/adb UI dumps** unless an
  accessibility service is active (semantics tree built lazily). For
  on-device verification, tap at computed coordinates and read
  `adb logcat`; assert screen/state correctness in widget tests.
  **In practice, don't drive the UI by coordinates at all — write a `patrol`
  test instead.** Enabling a stock accessibility service
  (`settings put secure enabled_accessibility_services …accessibilitymenu/…`)
  does *not* populate the tree either (the dump stays a single bare node), so
  there is no adb route to finding a button. Coordinate taps also fail silently
  in two distinct ways worth recognising: right after `am start` the activity
  can reject input entirely — logcat shows
  `InputDispatcher: Not sending touch gesture … NO_INPUT_CHANNEL` and *every*
  tap is swallowed, so a whole coordinate sweep proves nothing (relaunch via
  `monkey -p <pkg> -c android.intent.category.LAUNCHER 1` and re-check for that
  line before trusting a negative result); and a blind sweep can *succeed* at
  something you didn't intend — one run silently hit "Continue" on the consent
  step and recorded consent, which only showed up later in the pulled DB.
  Patrol's Flutter finders (`$('text')`, `$(Switch).at(n)`,
  `find.byTooltip(...)`) make all of this a non-issue and double as the
  end-to-end verification artifact.
  **Do not reach for `adb shell settings put secure enabled_accessibility_services`
  to force the semantics tree open either.** A plain `adb shell uiautomator
  dump` alone gets `ERROR: null root node returned by UiTestAutomationBridge` —
  Flutter's `AccessibilityBridge` only activates for a real **bound**
  `AccessibilityService`, not a transient `UiAutomation` instrumentation
  connection. Enabling Samsung's TalkBack this way does bind a real service,
  but on a device where TalkBack has never been turned on before it launches
  **TalkBack's own first-run tutorial** full-screen over the app instead of
  exposing app semantics — a disruptive, persistent settings change on
  someone's real device for no payoff (restore
  `enabled_accessibility_services`/`accessibility_enabled` to their prior
  values immediately if this happens). Separately: never run a manual `adb
  shell uiautomator dump` while a `patrol test` is executing — both are clients
  of the same singleton `UiAutomation` service, and driving them concurrently
  hangs the patrol run (the `patrol` CLI process and its `adb shell` child both
  sit un-killed until you `kill` them by hand).
- **On-device manual verification: `pm grant` does not get you past onboarding, and
  the app DB is the only readable state.** `PhotoManager` reports the permission
  as *not yet requested* until the in-app request flow actually runs, so an
  `adb shell pm grant`-ed install still lands on `/onboarding` and never opens
  the database (an empty `app_flutter/` with no `.sqlite` is the tell). Tap the
  onboarding button at computed coordinates first (Flutter is invisible to
  `uiautomator`). After that, verify app state by pulling the DB —
  `adb exec-out run-as com.zmeul.sologallery cat
  /data/data/com.zmeul.sologallery/app_flutter/sologallery.sqlite > local.sqlite`
  — and querying it locally; **`sqlite3` is not on the device**, and `run-as`
  returns error text rather than failing, so a pulled `-wal`/`-shm` of ~100 bytes
  means "no such file", not a real WAL. Pick observable side effects as tap
  oracles: a DB write that only the target screen performs (Memories'
  `seen_at` stamp on player open) proves navigation happened without a
  screenshot, and re-tapping a *different* element afterwards proves the screen
  was popped back. Also: `timeout` is not installed on macOS — don't wrap
  `flutter run` in it.
- **A device-only assertion needs a positive control, or it passes vacuously.**
  `consent_test.dart` asserts the ML worker returns *no* faces when consent is
  declined — trivially true on a library with no faces in it. The first version
  scanned 5 assets, found none, and could not tell "the gate works" from "there
  was nothing to find" (a probe showed only 6 of 60 real camera-roll photos
  contain a detectable face). Pair every "derives nothing" assertion with a
  same-run positive case proving the pipeline *would* have produced something,
  and fail loudly when the control can't be established. Same shape as the
  missed-permission trap above: `PhotoManager` returns empty rather than
  throwing, so under-asserted device tests go green for the wrong reason.
- **Use the seeded fixtures, not the camera roll — and note that a *drawn* face
  is not detectable by default.** `tool/gen_test_assets.dart` generates
  `test_assets/` (see its README). The fixtures are **pushed to app-private
  storage, not bundled** — `integration_test/support/fixture_file.dart` resolves
  them and `fail()`s with the push command if absent (they used to ride along in
  `pubspec.yaml` `assets:`, but shipping `synthetic_face.jpg` inside a released
  privacy app invited the wrong question — the `rootBundle.load` claim that was
  here is stale). ML Kit did **not** detect the first synthetic face (flat
  shapes, hard edges). What made it work:
  correct proportions (eyes on the horizontal midline ~one eye-width apart),
  directional shading, and a final `gaussianBlur` so nothing has vector-sharp
  edges. `integration_test/test_fixtures_test.dart` re-asserts detectability on
  device, so an ML Kit bump that stops recognizing it fails loudly instead of
  quietly hollowing out every consent test. No `ffmpeg`/`exiftool`/PIL on this
  machine — `sips` does the HEIC conversion and the video asset must be supplied
  by hand.
- **`print`/`debugPrint` do not surface anywhere observable from a
  `patrol test`/`connectedAndroidTest` run** (not the CLI's own output, not
  `adb logcat`, even filtered on the exact tag right after the run) — unlike
  `flutter run`, where the same calls land under the `flutter` logcat tag.
  Diagnosing gesture/animation behavior on-device instead has to go through
  `expect()`/`fail()`, since test-framework failure messages *are* reliably
  surfaced by both the CLI and the HTML report: e.g. `fail('DEBUG: '
  'opacity=${opacity} count=${count}')` deliberately, read the message, then
  remove it. This is how the two gotchas above were actually root-caused.

---

## Flutter widget / layout / gesture

- **A horizontal `ListView` constrains its children's height *tightly*, so the
  strip's `SizedBox(height:)` is the child's height — not a maximum.** Adding a
  caption under an avatar therefore squashes the avatar into an oval rather than
  overflowing (no red stripe, no exception — it just looks subtly wrong). The
  height has to be computed: `PeopleStrip` sums the avatar diameter, the gap and
  `MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight` (1.45, with
  headroom — 1.4 overflowed by 0.29px on a device whose font ran fractionally
  taller), and adds the caption band **only when at least one item actually has
  a caption**, so the common all-unnamed row has no dead space under it. Assert
  the *circle* stays square at every text scale, not that the row height is
  constant — the height legitimately moves with the band. Same trap in
  `MemoriesCarousel`, which derives its height from `MemoryCard.width /
  aspectRatio`.
- **Bottom-nav taps in widget tests: pump before tapping, and use `skipOffstage`
  for backgrounded tabs.** `StatefulShellRoute.indexedStack` keeps a visited
  branch in the tree but **offstage**, so asserting on a backgrounded tab's
  widgets needs `find.byType(X, skipOffstage: false)`. Branches are built lazily
  on first visit, not eagerly, so a tap on a freshly-visited destination needs a
  bounded pump before its content exists (spinners forbid `pumpAndSettle`).
  Route transitions are instant (`NoTransitionPage`, Part 1 A1) — there is no
  slide to wait out, but the lazy build still costs a frame.
- **(Historical — `DismissiblePhoto`'s drag-dismiss animation was removed in
  Part 1 A4; the app has no `AnimatedBuilder`/`AnimationController` now. The
  trap is general to any `AnimatedBuilder` driving a gesture, should motion
  return.)** An `AnimatedBuilder`'s built tree shape must stay constant across a
  whole gesture, or it silently kills the gesture mid-flight. `DismissiblePhoto`'s
  first version special-cased `if (t == 0) return child!;` to skip wrapping
  the child in `Opacity`/`Transform` at rest, wrapping only once
  `_dismiss.value` moved off zero. The *very first* drag-update frame flips
  that branch, so `AnimatedBuilder`'s rebuild swaps the child's ancestor from
  "none" to "Opacity → Transform → Transform" — a structural change Flutter's
  reconciliation can't match by type, so it disposes and reinflates the
  `GestureDetector` beneath it, along with its in-flight gesture-arena
  membership. `onVerticalDragUpdate` fires once (before the dispose),
  `onVerticalDragEnd` never fires again — the widget just sits at whatever
  value the last update left it at, forever. A host widget test doing a real
  `startGesture`/`moveBy`/`up()` sequence (not `tester.drag`, which coalesces
  down+move+up and can hide this) is what caught it: `dismissed` stayed
  `false` and the value never moved after release. Fix: always build the
  *same* wrapper shape, with identity values (opacity 1, zero translate, unit
  scale) at rest — never branch the shape on the animated value itself.
- **`InteractiveViewer`'s scale recognizer can win the gesture arena over a
  sibling `VerticalDragGestureRecognizer` even with `panEnabled: false`, and
  then do nothing — silently swallowing the whole gesture.** It needs to be a
  candidate from the first touch to recognize an incoming pinch, so
  `panEnabled: false` only gates what it *does* with an accepted gesture, not
  arena *participation* — this is invisible on host tests that stub
  `detailImageProvider` to null bytes (no `InteractiveViewer` ever renders,
  so nothing competes) and only showed up against a *real* photo on device.
  Fix: track the drag-dismiss via raw `Listener` (`onPointerDown/Move/Up`)
  instead of a competing `GestureDetector` — `Listener` receives every raw
  pointer event regardless of which recognizer wins the arena, so it can't be
  starved this way. It self-gates on zoom state and locks onto whichever axis
  the drag reads as dominant once past `kTouchSlop`, deferring to the
  `PageView`'s own horizontal swipe by simply not acting when the movement
  reads as horizontal (see `DismissiblePhoto`).
- **A `late final AnimationController` field only gets created on first
  *access* — if a widget's `build()` conditionally never touches it (e.g.
  reduced motion skips the animated branch entirely), `dispose()` becomes
  that first access, and creating a `Ticker` there throws** ("Looking up a
  deactivated widget's ancestor is unsafe" — `SingleTickerProviderStateMixin
  .createTicker` needs a live `TickerMode` ancestor lookup, which isn't safe
  once the widget is already deactivating). The memory player's since-removed
  `KenBurnsPhoto` had exactly this: `late final _controller =
  AnimationController(...)`, with `build()`'s reduced-motion branch returning
  early without ever reading `_controller`. A host widget test pumping the
  reduced-motion case
  and letting teardown dispose the tree caught it immediately. Fix: create
  the controller *unconditionally* in `initState()` (never as a lazy field
  initializer), and gate whether it ever actually `.forward()`s — checked
  via `MediaQuery.of(context).disableAnimations` in `didChangeDependencies`,
  the usual initState-is-unsafe-for-context trap — so `dispose()` always
  finds an already-real controller to dispose of, used or not.
- **(Historical — `DismissiblePhoto` no longer animates its dismiss (Part 1
  A4); it pops the instant the threshold is crossed, and Hero flights are gone
  (A1). The sequencing lesson applies to any future dismiss/exit animation.)**
  Don't finish a drag-dismiss's own exit animation before popping the route —
  hand off to the route's own pop transition immediately. `DismissiblePhoto`'s
  first version ran its own `animateTo(1, ...)`
  (shrink+fade the photo to fully invisible, ~450ms) and only called
  `Navigator.pop()` in `.whenComplete()`. Visually this is **two**
  sequential ~450ms animations, not one: the photo fades to nothing (the
  screen goes black), then — only once that finishes — the route's own pop
  transition/Hero flight starts *on top of an already-invisible screen*,
  so the photo appears to "come back" and fly to the grid as a second,
  disconnected motion. Reported by the user as "feels laggy," which it
  technically wasn't (frame timing was fine) — it was a sequencing bug
  that read as broken/slow. Fix: on commit, call the dismiss callback
  (→ `Navigator.maybePop()`) **immediately** instead of animating first;
  the Hero flight takes over from wherever the drag left off, so there's
  exactly one motion. A host test asserting the callback fires with *no
  pump at all* is what proves this (the old version needed ~500ms of
  pumping before the flag went true).
- **A zero-size *unpositioned* child collapses a full-screen `Stack` to 0x0 —
  and it fails completely silently.** A `Stack` sizes itself to its largest
  **non**-positioned child; only if it has none does it take
  `constraints.biggest`. The memory player's stage is all `Positioned` children,
  so dropping the zero-size `PrecacheAdjacent` warm-up in unpositioned made the
  Stack 0x0, and `Clip.hardEdge` (the Stack default) then clipped the entire
  story away — a **black screen** with no exception, no overflow stripe, and no
  log line. The photo detail screen took the same widget without breaking,
  because its chrome `Align`s are unpositioned children that expand, which is
  what makes this look "impossible to be layout". Wrap any render-nothing helper
  in a `Positioned`. In a widget test the tell is that the tree is fully built
  but every `find.*` returns nothing while `skipOffstage: false` finds one:
  sliver/viewport elements report children with zero extent as offstage. Assert
  the stage's size, not just its contents.
- **`Center` (and bare `Align`) takes the *largest* size its constraints allow,
  so wrapping a fixed-size child in one inside a `bottomNavigationBar` makes the
  bar claim the whole screen.** Centring a compact nav capsule with
  `Center(child: Container(width: 240, height: 60))` sized the bar to the full
  viewport: the capsule floated in the middle of the screen, and — because
  `extendBody` reports the bar's height to the body as `padding.bottom` — every
  scroller got a screen-sized bottom inset, so scrolling to the end landed in
  pure padding with *nothing rendered*. The on-device test caught it as "reached
  the end with no content on screen", which reads like a flaky test rather than
  a layout bug; it is worth checking the bar's own height before believing the
  scroller is at fault. Use `Align(heightFactor: 1)` (or `widthFactor` on the
  other axis) to size to the child while still aligning it.
- **A lazy `ListView.builder`'s `maxScrollExtent` is an *estimate*, so one
  `jumpTo(maxScrollExtent)` lands mid-list, not at the end.** The extent is
  extrapolated from the children built so far and grows as more build, so the
  jump moves you somewhere the estimate immediately invalidates, and the guess
  *overshoots* — jumping straight to it can land past the last row in blank
  space where nothing renders. A device test asserting "the last row clears the
  floating nav capsule" failed this way against *correct* padding: it measured a
  row 120px below the viewport in a list still hundreds of pixels from its real
  end, and the overshoot happened to equal the padding, which reads exactly like
  the padding was never applied. Step toward the end a screenful at a time
  (`jumpTo(pixels + 1000)` in a bounded loop until `pixels` stops moving) so each
  step builds the next children and corrects the estimate, then assert. `find.byType(X)` also picks
  up children built in the ~250px cache extent *below* the viewport, so measure
  against the viewport, never against "the last widget found".
- **`Scaffold(extendBody: true)` reports the bottom widget's height to the body
  as `MediaQuery.padding.bottom`, and it survives nested Scaffolds.** A floating
  bottom nav therefore needs every scroller in the shell to add
  `MediaQuery.paddingOf(context).bottom` to its own bottom padding, or its last
  row hides behind the bar. This works through each branch's *own* `Scaffold`
  because a Scaffold only strips `padding.bottom` from its body when it has a
  `bottomNavigationBar`/`persistentFooterButtons` of its own (`_BodyBuilder`
  restores it as `max(padding.bottom, bottomWidgetsHeight)`), which the branch
  screens don't. The same expression is also right for a scroller shared with
  pushed routes (`AssetGrid`): there the inset is just the system one.
- **A `BoxScrollView` (`ListView`/`GridView`) with a null `padding` silently
  absorbs `MediaQuery.padding` on its main axis** (`scroll_view.dart:901`:
  "Automatically pad sliver with padding from MediaQuery"). Inside the shell
  that bottom inset is the floating nav capsule's height, so a nested,
  `shrinkWrap`ped grid appends a capsule-sized band *under itself* — the Library
  preview grids each grew a ~32 logical px band, which read as a huge gap
  between one month's photos and the next month's header. **Always pass an
  explicit `padding` (`EdgeInsets.zero` if none is wanted) on every scroll
  view.** Note the outer scroller does not protect the inner one: a
  `BoxScrollView` only wraps its children in `MediaQuery.removePadding` in the
  *null*-padding branch, so a parent with explicit padding leaves the full inset
  visible to descendants. Invisible on host tests (the test view has no
  padding) — reproduce with `tester.view.padding = FakeViewPadding(bottom: N)`.
  **And measure from the content, not from the scroll view's own box:** a
  `getRect` on the `GridView` includes the padding it absorbed, so the first
  version of the regression test passed against the *unfixed* code. Measure to
  the last child widget instead.
- **`tester.view.padding = FakeViewPadding(bottom: N)` injects a bottom inset
  into an existing widget-test harness with no changes to it** — `MediaQuery
  .fromView` divides by `devicePixelRatio` (3.0 by default, so N/3 logical), and
  every screen's existing `pump` helper picks it up. Pair with
  `addTearDown(tester.view.reset)`. This is how each scroller's capsule inset is
  pinned per screen without duplicating four provider harnesses.
- **A `SnackBar` with an action never times out, and on the root messenger that
  means it follows the user across every screen forever.** `SnackBar.persist`
  defaults to `action != null` (`snack_bar.dart:303`), and
  `ScaffoldMessengerState.build`'s timeout callback does `if (snackBar.persist)
  return;` — so the `duration` is simply ignored. The People merge's "Merged ·
  Undo" banner therefore stayed up permanently, and since `ScaffoldMessenger`
  sits *above* the Navigator it survived every navigation, which is how it was
  reported ("doesn't go away, no matter the screen"). Always pass
  `persist: false` with an explicit `duration` when a snackbar carries an
  action, **and** hide screen-scoped snackbars in `dispose()` — capture the
  messenger in `didChangeDependencies` (an ancestor lookup in `dispose()` is
  unsafe). An Undo for an action taken on one screen has no meaning once that
  screen is gone.
- **Drive on-device scrolling with `fling`, never `position.jumpTo` — and never
  measure "the lowest widget found".** Both halves of this bit `nav_shell_test`'s
  "last row clears the nav capsule" the moment `scrollCacheExtent` grew. (1)
  `jumpTo` puts the position where you say and leaves it there: two runs ended
  with `pixels` **greater than** `maxScrollExtent` (37,337 of 36,688), an
  overscroll a real fling resolves ballistically and a jump simply never does.
  It also outruns the work a scroll exists to trigger — Library pages in through
  a growing-window watch and decodes thumbnails async — so feeding it screenfuls
  every 100ms measures a list still loading, landing at a different place every
  run (826, then 37,000, then 107,000 of the same library). Use
  `tester.fling(...)` plus a bounded settle pause per iteration. (2) End the walk
  only when the position has stopped moving **and** `maxScrollExtent` has stopped
  growing; either alone is a false finish, since paging in more rows pushes the
  end away just as the position lands on it. (3) Fling the **vertical** scroller
  — `find.byType(Scrollable).first` is Library's horizontal filter bar, and a
  vertical fling on it moves nothing, so the walk "finishes" at pixel 0. Get a
  finder with `find.byWidget(verticalScrollableState.widget)`. (4) A scroller
  pre-builds children past the viewport, so `find.byType(X)` returns rows that
  sit below the nav capsule by construction — filter to rects inside the
  viewport before measuring, and assert at least one qualified or the test proves
  nothing.
- **Don't fling a growing-window-watch scroller via an instance-based finder —
  fling from the captured `ScrollableState`'s render-box centre instead.**
  `nav_shell_test`'s "scrolled to the end" case captured the timeline's
  `ScrollableState` then flung with `find.byWidget(scrollable.widget)`. The
  Library timeline is a `WatchedAssetsNotifier` growing-window watch, so a
  watch emission between capture and the first fling rebuilds the `ListView`
  and swaps in a *new* `Scrollable` widget instance; the captured-instance
  finder then matches zero and `tester.fling` throws ("Found 0 widgets").
  This is a race independent of the padding under test — it failed 3× in a row
  after the no-motion A2 pass, which only *removed* `EntranceFade`'s delayed
  `setState`s (fewer rebuilds, not more) but shifted the race window. A
  type/axis predicate is too broad: the `shrinkWrap` section preview grids are
  vertical `NeverScrollable` `Scrollable`s too (4 matches on Library). Fix:
  `final box = state.context.findRenderObject() as RenderBox;` then
  `tester.flingFrom(box.localToGlobal(box.size.center(Offset.zero)), offset,
  duration)`. The `ScrollableState` and its `position` persist across the
  rebuild (same element, retyped widget), so the centre and the pixel
  measurement stay valid and the gesture lands on the right viewport with no
  finder at all. Two consecutive 5/5 runs after the fix.
- **`cacheExtent` is deprecated — use `scrollCacheExtent`**
  (`ScrollCacheExtent.pixels(n)` / `.viewport(n)`); it lives in
  `package:flutter/rendering.dart`, not `material.dart`. Prefer
  `.viewport(1)` over a pixel count so a tablet gets a screenful too.
  **Only raise it alongside a bound on thumbnail requests** — pre-building more
  cells requests more thumbnails, so on its own a larger extent deepens exactly
  the queue of scrolled-past decodes it is meant to hide (see `ThumbnailGate`).
- **A `FutureProvider.autoDispose` does not cancel work already handed to a
  platform channel.** Disposing frees the *bytes*, but an in-flight
  `thumbnailDataWithSize` runs to completion natively and the result is thrown
  away, so a fling piles up decodes for cells nobody is looking at.
  `ThumbnailGate` (`lib/services/thumbnail_gate.dart`) caps concurrency at 6 and
  — the part that actually matters — re-checks a `cancelled` callback *after*
  waiting for a slot, so queued requests for recycled cells are never started.
  The queue is LIFO because the newest request is the one nearest the viewport.
  `previewImage` is deliberately **not** gated: the detail viewer must not queue
  behind a grid fling's backlog.
- **`FolderList` is a sliver, not a box** — mount it directly in a
  `CustomScrollView`, never in a `SliverToBoxAdapter`. As a `shrinkWrap`ped
  `GridView` it laid out against unbounded extent and so built *every* tile up
  front to find its own height, and each tile blurs its cover at sigma 18 — on a
  30-folder device that was thirty decodes and thirty Gaussian passes on Albums'
  first frame. Note a zero-extent sliver is reported **offstage**, so an empty
  `FolderList` needs `find.byType(FolderList, skipOffstage: false)`.
- **`tester.tap` produces no frame, so an animation it starts records t=0 on the
  *next* pump.** `tap(...)` then a single `pump(400ms)` lands exactly on that
  zero-elapsed frame — `PageController.nextPage` looks like it did nothing and
  the tap reads as ignored. Always `tap` → bare `pump()` → `pump(duration)`.
  Same shape for a pushed route whose screen opens on an `AsyncValue` loading
  branch: the future only resolves after the frame that subscribes to it, so
  the pushed screen needs one more pump before its content exists.
- **A `Listener` defaults to `HitTestBehavior.deferToChild`, so it sees no
  events where its child paints nothing — make a full-bleed gesture surface
  `behavior: HitTestBehavior.opaque`.** `DismissiblePhoto`'s raw-pointer
  drag/tap `Listener` relied on the stage underneath filling the screen to be
  hit-testable everywhere. While the 1080 base-thumbnail underlay sat beneath
  the real page (a `StackFit.expand` stack) that held — the underlay covered
  the whole stage. Retiring the underlay (Part 1 A4) left the hit area as
  whatever `PhotoPage` paints: a real image's `Image.memory(
  width/height: double.infinity)` still fills it, but the broken-image
  fallback `_Unavailable` is a 44 px centred icon, so taps off it fell through
  to nothing and the gesture silently never saw them. It surfaced as a host
  test (`dismissible_photo_test`'s "a second double tap returns to fit", whose
  second pair taps off-centre) where the second `_handleDoubleTap` never fired
  — the value stayed at the first zoom. `HitTestBehavior.opaque` makes the
  `Listener` hit-testable across its whole bounds regardless of what the child
  paints; in production (image fills the stage) it is a no-op, and it makes
  tap-to-toggle chrome work on a missing image too. The same trap hides any
  gesture on a widget whose content is async/empty/sparse.

---

## Riverpod

- **Riverpod 3 `ProviderContainer` tests — two traps.** (1) `await
  container.read(someStreamProvider.future)` on an **autoDispose
  `StreamProvider`** fails the test at teardown: disposing the element completes
  the pending future with an error (`ElementWithFuture.dispose`). Don't await a
  stream's `.future`; instead `container.listen(...)` to keep it alive and let
  it emit, then read the derived sync provider. (2) After mutating a
  `Notifier`/state provider, a downstream provider's recompute is **batched on
  Riverpod's scheduler (a real Timer)** — a microtask (`await Future(() {})` /
  `Duration.zero`) isn't enough. Await a real turn
  (`await Future.delayed(const Duration(milliseconds: 10))`) before reading the
  recomputed value.
- **Don't use `ProviderScope.overrideWithValue` inside `build` to feed a
  `FutureProvider.family`.** We tried overriding `detailImageMaxEdgeProvider`
  from `PhotoDetailScreen.build` so phone screens could request a smaller edge
  than the 2048 px default. The override *looks* scoped correctly, but the
  `FutureProvider.autoDispose.family` for the visible asset was created on its
  first `ref.watch` with the **root-container default value**; it then rebuilt a
  moment later with the overridden value, causing two platform round-trips and
  a 2048 px fetch alongside the desired smaller one. The simpler fix is to
  keep the cap as a constant provider (`kDetailImageMaxEdge = 1440`) and not
  override it per screen. If a value truly must vary by screen, set it before
  the family provider is first watched (e.g. a `StateProvider` in the route
  argument parsing) rather than inside the family's own build path.
- **An `AsyncNotifier` method that writes `state` after an `await` must guard
  `ref.mounted` first.** `PagedAssetsNotifier.loadMore` is fired from
  `AssetGrid`'s scroll callback (fire-and-forget) against an **autoDispose**
  provider, so the screen can be popped while the page fetch is in flight; the
  trailing `state = AsyncData(...)` then throws `UnmountedRefException` into the
  void. Fix is `if (!ref.mounted) return;` after the `await`.
  `WatchedAssetsNotifier` avoids it a different way — it cancels its stream sub
  in `ref.onDispose`, so its completer never fires post-dispose.

---

## Tooling / env

- **JVM-target mismatch under JDK 21.** Android Studio JBR (JDK 21)
  compiles plugin Kotlin to JVM 21 while plugins pin their **Java** lower →
  "Inconsistent JVM-target compatibility". Plugins disagree on the level
  (`photo_manager` 17, `google_mlkit_commons` 11, `google_mlkit_image_labeling`
  1.8), and their Java `compileOptions` are **finalized by AGP** — you can't
  raise them from the root (`afterEvaluate` throws "sourceCompatibility has
  been finalized"; a subproject `afterEvaluate` from the root can also throw "already
  evaluated"). So the `subprojects` block in `android/build.gradle.kts` **matches
  each `com.android.library` module's Kotlin `jvmTarget` to its own (read-lazily)
  Java `targetCompatibility`** (1.8/11/17), rather than forcing a single value.
  `patrol` self-pins both sides (1.8) and stays in the `selfConsistentModules`
  skip set. Do *not* override raw `JavaCompile` tasks to 17 — that strips the
  `android.jar` bootclasspath ("package android.app does not exist"). Re-check a
  plain `flutter build apk` (not just `patrol test`) when adding Android plugins.
- **`developer.log` alone reaches nothing but DevTools — the logger needs a
  `debugPrint` mirror.** `dart:developer.log` feeds the VM-service *Logging*
  stream only: it is **not** printed by `flutter run` and never reaches the
  Android log. Measured on a Pixel 9 Pro XL, a full fresh-install onboarding
  plus an 892-asset indexing pass produced 14,982 logcat lines and **zero**
  from `SoloGallery.*`, despite the pass logging unconditionally. `dart:io`
  `stdout.writeln` is not a fix either — Android discards that descriptor
  (verified: still nothing in logcat). Only `print`/`debugPrint` is routed by
  the engine to logcat under the `flutter` tag, so `configureLogging()` keeps
  `developer.log` for DevTools **and** mirrors every record through
  `debugPrint` outside release builds. That mirror is the sole sanctioned use
  of `debugPrint` in the tree; it is what makes the documented
  `adb logcat -s flutter:V SoloGallery:V` workflow actually produce output.
  Delete it and on-device debugging goes silent again.
- **Keep the `Logger.root.onRecord` subscription alive.** `configureLogging()`
  must hold the `StreamSubscription<LogRecord>` in a static variable. If the
  subscription is created inside the function without a reference, the GC drops
  it as soon as `configureLogging()` returns and debug logs stop appearing even
  in `flutter run`. The subscription itself has no strong reference from
  `Logger.root`.
- **`build_runner` dropped `--delete-conflicting-outputs`** — removed and
  now the default; passing it only prints a warning. `tool/check.sh`
  runs plain `dart run build_runner build`.
- **`package_info_plus` has no host-platform channel** — `PackageInfo.fromPlatform()`
  throws in `flutter test`, so the `appVersionProvider` FutureProvider resolves to
  `AsyncError` (the About row shows `—`, no crash). Override it in widget tests
  (`appVersionProvider.overrideWith((ref) async => '1.0.0 (1)')`). Reads only the
  Android `PackageManager` / iOS bundle — adds no network perms (release manifest
  re-verified clean).
- **Golden tests cannot see icon glyphs.** Alchemist's CI variant obscures
  fonts, so every `Icon` renders as a solid box regardless of codepoint — the
  Phase-5 icon-family swap left every golden byte-identical (md5-verified),
  which is the *expected* outcome, not a missed regen. Goldens verify layout/
  color only; verify glyph shapes on device (or by eye in the running app).
- **`flutter install --debug` can install a stale patrol test bundle instead of
  the app.** `patrol test` and `flutter build apk --debug -t lib/main.dart`
  write to the **same** output path
  (`build/app/outputs/flutter-apk/app-debug.apk`), keyed only by mtime, not
  entrypoint. Run a `patrol test`, then later `flutter install --debug -d <id>`
  without an intervening plain build, and `flutter install` sees an
  up-to-date-looking artifact and skips rebuilding — installing the **patrol
  harness** (entrypoint `patrol_test/test_bundle.dart`) under the app's own
  launcher icon. It launches, then immediately throws `ClientException with
  SocketException: Connection refused … uri=http://localhost:8081/initialize`
  (the harness trying to reach a patrol server that isn't there) instead of
  showing the app. Fix: `flutter build apk --debug -t lib/main.dart` explicitly
  before `adb install -r`, any time a `patrol test` ran more recently than the
  last plain install.

---

## Release / Play signing

- **Lost upload keystore is fatal without Play App Signing, recoverable
  with it.** A lost upload key normally means the app's identity on Play
  is unrecoverable — Google cannot retrieve it and you cannot push
  updates under the same `applicationId`. Enable Play App Signing in
  Play Console (Setup → App signing) before any production upload: Google
  holds the app-signing key as the source of truth, and the upload key
  becomes replaceable (Setup → App signing → Request upload key reset).
  The first upload must still be signed with a key whose SHA-256 you can
  prove, so the upload keystore still needs an offline backup — but a
  later loss is no longer fatal.
- **`keytool` defaults to 90-day validity, which Play rejects.** A Play
  upload keystore must be valid for at least ~25 years. Always pass
  `-validity 10950` (days) to `keytool -genkey`. Also: the JBR's
  `keytool` silently ignores `-storetype JKS` (its engine-load stack
  shows `PKCS12KeyStore` regardless); use `-storetype pkcs12` to match
  what the JBR actually creates. AGP's signing config accepts both
  PKCS12 and JKS.
- **The JBR's `keytool` needs `DYLD_LIBRARY_PATH` set to run from a
  shell on macOS.** A bare `/Applications/Android Studio.app/Contents/
  jbr/Contents/Home/bin/keytool` fails with "Unable to locate a Java
  Runtime" because macOS's hardened-runtime policy blocks the
  embedded `@rpath` lookup of `libjli.dylib`. The Flutter CLI sets
  `JAVA_HOME` for you, so `flutter build appbundle` works; a bare
  `keytool` does not. Set `JAVA_HOME=/Applications/Android Studio.app/
  Contents/jbr/Contents/Home` and `DYLD_LIBRARY_PATH="$JAVA_HOME/lib"`
  before invoking `keytool` directly. The `DYLD_LIBRARY_PATH` only
  points dyld at the JBR's own `lib/`, not system libraries, so it's
  safe.