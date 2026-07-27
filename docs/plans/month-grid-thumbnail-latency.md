# Full-grid thumbnail latency — diagnosis

## Symptom

Tapping "View all" on a Library month/year/day section shows grey placeholder
tiles for ~1s before photos appear (first visit only).

## Measured on-device (Pixel 9 Pro XL, busiest month = 80 photos, 400px cells)

Reproduced at the service layer (bulk prewarm of entities, then decode disjoint
**cold** id sets at different concurrencies):

| Measurement | Result |
|---|---|
| Bulk-resolve 80 `AssetEntity`s (`getAssetListPaged`, one path query) | ~50 ms |
| First screenful (18) decode, **entities already warm** | ~936 ms |
| Decode 18 cold @ concurrency **1** | ~1850 ms (~103 ms/thumb) |
| Decode 18 cold @ concurrency **6** (current gate) | ~858 ms (~48 ms/thumb) |
| Decode 18 cold @ concurrency **18** | ~1870 ms (~104 ms/thumb) |
| Re-decode same 18 (photo_manager native byte cache warm) | ~70 ms |

## Corrected root cause

**The bottleneck is native thumbnail *decode*, not entity resolution.**

- An initial diagnosis blamed `AssetEntity.fromId` (~52 ms/cell, serialized).
  That was wrong: prewarming all entities up front (~50 ms total) left the
  decode pass still at ~936 ms. Entity resolution is only ~60 ms of the ~1 s.
- `photo_manager` decodes a 400px thumbnail from the **original file** each time.
  Decode parallelizes only ~2× (native has a small decode pool), so the current
  `ThumbnailGate(maxConcurrent: 6)` is **already near-optimal** — concurrency 1 is
  ~2× slower, concurrency 18 thrashes and is *worse* than 6.
- photo_manager caches decoded bytes **in memory only**, so the *second* visit to
  a month is ~70 ms. Every *first* visit re-pays ~850 ms for the screenful, and
  more as you scroll (each new screenful decodes fresh).

So there is no cheap win in the request path: entities aren't the cost, and the
gate is already tuned. Fixing "time to photos visible" means moving the decode
cost **off the critical path** or making it persist.

## Candidate fixes (need a decision — not yet implemented)

1. **Persistent thumbnail cache** — decode each asset's grid-size (400px) thumb
   once, store the JPEG bytes on disk (or Drift blob) keyed by `assetId:size`,
   reuse forever. First-ever decode still costs, but can be **warmed during idle
   indexing** (the indexer already visits every asset for ML and already pulls a
   512px thumb — add a 400px grid thumb + persist). Biggest, most durable win;
   adds a storage layer + eviction policy + the ML-perms/isolate constraints.
2. **Warm the byte cache just-in-time** — when a Library section is on screen,
   start decoding its full window's 400px thumbs in the background so "View all"
   opens warm. Cheaper than (1), no disk, but only helps sections the user
   actually looked at, and the in-memory cache is LRU (evicts under scroll).
3. **Shrink the decode** — request a smaller cell thumb, and/or verify
   photo_manager uses Android `ContentResolver.loadThumbnail` (MediaStore's
   pre-generated thumbnails, ~ms) rather than a full decode. If it's doing a full
   decode of the original, switching to the MediaStore thumbnail path could cut
   the ~48 ms/thumb dramatically. **Investigate before building (1).**
4. **Check indexing contention** — grid decodes and the ML indexer share the same
   native decode pool. Opening a month *while indexing runs* likely amplifies the
   delay well past the 850 ms measured idle. Confirm indexing is paused/deferred
   on the detail/grid navigation, per CLAUDE.md's "move work to background".

## Investigation results (3) + (4)

### (3) It is a full Glide decode of the original — not a MediaStore thumbnail

Traced the Android path through `photo_manager-3.10.0`:

`AssetEntity.thumbnailDataWithSize` → native `PhotoManager.getThumb` →
`ThumbnailUtil.getThumbnail` (`android/.../thumb/ThumbnailUtil.kt`):

```kotlin
Glide.with(context).asBitmap()
  .apply(RequestOptions().frame(frame).priority(IMMEDIATE))
  .load(entity.getUri())
  .signature(ObjectKey(entity.modifiedDate))
  .submit(width, height).get()
```

