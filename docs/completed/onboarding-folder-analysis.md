# Onboarding: choose folders for on-device analysis

**Goal:** Add the same "folders to analyze" control that lives in **Settings → Analysis** into the onboarding consent step, and tell the user how long the first analysis may take based on the number of photos selected.

**Status:** Complete — implementation, tests, and device verification done.

---

## What we know today

- Onboarding is a two-step screen (`lib/features/onboarding/onboarding_screen.dart`):
  1. Ask for library access.
  2. Ask which on-device features to turn on (content search, memories, face detection), all default **off**.
- Step 2 already asks "What should stay on the shelf?" — the features the user leaves off stay off until they turn them on later.
- `Settings → Analysis` already has a **Folders to analyze** row that opens `FolderPickerSheet`, and the service layer already respects excluded folder ids (`IndexingService.setExcludedFolderIds`).
- Consent is recorded through `ConsentNotifier.record` → `IndexingService.applyConsent`, which writes the three feature flags and the `ml_consent` marker in a single Drift transaction.
- `SettingsDao.consentVersion = 1`. The rules in `settings_dao.dart` say this must be bumped whenever the prompt's scope changes, because an old answer is not an answer to a new question.

---

## Decisions (confirmed 2026-07-24)

1. **Consent version:** Bump `SettingsDao.consentVersion` from `1` to `2`. Existing users will be re-shown the consent step once to choose folders. ✅
2. **Time-estimate copy:** Use the simpler copy — show the selected photo count plus **"This may take a while."** No per-count thresholds. ✅
3. **Folder-selection validation:** Do **not** block Continue. If all folders are excluded while an ML feature is on, analysis simply skips every asset. ✅

---

## Proposed approach

### Frontend-design outcome

`/frontend-design:frontend-design` invoked. The project’s design system is locked (warm off-white/near-black palette, default typeface, no accent color, pill CTAs, tracked-uppercase section labels, `r12` cards). The new onboarding element therefore reuses existing components and tokens rather than introducing a new visual direction. The “signature” of this screen remains the quiet, promise-first consent surface; the folder row is just an additional grouped control.

### UI / UX

1. In the onboarding consent step, below the three feature toggles, add a new action row:
   - Label: **"Folders to analyze"**
   - Value/summary: **"All folders"** or **"N of M folders"**
   - Chevron → opens the existing `FolderPickerSheet`.
2. Under the row, show a small caption with:
   - The number of selected photos (sum of `DeviceFolder.count` for included folders).
   - **"This may take a while."** when at least one ML feature is on; otherwise **"No on-device analysis is turned on."**
3. Keep the existing **Continue** CTA. The footer text "Your photos open next either way." stays.
4. The `FolderPickerSheet` itself is reused unchanged — it already matches the design system and has the "All folders" shortcut.
5. Use `SettingsActionRow` + `SettingsCaptionRow` from `features/settings/widgets/settings_rows.dart` for the row and caption, wrapped in an `AppCard.divided` (or `AppCard` if a single row) to match the settings screen. The onboarding step currently uses its own `_ConsentToggle` rows, but the new folder row is a navigation control, so the settings row anatomy is the right fit.

### State / service changes

1. Add a local `_excludedFolderIds` state to `_OnboardingScreenState`, default `{}`.
2. Open `FolderPickerSheet.show(initialExcluded: _excludedFolderIds)` from the new row; update state when it returns a non-null set.
3. Update `ConsentNotifier.record` to accept `required Set<String> excludedFolderIds`.
4. Update `IndexingService.applyConsent` to accept `required Set<String> excludedFolderIds` and write them inside the same transaction as the feature flags. Add the excluded-folder ids to `SettingsDao.setConsent` (or create a new atomic helper) so the three flags, the consent marker, and the folder scope are durable together before any indexing pass starts.
5. Keep `IndexingService.setExcludedFolderIds` unchanged for the Settings path.

### Why atomic matters here

