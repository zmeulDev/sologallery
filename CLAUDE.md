# SoloGallery — Flutter Photo App

Privacy-first, 100% local photo app for iOS and Android. No cloud, no
analytics, no network calls after install.

---

## Core features

- Cross-platform (Android + iOS); robust consent + native permission
  handling for photo library access
- **App bar:** settings (on Library)
- **Main view:** gallery grouped by month — first 6 photos per month,
  newest first; the section header row itself opens the full month (label,
  count and chevron are one tap target, not a separate "view all" button)
- **Detail view (on tap):** full-screen viewer. Chrome splits by direction of
  travel: the top bar carries back · add-to-album · share as scrim discs (the
  outbound actions), the action bar below carries favorite · info · delete (the
  ones acting on the photo itself). Gestures: swipe left/right for
  previous/next, swipe down to close, swipe up for details, pinch and
  double-tap (2× at the tap point) to zoom, single tap to toggle chrome.
  Neighbours ±3 are pre-warmed
- **Bottom nav:** Home Gallery · Search · Saved · Albums — a floating
  inverted-ink capsule over the content, active destination marked by a
  sliding circular knob; while background analysis runs, a small dial rides at
  the capsule's right with the number of photos left, and goes when it finishes

---

## Stack

- **Targets:** Android 15+ (API 35) and iOS 26+ only. Do not add
  compatibility code, polyfills, or branches for older OS versions.
- **Framework:** Flutter (latest stable) + Dart
- **Database:** Drift (SQLite ORM) — never Isar (abandoned Jan 2025)
- **State:** flutter_riverpod (conventions below)
- **Photo library:** photo_manager (API only, no UI integration)
- **ML:** all on-device — google_mlkit_* + TFLite via tflite_flutter
- **Design:** warm off-white/near-black palette, pill filters, floating nav
  capsule (see Design system)
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
(cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:processReleaseManifest) \
  && grep -R "INTERNET\|READ_PHONE_STATE\|c2dm" \
     build/app/intermediates/merged_manifests/release/  # must return nothing
     # gradlew lives in android/; the merged manifest lands under repo-root build/
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
  pills, nav capsule + knob, EXIF chips, detail action bar — light
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
    library/ saved/ search/ albums/ detail/ people/ onboarding/ settings/
    saved/domain/masonry_layout.dart  # pure-Dart column-balanced placement
    saved/widgets/masonry_grid_delegate.dart # feeds it to a lazy SliverGrid
    memories/                   # auto-curated memories: builder, carousel, player
    # edit/ (non-destructive editor) is spec'd but not built yet
  services/
    photo_library_service.dart  # photo_manager wrapper
    paged_assets_notifier.dart  # one-shot pagination base (Search)
    watched_assets_notifier.dart # reactive growing-window base (Library grids)
    ml_service.dart             # ML Kit + TFLite
    indexing_service.dart       # background indexing orchestration
  widgets/
    app_shell.dart              # bottom nav shell (StatefulShellRoute)
    nav_pill_bar.dart           # floating nav capsule + sliding knob (golden-tested)
                                #   `trailing` pins a companion right of the capsule
    indexing_dial.dart          # app-wide "analyzing" dial, the capsule's trailing
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
| Display | 34sp | 700 |
| Button | 15sp | 600 |
| Section label | 11sp | 600 (uppercase, 0.08em spacing) |
| Filter pill | 12sp | 500 |
| Body / list | 14sp | 400 |
| EXIF value | 12sp | 600 |
| EXIF key | 9sp | 400 (uppercase) |
| Caption | 11sp | 400 |

### Spacing (`AppSpace`)

`s2 s4 s8 s12 s16 s20 s24 s32` — s4 photo-grid gutter (`AssetGrid`: Search
results, month/folder grids — cells clip to r12, so a tighter gutter puts
adjacent corners on top of each other), s4 also for *inset* preview grids
(Library sections, which inset s8 rather than s16 so the grid runs wider than
the header), s8 Saved masonry gutter, s16 screen inset, s20 the Library
timeline's inter-section rhythm.

**Vertical gaps between stacked sections are owned by the top edge alone.** A
top *and* a bottom pad makes the visible gap their sum, which is how the
Library's month rhythm silently drifted to 36px.

### Radius (`AppRadius`)

| Token | Use |
|---|---|
| r2 | grab handle, progress segments |
| r4 | DurationBadge |
| r12 | cards, banner, filled inputs, **every photo thumbnail** (grid cells, previews, row and tile covers — one radius, no exceptions) |
| r20 | sheets AND dialogs |
| — | pills = `StadiumBorder` |

