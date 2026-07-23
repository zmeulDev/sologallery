# SoloGallery — Specification

> **Authority:** `CLAUDE.md` is authoritative for *rules* (Absolute rules,
> workflow, design *tokens*, model usage, environment) — the compact, always-loaded
> doc. This document details *structure and reference* — architecture, data model,
> routing, the **Design system** prose rules, and **Test strategy** detail. Hard-won
> traps live in `docs/gotchas.md`. Where they overlap, CLAUDE.md wins.

SoloGallery is a privacy-first, 100% local photo-management app for iOS and
Android. There are **zero network calls** after install: no cloud, no
analytics, no sync. All processing (including ML) happens on-device.

---

## Architecture

The app is split into three layers with a strict dependency direction:

```
UI  ──▶  Domain  ◀──  Data
        (pure Dart)
```

- **UI depends on Domain.** Data depends on Domain. Domain depends on nothing
  Flutter- or plugin-specific. Wiring between layers is done with Riverpod
  providers (dependency injection), never direct construction inside widgets.

### UI layer — `lib/features/*`, `lib/widgets/*`
- Widgets and Riverpod consumers only. **No business logic** — anything beyond
  layout/interaction belongs in a provider or service.
- Consumes async state as `AsyncValue` via `when(...)`; every screen renders
  explicit **loading / error / empty / data** states. Never `.value!`.
- `features/*` = one folder per screen/feature. `widgets/*` = shared widgets
  (e.g. `app_shell.dart`, the bottom-nav shell).
- Screen-scoped providers are `autoDispose`.

### Domain layer — pure Dart
- Plain models and logic with **no Flutter imports** and no plugin imports
  (no `photo_manager`, no `drift`). Unit-testable on the host with zero
  mocking of infrastructure.
- Examples (added as features land): month/date grouping, the edit-instruction
  model, ML clustering math.

### Data layer — `lib/services/*`, `lib/core/database/*`
- The only layer that touches persistence and native plugins.
- `core/database/*` — the Drift database, tables, and DAOs (see Data model).
- `services/*` — plugin wrappers and orchestration:
  - `photo_library_service.dart` — the sole `photo_manager` wrapper (permission
    handling, asset/album queries, thumbnail requests). UI never calls
    `photo_manager` directly.
  - `ml_service.dart`, `indexing_service.dart` — on-device ML + background
    indexing (later phases; ML runs on a background isolate).
- App-wide services (database, photo library, indexing) are kept alive at the
  root; only screen-scoped state is `autoDispose`.

### Cross-cutting rules (from CLAUDE.md Absolute rules)
- **Never duplicate photos** — everything references `photo_manager` asset ids;
  originals are never copied. Favorites, album membership, and edits are all
  keyed by asset id.
- **Non-destructive edits only** — edits are serialized JSON in the
  `edit_instructions` table; the original file is never modified.
- **Never decode originals for grid cells** — request thumbnails via
  `photo_manager` `ThumbnailSize`.
- **Zero network** — no HTTP client, Firebase, analytics, or cloud SDK.

---

## Data model

The local database is **Drift** (SQLite). It is **versioned**; every upgrade
path *to the current version* is covered by a `SchemaVerifier` migration test
against the committed schema dumps in `drift_schemas/` (`v1` … `v8`). Foreign
keys are enabled per-connection (`PRAGMA foreign_keys = ON` in `beforeOpen`) so
cascades fire.

### Schema v8 (current)

**User-authored state** — the only tables that must exist before ML indexing:

| Table | Key | Columns | Notes |
|---|---|---|---|
| `favorites` | `assetId` (PK) | `favoritedAt` | favorite flag keyed by asset id |
| `albums` | `id` (autoInc PK) | `name`, `coverAssetId?`, `createdAt`, `sortIndex` | user albums |
| `album_entries` | `id` (autoInc PK) | `albumId`→`albums.id` (cascade), `assetId`, `addedAt`; UNIQUE(`albumId`,`assetId`) | album membership by asset-id reference |
| `edit_instructions` | `assetId` (PK) | `instructionsJson`, `updatedAt` | non-destructive edit JSON |

