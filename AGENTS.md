# AGENTS.md — working on SoloGallery

Canonical instructions for any coding agent in this repository. Vendor-neutral;
`CLAUDE.md` defers to this file and adds only Claude Code specifics.

**Read first:** [PRD.md](PRD.md) for what the product is ·
[ARCHITECTURE.md](ARCHITECTURE.md) for how it is built ·
[docs/gotchas.md](docs/gotchas.md) before touching Drift, `photo_manager`, ML,
isolates, Patrol or the release manifest · [docs/design-system.md](docs/design-system.md)
before any UI work.

SoloGallery is a privacy-first, fully on-device photo app for Android and iOS.
No cloud, no accounts, no network calls after install.

---

## Absolute rules

Violating one of these is not a trade-off. It is a defect.

- **Zero network calls** — no HTTP client, Firebase, analytics or cloud SDK.
- **Never duplicate photos** — asset-id references only, never file copies.
- **Drift for all persistence** — never Isar (abandoned Jan 2025), never
  `shared_preferences`.
- **Non-destructive edits only** — JSON instructions in the `edit_instructions`
  table; never modify originals.
- **All ML on a background isolate** — never on the UI isolate.
- **Never decode originals for grid cells** — request thumbnails via
  `photo_manager` `ThumbnailSize`.
- **Never trust Dart-side image decode dimensions** — use `photo_manager`
  metadata (see gotchas).
- **Speed and UX come first** — 60fps scroll, no jank, instant taps; never block
  the UI isolate.
- **Move work to background when the app is idle** — pause indexing, ML and
  thumbnail warming on lifecycle `inactive`/`paused`; resume on `resumed`.
- **No dead code, no hallucinated APIs** — every symbol must exist and be used.
  Unused code, stubs and invented package APIs fail review. The single knowing
  exception is `EditInstructionsDao`, scaffolding for the planned editor.

---

## Stack

| | |
|---|---|
| Targets | Android 15+ (API 35), iOS 26+ — no compatibility code for older OS versions |
| Framework | Flutter (latest stable) + Dart, SDK `^3.12.2` |
| Database | **Drift** 2.34.0 (SQLite) |
| State | `flutter_riverpod` — manual providers, no codegen |
| Routing | `go_router` |
| Photo library | `photo_manager` (API only, no UI integration) |
| ML | on-device only — `google_mlkit_image_labeling` / `_text_recognition` / `_face_detection`, plus MobileFaceNet via `tflite_flutter` |
| Testing | `flutter_test`, `alchemist` (goldens), `integration_test` + `patrol` |

---

## Conventions

### Architecture

