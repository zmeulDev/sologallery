# SoloGallery — Specification

> **Authority:** `CLAUDE.md` is authoritative for *rules* (Absolute rules,
> workflow, testing, design tokens). This document details *structure* —
> architecture, data model, and routing. Where they overlap, CLAUDE.md wins.

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

Before adding v9, re-read the migration trap in CLAUDE.md "Known gotchas":
`m.createTable` builds the **current** shape, so any table whose columns change
after it was introduced needs an `else if` guard on the later step — that is why
`photo_assets` (v4), `face_embeddings` (v7) and `persons` (v8) each have one.

---

## Routing

Navigation uses **GoRouter** with a `StatefulShellRoute.indexedStack` for the
four bottom-nav tabs (persistent per-tab state). The shell
(`lib/widgets/app_shell.dart`) renders the active branch plus the custom bottom
nav with the design-system **dot active-indicator**.

| Screen | Route | Nav |
|---|---|---|
| Library (home grid) | `/` | tab |
| Search | `/search` | tab |
| Saved (favorites) | `/saved` | tab |
| Albums | `/albums` | tab |
| Settings | `/settings` | pushed (Library app bar) |
| Detail (full-screen viewer) | `/photo/:id` | pushed (later phase) |
| Album detail | `/album/:id` | pushed (later phase) |

Settings is an app-bar affordance on Library, not a tab — it is visited rarely,
where Search earns a permanent slot. Because the Search branch outlives a visit,
its field takes focus from `searchTabActiveProvider` (published by the shell)
rather than `autofocus`, and releases it when the tab is left. Detail,
album-detail, people, and edit routes are added in their respective feature
phases.

---

## Project structure

See CLAUDE.md "Project structure" for the full tree. In short:
`lib/core` (theme, router, database) · `lib/features` (screens) ·
`lib/services` (plugin wrappers) · `lib/widgets` (shared) · `test` mirrors
`lib` · `integration_test` (on-device, patrol) · `drift_schemas` (schema dumps).