**Indexing + ML** — all derived, all rebuildable from the photo library:

| Table | Key | Columns | Notes |
|---|---|---|---|
| `photo_assets` | `assetId` (PK) | `createdAt`, `isVideo`, `width`, `height`, `isDated`, `indexedAt?` | indexing cursor + lean cached metadata. `indexedAt` NULL = metadata swept but ML pending, so the indexer's remaining work is exactly the NULL rows. `isDated` is false only for Android undated assets, which route to the "Older" bucket |
| `photo_labels` | `id` (autoInc PK) | `assetId`→`photo_assets` (cascade), `label`, `confidence` | ML Kit image labels, one row per (asset, label). Indexed on `assetId` and `label` |
| `photo_texts` | `assetId` (PK) | `content` | on-device OCR. The column is `content`, not `text` — a Drift column cannot reuse a builder name |
| `persons` | `id` (autoInc PK) | `displayName?`, `coverAssetId?`, `createdAt`, `mergedInto?`→`persons.id` (setNull) | face clusters. `mergedInto` is a **redirect, not a move**: the absorbed row keeps its faces, which is what makes a user merge survive the periodic global re-cluster |
| `face_embeddings` | `id` (autoInc PK) | `assetId`→`photo_assets` (cascade), `personId?`→`persons` (setNull), `embedding` (blob), `left`, `top`, `right`, `bottom` | box edges are **fractions in `[0, 1]`**, never pixels — a pixel box is meaningless without the dimensions it was measured against. Indexed on `assetId` and `personId` |

**Preferences + memories:**

| Table | Key | Columns | Notes |
|---|---|---|---|
| `app_settings` | `key` (PK) | `value` | generic key/value prefs — `theme_mode`, `ml_consent`, `search_enabled`, `memories_enabled`, `faces_enabled`. Never `shared_preferences` (Drift-for-all-persistence rule) |
| `memories` | `id` (autoInc PK) | `sourceKey` (unique), `kind`, `title`, `subtitle?`, `coverAssetId?`→`photo_assets` (setNull), `score`, `periodStart?`, `periodEnd?`, `generatedAt`, `seenAt?`, `hidden` | auto-curated collections. Regeneration **upserts on `sourceKey`** rather than wiping the table, so `seenAt`/`hidden` survive and the carousel never reshuffles under the user |
| `memory_entries` | `id` (autoInc PK) | `memoryId`→`memories` (cascade), `assetId`→`photo_assets` (cascade), `position`; UNIQUE(`memoryId`,`assetId`) | ordered membership. Indexed on `memoryId` |

### Version history

| v | Change |
|---|---|
| 1 | `favorites`, `albums`, `album_entries`, `edit_instructions` |
| 2 | + `photo_assets`, `photo_labels` |
| 3 | + `photo_texts`, `persons`, `face_embeddings` |
| 4 | `photo_assets.indexed_at` → nullable; + `photo_assets.is_dated` |
| 5 | + `app_settings` |
| 6 | + `memories`, `memory_entries` |
| 7 | `face_embeddings` boxes → normalized `[0, 1]` reals; existing faces and clusters are dropped and re-derived (pixel values cannot be converted — the dimensions they were relative to were never stored, which *is* the bug) |
| 8 | + `persons.merged_into` |

DAOs (`lib/core/database/daos/`): `FavoritesDao`, `AlbumsDao`,
`EditInstructionsDao`, `IndexDao`, `FacesDao`, `SettingsDao`, `MemoriesDao`.
Accessed via the keep-alive `databaseProvider`.