### Motion (`AppMotion`)

| Token | ms | Use |
|---|---|---|
| pressed | 110 | Pressable card scale |
| short | 150 | pill selection, play glyph |
| medium | 180 | thumbnail fade, chrome |
| nav | 260 | nav-capsule knob slide |

Curve `easeOutCubic`; every duration via `AppMotion.of(context, d)`
(reduced-motion → `Duration.zero`).

### Over-media (`AppOverMedia`, app_colors.dart)

Theme-invariant consts for content over photos/video: scrims
`0x99`/`0xB3`/`0xD9` black (+`playScrim 0x66`), glyph whites
(`glyph/Soft/Faint/Dim/Ghost`), progress `segment`/`segmentOff`.

### System notes

- Error color = ink (no red anywhere; errors carried by copy).
- Dialogs and sheets share r20 + hairline border; actions are themed
  `TextButton`s.
- Snackbar = inverted-ink floating pill (`pillActiveBg`).
- Icons = Material rounded family; `ios_share_rounded` for share.
  Outlined-style glyphs with no rounded-outline variant stay on the
  default family (nav inactive `photo_library_outlined`/
  `photo_album_outlined`, `videocam_off_outlined`, `broken_image_outlined`).
- Shared components: `AppButton` (primary/secondary/quiet; primary takes
  `compact` for the 40-high app-bar metric and an optional leading icon),
  `AppCard` (surface + r12 + hairline; `.divided` for hairline-separated rows —
  the one grouping container), `CircleIconButton` (`.overMedia` scrim disc /
  `.surface` themed disc), `SegmentedControl<T>` (one value, mutually exclusive
  choices — distinct from a `FilterPill` row of independent facets),
  `SectionHeader` (uppercase section label; `onTap` makes the whole row the
  destination and adds a chevron), `EmptyState`, `CoverRow` (`showChevron` for
  rows that stand alone in a card), `AppSheet`/`AppSheetNote`, `app_dialog`
  helpers, `Pressable` (cards only — never grid cells), `IndexingDial` (the
  app-wide "analysis is running" indicator: a 44 disc in the capsule's own
  inverted ink carrying the remaining count and a progress ring, mounted once as
  `NavPillBar`'s `trailing` in `AppShell`, shows nothing when idle — never say it
  a second time on an individual screen. It rides *beside* the capsule, not as a
  slot inside it, so no destination shifts under the thumb when a pass starts or
  ends).
- Grids differ by job: Library and Search are square multi-column grids for
  *finding* a photo among thousands (uniform scan pattern); Saved is a
  two-column aspect-preserving masonry (`layoutMasonry` + `MasonryGridDelegate`)
  because it is a small, deliberately-kept set.

### Screens

| Screen | Route |
|---|---|
| Library | `/` |
| Search | `/search` |
| Saved | `/saved` |
| Albums | `/albums` |
| Detail | `/photo/:id` |
| Album detail | `/album/:id` |
| Memory player | `/memory/:id` |
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
  compiles plugin Kotlin to JVM 21 while plugins pin their **Java** lower →
  "Inconsistent JVM-target compatibility". Plugins disagree on the level
  (`photo_manager` 17, `google_mlkit_commons` 11, `google_mlkit_image_labeling`
  1.8), and their Java `compileOptions` are **finalized by AGP** — you can't
  raise them from the root (`afterEvaluate` throws "sourceCompatibility has been
  finalized"; a subproject `afterEvaluate` from the root can also throw "already
  evaluated"). So the `subprojects` block in `android/build.gradle.kts` **matches
  each `com.android.library` module's Kotlin `jvmTarget` to its own (read-lazily)
  Java `targetCompatibility`** (1.8/11/17), rather than forcing a single value.
  `patrol` self-pins both sides (1.8) and stays in the `selfConsistentModules`
  skip set. Do *not* override raw `JavaCompile` tasks to 17 — that strips the
  `android.jar` bootclasspath ("package android.app does not exist"). Re-check a
  plain `flutter build apk` (not just `patrol test`) when adding Android plugins.
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
  isolate via `rootBundle` and pass them to the worker). Face boxes are stored in
  the 512-thumb coordinate space so avatars crop the cached thumbnail. **Labels
  and faces run on the 512 thumbnail; OCR runs on a separate larger (1024)
  thumbnail** (`_ocrEdge`, via `analyzeFile(jpegPath, {ocrPath})`) for small-text
  recall — don't collapse them back to one image (it would move the face-box
  space off 512 and break avatars, or shrink OCR again). Both are still bounded
  thumbnails, never the original. Host tests use fake (undecodable) bytes, so
  avatar geometry only shows on-device — validate people avatars on a real device.
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
- **Bottom-nav taps in widget tests need the shell's entry transition to finish.**
  `pumpApp` + a 50 ms pump leaves the shell route mid-slide — the whole nav bar
  sits ~176 px right of its final position, so `tap(find.byTooltip(...))` on a
  right-hand destination derives an offset outside the 800×600 test surface and
  silently misses (only a `warnIfMissed` warning, then the *next* expect fails).
  Pump ~500 ms (still bounded — spinners forbid `pumpAndSettle`) before tapping.
  Also, `StatefulShellRoute.indexedStack` keeps a visited branch in the tree but
  **offstage**, so asserting on a backgrounded tab's widgets needs
  `find.byType(X, skipOffstage: false)`. Branches are built lazily on first
  visit, not eagerly.
