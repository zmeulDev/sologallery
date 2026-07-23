# SoloGallery — Flutter Photo App

Privacy-first, 100% local photo app for iOS and Android. No cloud, no
analytics, no network calls after install.

> **Reference docs:** structure, data model, routing, **Design system** prose
> rules, and **Test strategy** detail → `docs/spec.md`. Hard-won traps →
> `docs/gotchas.md`. In-flight task state → `docs/plans/`.

---

## Core features

- Cross-platform (Android + iOS); robust consent + native permission handling for photo-library access
- **App bar:** settings (on Library)
- **Library:** filter pills `All` (default) · `This week` · `Months` · `Year`. `All`/`Months` group into month sections (`Months` adds a year hero header), `Year` into year sections, `This week` is one flat grid of the rolling last 7 days. Each section shows ≤6 previews, newest first; the section header row opens the full grid (label + count + chevron = one tap target, not a separate "view all"). The memories carousel sits on top under `All` only. Undated assets (Android only — `datetaken` null/0) land in a trailing "Older" section
- **People strip:** horizontal avatar row on Search and Albums (not Library)
- **Detail view:** full-screen viewer. Top bar = back · add-to-album · share (scrim discs, outbound actions); action bar below = favorite · info · delete (actions on the photo). Gestures: swipe left/right prev/next, swipe down close, swipe up details, pinch + double-tap (2× at tap point) zoom, single tap toggles chrome. Neighbours ±3 pre-warmed
- **Bottom nav:** Home Gallery · Search · Saved · Albums — floating inverted-ink capsule, active destination marked by a circular knob that teleports to it; while background analysis runs, a small dial rides at the capsule's right with the remaining photo count, gone when it finishes

---

## Stack

- **Targets:** Android 15+ (API 35) and iOS 26+ only — no compatibility code/polyfills for older OS versions
- **Framework:** Flutter (latest stable) + Dart
- **Database:** Drift (SQLite ORM) — never Isar (abandoned Jan 2025)
- **State:** flutter_riverpod (conventions below)
- **Photo library:** photo_manager (API only, no UI integration)
- **ML:** all on-device — google_mlkit_* + TFLite via tflite_flutter
- **Design:** warm off-white/near-black palette, pill filters, floating nav capsule (see Design system)
- **Architecture spec:** `docs/spec.md#architecture` — read before structural work

---

## Absolute rules

- **Zero network calls** — no HTTP client, Firebase, analytics, or cloud SDK
- **Never duplicate photos** — asset ID references only, never file copies
- **Drift for all persistence** — never Isar
- **Non-destructive edits only** — JSON instructions in `edit_instruction` table; never modify originals
- **All ML on a background isolate** — never on the UI isolate
- **Never decode originals for grid cells** — request thumbnails via photo_manager `ThumbnailSize`
- **Never trust Dart-side image decode dimensions** — use photo_manager metadata (see `docs/gotchas.md`)
- **Speed and UX come first** — 60fps scroll, no jank, instant taps; never block the UI isolate
- **Move work to background when the app is idle** — pause/defer indexing, ML, thumbnail warming on lifecycle `inactive`/`paused`; resume on `resumed`
- **No dead code, no hallucinated APIs** — every symbol must exist and be used; unused code/stubs/invented package APIs fail review

---

## Workflow

- **Plan mode first** — ask clarifying questions until the task is well understood, present a plan, save it to `docs/plans/<task>.md`. Work begins only after the plan is saved and approved
- **The plan doc is a living handoff log** — update as you go: check off steps, record decisions and why, keep a "Next step" line current. A fresh session or agent must be able to read CLAUDE.md + the plan and resume immediately
- **UI work** — invoke `/frontend-design:frontend-design` before building or reshaping any screen or widget
- **Architecture** — UI/domain/data separation per `docs/spec.md#architecture`; pure-Dart domain (no Flutter imports); const constructors where possible; Riverpod conventions below
- **Testing is mandatory** — all applicable tiers (see Test strategy), then manual end-to-end on the connected real device
- **Debugging** — no screenshots; drive via adb and read logs (`adb logcat -s flutter:V SoloGallery:V`)
- **Token-optimized work** — delegate read-heavy work to sub-agents, read only files you need, keep answers short (no preamble/recap), let diffs and code speak
- **Verified work — no mistakes** — every change is checked; no dead code, no unused symbols, no invented package APIs; confirm a symbol exists before using it if unsure
- **Maintain this file** — surprising failures go to `docs/gotchas.md` (short form; long form in `docs/plans/`). After each completed task, prune task-scoped notes — only durable rules, conventions, gotchas, and environment facts stay here

---

## Sub-agents

**Delegate whenever possible** — keep the main session small and token-cheap; sub-agents return summaries, not raw output.

