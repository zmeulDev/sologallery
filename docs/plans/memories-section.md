# Memories section

Auto-curated "Memories": a horizontal carousel on top of Library, opening a
full-screen story player.

**Status: complete.** Shipped and verified end-to-end on the Pixel 9 Pro XL.
**Next step:** none — see "Follow-ups" for the deferred work.

- [x] Step 1 — schema v6 (`memories`, `memory_entries`), dump + migration tests
      (v1..v5 → v6, all green)
- [x] Step 2 — `MemoriesDao` (+ 18 DAO tests green)
- [x] Step 3 — pure-Dart generation engine (+ 19 builder tests green)
- [x] Step 4 — regeneration hook in `IndexingService` (+ 5 tests)
- [x] Step 5 — providers (`memories_providers.dart`)
- [x] Step 6 — UI: carousel on Library, `MemoryCard`, `/memory/:id` player
- [x] Step 7 — widget tests (4 carousel, 5 player), `memory_card` golden,
      `integration_test/memories_test.dart`, manual device verification

### Verification record

- `tool/check.sh`: **301 tests green**, `flutter analyze` clean.
- `integration_test/memories_test.dart` on `46121FDAS008AA`: both cases pass.
- Manual E2E on device — real library of 92 assets fully indexed (534 labels),
  which generated exactly three memories:

  | source_key | kind | title | subtitle | entries |
  |---|---|---|---|---|
  | `trip:2026-07-10` | trip | Early July | 2026 | 40 (capped) |
  | `theme:dog` | theme | Dog | 23 photos | 23 |
  | `theme:sky` | theme | Sky | 14 photos | 14 |

  Baselines stamped (`memories_generated_on=2026-07-19`,
  `memories_asset_baseline=92`); entries verified oldest-first. Tapping the
  first card opened the player (`seen_at` stamped 10:54:15), which auto-advanced
  all 41 pages and popped itself back to Library — proven by the *second* card
  registering a tap afterwards (10:57:29). No exceptions, no RenderFlex
  overflows in `logcat`.
- No new dependencies, so DoD #5 (release merged manifest) is a no-op —
  `pubspec.*` and `android/` are untouched.
- No "On this day" memory appeared: this device's library has no photos from
  July 19 of a previous year. That is correct behavior, but it does mean the
  **On This Day path has not been exercised on a real library** — see
  Follow-ups.

### Follow-ups

- **Exercise On This Day on a device with multi-year history.** Only host tests
  cover it today.
- **Theme allowlist tuning.** `Dog` and `Sky` were the two that qualified here;
  `MemoryBuilder.presentableLabels` will need revisiting against a larger, more
  varied library. `Sky` in particular is a weak memory subject.
- Ken Burns, in-player favourite/share, GPS trips, export — all explicitly out
  of v1 scope.
- **Videos: resolved by exclusion.** The open question from the plan
  ("3s muted slice vs. excluded") was settled as *excluded* — the player renders
  every page through `PhotoPage`, so a clip would sit frozen on its poster frame
  for three seconds with nothing marking it as video. `MemoriesDao._liveAssetIds`
  filters `isVideo` when applying a plan, which covers all four memory kinds in
  one place. Revisit if the player ever grows real video playback.

### Deviations from the original plan (decided during implementation)

- **`memories.score`, not `rank`** — `RANK` is a SQL window-function name;
  sidestepping it costs nothing.
- **Cover = the middle photo**, not "the asset with the most faces". The
  face-count variant needed an extra join for a cosmetic gain; the middle of a
  time-ordered story is more representative than its first frame anyway.
  Person memories keep the person's existing avatar so People and Memories
  agree on who someone is.
- **The 40-asset cap samples evenly across the span** rather than truncating,
  so a 200-photo trip still closes on its last day.
- **`applyPlan` re-checks asset ids against `photo_asset` inside the
  transaction.** A photo pruned between planning and applying would otherwise
  abort the whole batch on the FK.

---

## Decisions (settled — do not re-litigate)

| Question | Decision |
|---|---|
| Feature | Auto-curated (Photos-style), no manual curation |
| Placement | Carousel above the month grid on Library. No nav change. |
| Signals | Date, ML labels, people/faces. **No GPS** (`photo_assets` has no lat/lng; adding it is out of scope) |
| Storage | New Drift tables at **schema v6** (`memories`, `memory_entries`) |
| v1 types | On This Day · Trip/event clusters · Theme (labels) · Person |
| Player | Core only: auto-advance, segmented progress, hold-to-pause, swipe, title card. **No** Ken Burns, **no** in-player actions in v1 |

Deferred to follow-ups: Ken Burns, in-player favorite/share, location-based
trips, memory export/video, notifications.

---

## Architecture