- **A `Hero` in an offstage shell branch still collides with the same tag in the
  active branch — gate inactive branches with `HeroMode`.** `/photo/:id` is a
  root route (`parentNavigatorKey: _rootNavigatorKey`), so its Hero flight scans
  the **whole shell subtree**, and `StatefulShellRoute.indexedStack` keeps every
  *visited* branch alive (offstage, but present — `Hero._allHeroesFor` does not
  skip offstage). A favorite shows in both Library and Saved with tag
  `asset-<id>`; once the user has opened the Saved tab (building that branch),
  opening that photo from Library throws "multiple heroes share the same tag"
  during `_startHeroTransition`. Latent until a second tab is visited, which is
  why it hid behind a single-tab session. Fix: the shell uses the general
  `StatefulShellRoute` with a `navigatorContainerBuilder` that rebuilds the
  indexed stack (`IndexedStack`, `StackFit.expand`) wrapping each branch in
  `HeroMode(enabled: i == currentIndex)` (`_BranchContainer` in `app_router`), so
  only the visible tab exposes Heroes — one per flight, state still preserved.
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
- **Use the bundled fixtures, not the camera roll — and note that a *drawn* face
  is not detectable by default.** `tool/gen_test_assets.dart` generates
  `test_assets/` (see its README); `assets/test_fixtures/synthetic_face.jpg` is
  also bundled via `pubspec.yaml` so tests can `rootBundle.load` it without
  seeding MediaStore and polluting a real photo library. ML Kit did **not**
  detect the first synthetic face (flat shapes, hard edges). What made it work:
  correct proportions (eyes on the horizontal midline ~one eye-width apart),
  directional shading, and a final `gaussianBlur` so nothing has vector-sharp
  edges. `integration_test/test_fixtures_test.dart` re-asserts detectability on
  device, so an ML Kit bump that stops recognizing it fails loudly instead of
  quietly hollowing out every consent test. No `ffmpeg`/`exiftool`/PIL on this
  machine — `sips` does the HEIC conversion and the video asset must be supplied
  by hand.
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
  about: 0.45 is right for this pipeline, and 0.40 (which looked clean against
  three probe clusters) fuses visibly different people once every merge it adds is
  inspected. Single linkage chains — at 0.60 it produced one 129-face blob
  including dog faces.
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
- **`IndexingService` toggle methods kick a pass fire-and-forget, so `await
  start()` right after one returns immediately** (`start()` no-ops while
  `_running`). The Settings switch must not block on a full re-index, so
  `setFacesEnabled(true)` calls `unawaited(start())`; a test that then awaits
  `start()` asserts against an unfinished pass and sees empty tables. Poll for
  the outcome with a deadline instead.
- **`package_info_plus` has no host-platform channel** — `PackageInfo.fromPlatform()`
  throws in `flutter test`, so the `appVersionProvider` FutureProvider resolves to
  `AsyncError` (the About row shows `—`, no crash). Override it in widget tests
  (`appVersionProvider.overrideWith((ref) async => '1.0.0 (1)')`). Reads only the
  Android `PackageManager` / iOS bundle — adds no network perms (release manifest
  re-verified clean).
- **Golden tests cannot see icon glyphs.** Alchemist's CI variant obscures
  fonts, so every `Icon` renders as a solid box regardless of codepoint — the
  Phase-5 icon-family swap left all 18 goldens byte-identical (md5-verified),
  which is the *expected* outcome, not a missed regen. Goldens verify layout/
  color only; verify glyph shapes on device (or by eye in the running app).
