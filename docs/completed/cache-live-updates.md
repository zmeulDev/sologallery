# Plan — Cache live updates (change listener + reactive paged grids)

_On approval, this is saved to `docs/plans/cache-live-updates.md` (CLAUDE.md
workflow) and CHECKPOINT.md's "Next up" is updated._

## Context

New photos only appear on the next app `resume` today: `IndexingService`
sweeps the `photo_asset` cache at start / permission-grant / resume
(`lib/app.dart`), and nothing re-sweeps while the app stays foregrounded. The
Library **home** is already reactive over the cache
(`libraryMonthCountsProvider`, `olderCountProvider` → `.watch()`), but:

1. Nothing tells the sweep the device library changed while foregrounded, so
   the cache is stale until a background→resume cycle.
2. The paged **full-month** / **Older** grids and the month/older **previews**
   read one-shot `.get()` queries, so even a cache change doesn't reflect while
   they're on screen (a delete inside a month grid, or a new capture, doesn't
   show).

Goal: a foreground `photo_manager` change listener re-sweeps the cache
(debounced), and the paged grids + previews become reactive — new/deleted
photos appear without leaving the app. This is the top Phase-4 cache follow-up
in `docs/plans/CHECKPOINT.md`.

## Part A — Foreground change listener → debounced re-sweep

**`lib/services/photo_library_service.dart`** — keep `photo_manager` behind the
service (architecture rule). Add:
- `Future<void> startLibraryChangeNotify(void Function() onChanged)` —
  stores the callback, `PhotoManager.addChangeCallback(_handleChange)`,
  `await PhotoManager.startChangeNotify()`.
- `Future<void> stopLibraryChangeNotify()` — `removeChangeCallback` +
  `stopChangeNotify()`, clear the callback.
- private `_handleChange(MethodCall _) => _onLibraryChanged?.call();`

**`lib/services/indexing_service.dart`**:
- Register once, lazily, at the top of `start()` (before the `_running`
  guard, so it also covers the grant path): `_ensureChangeNotify()` →
  `photos.startLibraryChangeNotify(_onLibraryChanged)` guarded by a
  `_changeNotifyStarted` bool.
- `_onLibraryChanged()` debounces with a `Timer` (~2s) to coalesce the burst
  of events `photo_manager` emits per change → `_kickResweep()`.
- `_kickResweep()`: skip if `_paused` (backgrounded — resume already
  re-sweeps) or `_cancelled`; if `_running`, set a new `_dirty` flag; else
  `unawaited(start())`.
- Wrap `_run()`'s body in a `do { _dirty = false; sweep; …ML… } while (_dirty
  && !_cancelled)` loop, so a change arriving mid-pass triggers one more
  sweep+backfill afterwards. `_sweepMetadata` is already idempotent (upsert +
  prune) — no other change needed.
- `dispose()`: cancel `_resweepTimer`, `await photos.stopLibraryChangeNotify()`.

Notify stays registered across background; the `_paused` guard in
`_kickResweep` is what defers work (CLAUDE.md: no work while idle).

## Part B — Reactive paged grids + previews

**`lib/core/database/daos/index_dao.dart`** — add `.watch()` variants; keep
the one-shot methods only if still referenced (they won't be):
- `Stream<List<AssetRef>> watchMonthAssets(YearMonth month, {required int limit})`
  and `Stream<List<AssetRef>> watchOlderAssets({required int limit})` —
  same WHERE/ORDER as `monthAssets`/`olderAssets`, `LIMIT limit OFFSET 0`,
  `.watch()`. Growing-window (offset always 0, limit grows) so a single live
  subscription stays correct as pages load.
- `watchMonthPreviews(YearMonth, {int limit=6})` /
  `watchOlderPreviews({int limit=6})` — `.watch()` versions of the existing
  preview queries.

**New reactive paginator** — do **not** touch `PagedAssetsNotifier` (Search
still uses it). Add `lib/services/watched_assets_notifier.dart`:
`abstract WatchedAssetsNotifier extends AsyncNotifier<List<AssetRef>>` that
holds `_limit` (starts at `pageSize`, grows by `pageSize` on `loadMore`),
subscribes to `watchWindow(_limit)`, cancels/re-subscribes on `loadMore`,
sets `state = AsyncData(rows)` on each emission, and derives
`_hasMore = rows.length == _limit`. `build()` returns the first emission (via a
`Completer`) so `.future` still works; `loadMore()` awaits the re-subscribed
window's next emission. `ref.onDispose` cancels the subscription. Same public
surface (`pageSize`, `hasMore`, `loadMore`) as today so the grid screens are
untouched.

**`lib/features/library/month_assets_provider.dart`** — `MonthAssetsNotifier`
/`OlderAssetsNotifier` extend `WatchedAssetsNotifier`, implement `watchWindow`
via the new DAO streams. Provider declarations unchanged
(`AsyncNotifierProvider.autoDispose(.family)`).

**`lib/features/library/library_providers.dart`** — `monthPreviewsProvider` /
`olderPreviewsProvider` become `StreamProvider` over the new watch methods
(consumers already use `.when`).

**`lib/features/detail/detail_providers.dart`** — drop the now-redundant
`invalidate(monthAssetsProvider)` / `invalidate(olderAssetsProvider)` on delete
(the reactive grids reflect the cache prune themselves).

## Tests

- **`test/services/indexing_service_test.dart`** + `fake_photo_library_service`:
  record `startLibraryChangeNotify`, expose a way to fire the callback; assert
  it triggers a second `upsertMetadata` sweep (debounced). Real async `test()`.
- **`test/core/database/index_dao_test.dart`**: `watchMonthAssets` /
  `watchOlderAssets` / preview streams re-emit after an insert/delete
  (in-memory Drift, `expectLater(..., emitsInOrder)`).
- **`test/features/library/month_assets_provider_test.dart`**: keep the
  length/`hasMore`/`loadMore` expectations (still hold with growing window:
  90 → 180 → 200, then `hasMore` false); add one reactivity assertion (insert
  a row → new emission) via `container.listen` (not `await …future` on a
  stream-backed autoDispose — Riverpod-3 trap in gotchas).
- **`test/features/library/{month,older}_grid_screen_test.dart`**: now consume
  a `.watch()`-backed provider → apply the Drift+FakeAsync gotchas: override
  `databaseProvider` with the in-memory DB, **bounded pumps** (a grid `.when`
  loading spinner hangs `pumpAndSettle`), and end with dispose-tree +
  `pump(1s)` to clear Drift's teardown timer.
- **Fake-pairing rule (CLAUDE.md):** the change-listener fake needs one
  on-device integration test of the real path. Extend
  `integration_test/library_month_grouping_test.dart` (or a new
  `cache_live_update_test.dart`): push an image via adb + MEDIA_SCANNER while
  foregrounded, assert a new `photo_asset` row/section appears without a
  resume. Flagged as the on-device DoD step.

## Verification

1. `tool/check.sh` (analyze, build_runner, host tests) green.
2. On the Pixel 9 Pro XL: launch, foreground the app, capture a photo with the
   system camera (or `adb` push + MEDIA_SCANNER), return — the new photo
   appears in the current month **without** backgrounding. Delete a photo
   inside a full-month grid — it disappears live. Watch
   `adb logcat` via `flutter logs` for the `SoloGallery.ml` sweep line.
3. Re-verify the release merged manifest is still network-free (no dep added,
   but DoD #5): the manifest grep returns nothing.

## Out of scope (later Phase-4 polish)

Global face re-cluster, higher-res OCR, tighter avatar crop, `test_assets/`
seeding.
