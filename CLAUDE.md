# SoloGallery — Flutter Photo App

Privacy-first, 100% local photo app for iOS and Android. No cloud, no
analytics, no network calls after install.

---

## Core features

- Cross-platform (Android + iOS); robust consent + native permission
  handling for photo library access
- **App bar:** search
- **Main view:** gallery grouped by month — first 6 photos per month,
  newest first, plus a per-month "view all" button
- **Detail view (on tap):** full-screen viewer with horizontal swipe;
  actions: favorite, delete, share, add to existing album; dedicated
  button to reveal EXIF metadata
- **Bottom nav:** Home Gallery · Favourites · Albums · Settings

---

## Stack

- **Targets:** Android 15+ (API 35) and iOS 26+ only. Do not add
  compatibility code, polyfills, or branches for older OS versions.
- **Framework:** Flutter (latest stable) + Dart
- **Database:** Drift (SQLite ORM) — never Isar (abandoned Jan 2025)
- **State:** flutter_riverpod (conventions below)
- **Photo library:** photo_manager (API only, no UI integration)
- **ML:** all on-device — google_mlkit_* + TFLite via tflite_flutter
- **Design:** warm off-white/near-black palette, pill filters, dot nav
  indicator (see Design system)
- **Architecture spec:** `docs/spec.md#architecture` — read it before
  structural work

---

## Absolute rules

- **Zero network calls** — no HTTP client, Firebase, analytics, or cloud SDK
- **Never duplicate photos** — asset ID references only, never file copies
- **Drift for all persistence** — never Isar
- **Non-destructive edits only** — JSON instructions in `edit_instruction`
  table; never modify originals
- **All ML on a background isolate** — never on the UI isolate
- **Never decode originals for grid cells** — request thumbnails via
  photo_manager `ThumbnailSize`
- **Never trust Dart-side image decode dimensions** — use photo_manager
  metadata (see Gotchas)
- **Speed and UX come first** — 60fps scroll, no jank, instant taps.
  Never block the UI isolate; do heavy work off-thread.
- **Move work to background when the app is idle** — pause/defer indexing,
  ML, and thumbnail warming on lifecycle `inactive`/`paused`; resume on
  `resumed`. No work runs while the app isn't in use beyond OS-permitted
  background tasks.
- **No dead code, no hallucinated APIs** — every symbol must exist and be
  used. Work is verified; unused code, stubs, or invented package APIs
  fail review.

---

## Workflow

- **Plan mode first.** Ask clarifying questions until the task is well
  understood, then present a plan and save it to `docs/plans/<task>.md`.
  Work begins only after the plan is saved and approved.
- **The plan doc is a living handoff log.** Update it as you go, not just
  at the end: check off completed steps, record decisions and why, and
  keep a "Next step" line current. A fresh session or any other agent must
  be able to read CLAUDE.md + the plan doc and resume immediately — zero
  re-discovery, zero re-litigating decisions.
- **UI work:** invoke the `/frontend-design:frontend-design` skill before
  building or reshaping any screen or widget.
- **Architecture:** UI / domain / data separation per
  `docs/spec.md#architecture`; pure-Dart domain logic (no Flutter
  imports); const constructors where possible; Riverpod conventions below.
- **Testing is mandatory** — all applicable tiers in Test strategy, then
  manual end-to-end verification on the connected real device. A task
  missing either is not done.
- **Debugging:** no screenshots — drive via adb and read logs
  (`adb logcat -s flutter:V SoloGallery:V`).
- **Token-optimized work:** delegate read-heavy work (Sub-agents),
  read only the files you need, keep answers very short (no preamble,
  no recap, no restating the plan), let diffs and code speak.
- **Verified work — no mistakes:** every change is checked. No dead
  code, no unused symbols, no invented package APIs. If unsure a symbol
  exists, confirm it before using it.
- **Maintain this file:** surprising failures go to Known gotchas
  (short form) and, if long, `docs/postmortems/`. After each completed
  task, prune any task-scoped notes that leaked in — only durable rules,
  conventions, gotchas, and environment facts stay here; task state lives
  in `docs/plans/`.

---

## Sub-agents

**Delegate whenever possible** — keep the main session small and
token-cheap. Push work to sub-agents unless it must stay in the main
session, and have them return only summaries, not raw output.