- **An `AnimatedBuilder`'s built tree shape must stay constant across a whole
  gesture, or it silently kills the gesture mid-flight.** `DismissiblePhoto`'s
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
- **`print`/`debugPrint` do not surface anywhere observable from a
  `patrol test`/`connectedAndroidTest` run** (not the CLI's own output, not
  `adb logcat`, even filtered on the exact tag right after the run) — unlike
  `flutter run`, where the same calls land under the `flutter` logcat tag.
  Diagnosing gesture/animation behavior on-device instead has to go through
  `expect()`/`fail()`, since test-framework failure messages *are* reliably
  surfaced by both the CLI and the HTML report: e.g. `fail('DEBUG: '
  'opacity=${opacity} count=${count}')` deliberately, read the message, then
  remove it. This is how the two gotchas above were actually root-caused.
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
- **Don't finish a drag-dismiss's own exit animation before popping the
  route — hand off to the route's Hero return-flight immediately.**
  `DismissiblePhoto`'s first version ran its own `animateTo(1, ...)`
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
- **A full-screen route over the shell must be opaque and un-transformed, or the
  light shell bleeds around it as a white frame.** `fadeThroughPage`'s fade
  (partial opacity) + 0.96 scale means the background is visible *around and
  behind* the incoming page for the whole flight — on a black media stage over
  the off-white shell that reads as a white border on open and close.
  `heroMediaPage` returns the child untouched (opaque from frame one) and lets
  the Hero, drawn in the app overlay above the page, carry the motion. The
  precondition is that the destination Hero exists on the **first** frame:
  build the landing widget from state you already hold (the memory player takes
  its cover from the `memoriesProvider` summary the carousel is keeping alive)
  rather than from the screen's own async load, and let the load decide only
  what comes *after*. A screen that opens on its `loading` branch has no Hero
  destination, so the flight silently doesn't happen.
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
- **`tester.tap` produces no frame, so an animation it starts records t=0 on the
  *next* pump.** `tap(...)` then a single `pump(400ms)` lands exactly on that
  zero-elapsed frame — `PageController.nextPage` looks like it did nothing and
  the tap reads as ignored. Always `tap` → bare `pump()` → `pump(duration)`.
  Same shape for a pushed route whose screen opens on an `AsyncValue` loading
  branch: the future only resolves after the frame that subscribes to it, so
  the pushed screen needs one more pump before its content exists.

---

## Environment notes

- **App id / namespace:** `com.zmeul.sologallery` (both platforms, and the
  desktop scaffolding). Renamed off the `flutter create` default for release;
  the Android package dirs live at `android/app/src/{main/kotlin,androidTest/java}/com/zmeul/sologallery/`,
  and `pubspec.yaml`'s `patrol:` block carries the same id twice — `patrol test`
  installs by it, so both must move together.
- **Release signing is still the debug key.** `android/app/build.gradle.kts`
  keeps the `flutter create` TODO; `android/key.properties` and any `.jks` are
  gitignored but do not exist. The app builds and installs but **cannot be
  uploaded to Play** until a real upload keystore is created.
- **`patrol` CLI is not on PATH either:** `~/.pub-cache/bin/patrol`, and it
  shells out to `adb`, so export platform-tools first or it fails at teardown
  with `AdbExecutableNotFound`:
  `PATH="$HOME/Library/Android/sdk/platform-tools:$PATH" ~/.pub-cache/bin/patrol test -t <file> -d <device>`.
  Patrol files must run under `patrol test`; `flutter test integration_test/<patrol file>`
  dies with "Binding is already initialized to IntegrationTestWidgetsFlutterBinding".
- **adb not on PATH:** `~/Library/Android/sdk/platform-tools/adb`.
  Direct `./gradlew` calls need
  `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`
  (the `flutter` tool sets this itself).
- **Primary device:** Pixel 9 Pro XL (`46121FDAS008AA`), Android 17 (API 37).
- **Never run `dart format` on a directory — only on the files you edited.**
  The committed tree predates the current `dart format` style, so
  `dart format lib/ test/` rewrites **~115 files** (trailing-comma/argument
  wrapping), burying a real change in thousands of lines of cosmetic diff.
  Worse, it is unrecoverable where it lands on a file that already had
  *uncommitted* edits: the pre-format content was never committed, so the
  formatting can't be separated from the work afterwards, and `git checkout`
  would take both. `tool/check.sh` deliberately does **not** run a format check,
  so nothing forces the issue — reformat the whole tree only as its own
  standalone commit, never as a side effect of a feature.
