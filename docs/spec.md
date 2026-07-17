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

The local database is **Drift** (SQLite). It is **versioned**; every schema
upgrade path (v1 → v2 → … → N) is covered by a `SchemaVerifier` migration test
against committed schema dumps in `drift_schemas/`. Foreign keys are enabled
per-connection (`PRAGMA foreign_keys = ON` in `beforeOpen`) so cascades fire.

### Schema v1 (current)

Only user-authored state that must exist **before** ML indexing lives here.

| Table | Key | Columns | Notes |
|---|---|---|---|
| `favorites` | `assetId` (PK) | `favoritedAt` | favorite flag keyed by asset id |
| `albums` | `id` (autoInc PK) | `name`, `coverAssetId?`, `createdAt`, `sortIndex` | user albums |
| `album_entries` | `id` (autoInc PK) | `albumId`→`albums.id` (cascade), `assetId`, `addedAt`; UNIQUE(`albumId`,`assetId`) | album membership by asset-id reference |
| `edit_instructions` | `assetId` (PK) | `instructionsJson`, `updatedAt` | non-destructive edit JSON |

DAOs: `FavoritesDao`, `AlbumsDao`, `EditInstructionsDao`
(`lib/core/database/daos/`). Accessed via the keep-alive `databaseProvider`.

### Deferred to later schema versions (ML / indexing phase)

Not yet defined — added via a future migration when indexing is built, so the
embedding/label shape isn't committed to prematurely:

- `photo_asset` — cached indexed metadata (dimensions, created/modified, type,
  duration, GPS, indexed flag). The gallery grid reads `photo_manager`
  directly until this exists.
- `photo_label` — on-device ML Kit image labels (asset id, label, confidence).
- `face_embedding` — face vectors for people clustering.

---

## Routing

Navigation uses **GoRouter** with a `StatefulShellRoute.indexedStack` for the
four bottom-nav tabs (persistent per-tab state). The shell
(`lib/widgets/app_shell.dart`) renders the active branch plus the custom bottom
nav with the design-system **dot active-indicator**.

| Screen | Route | Nav |
|---|---|---|
| Library (home grid) | `/` | tab |
| Saved (favorites) | `/saved` | tab |
| Albums | `/albums` | tab |
| Settings | `/settings` | tab |
| Detail (full-screen viewer) | `/photo/:id` | pushed (later phase) |
| Album detail | `/album/:id` | pushed (later phase) |

Search is an app-bar affordance on Library, not a tab. Detail, album-detail,
people, and edit routes are added in their respective feature phases.

---

## Project structure

See CLAUDE.md "Project structure" for the full tree. In short:
`lib/core` (theme, router, database) · `lib/features` (screens) ·
`lib/services` (plugin wrappers) · `lib/widgets` (shared) · `test` mirrors
`lib` · `integration_test` (on-device, patrol) · `drift_schemas` (schema dumps).
