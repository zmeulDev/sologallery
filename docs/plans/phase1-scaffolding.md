# Plan — Phase 1: Project Scaffolding

> **Status: ✅ Complete** (2026-07-17). `tool/check.sh` green (analyze clean,
> codegen ok, 19 unit/widget tests pass). Verified on Pixel 9 Pro XL: clean
> boot (Impeller/Vulkan, no native crash), four-tab nav driven on-device with
> no exceptions. Release manifest confirmed network-free.
>
> Deviations from plan: pinned `drift` to `2.34.0` to match `drift_dev`
> (schema-tooling incompatibility) and added a Kotlin `jvmTarget=17` fix in
> `android/build.gradle.kts` for the JDK-21 plugin build — both recorded in
> CLAUDE.md Known gotchas.

## Context

`~/Dev/sologallery` is currently a bare `flutter create` skeleton (Flutter
3.44.6 / Dart 3.12.2): only default `lib/main.dart` (counter demo),
`test/widget_test.dart`, and platform folders. No dependencies beyond
`cupertino_icons`, no app architecture, no database, and the architecture
doc CLAUDE.md points to (`docs/spec.md#architecture`) does not exist.

This task lays the foundation every later feature builds on: core
dependencies, the UI/domain/data layer structure from CLAUDE.md "Project
structure", the design-system theme, a GoRouter + bottom-nav shell with the
four placeholder tabs, and the Drift database layer (schema v1 + codegen +
migration-test harness). **No feature logic** — screens are placeholders and
the DB is not yet wired into any screen. The goal is a compiling, tested,
architecturally-correct baseline so Phase 2+ features drop into place.

Decisions already made with the user:
- Write `docs/spec.md` now (this task).
- **Defer** ML deps (`google_mlkit_*`, `tflite_flutter`) and the ML/indexing
  Drift tables to the ML phase.
- **Skip** `git init` (user handles git).
- Schema/architecture designed here in the main Opus session (not delegated,
  per CLAUDE.md Sub-agents rules).

## Non-goals (deferred to later phases)

- photo_manager permission flow + real gallery grid (Phase 2)
- Favorites / albums / edit / detail feature logic and screen wiring (Phase 3)
- ML deps, `photo_asset`/`photo_label`/`face_embedding` tables, indexing (Phase 4)
- `alchemist` golden tooling and `patrol` integration tooling — added when the
  first golden / on-device test is written, to keep scaffolding lean

## Deliverables

### 1. Dependencies (`pubspec.yaml`)
Add via `flutter pub add` (resolve latest compatible; no hand-pinned versions):
- Runtime: `flutter_riverpod`, `go_router`, `drift`, `drift_flutter`,
  `sqlite3_flutter_libs`, `path_provider`, `path`, `photo_manager`, `logging`
- Dev: `drift_dev`, `build_runner`

`photo_manager` is added now (core dep) but only referenced by a thin service
stub; no permission calls yet.

### 2. `docs/spec.md` (with `#architecture` anchor)
The authoritative architecture doc CLAUDE.md references. Sections:
- **Overview** — restate privacy-first / 100% local constraints
- **Architecture** (`## Architecture`) — the three layers and their rules:
  - **UI layer** (`features/*`, `widgets/*`) — widgets + Riverpod consumers,
    no business logic, renders `AsyncValue` via `when(...)`
  - **Domain layer** — pure-Dart models & logic, **no Flutter imports**
    (date grouping, edit-instruction model, clustering later)
  - **Data layer** (`services/*`, `core/database/*`) — Drift DAOs +
    photo_manager wrapper; the only layer touching persistence/plugins
  - Dependency direction (UI → domain ← data; wiring via Riverpod)
  - Asset-ID-reference rule (never copy/duplicate photos)
  - Non-destructive edit rule (`edit_instructions` JSON)
- **Data model** — the v1 schema (below) and the deferred ML tables, with a
  note that schema is versioned and migrations are `SchemaVerifier`-tested
- **Routing** — the screens/routes table from CLAUDE.md
- Cross-link: CLAUDE.md remains authoritative for rules; spec.md details structure

### 3. Directory structure (from CLAUDE.md "Project structure")
Create `lib/{core/{theme,router,database},features/{library,saved,search,albums,detail,people,edit,settings},services,widgets}`,
plus `test/` mirrors, `integration_test/`, `docs/{plans,postmortems}`,
`tool/`. Empty feature dirs for not-yet-built screens are created only where a
file lands this task (library, saved, albums, settings); the rest are created
when their feature phase starts.

### 4. Theme — `lib/core/theme/`
`app_theme.dart`: `lightTheme` / `darkTheme` `ThemeData` built from the
CLAUDE.md Design-system tokens (background/surface/surface2/text/pill/border)
and the typography table (page title 22/700, section label 11/600 uppercase
0.08em, filter pill 12/500, body 14/400, EXIF value 12/600, EXIF key 9/400,
caption 11/400) exposed as a `TextTheme` + a small `AppColors`/extension for
the non-Material tokens (pill active, surface2, text muted, border).
Typeface: default platform font for now; final type choice deferred to the
frontend-design pass. **Invoke `/frontend-design:frontend-design` before
writing this file.**

