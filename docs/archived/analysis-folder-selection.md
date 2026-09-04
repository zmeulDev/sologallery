# Plan: Analysis settings screen + folder selection

**Goal:** Create a dedicated **Analysis** settings sub-screen and move all analysis-related controls there. The main Settings screen keeps only a single **Analysis** entry row. The new screen hosts on-device analysis consent toggles, the rebuild-index action, and a folder picker that controls which device folders are included in ML analysis. Excluded folders remain visible in the Library/Saved grids — only labels, OCR text, and face detection are skipped.

**Assumptions to confirm:**
1. *Scope is analysis only*, not library visibility. Photos in excluded folders still appear when browsing; they just are not searchable by content and do not contribute to People/Memories.
2. *Strict exclusion rule:* if an asset appears in any excluded folder, it is not analyzed. (On iOS an asset can live in multiple albums; this rule errs on the side of privacy.)
3. New folders that appear after the user makes a selection are **included by default** — the exclusion set is explicit.

---

## Design

### User flow
- Settings main screen shows an **Analysis** row under a new group (or folded into Library/Index).
- Tap **Analysis** → push `/settings/analysis`.
- `AnalysisSettingsScreen` shows:
  - **On-device analysis** section with the three existing consent cards (Content search, Memories, Face detection).
  - **Index** section with **Rebuild index** action.
  - **Folders for indexing** section with row **"Folders to analyze"**.
    - Row value reads **"All folders"** when nothing is excluded, otherwise **"X of Y folders"**.
    - Tap opens an `AppSheet` bottom sheet titled **"FOLDERS TO ANALYZE"**.
    - Sheet shows:
      - A top **"All folders"** checkbox row.
      - A divider.
      - A scrollable list of device folders with a checkbox each.
      - A bottom **"Done"** button.
    - Changes are saved on **Done**.
- The main Settings screen no longer renders the On-device analysis or Rebuild index sections.

### Routing
- Add route `/settings/analysis` to the root GoRouter config.
- Push from Settings via `context.push('/settings/analysis')`.

### Data layer
- Persist in `app_settings` as a JSON list under key `excluded_folder_ids`.
- Add helpers in `SettingsDao`:
  - `Stream<Set<String>> watchExcludedFolderIds()`
  - `Future<Set<String>> readExcludedFolderIds()`
  - `Future<void> setExcludedFolderIds(Set<String> ids)`
- No schema change needed (uses existing `AppSettings` table).

### Indexer behavior
- During an indexing pass, after reading consent flags, read the excluded-folder set.
- If non-empty, build a `Set<String>` of asset IDs contained in those folders by paging each excluded folder via the existing `folderAssets` API. Cache this set for the pass.
- In `_indexOne`, if the asset is in the excluded set:
  - Skip the ML worker call entirely.
  - Still call `IndexDao.upsertIndexed(... labels: [], text: '')` so the asset is stamped `indexed_at` and does not keep re-appearing as pending.
  - Do not insert faces for it (`insertFaces` is only called after a worker result).
  - Existing labels/text for that asset are already deleted by `upsertIndexed`'s per-asset replacement.
- Existing face embeddings for a newly excluded asset are handled by resetting all derived data when the setting changes (see below).

### Applying a setting change
- Route through `IndexingService` (same reason consent toggles live there: withdrawing analysis scope must delete derived data).
- `IndexingService.setExcludedFolderIds(Set<String> ids)`:
  1. Persist via `SettingsDao.setExcludedFolderIds`.
  2. Delete all `photo_labels`, `photo_texts`, `face_embeddings`.
  3. Reset `indexed_at = NULL` on all `photo_assets`.
  4. Clear memories and memory baselines so they regenerate with the new scope.
  5. Kick `start()` so the next pass re-analyzes only included folders.
- This is intentionally a full derived-data reset: correctly identifying only the newly excluded/included assets requires the same expensive folder paging, and the setting changes rarely.

---

## Files to touch