UI / domain / data separation per [ARCHITECTURE.md](ARCHITECTURE.md#layers).
Domain is **pure Dart** — no Flutter imports, no plugin imports. `const`
constructors wherever possible. `photo_manager` is touched only by
`photo_library_service.dart`.

### Riverpod

- Manual providers. No `riverpod_generator` codegen.
- `autoDispose` by default for screen-scoped providers; app-wide services
  (database, photo library, indexing, ML worker) are kept alive at the root.
- UI consumes `AsyncValue` via `when(...)` or an exhaustive `switch` — explicit
  loading / error / empty states on every screen. **Never `.value!`.**
  (`ref.watch(x).value ?? fallback` for a synchronously-composed flag or count is
  an accepted house idiom; comment it at the site.)
- Side effects live in `*Actions` classes exposed as plain `Provider`s, not in
  widget callbacks.
- No logic in a widget that belongs in a provider, service or domain file.

### Logging

- `package:logging`, one hierarchical root logger `SoloGallery` with children
  (`SoloGallery.ml`, `SoloGallery.photos`, …).
- **Never raw `print` / `debugPrint` in committed code.** The one sanctioned
  exception is `lib/core/logging_config.dart`, the logger's own logcat sink.
- Device filter: `adb logcat -s flutter:V SoloGallery:V`.

### Formatting

**Never `dart format` a directory** — only the files you edited. The committed
tree predates the current style, and a directory format rewrites ~115 files,
burying the real change.

---

## Project structure

The authoritative tree is in
[ARCHITECTURE.md](ARCHITECTURE.md#project-structure). In short:

`lib/core` (theme · router · database + 7 DAOs · format · logging) ·
`lib/features` (10 feature folders, each with optional `domain/` and `widgets/`) ·
`lib/services` (11 files — the `photo_manager` wrapper, the caching stack, the ML
isolate, indexing) · `lib/widgets` (20 shared design-system components) ·
`test` mirrors `lib` · `integration_test` (18 on-device Patrol tests) ·
`drift_schemas` (v1 … v10) · `tool/check.sh`.

---

## Workflow

- **Plan first.** Ask clarifying questions until the task is understood, present
  a plan, save it to `docs/plans/<task>.md`. Work begins only after the plan is
  saved and approved.
- **The plan doc is a living handoff log.** Update it as you go: check off steps,
  record decisions and why, keep a "Next step" line current. A fresh session must
  be able to read AGENTS.md plus the plan and resume immediately.
- **UI work** — read [docs/design-system.md](docs/design-system.md) before
  building or reshaping any screen or widget. Reuse the shared components; do not
  hand-roll an equivalent.
- **Testing is mandatory** — all applicable tiers, then manual end-to-end on the
  connected device.
- **Debugging** — no screenshots. Drive the device via `adb` and read logs.
  Screenshots can pollute the real photo library through MediaStore.
- **Read only the files you need.** Keep answers short — no preamble, no recap;
  let the diff speak.
- **Verify.** No dead code, no unused symbols, no invented package APIs. Confirm
  a symbol exists before using it.
- **Maintain the docs.** Surprising failures go to `docs/gotchas.md`. After a
  completed task, prune task-scoped notes — only durable rules, conventions,
  gotchas and environment facts stay.

---

## Test strategy

Full detail in [ARCHITECTURE.md](ARCHITECTURE.md#test-strategy). Every layer has
a required tier; "write tests" means all applicable tiers, not one unit test.

- **Unit** — pure-Dart domain logic; DAOs against in-memory Drift; providers via
  `ProviderContainer`; Drift migration tests for every upgrade path.
- **Widget** — screens with mocked providers (loading / data / error / empty);
  `alchemist` goldens for design-system widgets, light and dark.
- **Integration** (`integration_test` + `patrol`, real device) — boot,
  onboarding, tabs, scroll, detail, favorite round-trip; the permission matrix; a
  real-isolate ML smoke test.
- **Fake-pairing rule** — any fake or mock of infrastructure must be paired with
  ≥1 on-device integration test of the real implementation. Two production bugs
  (the isolate binding hang, the HEIC OOM) were invisible to `flutter test`
  because fakes bypassed the real path.

---

## Verification commands

```bash
tool/check.sh                                 # analyze + build_runner + tests
flutter analyze                               # zero warnings allowed
dart run build_runner build                   # --delete-conflicting-outputs is now default
flutter test                                  # all unit + widget tests

# ONE integration file per run — teardown uninstalls the app
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH" \
  ~/.pub-cache/bin/patrol test -t integration_test/<file>.dart -d <device-id>

adb logcat -s flutter:V SoloGallery:V         # runtime debugging
adb shell dumpsys dropbox --print             # native crash inspection

# Release manifest check — must return nothing
(cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:processReleaseManifest) \
  && grep -R "INTERNET\|READ_PHONE_STATE\|c2dm" \
     build/app/intermediates/merged_manifests/release/
```

`tool/check.sh` runs `flutter analyze` → `dart run build_runner build` →
`flutter test`. It does **not** run integration tests or the manifest check;
those are separate steps.

---

## Definition of Done

1. `tool/check.sh` passes.
2. Integration tests for the touched area pass on the connected device.
3. The feature is manually verified end-to-end on the device.
4. Schema changed → schema dump committed **and** a migration test added.
5. Android dependency added → release merged manifest re-verified (no `INTERNET`,
   `READ_PHONE_STATE`, `c2dm`).
6. `docs/gotchas.md` updated if anything surprising happened.
7. The plan doc in `docs/plans/` is marked complete, with final state and
   follow-ups.
8. Docs pruned of any task-scoped notes added during the work.

---

## Known gotchas

Full list in [docs/gotchas.md](docs/gotchas.md) — Drift · photo_manager and the
Android manifest · indexing/ML/faces · Patrol · Flutter layout and gesture ·
Riverpod · tooling · release. The few that touch almost every change:

- **`drift` patch must match `drift_dev` exactly.** `drift` is pinned to
  `2.34.0`; a `pub upgrade` can float `drift_dev` (`^2.34.0`) off it and break
  `schema dump` / `schema generate`.
- **Strip ML/tflite/video permissions and the push receiver from the release
  manifest** with `tools:node="remove"` in
  `android/app/src/main/AndroidManifest.xml`, and re-verify the merged manifest
  after any ML/tflite/video dependency bump. This is what makes the zero-network
  claim verifiable.
- **`thumbnail(id, N, N)` is aspect-fill** — the short edge is N and the long edge
  is larger (a 4:3 at 512 comes back 683×512). Never store a pixel coordinate
  whose reference dimensions you do not also store; face boxes are normalized
  `[0, 1]`.
- **Background isolate ML** — call
  `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` before any ML Kit
  call or the channels hang forever. TFLite is FFI and needs no messenger. Feed
  ML a downsized thumbnail, never the original.
- **Drift migrations** — `m.createTable` builds the **current** shape, so a table
  whose columns changed after it was introduced needs an `else if` guard on the
  later step.

---

## Environment

- **App id / namespace:** `com.zmeul.sologallery`, on both platforms and the
  desktop scaffolding. Android package dirs at
  `android/app/src/{main/kotlin,androidTest/java}/com/zmeul/sologallery/`.
  `pubspec.yaml`'s `patrol:` block carries the same id twice — all of these move
  together, because `patrol test` installs by it.
- **Release signing** is configured against `android/key.properties` and
  `android/app/upload-keystore.jks`. **Both files are currently tracked in git**
  and the passwords are in plaintext; `.gitignore` contains only `.DS_Store`.
  This is a known issue recorded in [PRD.md](PRD.md#known-gaps) — do not add
  further secrets to the repository, and do not assume `.gitignore` protects
  anything.
- **`patrol` CLI is not on PATH** — it lives at `~/.pub-cache/bin/patrol` and
  shells out to `adb`, so export platform-tools first or it fails at teardown
  with `AdbExecutableNotFound`. Patrol files must run under `patrol test`; plain
  `flutter test` dies with "Binding is already initialized".
- **`adb` is not on PATH** — `~/Library/Android/sdk/platform-tools/adb`. Direct
  `./gradlew` calls need
  `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`; the
  `flutter` tool sets this itself. `gradlew` lives in `android/`, but the merged
  manifest lands under the repo-root `build/`.
- **Primary device:** Pixel 9 Pro XL (`46121FDAS008AA`), Android 17 (API 37).