Generation is **pure-Dart domain logic** (no Flutter imports) fed by bounded
DAO projections, run on the **background indexing loop** — never on a UI path.
This mirrors the existing faces flow: `FacesDao.rebuildClusters(List<PlannedCluster>)`
is the precedent for `MemoriesDao.applyPlan(List<PlannedMemory>)`.

```
IndexingService._run()  ──tail──▶  _maybeRegenerateMemories()
                                        │
                          bounded projections from MemoriesDao/IndexDao/FacesDao
                                        │
                                        ▼
                        MemoryBuilder.build(...)  (pure Dart, unit-tested)
                                        │  List<PlannedMemory>
                                        ▼
                            MemoriesDao.applyPlan(...)   (idempotent upsert by sourceKey)
                                        │
                                        ▼ .watch()
                     memoriesProvider  ──▶  MemoriesCarousel  ──▶  MemoryPlayerScreen
```

### Idempotence via `sourceKey`

Every planned memory carries a stable `sourceKey`
(`otd:07-19:2024`, `trip:2025-06-01`, `theme:dog`, `person:3`). `applyPlan`
upserts on it rather than wiping the table, so regeneration preserves
`seenAt`/`hidden` and never reshuffles the carousel under the user.

---

## Step 1 — Schema v6

`lib/core/database/tables.dart`:

```dart
class Memories extends Table {
  IntColumn  get id          => integer().autoIncrement()();
  TextColumn get sourceKey   => text().unique()();          // idempotence key
  TextColumn get kind        => text()();                   // MemoryKind.name
  TextColumn get title       => text()();
  TextColumn get subtitle    => text().nullable()();
  TextColumn get coverAssetId=> text().nullable()
      .references(PhotoAssets, #assetId, onDelete: KeyAction.setNull)();
  RealColumn get rank        => real()();                   // carousel order, desc
  DateTimeColumn get periodStart => dateTime().nullable()(); // display window …
  DateTimeColumn get periodEnd   => dateTime().nullable()(); // … (On This Day expires)
  DateTimeColumn get generatedAt => dateTime()();
  DateTimeColumn get seenAt      => dateTime().nullable()();
  BoolColumn get hidden          => boolean().withDefault(const Constant(false))();
  @override Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'memory_entry_memory', columns: {#memoryId})
class MemoryEntries extends Table {
  IntColumn  get id       => integer().autoIncrement()();
  IntColumn  get memoryId => integer()
      .references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get assetId  => text()
      .references(PhotoAssets, #assetId, onDelete: KeyAction.cascade)();
  IntColumn  get position => integer()();
  @override Set<Column> get primaryKey => {id};
}
```

Notes / gotcha compliance:
- No column reuses a Drift builder name (`text`/`real`/`boolean`/…).
- Cover is `setNull` (not cascade) so deleting the cover photo doesn't delete
  the memory; entries are `cascade` so deletions self-heal. A memory whose
  entries fall below the minimum is pruned on the next regeneration.
- `app_database.dart`: `schemaVersion => 6`, register `MemoriesDao`, add a
  fresh `if (from < 6) { await m.createTable(memories); await m.createTable(memoryEntries); }`
  block. Both tables are *introduced* at v6, so no `else if` guard is needed
  (that trap only bites tables whose shape changes after introduction).
- `drift_schemas/drift_schema_v6.json` dumped + committed; regenerate
  `test/core/database/generated_migrations/`.

---

## Step 2 — `MemoriesDao` (`lib/core/database/daos/memories_dao.dart`)

Read side (UI):
- `Stream<List<MemoryCard>> watchActive({int limit = 10})` — joins cover,
  counts entries, excludes `hidden`, excludes rows whose `periodEnd` has
  passed, orders by `rank DESC`. `MemoryCard` is a record typedef
  (`({int id, String kind, String title, String? subtitle, String? coverAssetId, int count})`).
  **Add the entry-count aggregate to `addColumns`** (documented Drift trap).
- `Future<List<AssetRef>> assetsFor(int memoryId)` — entries joined to
  `photo_assets`, ordered by `position`. Bounded (≤ 40), so no paging base is
  used; `personAssetsProvider` in `people_providers.dart` is the shape to copy.
- `Future<void> markSeen(int id)` / `Future<void> hide(int id)`.

Generation side (background):
- `Future<List<DatedAsset>> recentDatedProjection({int limit = 20000})` —
  `(assetId, createdAt)` only, `isDated = true`, ordered `createdAt DESC`.
  Feeds trip clustering. Deliberately a thin projection, never full rows.
- `Future<List<DatedAsset>> onThisDay(int month, int day)` — uses the
  **`STRFTIME(..., 'unixepoch', 'localtime')` `CustomExpression` idiom**
  (`IndexDao.watchMonthCounts` is the template). Drift's `.month`/`.day` run
  in UTC and would mis-bucket — see the CLAUDE.md gotcha.
