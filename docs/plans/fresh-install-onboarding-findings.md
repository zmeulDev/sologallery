# Fresh-install onboarding pass — findings (2026-07-24)

Device: Pixel 9 Pro XL (`46121FDAS008AA`), Android 17. Debug build, clean
install (`pm clear` + fresh APK). Onboarding driven via `adb input` with
`uiautomator dump` for state (no screenshots).

**Run:** Allow photo access → *Allow all* → enabled Content search + Memories +
Face detection → **Folders to analyze = Camera only (66 of 892 photos)** →
Continue → Library → Search → Person detail → Detail view → Saved → Albums.

**Functional result: correct.** No exceptions, no crashes, no jank beyond the
usual startup `Skipped 75 frames`. Scrolling the Library stayed smooth. The
exclusion itself works — DB after the pass:

| | |
|---|---|
| `photo_assets` | 892 |
| distinct assets in `photo_labels` | 65 |
| distinct assets in `photo_texts` | 15 |
| `face_embeddings` / `persons` | 5 / 4 |
| `app_settings.excluded_folder_ids` | 5 ids (all but Camera) |

65 of 66 Camera photos labelled, nothing outside Camera analyzed.

---

## Findings

### 1. App logs never reach the console or logcat — BLOCKING for debugging

`configureLogging()` (`lib/core/logging_config.dart:20`) sends every record
through `dart:developer.log`, which only feeds the VM-service *Logging* stream
(visible in DevTools). It is **not** forwarded by `flutter run` and never
reaches Android logcat.

Evidence: this whole session — fresh install, onboarding, an 891-asset indexing
pass — produced **14,982 logcat lines and 0 from `SoloGallery.*`**, even though
`indexing_service.dart:532` unconditionally logs `Indexing 891 new asset(s)`.
The doc comment at `logging_config.dart:9` and the workflow in CLAUDE.md
(`adb logcat -s flutter:V SoloGallery:V`) both describe behaviour that does not
happen.

**Fix:** keep `developer.log` for DevTools, and in non-release builds also write
a formatted line to `stdout` (the engine mirrors Dart stdout to logcat under the
`flutter` tag). This is the one legitimate place for a raw sink; the
"never raw `print`/`debugPrint`" rule targets feature code.

### 2. The indexing dial contradicts the folder choice

Onboarding promises `1 of 6 folders · 66 photos`. The dial then reads
**`Analyzing your photos — 891 left`** and crawls for ~55 s.

`_run()` builds `todo` from `dao.pendingMlIds()` — every asset — and emits
`IndexingStatus(remaining: todo.length, total: todo.length)`
(`indexing_service.dart:530-553`). The 825 excluded assets are in that count
even though `_indexOne(..., excluded: true)` only stamps `indexed_at` for them.
Observed decay: 891 → 761 over 50 s (the real ML work), then 761 → done in
under 10 s (the stamps). So the number is ~13× overstated and its implied ETA is
wrong in both directions.

**Fix:** keep iterating `todo` in full, but derive the emitted
`remaining`/`total` from `todo.where((id) => !excludedAssetIds.contains(id))`.

### 3. Time-window memories ignore the folder gate

Of the 6 memories generated, 3 contain **zero** analyzed assets — they are built
entirely out of the excluded `solo` folder:

| memory | assets | analyzed |
|---|---|---|
| Early July | 28 | 25 |
| Mid April | 23 | **0** |
| Late December | 26 | **0** |
| Sky | 16 | 16 |
| Dog | 18 | 18 |
| Late July | 22 | **0** |

Label-derived memories (Sky, Dog) correctly stay inside Camera; date-window ones
do not. 71 photos from folders the user explicitly excluded were surfaced as
curated content. The sheet's promise is "Excluded folders stay visible; their
photos are skipped."

**Decision needed:** either scope the date-window builders to non-excluded
assets, or reword the folder sheet so it only claims to gate *analysis*.
Recommend scoping the builders — the exclusion reads as a content gate, not just
a CPU gate.

### 4. People-strip tiles are invisible to accessibility

`_PersonTile` (`lib/widgets/people_strip.dart:135`) is a bare `GestureDetector`
with no `Semantics`. On Search the entire section collapses into **one** node,
`[0,1183][1344,1633]`, labelled `PEOPLE\nSee all` — 450 px tall. Tapping inside
the avatar row navigates to a person while the only announced label says
"See all". No individual person is reachable or nameable by a screen reader,
and the strip is untestable by semantics finders.