### 5. Router + shell — `lib/core/router/` + `lib/widgets/app_shell.dart`
- `app_router.dart`: `GoRouter` with a `StatefulShellRoute.indexedStack` over
  four branches → `/` (Library), `/saved` (Saved), `/albums` (Albums),
  `/settings` (Settings). Provided via a keep-alive Riverpod provider.
- `app_shell.dart`: scaffold hosting the branch `navigationShell` + a custom
  bottom nav bar with the **dot active-indicator** (design system), four
  destinations (Home/Saved/Albums/Settings). **Invoke frontend-design before
  building the nav bar.**
- Detail/album-detail routes are added in their feature phases.

### 6. Placeholder tab screens — `lib/features/{library,saved,albums,settings}/`
Four `ConsumerWidget` screens, each a `Scaffold` with a design-system-styled
page title (Library shows the app-bar search icon as an inert placeholder) and
a centered muted "Coming soon" placeholder body. No providers/data yet.

### 7. Drift database — `lib/core/database/`
`app_database.dart` — `@DriftDatabase` `AppDatabase`, `schemaVersion = 1`,
`PRAGMA foreign_keys = ON` in `beforeOpen` (and in the test connection).
Backed by `drift_flutter`'s `driftDatabase(name: ...)` for the app; DAOs get
in-memory `NativeDatabase.memory()` connections in tests.

**v1 tables** (Phases 2–3 needs only; ML tables deferred to a v2 migration):

| Table | Columns | Notes |
|---|---|---|
| `favorites` | `assetId` TEXT **PK**, `favoritedAt` DATETIME | keyed by photo_manager asset id — works before `photo_asset` exists |
| `albums` | `id` INT autoInc **PK**, `name` TEXT, `coverAssetId` TEXT?, `createdAt` DATETIME, `sortIndex` INT default 0 | user albums |
| `album_entries` | `id` INT autoInc **PK**, `albumId` INT → `albums.id` **onDelete cascade**, `assetId` TEXT, `addedAt` DATETIME; **UNIQUE(albumId, assetId)** | album membership by asset-id reference |
| `edit_instructions` | `assetId` TEXT **PK**, `instructionsJson` TEXT, `updatedAt` DATETIME | non-destructive edit JSON |

DAOs (data-layer pattern + something to test — not wired to any screen):
`FavoritesDao`, `AlbumsDao`, `EditInstructionsDao` with basic
watch/list/insert/delete/upsert methods.

Riverpod: a keep-alive `databaseProvider` (root-scoped) exposing `AppDatabase`.

Codegen: `dart run build_runner build --delete-conflicting-outputs`. Commit
the v1 schema dump to `drift_schemas/` via
`dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`.

### 8. Logging — `lib/core/`
`logging_config.dart`: configure the hierarchical `SoloGallery` root logger in
`main()` (level + a single listener); children created per-service later. No
`print`/`debugPrint`.

### 9. App entry — `lib/main.dart` + `lib/app.dart`
- `main.dart`: `WidgetsFlutterBinding.ensureInitialized()`, init logging,
  `runApp(ProviderScope(child: SoloGalleryApp()))`.
- `app.dart`: `SoloGalleryApp` → `MaterialApp.router` with light/dark themes,
  `themeMode: system`, `routerConfig` from the provider.
- Delete the counter demo.

### 10. `tool/check.sh`
`flutter analyze` (zero warnings) → `dart run build_runner build
--delete-conflicting-outputs` → `flutter test`. Executable, `set -euo pipefail`.

### 11. Tests (`test/`, mirrors `lib/`)
- **DAO tests** (in-memory Drift, FK pragma ON): each DAO method incl. the
  `album_entries` cascade-on-album-delete and the UNIQUE(album, asset) constraint.
- **Migration harness test**: `SchemaVerifier` opens v1 from the committed
  dump and validates the live schema matches (establishes the v1→vN pattern).
- **Widget smoke tests**: each placeholder screen renders its title;
  `app_shell` renders four destinations and tapping switches branches.
- Replace the default counter `widget_test.dart`.

## Files (representative)
- `pubspec.yaml`, `docs/spec.md`, `tool/check.sh`
- `lib/main.dart`, `lib/app.dart`, `lib/core/logging_config.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/router/app_router.dart`, `lib/widgets/app_shell.dart`
- `lib/core/database/app_database.dart` (+ `.g.dart`), `.../daos/*.dart`,
  `drift_schemas/drift_schema_v1.json`
- `lib/features/{library,saved,albums,settings}/*_screen.dart`
- `lib/services/photo_library_service.dart` (thin stub, no permission calls yet)
- `test/**` mirrors + `integration_test/` (dir only this task)

## Verification
1. `tool/check.sh` — analyze clean, codegen runs, all unit+widget tests pass.
2. `flutter run` on the connected device: app boots to Library, bottom nav
   switches between the four tabs, dot indicator tracks the active tab, light
   & dark render correctly. (Per CLAUDE.md: verify on device; no screenshots —
   read `adb logcat -s flutter:V SoloGallery:V`.)
3. Confirm no network deps pulled in (`pubspec.lock` review) and that Drift
   codegen produced `app_database.g.dart` + the v1 schema dump.

## Notes
- `/frontend-design:frontend-design` will be invoked before the theme and the
  nav shell (the two real UI surfaces here) per CLAUDE.md workflow rule.
- Mark this plan complete and copy it to `docs/plans/phase1-scaffolding.md` on
  completion (Definition of Done #7).
