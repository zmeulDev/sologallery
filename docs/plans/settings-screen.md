# Plan — Build out the Settings screen

**STATUS: ✅ Complete (host side).** Schema v5 + SettingsDao, theme override,
rebuild index, library stats, About, and the full UI landed; `tool/check.sh`
green (215 host tests incl. migration v1→v5…v4→v5 + theme-picker golden),
release manifest re-verified network-free. **Remaining: manual on-device
verification** (checklist in Verification §3) — user is running device tests.


_On approval, saved to `docs/plans/settings-screen.md`. **Phase 4 polish is NOT
superseded** — global face re-cluster, higher-res OCR, and tighter avatar crop
remain open in `docs/plans/CHECKPOINT.md` and are the next work after this._

## Context

`lib/features/settings/settings_screen.dart` is a 21-line placeholder, yet
Settings is a core bottom-nav tab. This builds it into a real screen with five
sections, reusing existing providers/design tokens. The one structural addition
is a **Drift settings table (schema v5)** to persist a theme override — required
because "Drift for all persistence" forbids `shared_preferences`.

Sections (all four opted in, plus Photo access + About):
Photo access · Manage limited access · Appearance (theme) · Library stats ·
Rebuild index · About.

## 1. Schema v5 — persisted settings (Drift)

- **`lib/core/database/tables.dart`** — add a key/value `AppSettings` table:
  `TextColumn key` (PK), `TextColumn value`. Generic so future prefs reuse it.
- **`app_database.dart`** — register `AppSettings`; `schemaVersion => 5`; add
  `if (from < 5) await m.createTable(appSettings);` to `onUpgrade` (append, does
  not disturb the existing v1–v4 branches). Add the doc-comment line for v5.
- **`lib/core/database/daos/settings_dao.dart`** (new, `@DriftAccessor([AppSettings])`):
  `Stream<String?> watch(String key)`, `Future<void> put(String key, String value)`
  (upsert), and typed helpers `watchThemeMode()` → `ThemeMode` (default
  `system`) and `setThemeMode(ThemeMode)`. Register `SettingsDao` in
  `@DriftDatabase(daos: [...])` and add `settingsDaoProvider` in
  `database_provider.dart` (mirror `indexDaoProvider`).
- **Schema dump + migration test (DoD #4):**
  - `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`
    → new `drift_schemas/drift_schema_v5.json`.
  - `dart run drift_dev schema generate drift_schemas/ test/core/database/generated_migrations/`
    → new `schema_v5.dart`, regenerated `schema.dart`.
  - `test/core/database/migration_test.dart` — add v1→v5, v2→v5, v3→v5, v4→v5
    cases (validate **to current**, per the existing harness note). Keep
    v1→v4/etc.? No — bump the existing "→ v4" cases to "→ 5" (current is 5 now;
    the harness validates only to current).
  - Watch the drift/drift_dev patch-match gotcha before dumping.

## 2. Theme override wiring

- **`lib/features/settings/theme_mode_provider.dart`** (new) —
  `StreamProvider<ThemeMode>` over `settingsDaoProvider.watchThemeMode()`, kept
  alive (app-wide). Default `ThemeMode.system` until it emits.
- **`lib/app.dart`** — `themeMode: ref.watch(themeModeProvider).value ??
  ThemeMode.system` (replaces the hardcoded `ThemeMode.system`).

## 3. Rebuild index

- **`IndexDao.clearIndex()`** (new) — `delete(photoAssets)` (cascades to
  labels/OCR/faces) + `delete(persons)`, in a transaction.
- **`IndexingService.rebuild()`** (new) — cancel the active pass
  (set `_cancelled`, await `_running == false`), reset `_cancelled = false`,
  `await dao.clearIndex()`, emit swept=`false` (add a `_setSwept(bool)` that can
  go false, driving the Library spinner during rebuild), then `start()`. Guard
  against re-entrancy with a `_rebuilding` bool.
- Settings action: confirm dialog → `ref.read(indexingServiceProvider).rebuild()`;
  progress reflected by the existing `indexingStatusProvider`.

## 4. Library stats (read-only)

- **`IndexDao`** — add `Stream<({int photos, int videos})> watchLibraryTotals()`
  (`count()` over all rows; a second filtered by `isVideo`). Reuse
  `FacesDao.watchPersonSummaries()` (`.map((l) => l.length)`) for the people
  count; `indexingStatusProvider` for "Indexing… N left".
- A `libraryStatsProvider` combining these for the section.

## 5. About + dependency

- Add **`package_info_plus`** to read the app version at runtime (no network
  perms; re-verify the release manifest per DoD #5 after adding).
- Static privacy line: "100% on-device · zero network · your photos never leave
  this device."

## 6. UI — `settings_screen.dart` (rebuild)

Invoke **`/frontend-design:frontend-design`** before building. A scrolling list
of grouped sections using existing tokens: `AppColors`
(`surface`/`surface2`/`textSecondary`/`border`) and `AppTextStyles`; the
uppercase **section-label** style already used in `month_section_header.dart` /
`library_screen.dart`. Rows are simple tiles (label + value/trailing action);
theme picker as a 3-way pill segmented control (mirror the existing filter-pill
look). Consume providers via `.when(...)` (loading/error/empty) per Riverpod
conventions — never `.value!`. Photo-access actions call the existing
`permissionProvider` methods (`presentLimited`, `openSettings`); access label
derives from `PhotoAccess`.

## Tests

- **Migration**: v1→v5 … v4→v5 (SchemaVerifier + committed v5 dump).
- **`settings_dao_test.dart`**: put/watch round-trip; `watchThemeMode` default +
  set (in-memory Drift).
- **`index_dao_test.dart`**: `clearIndex` empties photo_assets + cascades +
  persons; `watchLibraryTotals` counts photos/videos.
- **`indexing_service_test.dart`**: `rebuild()` clears then re-sweeps (fake
  photos + worker; assert cache repopulated and swept re-emits false→true).
- **`settings_screen_test.dart`** (widget): renders each section for a seeded
  in-memory DB; theme pill tap writes via SettingsDao; limited-access actions
  visible only when access == limited. Apply the Drift+FakeAsync gotchas
  (databaseProvider override, bounded pumps, dispose-tree + `pump(1s)` teardown
  since it watches settings/stats streams).
- **Golden (alchemist)** for the theme segmented control (light+dark) — a
  design-system widget, per Test strategy.

## Verification

1. `tool/check.sh` green (analyze, codegen, host tests incl. new migration +
   widget + golden).
2. Release manifest still network-free after adding `package_info_plus`
   (DoD #5 grep returns nothing).
3. On device (Pixel 9 Pro XL): open Settings — switch Light/Dark/System (whole
   app re-themes and persists across relaunch); confirm stats match the library;
   run Rebuild index (grid shows the spinner, then repopulates); with limited
   access, "Select more photos" opens the picker.

## Out of scope (still tracked)

Phase 4 polish — periodic global face re-cluster, higher-res OCR, tighter
avatar crop — remains the next task after Settings.