- **Delegate (read-heavy, summary-out):** codebase exploration before planning (Explore agent), digesting `adb logcat`/`dumpsys dropbox`, running `tool/check.sh` + reporting failures, reviewing a diff against CLAUDE.md, well-defined self-contained edits
- **Keep in the main session:** architecture/schema decisions and anything whose intermediate reasoning must stay visible in the plan
- **Every invocation:** self-contained prompt (paths, error text, decisions included); instruct the sub-agent to read CLAUDE.md first; read-only tasks get read-only tools (Read/Grep/Glob — no Bash/Write); custom agents in `.claude/agents/` (prefer built-ins); route to cheap models via frontmatter `model` (Haiku for logs, Sonnet for review)

---

## Definition of Done (every task)

1. `tool/check.sh` passes (analyze, build_runner, unit + widget tests)
2. Integration tests for the touched area pass on the connected device
3. Feature manually verified end-to-end on the device
4. Schema changed → schema dump committed + migration test added
5. Android dependency added → release merged manifest re-verified (`docs/gotchas.md`)
6. `docs/gotchas.md` updated if anything surprising happened
7. Plan doc in `docs/plans/` marked complete, with final state and follow-ups — next session starts from it
8. CLAUDE.md pruned of any task-scoped notes added during the work

---

## Verification commands

Prefer `tool/check.sh` (create if missing), which runs the first three:

```bash
flutter analyze                               # zero warnings allowed
dart run build_runner build                   # (delete-conflicting-outputs is now default; see docs/gotchas.md)
flutter test                                  # all unit + widget tests
flutter test integration_test/<one_file>.dart -d <device-id>  # ONE file per run
                                              #   (teardown uninstalls — docs/gotchas.md)
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

Every layer has a required tier — "write tests" means all applicable tiers, not one unit test. Full tiers, the fake-pairing rule, and deterministic test assets → `docs/spec.md#test-strategy`.

- **Unit** — pure-Dart domain logic; DAOs vs in-memory Drift; providers via `ProviderContainer`; drift migration tests (every upgrade path)
- **Widget** — screens with mocked providers (loading/data/error/empty); golden tests (`alchemist`) for design-system widgets, light + dark
- **Integration** (`integration_test` + `patrol`, real device) — boot/onboarding/tabs/scroll/detail/favorite round-trip; the permission matrix; a real-isolate ML smoke test (incl. HEIC)
- **Fake-pairing rule** — any fake/mock of infrastructure must be paired with ≥1 on-device integration test of the real implementation

---

## Riverpod conventions

- Manual providers — no riverpod_generator codegen
- `autoDispose` by default for screen-scoped providers; app-wide services (database, photo library, indexing) kept alive at the root
- UI consumes `AsyncValue` via `when(...)` — explicit loading/error/empty states on every screen; never `.value!`
- No logic in widgets that belongs in providers or services

## Logging

- `package:logging`, single hierarchical root logger `SoloGallery` (children: `SoloGallery.ml`, `SoloGallery.db`, …)
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
    database/                   # Drift DB (app_database, tables) + daos/
  features/
    library/ saved/ search/ albums/ detail/ people/ folders/ onboarding/ settings/
    saved/domain/masonry_layout.dart          # pure-Dart column-balanced placement
    saved/widgets/masonry_grid_delegate.dart  # feeds it to a lazy SliverGrid
    memories/                   # auto-curated memories: builder, carousel, player
    # edit/ (non-destructive editor) is spec'd but not built yet
  services/
    photo_library_service.dart  # photo_manager wrapper
    permission_provider.dart    # library-access state
    thumbnail_provider.dart     # thumbnail request/cache layer
    paged_assets_notifier.dart  # one-shot pagination base (Search)
    watched_assets_notifier.dart # reactive growing-window base (Library grids)
    ml_service.dart             # ML Kit + TFLite
    indexing_service.dart       # background indexing orchestration
  widgets/
    app_shell.dart              # bottom nav shell (StatefulShellRoute)
    nav_pill_bar.dart           # floating nav capsule + knob; `trailing` pins a companion right of the capsule
    indexing_dial.dart          # app-wide "analyzing" dial, the capsule's trailing
test/                           # unit + widget + golden (mirrors lib/)
integration_test/               # on-device tests (patrol)
test_assets/                    # seeded device assets (Test strategy)
tool/check.sh                   # analyze + build_runner + tests
docs/
  spec.md                       # architecture, data model, routing, design system, test strategy
  gotchas.md                    # hard-won traps (full detail)
  plans/                        # in-flight plan/handoff docs
```

---

## Design system

Token tables (quick reference); the prose rules — what the tokens mean and how to apply them — live in `docs/spec.md#design-system`.

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

### Rules (one line each — see `docs/spec.md#design-system` for prose)