- So every grid thumb is a **Glide downsample decode of the original file**, not
  `ContentResolver.loadThumbnail` (MediaStore's pre-generated thumbs). Confirms
  the decode-bound diagnosis.
- Glide **does** have a fast MediaStore path (`MediaStoreImageThumbLoader`), but
  it only fires when the request fits the MINI-thumb kind: `width ≤ 512 &&
  height ≤ 384`. The grid asks for **400×400** — height 400 > 384, so it **always
  misses** the fast path and does a full decode. Requesting a height ≤ 384 could
  make Glide serve the OS thumbnail (~ms) — *if* the device has generated MINI
  thumbnails. Fragile, undocumented Glide behavior; **needs on-device measurement
  to confirm it actually hits the loader** before relying on it.
- No `DiskCacheStrategy` is set → Glide default `AUTOMATIC`. For a local URI +
  transformed bitmap that caches the decoded *resource* to Glide's disk cache, so
  a warm Glide disk cache helps across *app launches* — but photo_manager exposes
  no control over it, and the first-ever decode always pays full cost. The in-
  session "second visit ~70 ms" is Glide's in-memory bitmap cache.

### (4) Indexing does NOT pause on in-app navigation — contention is real

`app.dart` pauses/resumes indexing **only** on app lifecycle
(`resumed`→resume, `inactive`/`paused`/`hidden`/`detached`→pause). Nothing
pauses it when the user opens a month grid or the detail viewer while the app
stays foregrounded.

So opening a section *while a foreground indexing pass runs* has the ML indexer
(its 3-slot `_indexingGate`) decoding thumbnails on the **same Glide native
decode pool** the grid's 6-slot `_thumbnailGate` uses — amplifying the ~850 ms
idle figure. This is exactly the first-launch scenario (fresh install → indexing
running → user taps a section).

## Recommendation (revised, ordered)

1. **(4) Pause/deprioritize indexing during grid + detail navigation** — cheapest,
   safe, squarely in CLAUDE.md's "move work to background when idle." Likely
   removes a large chunk of the *first-launch* pain. Low risk, no new storage.
2. **(3a) Measure the ≤384px MediaStore fast path on-device** — if requesting
   400×384 (or 384²) makes Glide serve the OS MINI thumbnail, it's a near-free
   massive win. If it doesn't hit the loader / device has no MINI thumbs, drop it.
3. **(1) Persistent 400px thumb cache warmed during idle indexing** — the durable
   fix if decode stays ~48 ms/thumb. Biggest build (storage + eviction).

## Built

### (4) Indexing yields the native decode pool to the grid — DONE

Instead of a blunt route-based pause, coupled the two thumbnail gates at the
resource they actually share (the native decode pool):

- `ThumbnailGate` gained `isQuiet` + `whenQuiet()` (`lib/services/thumbnail_gate.dart`)
  — a future that resolves the next time the gate has nothing running *or*
  queued. `_release()` wakes every parked waiter when the gate drains.
- `PhotoLibraryService.thumbnail(..., indexing: true)` now `await`s
  `_thumbnailGate.whenQuiet()` inside its `_indexingGate` slot before decoding
  (`lib/services/photo_library_service.dart`). So while a "View all" screenful
  is decoding, the background pass parks; it resumes the instant the grid drains.
  A single indexing decode may overlap the next grid cell (harmless); what's
  prevented is a whole pass grinding against the burst.
- Foreground grid + detail-preview paths are unchanged (previewImage /
  adjacentThumbnail don't go through `_thumbnailGate`, so they're not yielded to
  — see follow-up).

Tests: `test/services/thumbnail_gate_test.dart` +3 cases (immediate-quiet,
burst-drain ordering, multi-waiter wake). Gate + provider + indexing suites green;
`flutter analyze` clean on the touched files. **Still needs on-device manual
verification** (open a month while a fresh-install pass runs; confirm the burst is
no longer starved) per Definition of Done.

### (1) Persistent grid-thumbnail cache — DONE (lazy-populate)

`lib/services/thumbnail_disk_cache.dart` — `ThumbnailDiskCache`, a filesystem
cache of grid JPEG bytes keyed `assetId:size:modifiedDateSecond`, under
`<app-support>/thumb_cache/`. **No schema / no Drift table / no migration.**
Best-effort throughout (every op swallows I/O errors → miss). FIFO eviction by
file mtime under a 200 MB budget, swept every 64 writes (no read-path writes).
`path_provider` is only touched on the first op, via an injectable
`resolveDirectory` (tests pass a temp dir).

Wired into `PhotoLibraryService`:
- Grid path (`thumbnail`, `indexing: false`) → `_gridThumbnail`: return the
  persisted bytes on a hit (no native decode at all); on a miss, decode once and
  fire-and-forget `put`. Grid requests are always square, so the key's size dim
  is `width`.
- The signature is `AssetEntity.modifiedDateSecond` — the same value Glide keys
  its own cache on — so an edited/replaced original self-invalidates.
- The indexer's ML thumbs (512/1024, `indexing: true`) are **not** persisted
  (used once, never re-read) — they keep only the `whenQuiet()` yield from (4).
- `clearThumbnailDiskCache()` added for a future settings "clear cache"; **not**
  wired to lifecycle pause (the whole point is to survive backgrounding).

Effect: turns "grey tiles on every first visit *per session*" into "first visit
*ever*". A month reopened later — even after an app restart or a memory-cache
eviction — is a file read, not an ~850 ms decode burst.

Tests: `test/services/thumbnail_disk_cache_test.dart` (round-trip, dir
auto-create, signature + size invalidation, iOS-id chars, clear, FIFO eviction,
resolver-failure disables silently). Full suite green (775), `flutter analyze`
clean. **Still needs on-device manual verification** (open a month, back out,
reopen → instant; kill + relaunch → still instant).

## Follow-ups / remaining candidates

- **(3a) MediaStore fast path — RULED OUT (no harness needed).** Glide's
  `MediaStoreImageThumbLoader` fast path reads the legacy
  `MediaStore.Images.Thumbnails` table, deprecated in Android Q in favour of
  on-demand `ContentResolver.loadThumbnail`. On the Pixel 9 Pro XL (Android 15)
  that table is **empty** — `adb shell content query --uri
  content://media/external/images/thumbnails` → 0 rows, vs 157 images in
  `images/media`. So even if we shrank the request to ≤384px height to qualify,
  Glide would find no OS thumbnail and fall back to a full decode anyway, at the
  cost of a smaller/non-square source. Dead end on our target OS. (A native
  platform-channel calling `loadThumbnail` directly is the only way to reach the
  modern path, but its speed win isn't guaranteed — it still decodes/downsamples
  when no cached thumb exists, which is the same 0-rows situation. Not worth it
  over (1).)
- **Warm the disk cache during idle indexing** — the shipped (1) is lazy-populate
  (first-ever visit still decodes, then it's permanent). A `warmGridThumbnail`
  step in the indexer could pre-populate so even the first-ever open is warm.
  Deferred deliberately: it only helps *newly* indexed assets (already-indexed
  libraries are skipped by the pass), is independent of ML consent (so it can't
  just piggyback the existing ML-thumb decode), and adds one 400px decode per
  new asset — meaningful idle work on a huge library. Weigh against the marginal
  win over lazy-populate before building.
- Detail-viewer contention: `previewImage`/`adjacentThumbnail` bypass the grid
  gate, so indexing does not yet yield to a detail open. Lower priority (detail
  has its own placeholder machinery); revisit if measured.

## Status

- [x] Measured; root cause corrected (decode-bound, not entity-bound).
- [x] Reverted the entity-prewarm change — it saved only ~6% (wrong target).
- [x] (3) traced: full Glide decode, misses MediaStore fast path at 400×400.
- [x] (4) confirmed: indexing only pauses on app lifecycle, not navigation.
- [x] (4) built: indexing yields the decode pool to the grid via `whenQuiet()`.
- [x] (3a) ruled out: device's MediaStore thumbnails table is empty (Android 15).
- [x] (1) persistent grid-thumbnail disk cache built (lazy-populate) + unit-tested.
- [x] (1) verified on-device (Pixel 9 Pro XL): `files/thumb_cache/` populates live
      as you browse (grew past 78 files / ~16 MB), filenames match the key scheme
      (`base64url(id)_size_signature.jpg`; decoded ids are real MediaStore ids,
      signature = `modifiedDateSecond`), bytes are valid JPEGs (SOI `ff d8 ff`,
      and the grid renders them). Only real UI sizes present (256/400/500/1000 +
      dynamic `cellWidth×dpr` values 312/424/500/612/1024) — **zero `_512_`**,
      confirming the indexer's ML thumbs are correctly NOT persisted.
- [ ] (4) manual on-device check while indexing runs (open a month mid-pass).
- [ ] Decided AGAINST warming during indexing — marginal + spotty coverage
      (see follow-up); lazy-populate delivers the durable win.

### On-device note (sizes)

Grid thumbnail sizes are per-screen: fixed (asset_grid/album grid 400, Saved/
memory 500/1000, covers 256/120) and dynamic `(cellWidth × devicePixelRatio)
.ceil()` (Library, Saved masonry, recently-viewed → 312/424/500/612/1024 on this
device). Dynamic sizes are deterministic for a given device+orientation, so
reopening the same screen is a cache hit; a rotation/split-screen resize decodes
once at the new size (a new key). Every `AssetThumbnail` size persists, so covers
and memory thumbs get the same durability for free.

### Note

Device currently holds a throwaway debug build from the benchmark runs; next
`flutter run`/test rebuilds it. The on-device benchmark harness was removed after
measuring — recreate from the numbers above if needed.