- `Future<List<LabelTally>> topLabels({double minConfidence = 0.7, int limit = 40})`
  — new aggregate (`label`, `COUNT(DISTINCT asset_id)`), the one query that
  doesn't exist today.
- `Future<void> applyPlan(List<PlannedMemory> plan)` — one transaction:
  upsert each memory on `sourceKey` (preserving `seenAt`/`hidden`), replace its
  entries, delete memories whose `sourceKey` is absent from the plan.

---

## Step 3 — Generation engine (pure Dart)

`lib/features/memories/domain/` — no Flutter imports, fully unit-tested.

- `memory_kind.dart` — `enum MemoryKind { onThisDay, trip, theme, person }`.
- `planned_memory.dart` — `PlannedMemory` (sourceKey, kind, title, subtitle,
  coverAssetId, rank, periodStart/End, ordered `assetIds`).
- `memory_builder.dart` — `MemoryBuilder.build({required DateTime today, ...inputs}) → List<PlannedMemory>`.
  Deterministic and clock-injected so tests don't depend on the real date.

Rules (tunable constants at the top of the file, all unit-tested at boundaries):

| Type | Rule | Title / subtitle |
|---|---|---|
| On This Day | same local month+day, a **past** year, ≥ 5 assets → one memory per year | "On this day" / "2024" |
| Trip | scan `recentDatedProjection` desc; split on gaps > 3 days; keep clusters spanning ≤ 10 days with ≥ 20 assets; max 4 | "Early June" / "2025" |
| Theme | `topLabels` ∩ curated allowlist const set, ≥ 12 assets; max 3 | label, title-cased / "42 photos" |
| Person | named `persons` with ≥ 15 faces spanning ≥ 2 distinct months; max 2 | person name / "Over the years" |

- **Theme labels need an allowlist.** Raw ML Kit labels are noisy and
  unpresentable ("Person", "Event", "Room"). A const `presentableLabels` set in
  the domain file gates them; anything outside it never becomes a memory.
- Per-memory assets capped at **40**, sorted by `createdAt` ascending (a story
  should read forward in time). Cover = the memory's asset with the most faces
  if available, else the middle asset — decided in the builder, not the UI.
- `rank`: `kindWeight * recencyDecay(mostRecentAsset)`. On This Day outranks
  everything on its day. Global cap of 10 surfaced memories.

---

## Step 4 — Regeneration hook

`IndexingService._maybeRegenerateMemories()`, called at the tail of `_run()`
alongside `_clusterNewFaces()` / `_maybeGlobalRecluster()` — inheriting
pause/resume lifecycle gating for free (`app.dart` already drives it).

Trigger: local calendar date differs from the `app_settings` baseline
`memories_generated_on`, **or** ≥ 50 new cached assets since the baseline
(mirrors the `faces_at_last_recluster` pattern).

Trip clustering scans up to 20k `(id, createdAt)` records on the **UI isolate's
event loop** (indexing is not isolated — only ML is). Chunk the scan and
`await Future.delayed(Duration.zero)` every 2000 records, exactly as `_run()`
already does, so the 60fps rule holds. Verify with a scroll-during-generation
pass on device.

---

## Step 5 — Providers

`lib/features/memories/memories_providers.dart`, matching
`library_providers.dart` house style (autoDispose + permission guard):

- `memoriesProvider` — `StreamProvider.autoDispose<List<MemoryCard>>`,
  returns `Stream.value(const [])` unless `access.canReadLibrary`.
- `memoryAssetsProvider` — `FutureProvider.autoDispose.family<List<AssetRef>, int>`.
- `memoryActionsProvider` — `Provider<MemoryActions>` (`markSeen`, `hide`),
  following `PeopleActions`.

---

## Step 6 — UI

Run `/frontend-design:frontend-design` before building either surface
(CLAUDE.md workflow rule).

**Carousel.** `_MonthList` is a `ListView.builder`, not a `CustomScrollView`.
Insert the carousel as an **index-0 header row** and offset the month/older
indices by 1 — a smaller change than converting to slivers. The carousel is its
own `ConsumerWidget` (`lib/features/memories/widgets/memories_carousel.dart`),
matching `_MonthSection`'s lazy-watch pattern so memories only load when the
row is built. It renders nothing (zero height) when the list is empty — no
empty state on Library.

A horizontal `ListView` gives children a **tight cross-axis constraint** (the
load-bearing comment at `search_screen.dart:398`), so wrap it in a fixed-height
`SizedBox`. Header via the existing `MonthSectionHeader(label: 'MEMORIES')`.

**`MemoryCard`** (`lib/features/memories/widgets/memory_card.dart`) — sibling
of `AlbumCard`, not a reuse (`AlbumCard` is `AlbumSummary`-typed). Same visual
grammar: `ClipRRect` r12 over `AssetThumbnail(size: 500)`, title `text.body`
w600, subtitle `text.caption` / `colors.textSecondary`. Golden-tested.