Before adding v9, re-read the migration trap in `docs/gotchas.md`
(Drift section): `m.createTable` builds the **current** shape, so any table whose
columns change after it was introduced needs an `else if` guard on the later
step — that is why `photo_assets` (v4), `face_embeddings` (v7) and `persons`
(v8) each have one.

---

## Routing

Navigation uses **GoRouter** with a `StatefulShellRoute.indexedStack` for the
four bottom-nav tabs (persistent per-tab state). The shell
(`lib/widgets/app_shell.dart`) renders the active branch plus the custom bottom
nav with the design-system **dot active-indicator**.

Shell branches (bottom nav):

| Screen | Route |
|---|---|
| Library (home grid) | `/` |
| Search | `/search` |
| Saved (favorites) | `/saved` |
| Albums | `/albums` |

Root-navigator routes (outside the shell):

| Screen | Route |
|---|---|
| Onboarding | `/onboarding` (redirect target, not pushed) |
| Detail (full-screen viewer) | `/photo/:id` |
| Month grid | `/month/:key` |
| Older grid (undated assets) | `/older` |
| Album detail | `/album/:id` |
| Folder detail | `/folder?id=&name=` |
| People | `/people` |
| Person detail | `/person/:id` |
| Memory player | `/memory/:id` |
| Settings | `/settings` (pushed from Library app bar) |

Folder detail takes its id as a **query parameter, not a path segment** — an iOS
folder id is a `PHAssetCollection` local identifier and may contain `/`, which no
encoding makes safe in a `:id` segment. `name` only titles the app bar.

Settings is an app-bar affordance on Library, not a tab — it is visited rarely,
where Search earns a permanent slot. Because the Search branch outlives a visit,
its field takes focus from `searchTabActiveProvider` (published by the shell)
rather than `autofocus`, and releases it when the tab is left.

---

## Project structure

See CLAUDE.md "Project structure" for the full tree. In short:
`lib/core` (theme, router, database) · `lib/features` (screens) ·
`lib/services` (plugin wrappers) · `lib/widgets` (shared) · `test` mirrors
`lib` · `integration_test` (on-device, patrol) · `drift_schemas` (schema dumps).

---

## Design system

The token *tables* (colors, typography) live in CLAUDE.md as a quick reference.
The prose rules — what the tokens mean and how to apply them — live here.

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

### Motion

The app has **no decorative motion** — every animated widget was physically
deleted (Part 1). State changes are instant: filter pills, nav-capsule knob,
segmented thumb, indexing dial, thumbnail reveal, chrome show/hide, onboarding
step changes, and the detail drag-dismiss + double-tap zoom all snap. Two
exceptions remain: **Material defaults** (`showDialog`/`showModalBottomSheet`/
`SnackBar` keep Flutter's built-in transitions) and the **memory-player scene
change** (a 320 ms `easeOutCubic` cross-slide between story photos, inlined as
file-private consts in `memory_player_screen.dart` with a
`MediaQuery.disableAnimations` guard for reduced-motion jump-cuts).

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
  helpers, `IndexingDial` (the
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

---

## Test strategy

Every layer has a required tier. "Write tests" means all applicable tiers, not
one unit test. The tier *headings* are in CLAUDE.md; the detail is here.

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
- **Golden tests** (`alchemist`) for design-system widgets, light and dark —
  this is what makes the Design system enforceable. They live in
  `test/widgets/design_goldens_test.dart` and
  `test/features/detail/detail_goldens_test.dart`, with the images under
  `<dir>/goldens/ci/`. Every new design-system widget gets one.

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

Required set (`test_assets/`, generated by `tool/gen_test_assets.dart`):
`large_48mp.heic` (~48MP iPhone, the OOM regression asset) · `gps_exif.jpg` ·
`no_exif.jpg` · `small_png.png` (labeling fast path) · `synthetic_face.jpg`.
**The video asset (thumbnail + duration badge) is still missing** — no
`ffmpeg` on this machine, so it has to be supplied by hand.