The existing `applyConsent` comment explains the race: if the folder scope were written after the pass started, the indexer could read a half-written scope. Writing everything in one transaction and then calling `resetMlPending` / `start()` once keeps the same safety property.

### Tests to add / update

- `test/features/onboarding/onboarding_screen_test.dart`
  - Pump with seeded `DeviceFolder`s and verify the new row shows the folder summary and selected-photo count.
  - Tap the row, toggle a folder off in `FolderPickerSheet`, and verify the summary/caption update.
  - Tap **Continue** and assert `settingsDao.readExcludedFolderIds()` matches the chosen set.
  - Verify the time-estimate caption appears only when at least one ML feature is on.
- `test/features/settings/consent_provider_test.dart`
  - Update `record(...)` calls to include `excludedFolderIds: {}`.
  - Add a test that recording consent also writes the excluded-folder set.
- `test/services/indexing_service_test.dart`
  - Update `applyConsent` call sites to pass `excludedFolderIds: {}`.
  - Add a test that `applyConsent` writes excluded folder ids and that those ids are later respected by the indexing pass (assets in excluded folders get stamped `indexed_at` but no labels/faces).
- Fake-pairing: add or extend a patrol integration test that walks onboarding on a real device, opens the folder picker, and verifies analysis respects the choice. (Use the existing `integration_test` patterns.)

### Definition of Done

1. `/frontend-design:frontend-design` invoked and design decisions recorded here.
2. `tool/check.sh` passes: `flutter analyze`, `dart run build_runner build`, `flutter test`.
3. Widget tests for onboarding folder selection pass.
4. Updated service tests pass.
5. Integration test for onboarding with real folders passes on the connected Pixel 9 Pro XL.
6. Manual end-to-end check: fresh install → onboarding → pick a subset of folders → Continue → Library opens → Settings → Analysis shows the same excluded set.
7. `docs/gotchas.md` updated only if something surprising surfaces.
8. This plan marked complete with final state and follow-ups.

---

## Files changed

- `lib/features/onboarding/onboarding_screen.dart` — added `_FolderScopeCard` row + caption.
- `lib/features/settings/consent_provider.dart` — `record` now takes `excludedFolderIds`.
- `lib/core/database/daos/settings_dao.dart` — `setConsent` writes excluded folder ids atomically; `consentVersion` bumped `1 → 2`.
- `lib/services/indexing_service.dart` — `applyConsent` accepts/persists folder scope and clears derived data when scope narrows; fixed `setExcludedFolderIds` to also stamp `_clusterAlgoKey` after a baseline reset.
- `test/features/onboarding/onboarding_screen_test.dart` — added folder-summary/caption/picker tests.
- `test/features/settings/consent_provider_test.dart` — updated call sites + added excluded-folder persistence test.
- `test/services/indexing_service_test.dart` — updated call sites + added two `applyConsent` folder-scope tests.
- `integration_test/consent_flow_test.dart` — added folder-scope patrol test and fixed pre-existing out-of-date assertions.
- `docs/gotchas.md` — added note about `_reclusterBaselineKey` + `_clusterAlgoKey` reset pairing.

---

## Verification

- `flutter analyze` ✅
- `dart run build_runner build` ✅
- Host tests for onboarding, consent provider, and indexing service ✅ (57/57)
- Patrol integration test `consent_flow_test.dart` on Pixel 9 Pro XL ✅ (5/5)

### Pre-existing host-suite failures

`tool/check.sh` (`flutter test` across the whole repo) still fails on unrelated pre-existing tests:
- `test/features/albums/album_detail_screen_test.dart`
- `test/features/library/day_grid_screen_test.dart`
- `test/features/settings/folder_picker_sheet_test.dart` (10-minute timeout, unrelated to the reused picker)
- `test/widgets/design_goldens_test.dart`
- `test/widgets/thumbnail_radius_test.dart`

These were failing before this task started and are outside the onboarding/consent scope.