**Delegate (read-heavy, summary-out):** codebase exploration before
planning (built-in Explore agent), digesting `adb logcat` /
`dumpsys dropbox`, running `tool/check.sh` and reporting failures,
reviewing a diff against CLAUDE.md, and well-defined self-contained
edits.

**Keep in the main session only:** architecture/schema decisions and
anything whose intermediate reasoning must stay visible in the plan.

**Every invocation:**
- Self-contained prompt (file paths, error text, decisions included) and
  instruct the sub-agent to read CLAUDE.md first so Absolute rules are
  never bypassed
- Read-only tasks get read-only tools (Read, Grep, Glob) — no Bash/Write
  for reviewers or explorers
- Custom agents live in `.claude/agents/`; prefer built-ins until a
  repeated need justifies one
- Route to cheap models via frontmatter `model` (Haiku for log digestion,
  Sonnet for review)

---

## Definition of Done (every task)

1. `tool/check.sh` passes (analyze, build_runner, unit + widget tests)
2. Integration tests for the touched area pass on the connected device
3. Feature manually verified end-to-end on the device
4. Schema changed → schema dump committed + migration test added
5. Android dependency added → release merged manifest re-verified (Gotchas)
6. Known gotchas updated if anything surprising happened
7. Plan doc in `docs/plans/` marked complete, with final state and
   follow-ups recorded — the next session starts from it, not from scratch
8. CLAUDE.md pruned of any task-scoped notes added during the work

---

## Verification commands

Prefer `tool/check.sh` (create if missing), which runs the first three:

```bash
flutter analyze                               # zero warnings allowed
dart run build_runner build                   # (--delete-conflicting-outputs is now default; see Gotchas)
flutter test                                  # all unit + widget tests
flutter test integration_test -d <device-id>  # on-device integration
adb logcat -s flutter:V SoloGallery:V         # runtime debugging
adb shell dumpsys dropbox --print             # native crash inspection
./gradlew :app:processReleaseManifest \
  && grep -R "INTERNET\|READ_PHONE_STATE\|c2dm" \
     build/app/intermediates/merged_manifests/release/  # must return nothing
```

---

## Test strategy

Every layer has a required tier. "Write tests" means all applicable
tiers, not one unit test.

### 1. Unit tests (`flutter_test`, host)
- Pure-Dart domain logic (clustering, edit instructions, date grouping)
- **DAOs against in-memory Drift** — `NativeDatabase.memory()`, real
  schema, real queries; every DAO method, including cascades (enable
  foreign keys in the test connection too)
- **Providers via `ProviderContainer`** with overrides; test state
  transitions and disposal
- **Migration tests** — drift `SchemaVerifier` with committed schema
  dumps, every upgrade path (v1→v2→…→N)

### 2. Widget tests (host)
- Screens with mocked providers: loading / data / error / empty states
- **Golden tests** (`alchemist`) for design-system widgets — filter
  pills, nav bar + dot indicator, EXIF chips, detail action bar — light
  and dark. This makes the Design system enforceable.

### 3. Integration tests (`integration_test` + `patrol`, real device)
- App boot, onboarding, tab navigation, grid scroll, detail open,
  favorite/unfavorite round-trip
- **Permission matrix** (patrol drives native dialogs; plain
  integration_test cannot): full access · **limited/partial** (iOS
  limited library, Android 14 picker subset — photo_manager returns a
  different asset set; UI must handle it) · denied · denied → granted
  via Settings · revoked mid-session (backgrounded, revoked, resumed)
- **Real-isolate ML smoke test:** spawn the actual worker isolate,
  process seeded assets end-to-end, assert rows in `photo_label` /
  `face_embedding`. Must include the HEIC asset.

### 4. Fake-pairing rule
Any fake/mock of infrastructure (e.g. fake `MlWorkerController`) must be
paired with ≥1 on-device integration test of the real implementation.
Two production bugs (isolate binding hang, HEIC OOM) were invisible to
`flutter test` because fakes bypassed the real path.

### Deterministic test assets
Never depend on whatever is on the device — seed first:

```bash
adb push test_assets/ /sdcard/Pictures/SoloGalleryTest/
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Pictures/SoloGalleryTest/
```