- **Spacing** `s2 s4 s8 s12 s16 s20 s24 s32`; s4 photo-grid gutter, s8 Saved masonry gutter, s16 screen inset, s20 Library inter-section rhythm; vertical gaps between stacked sections owned by the top edge alone
- **Radius** r2 grab handle/progress · r4 DurationBadge · r12 cards + **every photo thumbnail** (no exceptions) · r20 sheets AND dialogs · pills `StadiumBorder`
- **Motion** no decorative motion — state changes snap. Two exceptions: Material default transitions (dialog/sheet/snackbar) and the 320 ms memory-player scene cross-slide (reduced-motion guard)
- **Over-media** (`AppOverMedia`) theme-invariant scrims `0x99/0xB3/0xD9` (+`playScrim 0x66`), glyph whites, progress `segment`/`segmentOff`
- **Error color = ink** (no red; errors carried by copy)
- **Snackbar** = inverted-ink floating pill (`pillActiveBg`); dialogs/sheets share r20 + hairline border, themed `TextButton` actions
- **Icons** Material rounded family; `ios_share_rounded` for share; outlined glyphs with no rounded-outline variant stay default family
- **Shared components** `AppButton` · `AppCard` (`.divided`) · `CircleIconButton` (`.overMedia`/`.surface`) · `SegmentedControl<T>` · `SectionHeader` · `EmptyState` · `CoverRow` · `AppSheet`/`AppSheetNote` · `app_dialog` · `IndexingDial`
- **Grids** Library + Search = square multi-column (find among thousands); Saved = two-column aspect-preserving masonry (small, kept set)
- **Screens/routes** → `docs/spec.md#routing`

---

## Model usage (Claude Pro, 5-hour rolling window)

- **Opus 4.8:** architecture/schema decisions, platform channel code (PhotoKit, MediaStore), ML pipeline integration, complex multi-file refactoring
- **Sonnet 5:** UI widgets and screens, unit tests, small bugfixes, anything repetitive or well-defined
- **Haiku 4.5:** quick questions, lookups, clarifications

**Session hygiene:** new conversation per feature (long sessions re-process history and burn tokens exponentially; `/compact` mid-session if long); one focused task per conversation — CLAUDE.md carries project context, don't re-explain it; delegate read-heavy exploration so the main session receives only summaries

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

Full list in `docs/gotchas.md`. The few that touch almost every change:

- **drift patch must match drift_dev exactly** — pin `drift` to drift_dev's patch (currently `2.34.0`); a `pub upgrade` can float `drift_dev` (`^2.34.0`) off it and break `schema dump`/`schema generate`
- **Strip ML/tflite/video perms + the push receiver from the release manifest** with `tools:node="remove"` in `android/app/src/main/AndroidManifest.xml`; re-verify the merged manifest (no `INTERNET`/`READ_PHONE_STATE`/`c2dm`) after any ML/tflite/video dep bump
- **`thumbnail(id, N, N)` is aspect-fill** — short edge is N, long edge larger (a 4:3 at 512 comes back 683×512). Never store a pixel coordinate whose reference dimensions you don't also store; face boxes are normalized `[0, 1]`
- **All ML on a background isolate** — call `BackgroundIsolateBinaryMessenger.ensureInitialized(token)` before any ML Kit call or channels hang; tflite is FFI (no messenger); feed ML a downsized thumbnail, never the original
- **Never `dart format` a directory** — only files you edited; the committed tree predates the current style and a directory format rewrites ~115 files, burying real changes

---

## Environment notes

- **App id / namespace:** `com.zmeul.sologallery` (both platforms + desktop scaffolding). Android package dirs at `android/app/src/{main/kotlin,androidTest/java}/com/zmeul/sologallery/`; `pubspec.yaml`'s `patrol:` block carries the same id twice — both must move together (`patrol test` installs by it)
- **Release signing is still the debug key** — `android/app/build.gradle.kts` keeps the `flutter create` TODO; `android/key.properties`/`.jks` are gitignored but don't exist. Builds and installs but **cannot upload to Play** until a real upload keystore is created
- **`patrol` CLI not on PATH** — `~/.pub-cache/bin/patrol`; shells out to `adb`, so export platform-tools first or it fails at teardown (`AdbExecutableNotFound`): `PATH="$HOME/Library/Android/sdk/platform-tools:$PATH" ~/.pub-cache/bin/patrol test -t <file> -d <device>`. Patrol files must run under `patrol test` (plain `flutter test` dies with "Binding is already initialized")
- **adb not on PATH** — `~/Library/Android/sdk/platform-tools/adb`. Direct `./gradlew` calls need `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"` (the `flutter` tool sets this itself)
- **Primary device:** Pixel 9 Pro XL (`46121FDAS008AA`), Android 17 (API 37)