**Fix:** wrap each tile in `Semantics(button: true, label: person.displayName ?? 'Unnamed person')`.

### 5. Folder-picker rows expose no checked state

`_CheckboxRow` (`lib/features/settings/widgets/folder_picker_sheet.dart:154`)
puts the label and the `Checkbox` inside a plain `InkWell`. Every row —
including "All folders" — dumps as `checkable=false checked=false
selected=false`. Selection state is unavailable to accessibility *and* to
integration tests; during this run the only way to confirm the selection was the
summary line on the screen behind the sheet.

**Fix:** `MergeSemantics` + `Semantics(checked: checked, inMutuallyExclusiveGroup: false)`
on the row, and drop the `Checkbox`'s own duplicate node.

### 6. Minor

- `This may take a while.` is unconditional — identical copy for 66 photos and
  for 892.
- All three analysis toggles default **off**, so the folder row initially reads
  `All folders · No on-device analysis is turned on.` while remaining tappable
  and consequence-free.
- The detail-view image carries no semantics label.

---

---

## Resolution — all six fixed and verified on device

Second fresh-install pass on the same device, same selection (Camera only,
66 of 892), all three toggles on.

| # | Fix | Device evidence |
|---|---|---|
| 1 | `configureLogging()` mirrors every record through `debugPrint` outside release builds | `adb logcat -s flutter:V SoloGallery:V` now streams `INFO [SoloGallery.ml] …` |
| 2 | Progress measured over `todo` minus `excludedAssetIds` | dial opened at **65** and decayed 58 → 48 → 8 → gone, matching the promised 66 |
| 3 | `onThisDay` / `recentDated` filtered before planning | 6 memories → **3**, all inside Camera; the 71 `solo`-only photos are gone |
| 4 | `_PersonTile` wrapped in `Semantics(container/button/label/onTap, excludeSemantics)` | four separate `Unnamed person` targets on Search *and* Albums, was one 450 px blob |
| 5 | `_CheckboxRow` carries `checked` + label; `Checkbox` excluded | rows dump `checkable=true`, only Camera `checked=true` |
| 6 | `This may take a while.` gated on `_slowAnalysisThreshold = 100` | caption read `1 of 6 folders · 66 photos.` |

Key log line, which is both the #1 and the #2 proof:

```
INFO [SoloGallery.ml] Indexing 892 new asset(s); 66 to analyze
INFO [SoloGallery.ml] Indexing pass complete (892 asset(s))
INFO [SoloGallery.ml] Regenerated 3 memory/memories
```

### Notes on the fixes

- **#1** `dart:io` `stdout.writeln` was tried first and produced nothing —
  Android discards that descriptor. Only `print`/`debugPrint` is routed to
  logcat by the engine. Recorded in `docs/gotchas.md`.
- **#3** `excludedAssetIds` is now built when `needsMl || memoriesEnabled`; it
  used to be gated on `needsMl` alone, so memories-on/search-off never had a set
  to filter with.
- **#4** `excludeSemantics: true` also drops the `GestureDetector`'s action, so
  the tile announced as a button that could not be activated. The new test
  caught this; `onTap` is repeated on the `Semantics` itself.

### Tests

Added 5: folder-row semantics, person-tile semantics, below-threshold caption,
progress-excludes-excluded, memories-skip-excluded. All pass.

Fixed 1 pre-existing bug in `folder_picker_sheet_test.dart`: `returns the
selected exclusion set` **hung forever** (verified against a clean checkout, so
not introduced here). A fixed `pump(100ms)` left the sheet mid-animation, the
`Done` tap landed outside it, and a missed tap only warns — so the test blocked
on a completer that never completed. Now `pumpAndSettle`.

### Suite state

`tool/check.sh`: analyze clean, codegen clean, **728 passing / 4 failing**. The
4 are pre-existing and untouched by this work — confirmed by running them
against a stashed-clean tree:

- `album_detail_screen_test.dart: shows the album name, latest entry as cover…`
- `day_grid_screen_test.dart: renders the day title and a grid of assets`
- `design_goldens_test.dart: RecentlyViewedRow — label and square thumbnail cells`
- `thumbnail_radius_test.dart: AlbumCard covers clip to br12` (expects br12, gets br30)

## Next step

Triage the 4 pre-existing failures above — the `br12`/`br30` one in particular
looks like the design system moved and the test did not.