Required set (`test_assets/`): one ~48MP iPhone `.HEIC` (OOM regression
asset) · one JPEG with GPS EXIF · one JPEG with no EXIF · one video
(thumbnail + duration badge) · one small PNG (labeling fast path).

---

## Riverpod conventions

- Manual providers — no riverpod_generator codegen
- `autoDispose` by default for screen-scoped providers; app-wide services
  (database, photo library, indexing) kept alive at the root
- UI consumes `AsyncValue` via `when(...)` — explicit loading / error /
  empty states on every screen; never `.value!`
- No logic in widgets that belongs in providers or services

## Logging

- `package:logging`, single hierarchical root logger `SoloGallery`
  (children: `SoloGallery.ml`, `SoloGallery.db`, …)
- Never raw `print`/`debugPrint` in committed code
- Device filter: `adb logcat -s flutter:V SoloGallery:V`

---

## Project structure

```text
lib/
  main.dart
  app.dart                      # ThemeData, router, root providers
  core/
    theme/                      # lightTheme, darkTheme
    router/                     # GoRouter config
    database/                   # Drift DB, tables, DAOs
  features/
    library/ saved/ search/ albums/ detail/ people/ edit/ settings/
  services/
    photo_library_service.dart  # photo_manager wrapper
    paged_assets_notifier.dart  # shared pagination base (Library, Saved)
    ml_service.dart             # ML Kit + TFLite
    indexing_service.dart       # background indexing orchestration
  widgets/
    app_shell.dart              # bottom nav shell (StatefulShellRoute)
test/                           # unit + widget + golden (mirrors lib/)
integration_test/               # on-device tests (patrol)
test_assets/                    # seeded device assets (Test strategy)
tool/check.sh                   # analyze + build_runner + tests
docs/
  spec.md                       # full spec incl. architecture
  plans/                        # one living plan/handoff doc per task
  postmortems/                  # full incident writeups
```

---

## Design system

### Colors

| Token | Light | Dark |
|---|---|---|
| background | `#F5F5F3` | `#111110` |
| surface | `#FFFFFF` | `#1C1C1A` |
| surface2 | `#EBEBEB` | `#282826` |
| text primary | `#111110` | `#F0F0EE` |
| text secondary | `#6E6E6A` | `#8A8A84` |
| text muted | `#AEAEA9` | `#4A4A46` |
| pill active bg | `#1A1A18` | `#F0F0EE` |
| border | `rgba(0,0,0,0.07)` | `rgba(255,255,255,0.07)` |

### Typography

| Element | Size | Weight |
|---|---|---|
| Page title | 22sp | 700 |
| Section label | 11sp | 600 (uppercase, 0.08em spacing) |
| Filter pill | 12sp | 500 |
| Body / list | 14sp | 400 |
| EXIF value | 12sp | 600 |
| EXIF key | 9sp | 400 (uppercase) |
| Caption | 11sp | 400 |

### Screens

| Screen | Route |
|---|---|
| Library | `/` |
| Saved | `/saved` |
| Albums | `/albums` |
| Detail | `/photo/:id` |
| Album detail | `/album/:id` |
| Settings | `/settings` |

---

## Model usage (Claude Pro, 5-hour rolling window)

- **Opus 4.8:** architecture/schema decisions, platform channel code
  (PhotoKit, MediaStore), ML pipeline integration, complex multi-file
  refactoring
- **Sonnet 5:** UI widgets and screens, unit tests, small bugfixes,
  anything repetitive or well-defined
- **Haiku 4.5:** quick questions, lookups, clarifications

**Session hygiene:**
- New conversation per feature — long sessions re-process history and
  burn tokens exponentially; `/compact` mid-session if it gets long
- One focused task per conversation; CLAUDE.md carries the project
  context, don't re-explain it
- Delegate read-heavy exploration per the Sub-agents section so the main
  Opus session only receives summaries

---

## Prompt template (session start)

```text
You are building SoloGallery, a Flutter photo app. Read CLAUDE.md for
full context — especially Absolute rules, Test strategy, and Definition
of Done. Current task: [DESCRIBE TASK HERE].
Save/update the plan in docs/plans/ before writing code.
```

---

## Known gotchas

Short form; full postmortems in `docs/postmortems/`.