**Player.** `lib/features/memories/memory_player_screen.dart`, route
`/memory/:id` registered **top-level** (outside the shell) next to `/photo/:id`.
Structurally `detail_screen.dart` minus the chrome plus a ticker:
`PageView` + `_DetailPage`'s `PhotoPage`, reusing `detailImageProvider`
(screen-capped bytes — never decode originals). Adds: 3s-per-photo auto-advance
`Timer`, segmented progress bar, hold-to-pause, swipe-to-skip (cancels and
restarts the timer), a title card as page 0, close button. Calls `markSeen` on
open. Videos in a memory play muted for a fixed 3s slice rather than full
duration — or are excluded from v1 memories entirely if that proves fiddly on
device (decide during implementation, record the outcome here).

---

## Step 7 — Tests (all tiers, per Test strategy)

1. **Unit — `MemoryBuilder`** (`test/features/memories/memory_builder_test.dart`):
   injected clock; each type's threshold at boundary (4 vs 5 On This Day assets,
   3-day vs 4-day trip gap, 11 vs 12 theme assets); allowlist filtering; asset
   cap and ascending order; rank ordering; determinism (same input → same
   `sourceKey`s).
2. **Unit — `MemoriesDao`** against `NativeDatabase.memory()` with foreign keys
   ON: every method; `applyPlan` idempotence (re-apply preserves `seenAt`/`hidden`);
   plan-absent memories deleted; entry cascade on asset delete; cover `setNull`
   on cover-asset delete; `onThisDay` correctness in a **non-UTC** test timezone
   (the regression this codebase has already been bitten by).
3. **Migration** — `SchemaVerifier` v1→v6, v2→v6, v3→v6, v4→v6, v5→v6
   (**to current only**, never intermediate — documented gotcha).
4. **Providers** via `ProviderContainer`: empty/populated/permission-denied.
   Use `container.listen`, never `await streamProvider.future` on an autoDispose
   stream; allow a real 10ms turn after mutations.
5. **Widget** — carousel hidden when empty, renders N cards, tap routes to
   `/memory/:id`; player advances on timer, pauses on hold, title card first.
   Library tests touching the carousel need `databaseProvider.overrideWithValue(inMemoryDb)`
   and the `pumpWidget(SizedBox()) + pump(1s)` teardown; **bounded pumps only**
   (the player animates forever — `pumpAndSettle` would hang).
6. **Golden** — `MemoryCard` light + dark via `design_goldens_test.dart` →
   `test/widgets/goldens/ci/memory_card.png`.
7. **Integration (device)** — `integration_test/memories_test.dart`: seed
   `test_assets/`, force a regeneration, assert carousel appears, open a memory,
   assert it auto-advances. Pre-grant permissions per the CLAUDE.md recipe and
   run **one file per `flutter test` invocation**.
8. **Manual on device** — scroll Library during generation and confirm no jank;
   confirm no new permissions in the release merged manifest (no new Android
   deps expected, so DoD #5 should be a no-op — verify anyway).

---

## Risks

- **Trip clustering cost on a 50k-photo library.** Mitigated by the bounded
  projection + chunked yields; if it still janks, move the scan into the
  existing ML worker isolate.
- **Theme quality.** ML Kit labels are coarse; the allowlist is the whole
  defense. Expect to tune it after seeing real output on device.
- **Empty libraries / new users** produce zero memories — that is the correct
  behavior (carousel absent), not an error state.
- **Player battery/perf** with 40 full-size decodes; `detailImageProvider`
  caps bytes, but confirm memory on device with a 40-photo memory.

---

## File manifest

```
lib/core/database/tables.dart                          (+2 tables)
lib/core/database/app_database.dart                    (v6, dao, migration)
lib/core/database/daos/memories_dao.dart               (new)
lib/features/memories/domain/memory_kind.dart          (new)
lib/features/memories/domain/planned_memory.dart       (new)
lib/features/memories/domain/memory_builder.dart       (new)
lib/features/memories/memories_providers.dart          (new)
lib/features/memories/memory_player_screen.dart        (new)
lib/features/memories/widgets/memories_carousel.dart   (new)
lib/features/memories/widgets/memory_card.dart         (new)
lib/features/library/library_screen.dart               (carousel header row)
lib/services/indexing_service.dart                     (regeneration hook)
lib/core/router/app_router.dart                        (/memory/:id)
drift_schemas/drift_schema_v6.json                     (new)
test/…                                                 (per Step 7)
```

CLAUDE.md updates on completion: `Project structure` gains `memories/`,
`Design system → Screens` gains `Memory player | /memory/:id`, and any
surprises go to Known gotchas.