| File | Change |
|---|---|
| `lib/core/database/daos/settings_dao.dart` | Add `excluded_folder_ids` helpers |
| `lib/core/router/router_config.dart` (or wherever GoRouter lives) | Add `/settings/analysis` route |
| `lib/features/settings/settings_providers.dart` | Add `excludedFolderIdsProvider`; keep existing consent providers |
| `lib/features/settings/settings_screen.dart` | Remove On-device analysis + Rebuild index; add **Analysis** entry row |
| `lib/features/settings/analysis_settings_screen.dart` | New screen: On-device analysis + Rebuild index + Folders for indexing |
| `lib/features/settings/widgets/folder_picker_sheet.dart` | New sheet: folder list + checkboxes + All folders toggle |
| `lib/services/indexing_service.dart` | Read exclusions, build excluded-asset set, skip ML for excluded assets, apply setting change |
| `lib/services/photo_library_service.dart` | No change needed (uses existing `deviceFolders`/`folderAssets`) |
| `test/core/database/settings_dao_test.dart` | Test excluded-folder serialization |
| `test/services/indexing_service_test.dart` | Test excluded assets are skipped; test setting change resets derived data |
| `test/features/settings/settings_screen_test.dart` | Test main screen shows Analysis row; On-device/Rebuild rows removed |
| `test/features/settings/analysis_settings_screen_test.dart` | New widget test for the sub-screen |
| `test/features/settings/folder_picker_sheet_test.dart` | New widget test for the picker |
| `test/support/fake_photo_library_service.dart` | Add folder-asset paging hook if needed for tests |

---

## Implementation steps

1. **Design review:** invoke `/frontend-design:frontend-design` for the new screen layout, the main Settings Analysis row, and the picker sheet/checkbox styling.
2. **Data layer:** add `SettingsDao` excluded-folder helpers.
3. **Indexer plumbing:**
   - Read excluded IDs at the top of `_run`.
   - If non-empty, build `_excludedAssetIds` once per pass by paging excluded folders.
   - Pass the set into `_indexOne`; skip worker + empty-label `upsertIndexed` for excluded assets.
   - Add `setExcludedFolderIds` with the derived-data reset + re-kick.
4. **Routing:** add `/settings/analysis` to GoRouter.
5. **Settings UI refactor:**
   - Add `AnalysisSettingsScreen` and move `_OnDeviceGroup` + `_IndexGroup` there.
   - Replace them on the main Settings screen with a single `_AnalysisGroup` entry row.
   - Build `FolderPickerSheet` using `AppSheet`, `deviceFoldersProvider`, and checkboxes.
   - Wire sheet result back to `IndexingService.setExcludedFolderIds`.
6. **Tests:** DAO round-trip, indexer skip/reset behavior, main screen row, analysis screen sections, picker sheet interactions.
7. **Verification:** run `tool/check.sh`, then on-device integration tests, then manual end-to-end on Pixel.

---

## Tests

- **Unit/DAO:** `SettingsDao` excluded-folder set round-trips through JSON and defaults to empty.
- **Service:**
  - With `excluded_folder_ids` empty, all assets are analyzed.
  - With one folder excluded, assets in that folder are stamped `indexed_at` but produce no labels/text/faces; assets in other folders are analyzed normally.
  - Calling `setExcludedFolderIds` deletes labels/text/faces, resets `indexed_at`, and re-queues a pass.
- **Widget:**
  - Main Settings screen shows an **Analysis** row and no longer shows On-device analysis / Rebuild index.
  - Tapping the Analysis row pushes the new screen.
  - Analysis screen shows On-device analysis, Rebuild index, and Folders for indexing sections.
  - Folder picker sheet loads folders, toggles checkboxes, and returns the selected exclusion set.

---

## Open questions

- Should excluded folders also hide from Search's folder browse section? (Proposed: no — the picker is about analysis scope, not visibility.)
- Should the main Settings **Analysis** row live in its own group or be folded into the existing **Library** group? (Proposed: its own group, since it is a distinct destination.)

---

## Next step

Confirm assumptions above, then I will start with the `/frontend-design:frontend-design` review and the data-layer changes.