- **drift and drift_dev patch versions must match exactly.** With
  `drift 2.34.2` + `drift_dev 2.34.0`, `schema dump`/`schema generate`
  fail to compile (drift_dev's `SchemaVerifier` resolves
  `GeneratedDatabase` from drift's `drift3_preview`, which lacks
  `allSchemaEntities`). Pin `drift` to drift_dev's patch (currently
  `2.34.0`); re-check when bumping either.
- **JVM-target mismatch under JDK 21.** Android Studio JBR (JDK 21)
  compiles plugin Kotlin (e.g. `photo_manager`) to JVM 21 while their
  Java stays 17 → "Inconsistent JVM-target compatibility". Fix: the
  `subprojects` block in `android/build.gradle.kts` pins such modules'
  Kotlin `jvmTarget` to 17. Keep it when adding Android plugins.
  **But some plugins (e.g. `patrol`) already pin *both* their Java and
  Kotlin to 1.8** (self-consistent). Forcing only their Kotlin to 17
  re-breaks them (Kotlin 17 vs Java 1.8) — and it surfaces in a plain
  `flutter build apk`/`flutter run` (patrol is a dev-dependency plugin, so
  it compiles into debug builds) even when `patrol test` happens to build.
  Fix: the Kotlin rule **skips a `selfConsistentModules` set (currently
  `patrol`)**, leaving their config intact. Do *not* instead override raw
  `JavaCompile` tasks to 17 — that strips the `android.jar` bootclasspath
  ("package android.app does not exist"); and `afterEvaluate` on a
  subproject from the root block throws "already evaluated".
- **`developer.log` does not reach `adb logcat`.** The `SoloGallery`
  logger routes through `dart:developer.log`, which goes to the Dart VM
  service, **not** the Android log — so `adb logcat -s flutter:V
  SoloGallery:V` shows nothing from our logger (only `print`/`debugPrint`
  and engine lines appear under the `flutter` tag). For app-side logs use
  `flutter run`/`flutter logs`/DevTools, or the on-device test output;
  use `adb logcat` for native/crash inspection.
- **Android has no "not determined" photo-permission state.**
  `PhotoManager.getPermissionState` returns `denied` before the user is
  ever asked (unlike iOS's `notDetermined`). Onboarding must therefore
  offer "Allow" (which triggers the native request) on first run and only
  switch to "Open Settings" *after* a prompt was actually refused — see
  `OnboardingScreen`'s `_attempted` flag.
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
- **`video_player` (media3) injects network permissions** — `video_player_android`
  declares `INTERNET` **and** `ACCESS_NETWORK_STATE` (for streaming). Both merge
  into the **release** manifest and break the network-free check (Absolute rules /
  DoD #5). `android/app/src/main/AndroidManifest.xml` strips both with
  `tools:node="remove"` (needs `xmlns:tools` on `<manifest>`); media3 degrades to
  no network monitoring for local files. `WAKE_LOCK` is left (screen-on during
  playback, not a privacy concern). Surfacing videos also needs `READ_MEDIA_VIDEO`.
  Re-verify the merged manifest after any video-dep bump. Playback uses local
  `entity.file` only — never a URL.
- **`build_runner` dropped `--delete-conflicting-outputs`** — removed and
  now the default; passing it only prints a warning. `tool/check.sh`
  runs plain `dart run build_runner build`.
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
- **Flutter is invisible to `uiautomator`/adb UI dumps** unless an
  accessibility service is active (semantics tree built lazily). For
  on-device verification, tap at computed coordinates and read
  `adb logcat`; assert screen/state correctness in widget tests.
- **Debug builds inject the `INTERNET` permission** (Dart VM service /
  hot reload) — expected. Verify the **release** merged manifest instead
  (Definition of Done #5): no `INTERNET`/`READ_PHONE_STATE`/`c2dm`.
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

---

## Environment notes

- **App id / namespace:** still the `flutter create` default
  `com.example.sologallery` (both platforms). Change before any release.
- **adb not on PATH:** `~/Library/Android/sdk/platform-tools/adb`.
  Direct `./gradlew` calls need
  `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`
  (the `flutter` tool sets this itself).
- **Primary device:** Pixel 9 Pro XL (`46121FDAS008AA`), Android 17 (API 37).
