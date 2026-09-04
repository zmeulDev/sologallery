# Remediation plan — findings from the 2026-09-04 audit

**Status:** Phase 1 complete (1.1–1.7). Phase 2 complete (2.1 + 2.2 green on the
physical iPhone; 2.3 done as a host widget test — see its Result). Phase 3
complete: 3.1 done (host tests + one behaviour-preserving base-class fix — see
its Result). 3.2 done — plain `integration_test` not patrol, second face is a
StyleGAN photo not a synthetic draw (see its Result); green on the Samsung
SM-S938B (`RZGYB1E58CV`). 3.3 done — host widget tests for `app_button.dart`
and `settings_rows.dart` (see its Result). **Phase 3 complete.**
4.1 done — `SimpleLru<K, V>` extracted, both caches reimplemented on it, host
tests only, existing cache tests pass unmodified (see its Result). 4.2 done —
`IndexDao`'s repeated query shapes collapsed into three private builders,
634→575 lines, `index_dao_test.dart` green unmodified (see its Result).
**Phase 4 complete.**
5.1 done — Search screen split 621→121 lines into six new
`lib/features/search/widgets/` files, tests unmodified (see its Result).
5.2 done — Library screen split 612→71 lines into eight new
`lib/features/library/widgets/` files, tests unmodified (see its Result).
5.3 done — Onboarding screen split 586→114 lines into six new
`lib/features/onboarding/widgets/` files, tests unmodified, full first-run
walkthrough verified on the Samsung device including both `AccessStep`
branches and the live `ConsentStep`/`FolderScopeCard` update (see its Result).
5.4 done — memory player trimmed 402→274 lines, two new
`lib/features/memories/widgets/` files (title card, progress spine), tests
unmodified (see its Result). **Phase 5 complete.**
6.1 done — `lib/services/thumbnail_pipeline.dart` extracted from
`photo_library_service.dart` (853→726 lines), public API and doc comments on
`PhotoLibraryService` unchanged, `_thumbnailGate.whenQuiet()` yield preserved
verbatim, 827/827 host tests unmodified, `thumbnail_gate_test.dart` 5/5 green
on the real Samsung device (see its Result — also records a pre-existing,
unrelated `cache_live_update_test.dart` failure on Samsung, confirmed via A/B
against unmodified `main`, and two new `docs/gotchas.md` entries from this
task's device work).
6.2 done — `lib/services/indexing_consent.dart` extracted
(`IndexingService` 1027→909 lines), the single-transaction consent write
moved intact and unreordered, five shared `app_settings` key constants
promoted to one shared definition, 39/39 host tests unmodified, both
`consent_test.dart` (4/4, real ML worker) and `consent_flow_test.dart` (5/5,
real onboarding UI, patrol) green on the Samsung device (see its Result).
**Next step:** Phase 6 — Task 6.3, extract the indexing service's post-pass
triggers (`_clusterNewFaces`, `_maybeGlobalRecluster`,
`_maybeRegenerateMemories`) from `lib/services/indexing_service.dart` (909
lines after 6.2) into a collaborator, keeping the `Isolate.run` offloading
exactly as-is.

**Test device for Phase 2+ (2026-09-04):** a **physical iPhone 17 Pro Max**
(`-d 00008150-0016388A1A43401C`, iOS 26.6.1), run as a plain `integration_test`
via `flutter test integration_test/<file>.dart -d <id> --no-uninstall` (not
patrol — see below). The **iPhone 17 simulator can't run any `integration_test/`
file on this Apple Silicon Mac**: `google_mlkit_image_labeling`'s iOS frameworks
have no arm64-simulator slice, so Flutter sets
`EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64` in `ios/Flutter/Generated.xcconfig`
and the arm64 sim has no buildable architecture. Phase 1 was unaffected (host
tests only).

**Why not patrol on iOS (2026-09-04):** patrol-on-iOS was never wired here
(`gotchas.md` documents only the Android side). Getting there needs: a
`RunnerUITests` UI-test target, patrol as an SPM package on that target (the
project has SPM enabled, so patrol attaches only to `Runner`), and patrol_cli
`--release` on a physical device (4.6.1 restriction; 4.7.0 needs `patrol` ≥4.9.0
— a two-minor bump across the 17 existing patrol tests). Abandoned after four
successive blockers; the ML smoke test runs fine as a plain `integration_test`.
One artifact kept: `DEVELOPMENT_TEAM = 8K2SU5BZ2Z` on the `RunnerTests`
Debug/Release configs in `project.pbxproj` (matches its existing Profile config;
lets `RunnerTests` sign for a device). Note Xcode 26 rewrites `objectVersion`
60→54 in `project.pbxproj` on every `xcodebuild` — restore to 60 before
committing.

**iOS fixture seeding (no repo path existed — all docs were Android `adb`):**
push fixtures into the app data container with
`xcrun devicectl device copy to --device <udid> --domain-type appDataContainer
--domain-identifier com.zmeul.sologallery --source test_assets/<f> --destination
Documents`, then `fixtureFile()` resolves them. The container survives a
`flutter test` reinstall but **not** `flutter install` (it uninstalls first);
the photo-permission (TCC) grant survives both. A **debug** Flutter build cannot
be launched from the home screen on a physical device (crashes in
`VSyncClient`) — grant permissions from a `flutter run --release` / release
build.

Written to be executed by a Sonnet-class agent, one task at a time. Every task is
self-contained: it names the exact files, the exact change, and the command that
proves it worked.

## How to use this document

1. Read [AGENTS.md](../../AGENTS.md) first — absolute rules, conventions,
   Definition of Done.
2. Pick the **first unchecked task**. Do not batch tasks or reorder phases:
   phases 1–3 add safety that phase 4 depends on.
3. Do the task. Run its verification command. Paste the result into the task's
   **Result** line.
4. Tick the checkbox, update **Next step** at the top, and commit.
5. If a task turns out to be wrong or impossible, do not silently skip it —
   write why under **Result** and move on.

**Scope rule.** These are cleanups and coverage additions. No task here may
change user-visible behaviour. If a change would, stop and ask.

**Out of scope: the committed signing material.** `android/key.properties`
(plaintext passwords) and `android/app/upload-keystore.jks` are tracked in git
and pushed to the remote. This is recorded as a known issue in
[PRD.md](../../PRD.md#known-gaps) and is being handled outside this backlog. Do
not attempt to rotate keys, rewrite git history, or touch those files as part of
any task below. Do, however, avoid adding new secrets — `.gitignore` currently
contains only `.DS_Store` and protects nothing.

---

## Phase 1 — Correctness and hygiene

Small, independent, no structural risk. Each is a few minutes.

### 1.1 Fix the spacing-token-as-radius misuse

- [x] **File:** `lib/features/onboarding/onboarding_screen.dart:521`
- **Change:** the brand mark's `BoxDecoration` uses
  `BorderRadius.circular(AppSpace.s12)` — a *spacing* token in a *radius* slot.
  The value is numerically identical, so this is not a visual change. Replace it
  with `AppRadius.br12`. Add the `app_radius.dart` import if it is not already
  there.
- **Verify:** `flutter analyze` clean, and
  `grep -rn "AppSpace\.s[0-9]*)" lib/ | grep -i radius` returns nothing.
- **Result:** Done. `_BrandMark`'s `BoxDecoration.borderRadius` now uses
  `AppRadius.br12` (the doc comment there already said "at r12"); added the
  `app_radius.dart` import. `r12 == s12 == 12`, so no visual change.
  `flutter analyze lib/features/onboarding/onboarding_screen.dart` clean; the
  grep returns nothing; `flutter test test/features/onboarding/` → 13/13 pass
  (brand-mark goldens included).

### 1.2 Replace the bare Material colour over media

- [x] **File:** `lib/features/memories/memory_player_screen.dart:336`
- **Change:** the title-card subtitle uses `Colors.white60`. Every other glyph in
  this file uses an `AppOverMedia` token. Replace it with `AppOverMedia.glyphSoft`
  if that matches the rendered opacity closely enough; if it does not, add a
  named const to `AppOverMedia` in `lib/core/theme/app_colors.dart` rather than
  keeping the bare colour.
- **Verify:** `grep -rn "Colors\.white" lib/features/ lib/widgets/` returns
  nothing, and the memory-player golden (if one covers this) still passes:
  `flutter test test/features/memories/`.
- **Result:** Done. Used the existing `AppOverMedia.glyphFaint` (white54) rather
  than `glyphSoft` (white70) or a new const: white54 is the closest existing
  token to white60 (Δalpha ~6 vs ~25), and "faint" fits a tertiary photo-count
  caption better than "soft" (the subtitle above it is `glyphSoft`). No new
  token needed. `grep -rn "Colors\.white" lib/features/ lib/widgets/` returns
  nothing; analyze clean; `flutter test test/features/memories/` → 45/45 pass.

### 1.3 Resolve the orphaned radius token

- [x] **File:** `lib/core/theme/app_radius.dart:12`
- **Change:** `r8` and `br8` are defined with **zero call sites** anywhere in
  `lib/`, and neither appears in the design system's radius table. Delete both —
  an unused token is dead code, and the scale is documented as
  `r2 r4 r12 r20 r30`. If deletion breaks a test, that test is the only consumer
  and should be updated to a real token.
- **Verify:** `grep -rn "r8\b\|br8\b" lib/ test/` returns nothing;
  `tool/check.sh` passes.
- **Result:** Done. Deleted `r8` and `br8` (and `r8`'s doc comment) — no call
  sites anywhere in `lib/`, `test/`, or `integration_test/`. No tests referenced
  them, so none needed updating. Also updated `docs/design-system.md`: the
  Radius section's token list still named `r8`/`br8` and carried a blockquote
  note flagging them as uncalled — removed both; the radius table there already
  omitted r8. `grep -rn "r8\b\|br8\b" lib/ test/` returns nothing;
  `tool/check.sh` → all checks passed (779 tests).

### 1.4 Mark the editor scaffolding explicitly

- [x] **Files:** `lib/core/database/daos/edit_instructions_dao.dart`,
  `lib/core/database/app_database.dart`
- **Change:** `EditInstructionsDao` is registered in `@DriftDatabase(daos: [...])`
  but has no provider in `database_provider.dart` and no callers in `lib/`. It is
  intentional scaffolding for the planned editor, but nothing in the code says
  so, which reads as a violation of the no-dead-code rule. Add a doc comment at
  the top of the DAO stating that it is scaffolding for the non-destructive
  editor, that it is knowingly uncalled, and pointing at
  `PRD.md#planned-non-destructive-editor`. **Do not delete it** — the table is
  schema v1 and the feature is planned.
- **Verify:** the comment exists; `tool/check.sh` passes.
- **Result:** Done. Added a "Knowingly uncalled" paragraph to
  `EditInstructionsDao`'s class doc comment — states it is editor scaffolding,
  the sanctioned exception to the no-dead-code rule, has no provider/caller by
  design, must not be deleted, and links `PRD.md#planned-non-destructive-editor`.
  Also added a two-line marker comment at its `@DriftDatabase(daos: [...])`
  registration pointing back to that doc comment. **Not deleted.**
  `tool/check.sh` → all checks passed.

### 1.5 Fix the stale provider doc comment

- [x] **File:** `lib/features/folders/folders_providers.dart:8`
- **Change:** the doc comment says device folders are "the Search screen's idle
  Folders section". `FolderList` is actually rendered from
  `lib/features/albums/albums_screen.dart`, and `search_screen.dart` documents
  the same thing. Correct the comment to say Albums.
- **Verify:** read the comment back; no code change, so `tool/check.sh` suffices.
- **Result:** Done. `FolderList` renders from `albums_screen.dart:191`;
  `search_screen.dart` no longer has a Folders section at all. Grepping turned
  up the same stale "Search screen's Folders section" phrasing in three more
  live files, so fixed all four (same defect, fixing one in isolation would
  leave contradictory comments): `folders_providers.dart:8`,
  `folder_detail_screen.dart:9`, and `photo_library_service.dart:51` & `:398`.
  Archived docs left as historical record. `tool/check.sh` → all checks passed.

### 1.6 Remove committed golden-failure artifacts

- [x] **Files:** `test/widgets/failures/*.png`
- **Change:** these are alchemist failure-comparison outputs (`isolatedDiff`,
  `maskedDiff`, `masterImage`, `testImage` for album_card, month_header,
  recently_viewed_row, year_header) left in the tree by a past failing run.
  `git rm -r test/widgets/failures/`, then add `failures/` to `.gitignore` so it
  cannot happen again. While editing `.gitignore`, note that it currently
  contains only `.DS_Store` — add the standard Flutter/Dart entries
  (`build/`, `.dart_tool/`, `*.iml`, `.flutter-plugins-dependencies`) if they are
  genuinely absent, but **do not** touch anything related to signing material
  (out of scope, see above).
- **Verify:** `git status --porcelain test/widgets/failures/` is empty and
  `git check-ignore -v test/widgets/failures` matches a rule.
- **Result:** Done. `git rm -r test/widgets/failures/` (10 alchemist diff PNGs);
  added `failures/` to `.gitignore` under a comment. `git check-ignore -v` →
  `.gitignore:48:failures/`. No test or tool references the path.
  The standard Flutter/Dart entries (`/build/`, `.dart_tool/`, `*.iml`,
  `.flutter-plugins-dependencies`, `/coverage/`, …) were **already present** —
  the "only `.DS_Store`" claim in AGENTS.md line 233 and in this plan's
  out-of-scope note is stale. `.gitignore` still does **not** ignore the signing
  material (out of scope; left untouched). Left the AGENTS.md correction for the
  user to make. `flutter test test/widgets/` → 106/106 pass.

### 1.7 Fix the time-bomb test in the Library providers

- [x] **File:** `test/features/library/library_providers_test.dart:125-140`
- **Problem:** the test `this week groups dated assets into day counts, newest
  first` seeds **hardcoded** dates (`2026-08-28`, `2026-08-27`) and asserts they
  both fall inside `thisWeekDayCountsProvider`, which is a **rolling last-7-days
  window relative to `DateTime.now()`**. It passed when it was written and has
  been failing since 2026-09-03, when `2026-08-27` aged out of the window. As of
  2026-09-04 it is the only failing test in the suite:

  ```
  Expected: [DateTime:2026-08-28 00:00:00.000, DateTime:2026-08-27 00:00:00.000]
    Actual: [DateTime:2026-08-28 00:00:00.000]
  ```

  A red suite trains everyone to ignore red, so this is worth fixing before
  anything else in this document.
- **Change:** seed the assets **relative to now** rather than at fixed dates —
  e.g. `DateTime.now()` truncated to the day, and that day minus one — so the
  test asserts the same behaviour on any date. Check the rest of the file (and
  `test/features/library/`) for other hardcoded-date assertions against rolling
  windows and fix them the same way. Do **not** change
  `thisWeekDayCountsProvider` itself: the provider is correct and the test is
  wrong.
- **Verify:** `flutter test test/features/library/library_providers_test.dart`
  passes, then `flutter test` — the whole suite must be green.
- **Result:** Done. Rebased the seeded days on `DateTime.now()` — `today` =
  midnight today, `yesterday` = `today - 1 day` — with intra-day spread via
  `+1s`/`+2s` offsets, and asserted against those two `DateTime`s directly.
  `thisWeekDayCountsProvider` was left untouched (it is correct). Swept the rest
  of the file and `test/features/library/`: the only other rolling-window
  provider is `thisWeekDayCountsProvider`; the `isEmpty`-without-access test at
  line 119 asserts the access gate, not dates, so it was left as-is, and
  `day_grid_screen_test.dart` already rebases on the real clock.
  `flutter test test/features/library/library_providers_test.dart` → 9/9 pass.
  `flutter test` → 779/779 pass, suite fully green.

---

## Phase 2 — Close the test-determinism gap

This is the highest-value phase. The project's own test strategy mandates a
deterministic real-isolate ML smoke test including HEIC; it does not exist, and
the test that stands in for it violates the determinism rule.

### 2.1 Make the ML smoke test deterministic

- [x] **File:** `integration_test/ml_indexing_test.dart:32-51`
- **Problem:** the test pulls up to 5 **arbitrary photos off whatever is on the
  connected device**. `ARCHITECTURE.md#deterministic-test-assets` says never to
  do this. Results vary by device, and a device with no faces silently passes a
  test that asserts nothing.
- **Change:** seed `test_assets/` first (the push + media-scanner broadcast in
  ARCHITECTURE.md), then select **only** the seeded assets by filename or by the
  seeded folder, and assert against known expected content:
  - `synthetic_face.jpg` → ≥1 row in `face_embeddings`, with all four box edges
    inside `[0, 1]`.
  - `small_png.png` → ≥1 row in `photo_labels`.
  - If the device has none of the seeded assets, the test must **fail with a
    clear message**, not skip.
- **Verify:**
  `flutter test integration_test/ml_indexing_test.dart -d 00008150-0016388A1A43401C --no-uninstall`
  (device swapped to the physical iPhone; plain `integration_test`, not patrol —
  see the header). Prereq once per fresh install: push the three fixtures with
  `xcrun devicectl device copy to … appDataContainer … --destination Documents`,
  and grant Full Photos access.
- **Result:** Done — `→ All tests passed!` on the iPhone. Rewrote the file: it
  no longer touches the camera roll. **2.1 needs no photo library** — it reads
  `synthetic_face.jpg` and `no_exif.jpg` bytes via `fixtureFile()` and feeds
  them straight to the real `MlWorkerController` (same path as
  `test_fixtures_test.dart`), into an in-memory Drift DB, and asserts: for the
  face fixture, ≥1 `face_embeddings` row with all four box edges in `[0, 1]`,
  `left<right`/`top<bottom`, and a non-zero embedding; content search for the
  written label finds the asset.
  **Deviation from the plan:** `small_png.png` (a 64×64 XOR gradient) produces
  **zero** ML Kit labels ≥ 0.6 — measured on device — so it cannot back a
  "content was derived" assertion. `no_exif.jpg` reliably yields `Pattern`
  (~0.90) / `Tile` (~0.74); the label assertion uses `no_exif.jpg` → contains
  `Pattern`. Missing fixture → `fail()` with the push command (now
  cross-platform).
  **Also fixed** `integration_test/support/fixture_file.dart`:
  `getExternalStorageDirectories()` **throws** `UnsupportedError` on iOS (the
  code assumed it returned null), so `fixtureFile()` — and every test that uses
  it — was broken on iOS. Now guarded; the iOS fixture is resolved from
  `getApplicationDocumentsDirectory()`.

### 2.2 Add the mandated HEIC regression assertion

- [x] **File:** `integration_test/ml_indexing_test.dart` (same test, new case)
- **Problem:** `test_assets/large_48mp.heic` exists, is generated by
  `tool/gen_test_assets.dart`, is documented in `test_assets/README.md` — and is
  referenced by **no test**. It was created for a real production OOM bug. The
  fake-pairing rule exists because that exact bug was invisible to `flutter test`.
- **Change:** add a case that indexes the seeded `large_48mp.heic` end to end
  through the real worker isolate and asserts it completes without an OOM and
  stamps `indexedAt`. This is the regression guard for feeding ML a downsized
  thumbnail rather than the original.
- **Verify:** same command as 2.1; the run must not crash and the new case must
  pass.
- **Result:** Done — folded into the one test in 2.1's file (`→ All tests
  passed!` on the iPhone). `_seedOrReuseHeic` copies `large_48mp.heic` into the
  photo library via `PhotoManager.editor.saveImageWithPath`, **reusing** a copy
  from an earlier run (matched by its unique 8000×6000 dimensions) so runs don't
  pile up HEICs. It is **not deleted** — `deleteWithIds` raises an OS
  confirmation a plain `integration_test` can't tap (same reason
  `cache_live_update_test.dart` is a patrol test); remove the `sg_ml_heic` asset
  by hand when the backlog is done. Asserts: `assetIndexMeta` resolves at
  ≥7000×5000; the `indexing: true` thumbnail decodes to strictly-smaller-than-
  source dimensions and < 2048 px per edge (proves ML gets a downsized image,
  not the 8000×6000 original — the OOM path); the real worker completes;
  `photo_assets.indexedAt` is stamped. (`thumb.lengthInBytes` was tried as the
  guard first — iOS returns ~625 KB for the 512 request, well under the ~3 MB
  original but not a stable threshold, so the check is on decoded dimensions
  instead.)

### 2.3 Use the EXIF fixtures

- [x] **Files:** `test_assets/gps_exif.jpg`, `test_assets/no_exif.jpg`; new or
  existing test under `test/features/detail/`
- **Problem:** both fixtures are generated and documented but referenced by no
  test, so EXIF rendering has no coverage for its two interesting cases.
- **Change:** add host-side unit coverage for
  `lib/features/detail/domain/asset_detail_display.dart` over both shapes — a
  full EXIF record (GPS present) and an empty one — asserting the formatted
  output and that the no-EXIF case degrades to a sensible display rather than
  throwing or showing blanks. This is pure-Dart domain logic, so it needs no
  device.
- **Verify:** `flutter test test/features/detail/`
- **Result:** Done, but **not as written** — the task's premise doesn't hold.
  `asset_detail_display.dart` contains **no EXIF parsing**; it is pure primitive
  formatting (`int`, `DateTime`, nullable `double` lat/lng, mime string) and is
  **already fully unit-tested** by `test/features/detail/domain/
  asset_detail_display_test.dart` — every function, both the GPS-present and
  GPS-absent branch of `formatCoordinates`. The app only ever reads a JPEG's
  EXIF through `photo_manager` on a device (`entity.latlngAsync()`,
  `entity.mimeTypeAsync` in `photo_library_service.dart`); there is **no
  host-side EXIF reader anywhere in `lib/`**, so the `.jpg` fixtures cannot feed
  a host test of this file (decoding them with `package:image` would test
  DMS→decimal logic that doesn't exist in the app — a fake path, the exact thing
  Phase 2 removes).

  The genuinely untested surface is `_Chips` in
  `lib/features/detail/widgets/exif_sheet.dart` — which chips render for which
  `AssetDetail` shape. Added **`test/features/detail/widgets/exif_sheet_test.dart`**
  (widget test, host, no device — deviation from the task's "pure Dart domain"
  wording, approved) covering the two shapes the fixtures carry:
  - **full record + GPS** (tagged at `gps_exif.jpg`'s Zurich coords) → all seven
    chips render with formatted values (Taken / Dimensions / Resolution / Size /
    Type / Location).
  - **empty record** (every optional field null, like `no_exif.jpg`) → the three
    always-present chips still render, the four optional chips are **absent
    entirely** (not shown blank), no empty-string `Text` leaks in, no exception.
  - **null projection** → the "Details aren't available for this photo." note,
    not a broken sheet.

  Pre-existing coverage of the same behaviour left in place: `detail_screen_test.dart`
  (LOCATION chip shown with GPS / absent without; formatted fields) and
  `detail_goldens_test.dart` (populated `ExifSheet` golden). The `.jpg` EXIF
  fixtures remain unconsumed by any test — closing that needs an on-device
  integration test through `photo_manager` (out of scope for a Phase 2 host
  task; noted here for a future backlog).

  **Verify:** `flutter test test/features/detail/` → 77/77 pass (3 new).
  `flutter analyze test/features/detail/widgets/exif_sheet_test.dart` → clean.

---

## Phase 3 — Coverage before refactoring

Phase 5 restructures the two largest and most dangerous files in the app. Add
these tests **first** so that work has a safety net.

### 3.1 Unit-test the two pagination bases

- [x] **Files:** new `test/services/paged_assets_notifier_test.dart`,
  `test/services/watched_assets_notifier_test.dart`
- **Problem:** both base classes are covered only indirectly through subclasses.
  They own the pagination contract for every grid in the app.
- **Change:** test each base directly via a minimal test subclass and a
  `ProviderContainer`: initial load, `loadMore` appending, end-of-data (no
  further growth), error propagation into `AsyncValue.error`, and disposal
  mid-flight not emitting after dispose. For `WatchedAssetsNotifier`, also cover
  that a re-emission from the underlying stream replaces the window rather than
  appending to it.
- **Verify:** `flutter test test/services/`
- **Result:** Done. Two new files, each driving the base directly via a minimal
  test subclass and a `ProviderContainer`:
  - `paged_assets_notifier_test.dart` (7 tests): first-page load; `hasMore` true
    on a full page / false on a short one; `loadMore` appends newest-first;
    `loadMore` no-op once exhausted (asserts no further `fetchPage`); concurrent
    `loadMore` calls coalesce to one fetch (the `_loadingMore` guard); a fetch
    error surfaces as `AsyncValue.error`; disposal mid-fetch neither emits nor
    throws.
  - `watched_assets_notifier_test.dart` (7 tests): build subscribes to a
    page-sized window and completes on first emission; `loadMore` grows the
    window by a page and re-subscribes; a short window ends pagination (no
    re-subscribe); **a stream re-emission replaces the window rather than
    appending**; error on first emission → `AsyncValue.error`; a later stream
    error → `AsyncValue.error`; disposal cancels the subscription (no post-dispose
    emission).

  **One behaviour-preserving fix, approved mid-task (scope-rule check).** The
  disposal test caught a real defect: `PagedAssetsNotifier.loadMore` writes
  `state` after its `await fetchPage(...)` with no `ref.mounted` check. It is
  fired fire-and-forget from `AssetGrid`'s scroll callback against an
  **autoDispose** provider (Search results, folder detail), so popping the
  screen mid-fetch threw an unhandled `UnmountedRefException`. Added
  `if (!ref.mounted) return;` after the await — a no-op for every live grid,
  matches how `WatchedAssetsNotifier` already handles it (`ref.onDispose` cancels
  its sub). Recorded in `docs/gotchas.md` under Riverpod.

  **Verify:** `flutter test test/services/` → 106/106 pass (14 new).
  `tool/check.sh` → All checks passed (796 tests), `flutter analyze` clean.

### 3.2 Add a People integration test

- [x] **File:** new `integration_test/people_test.dart`
- **Problem:** People is the only feature with **no** on-device test. It is also
  the feature with the most intricate invariant — a user merge must survive the
  periodic global re-cluster, because the merge is stored as a redirect rather
  than a move. Nothing currently proves that on a device.
- **Change:** with the seeded assets and faces consent enabled, drive: index →
  People screen shows ≥1 person → open person detail → rename → merge two
  clusters → assert the merge holds after `_maybeGlobalRecluster` runs (force it,
  or assert via `FacesDao` that the redirect chain resolves). Follow the doc-comment
  convention of the other `integration_test/` files and name the fake it
  counterparts (`FakeMlWorker`).
- **Verify:**
  `PATH="$HOME/Library/Android/sdk/platform-tools:$PATH" ~/.pub-cache/bin/patrol test -t integration_test/people_test.dart -d 46121FDAS008AA`
- **Result:** Done — `→ All tests passed!` on the connected Samsung SM-S938B
  (`RZGYB1E58CV`, Android 16). Prereq: `adb push test_assets/synthetic_face.jpg
  test_assets/photo_face.jpg /sdcard/Android/data/com.zmeul.sologallery/files/`.

  **Deviation — plain `integration_test`, not patrol (approved).** Patrol buys
  nothing here: there is no native dialog to drive, and driving the real
  `PeopleScreen` would need a `databaseProvider` override (no existing patrol
  test does one) plus a real photo-library sweep that would pull camera-roll
  faces into the cluster and break determinism. The test spawns the **real**
  `MlWorkerController`, embeds the two fixture faces, then runs
  `clusterAll` → `planClusters` → `rebuildClusters` (verbatim what
  `_maybeGlobalRecluster` runs) against an in-memory Drift DB — no photo
  library, no camera roll. Run with
  `flutter test integration_test/people_test.dart -d <id> --no-uninstall`.

  Asserts: real embeddings of the two fixtures are < `clusterMergeThreshold`
  (0.45) apart; they cluster into **two** persons; rename one; `mergePersons`
  folds them to one (name + `faceCount 2` preserved); a second global re-cluster
  keeps it one person, `assetsForPerson(survivor)` still owns both assets,
  `assetsForPerson(absorbed)` is empty, and `absorbed.mergedInto == survivor` —
  the redirect chain still resolves. This is the on-device real-embedder
  counterpart to the `FakeMlWorker` host tests
  `faces_dao_test.dart` ("a global re-cluster does not undo the merge") and
  `indexing_service_test.dart` ("…preserving the rename").

  **Deviation — the second face is a photo, not a second `_syntheticFace()`
  (approved).** Two *drawn* synthetic faces never embedded more than ~0.57
  apart against the real MobileFaceNet (tried colour, aggressive geometry,
  in-plane tilt across ~8 device runs); the occluders that moved them further
  (beard, sunglasses) stopped ML Kit detecting a face at all. `photo_face.jpg`
  is a StyleGAN (thispersondoesnotexist) face — no real person, EXIF stripped,
  640×640, 132 KB. The prior session's uncommitted
  `tool/gen_test_assets.dart` work (a `_FaceSpec` split to generate a second
  synthetic face) was reverted; the generator is back to HEAD. Recorded in
  `docs/gotchas.md` (Indexing / ML / faces) and `test_assets/README.md`.

### 3.3 Fill the widget-test gaps

- [x] **Files:** new tests under `test/widgets/` and `test/features/settings/`
- **Change:** add behavioural widget tests (not just goldens) for
  `lib/widgets/app_button.dart` (all three voices, `compact`, leading icon, tap
  and disabled) and `lib/features/settings/widgets/settings_rows.dart` (all five
  row primitives, which are used by three screens and have no direct test).
- **Verify:** `flutter test test/widgets/ test/features/settings/`
- **Result:** Done. Two new host widget-test files, no device needed.
  - **`test/widgets/app_button_test.dart`** (14 tests). `.primary`: tap fires the
    callback; `onPressed: null` leaves `InkWell.onTap` null (disabled); `busy`
    replaces the label with a `CircularProgressIndicator`; `compact` → outer
    height 40, default → 52; `expand: true` stretches to the parent width (300);
    a leading `icon` renders. `.secondary`: tap fires; null disables; leading
    icon renders; height 40. `.quiet`: tap fires; null disables; the trailing
    `chevron_right_rounded` shows only with `chevron: true`.
  - **`test/features/settings/settings_rows_test.dart`** (10 tests, all five
    primitives). `SettingsGroup` uppercases the label and renders its child.
    `SettingsInfoRow` shows the trailing value when set, and renders exactly one
    `Text` (no blank) when `value` is null. `SettingsCaptionRow` renders its
    text. `SettingsSwitchRow` renders label + caption, reports the negated value
    on tap, and passes the row label to `ConsentSwitch.semanticLabel`.
    `SettingsActionRow` fires `onTap`, shows a caption only when given one, and
    always carries the trailing chevron.
  - `flutter test test/widgets/ test/features/settings/` → 154/154 pass (24
    new). `flutter analyze` on both files clean. `tool/check.sh` → all checks
    passed (820 tests, up from 796). No `lib/` changes — no user-visible
    behaviour touched.

---

## Phase 4 — Deduplication

Mechanical, behaviour-preserving. Do these before the screen and service splits:
they shrink the files those phases touch.

### 4.1 Extract one generic LRU

- [x] **Files:** `lib/services/adjacent_thumbnail_cache.dart`,
  `lib/services/detail_preview_cache.dart`, new `lib/services/simple_lru.dart`
- **Problem:** two structurally identical `LinkedHashMap` LRUs
  (get / put / move-to-MRU / evict-oldest), differing only in key shape and
  capacity — ~35 duplicated lines and two eviction policies to keep in sync.
- **Change:** add a pure-Dart `SimpleLru<K, V>` with an injected capacity, and
  reimplement both caches on top of it. Keep both public class names and their
  APIs exactly as they are — `PhotoLibraryService` and the lifecycle clear-on-background
  path in `app.dart` must not change. `SimpleLru` has no Flutter or plugin
  imports, so it is domain-shaped and host-testable.
- **Verify:** `flutter test test/services/adjacent_thumbnail_cache_test.dart test/services/detail_preview_cache_test.dart`
  passes **unmodified**. Add `test/services/simple_lru_test.dart` for the generic.
- **Result:** Done. Added `lib/services/simple_lru.dart` —
  `SimpleLru<K, V>(capacity)` with `get` / `put` / `clear` / `length` /
  `contains`, same move-to-MRU-on-touch + evict-oldest-at-capacity policy as
  both originals, no Flutter/plugin imports. Both caches now hold a
  `SimpleLru<String, Uint8List?>` field and forward every method to it
  one-line each; `DetailPreviewCache` still builds its own composite
  `'$assetId:$maxEdge'` key before delegating. Public class names, method
  signatures, doc comments and the `_capacity` constants (16 / 20) are
  unchanged; `PhotoLibraryService` and `app.dart`'s lifecycle
  clear-on-background calls needed no edits.
  `flutter test test/services/adjacent_thumbnail_cache_test.dart
  test/services/detail_preview_cache_test.dart` → both files' original tests
  pass **unmodified** (16 tests total). Added
  `test/services/simple_lru_test.dart` (7 tests: string/int keys, nullable-`V`
  cached-null vs. miss, LRU eviction, re-put refreshing recency without
  growing, clear). `tool/check.sh` → all checks passed (827 tests, up from
  820).

### 4.2 Collapse the repeated IndexDao query shapes

- [x] **File:** `lib/core/database/daos/index_dao.dart` (634 lines)
- **Problem:** the four Library grouping axes (month / year / day / older) each
  have count, previews, paged and watched variants — roughly five near-identical
  query shapes repeated four times.
- **Change:** introduce private query builders taking the `WHERE` fragment and a
  limit, and express the sixteen public methods over them. **Public method
  signatures and returned types must not change** — every caller and every
  existing test stays as-is. Take the existing SQL literally; do not "improve" a
  predicate along the way.
- **Verify:** `flutter test test/core/database/index_dao_test.dart` passes
  **unmodified**, and `tool/check.sh` is clean. Report the before/after line
  count.
- **Result:** Done. Three private query builders added, all taking a
  precomputed `Expression<bool> where` fragment (plus, for counts, the
  STRFTIME bucket format and a row mapper) so the SQL each public method runs
  is byte-for-byte the same as before:
  - `_groupedCounts<T>(strftimeFormat, where, mapRow)` — the grouped-count
    shape behind `watchMonthCounts`, `watchYearCounts`, `watchDayCounts`.
  - `_previewIds(where, limit)` — the preview-strip shape behind
    `watchMonthPreviews`, `watchYearPreviews`, `watchDayPreviews`,
    `watchOlderPreviews`.
  - `_watchGrowingWindow(where, limit)` — the reactive growing-window shape
    behind `watchMonthAssets`, `watchYearAssets`, `watchDayAssets`,
    `watchOlderAssets`, `watchRecentSince`.

  Also added `_datedInYear`/`_datedInDay` alongside the pre-existing
  `_datedInMonth`, and pointed `monthAssets`/`watchMonthAssets` at
  `_datedInMonth` too (they previously duplicated its expression inline —
  same SQL, now shared). `watchOlderCount` (a plain scalar count, not
  grouped) and `monthAssets`'s `Future`+offset shape are each used once, so
  neither was forced into a shared builder. No predicate was "improved" —
  every `WHERE`/`ORDER BY`/`LIMIT`/`GROUP BY` fragment is copied verbatim
  from its original call site.

  634 → 575 lines (-59).
  `flutter test test/core/database/index_dao_test.dart` → 53/53 pass,
  **unmodified**. `tool/check.sh` → all checks passed (827 tests),
  `flutter analyze` clean.

---

## Phase 5 — Split oversized files

Eight files exceed 400 lines. Large files are slower and less reliable to edit,
for a person or an agent.

**Rules for every task in this phase:**
- Extraction only. **No logic changes, no renames of public symbols, no
  behaviour changes.**
- Extracted widgets that were file-private (`_Foo`) stay private to the feature —
  move them into the feature's `widgets/` folder, not `lib/widgets/`, which is
  reserved for shared design-system components.
- **Preserve every doc comment.** These files carry unusually good explanations of
  *why*; that reasoning is the most valuable thing in them. Move comments with the
  code they explain.
- Existing tests must pass unmodified. If a test needs changing, the extraction
  changed behaviour — revert and rethink.

### 5.1 Split the Search screen

- [x] **File:** `lib/features/search/search_screen.dart` (621 lines)
- **Change:** extract into `lib/features/search/widgets/`: the search field, the
  facet/filter bar, the browsable label chips, the idle body, the results body,
  and the album/label match rows. `search_screen.dart` keeps the scaffold and the
  idle-vs-results branch.
- **Verify:** `flutter test test/features/search/`; report the new line count of
  `search_screen.dart` (target: under 200).
- **Result:** Done. Six new files under `lib/features/search/widgets/`, each
  keeping the moved doc comments verbatim:
  - `search_field.dart` — `SearchField` (from `_SearchField`).
  - `filter_bar.dart` — `FilterBar` (from `_FilterBar`).
  - `browse_labels.dart` — `BrowseLabels` (from `_BrowseLabels`).
  - `idle_body.dart` — `IdleBody` (from `_IdleBody`), plus its file-private
    helpers `_SearchSubtitle`, `_RecentlyViewedStrip`, `_IdleHint`.
  - `results_body.dart` — `ResultsBody` (from `_ResultsBody`), plus
    file-private `_Results` and `_ResultCount`.
  - `albums_result.dart` — `AlbumsResult` (from `_AlbumsResult`, the
    album-match rows), plus file-private `_AlbumTile`.

  Formerly file-private classes had to become public (no leading `_`) to cross
  a file boundary — Dart privacy is per-library, not per-class — but each stays
  feature-scoped under `search/widgets/`, matching the existing
  `RecentlyViewedRow` precedent. `search_screen.dart` now holds only
  `SearchScreen`/`_SearchScreenState` (the controller, debounce, and the
  idle-vs-results `Scaffold` branch) and imports the six extracted widgets.
  Two transitive imports (`MediaTypeFilter` from `domain/search_date.dart`,
  `searchEnabledProvider` from `../settings/consent_provider.dart`) had to be
  added explicitly to `search_screen.dart`, `filter_bar.dart` and
  `idle_body.dart` — the original file got them for free via
  `search_providers.dart`'s own imports, which don't re-export.

  621 → **121 lines** (target was under 200). No logic changes; every doc
  comment moved with its code.

  `flutter test test/features/search/` → 63/63 pass, **unmodified**.
  `flutter analyze lib/features/search/ test/features/search/` → clean.
  `tool/check.sh` → all checks passed (827 tests, same count as before —
  extraction only, no new tests needed since coverage already exercises the
  extracted pieces through `SearchScreen`).

  **Device check (Samsung SM-S938B, `RZGYB1E58CV`, connected via `adb`):**
  built and installed the debug APK on the physical device and launched it —
  boots clean, no crash, no exception in `adb logcat -s flutter:V
  SoloGallery:V AndroidRuntime:E`. Did not drive through onboarding to the
  Search tab itself: this is a pure structural extraction (no behaviour
  change, scope rule), the widget-test suite already asserts the exact section
  ordering and content of every extracted piece against a mocked
  `ProviderScope`, and driving a fresh-install consent flow blind (no
  screenshots, per project policy) to reach one screen was judged
  disproportionate to what it would additionally prove.

### 5.2 Split the Library screen

- [x] **File:** `lib/features/library/library_screen.dart` (612 lines)
- **Change:** extract the four filter-scoped bodies (`_MonthTimeline`,
  `_ThisWeekList`, `_YearList`, and the day sections) plus the section and
  preview-grid widgets into `lib/features/library/widgets/`. The screen keeps the
  scaffold, the app bar and the filter switch.
- **Verify:** `flutter test test/features/library/`, including
  `library_spacing_test.dart` — the s20 inter-section rhythm is easy to break
  during extraction, and that test is what catches it. Report the new line count.
- **Result:** Done. Eight new files under `lib/features/library/widgets/`, each
  keeping the moved doc comments verbatim:
  - `month_timeline.dart` — `MonthTimeline` (from `_MonthTimeline`), plus
    file-private `_MonthList` and `_MonthSection` (both used only here) and
    `_OlderSection` (the trailing "Older" bucket).
  - `year_list.dart` — `YearList` (from `_YearList`), plus file-private
    `_YearSection`.
  - `this_week_list.dart` — `ThisWeekList` (from `_ThisWeekList`), plus
    file-private `_DaySection`.
  - `library_section.dart` — `LibrarySection` (from `_LibrarySection`, the
    labelled-header-over-preview-grid shape shared by day sections and Older).
  - `preview_grid.dart` — `PreviewGrid` (from `_PreviewGrid`, the six-thumbnail
    tap-to-detail grid).
  - `refreshable_body.dart` — `RefreshableBody` (from `_RefreshableBody`, the
    pull-to-refresh wrapper).
  - `library_bottom_padding.dart` — `libraryBottomPadding` (from the top-level
    `_libraryBottomPadding` function), the nav-capsule-clearing padding shared
    by all three filter bodies.

  Formerly file-private classes and the one top-level helper function had to
  become public (no leading `_`) to cross a file boundary — Dart privacy is
  per-library, not per-class — matching the 5.1 precedent. Each newly-public
  widget picked up a `super.key` constructor param (absent before, since the
  `use_key_in_widget_constructors` lint only fires on public widgets) to keep
  `flutter analyze` at zero issues, also matching 5.1. One doc-comment cross-
  reference in `year_list.dart` (`_YearSection`'s "Like `_LibrarySection`...")
  was updated to the new name `LibrarySection` to stay accurate; no other
  comment text changed. `library_screen.dart` now holds only `LibraryScreen`
  (the scaffold, app bar, and the filter-switch `Expanded`/`KeyedSubtree`) and
  imports the three filter-scoped widgets.

  612 → **71 lines** (target was under 200).  No logic changes; every doc
  comment moved with its code.

  `flutter test test/features/library/` → 83/83 pass, **unmodified**, including
  `library_spacing_test.dart` (the s20 rhythm assertions). `flutter analyze
  lib/features/library/` → clean (zero issues, after adding the `super.key`
  params above — see note). `tool/check.sh` → all checks passed (827 tests,
  same count as before — extraction only, no new tests needed since coverage
  already exercises the extracted pieces through `LibraryScreen`).

  **Device check (Samsung SM-S938B, `RZGYB1E58CV`, connected via `adb`):**
  `flutter install --debug -d RZGYB1E58CV`, then launched via `monkey`. Boots
  clean, foreground activity confirmed
  (`com.zmeul.sologallery/.MainActivity`), no exception in `adb logcat -s
  flutter:V SoloGallery:V AndroidRuntime:E` and no `sologallery`-tagged
  exception/error/fatal anywhere in the full log. As with 5.1, did not drive
  onboarding to the Library tab by hand — pure structural extraction, no
  behaviour change (scope rule), and the widget-test suite already asserts the
  exact section ordering and content of every extracted piece against a mocked
  `ProviderScope`.

### 5.3 Split the Onboarding screen

- [x] **File:** `lib/features/onboarding/onboarding_screen.dart` (586 lines)
- **Change:** this is the only feature with no `widgets/` folder. Create one and
  extract: the brand mark, the assurance rows, the permission step body, the
  consent step body, and the folder-scope card. Keep the `InheritedWidget` that
  fans state to the folder-scope card — it is deliberate, and prop-drilling it
  instead would be a behaviour-adjacent change.
- **Verify:** `flutter test test/features/onboarding/`, then **manually re-run
  first-run onboarding on the device** — this screen gates the entire app and its
  consent write is transactional for a reason. Report the new line count.
- **Result:** Done. Six new files under `lib/features/onboarding/widgets/`,
  each keeping the moved doc comments verbatim:
  - `brand_mark.dart` — `BrandMark` (from `_BrandMark`).
  - `assurance.dart` — `Assurance` (from `_Assurance`).
  - `access_step.dart` — `AccessStep` (from `_buildAccessStep`, a method on
    `_OnboardingScreenState` promoted to a `StatelessWidget`). Computes its own
    `denied` flag from `access`/`attempted` and picks `onRequestAccess` vs.
    `onOpenSettings` internally, so the screen doesn't duplicate that branch.
  - `consent_step.dart` — `ConsentStep` (from `_buildConsentStep`, same
    method-to-widget promotion), plus the file-private `_ConsentToggle` (used
    only here, so it stayed private — no cross-file boundary to justify making
    it public, unlike 5.1/5.2's file-private helpers that had the same
    treatment).
  - `inherited_consent_scope.dart` — `InheritedConsentScope` (from
    `_InheritedConsentScope`) — given its own file rather than folded into
    `consent_step.dart` to avoid a two-file import cycle between it and
    `folder_scope_card.dart` (`ConsentStep` needs `FolderScopeCard`,
    `FolderScopeCard` needs the scope).
  - `folder_scope_card.dart` — `FolderScopeCard` (from `_FolderScopeCard`).

  Formerly file-private classes/methods had to become public to cross a file
  boundary, matching the 5.1/5.2 precedent — each stays feature-scoped under
  `onboarding/widgets/`. Each newly-public `StatelessWidget`/`ConsumerWidget`
  picked up a `super.key` (the `use_key_in_widget_constructors` lint doesn't
  fire on `InheritedWidget`, so `InheritedConsentScope` didn't need one).
  `onboarding_screen.dart` now holds only `_OnboardingScreenState` (the two
  step-2 field groups, `_run`/`_requestAccess`/`_recordConsent`/
  `_openFolderPicker`, and the `KeyedSubtree` access-vs-consent branch), wiring
  the extracted `AccessStep`/`ConsentStep` with plain callbacks — no new
  provider or InheritedWidget was introduced beyond the one being preserved.

  586 → **114 lines** (target was under 200). No logic changes; every doc
  comment moved with its code (the long `_attempted` field comment stayed on
  the field in the screen, since the field itself stays there; `AccessStep`'s
  `attempted` param carries a one-line pointer back to it instead of a
  duplicate).

  `flutter test test/features/onboarding/` → 13/13 pass, **unmodified**.
  `flutter analyze lib/features/onboarding/` → clean. `dart format` run on the
  screen + the six new files (not the directory). `tool/check.sh` → all checks
  passed (827 tests, same count — extraction only).

  **Device check (Samsung SM-S938B, `RZGYB1E58CV`, connected via `adb`) — full
  first-run walkthrough, no screenshots (semantics dumped via
  `uiautomator dump` and read as text instead):** uninstalled the app for a
  clean first run, `flutter install --debug`, launched. Confirmed via
  semantics dump that `AccessStep` renders (brand mark, wordmark, headline, all
  three `Assurance` rows, Continue). Tapped Continue → native
  `GrantPermissionsActivity` came up (confirms `onRequestAccess` fired).
  Dismissed it with back → `AccessStep`'s **denied branch** rendered correctly
  ("Photo access is turned off.", "Open Settings", the Settings-specific
  caption) — exercises the branch the plan's own text singles out. Granted
  `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` via `pm grant` (equivalent to tapping
  Allow; avoided guessing the system dialog's on-screen button coordinates
  blind), force-stopped and relaunched so `PermissionNotifier.refresh()` picked
  up the change. `ConsentStep` rendered: header, all three `_ConsentToggle`
  rows, `FolderScopeCard` via `InheritedConsentScope` showing "All folders · No
  on-device analysis is turned on." Tapped the CONTENT SEARCH switch → caption
  live-updated to "All folders · 85 photos." (the device's real photo count),
  proving the callback → `setState` → `InheritedConsentScope` → `FolderScopeCard`
  chain survived the extraction. Tapped Continue → consent recorded, redirected
  to the Library screen, indexing started ("Analyzing your photos — 80 left").
  No `sologallery`-tagged exception/error/fatal in
  `adb logcat -s flutter:V SoloGallery:V AndroidRuntime:E` or in
  `dumpsys dropbox --print` across the whole run.

### 5.4 Trim the memory player

- [x] **File:** `lib/features/memories/memory_player_screen.dart` (402 lines)
- **Change:** borderline. Extract the title card and the progress-segment row into
  `lib/features/memories/widgets/`. Leave the scene-transition logic and its
  reduced-motion guard in the screen — it is the app's one sanctioned animation
  and splitting it across files would make it easier to break.
- **Verify:** `flutter test test/features/memories/`
- **Result:** Done. Two new files under `lib/features/memories/widgets/`
  (a folder that already existed, holding `memories_carousel.dart` and
  `memory_card.dart`), doc comments moved verbatim:
  - `progress.dart` — `Progress` (from `_Progress`, the story-spine segment
    row).
  - `title_card.dart` — `TitleCard` (from `_TitleCard`, the opening frame).

  Matches the 5.1–5.3 precedent: both were file-private, had to become public
  to cross the file boundary, picked up `super.key`. `TitleCard.memoryId` is
  carried over unused in `build()` exactly as it was on `_TitleCard` (not a
  regression introduced by the move — `unused_field` only flags
  underscore-prefixed fields, so it was silent before too; left as-is, fixing
  it is outside this task's scope). Per the plan, left untouched in the
  screen: `_kSceneChange`/`_kSceneCurve`, `_advance`/`_restartTimer`/
  `_onPageChanged`/`_setHeld` and the `MediaQuery.disableAnimationsOf` guard,
  plus the small `_CloseButton`/`_Stage`/`_Spinner`/`_Message` helpers (none
  named in the task, and each under 20 lines).

  402 → **274 lines**. No logic changes.

  `flutter test test/features/memories/` → 45/45 pass, **unmodified**.
  `flutter analyze lib/features/memories/` → clean. `dart format` run on the
  three touched/new files (not the directory). `tool/check.sh` → all checks
  passed (827 tests, same count — extraction only).

  **Device check (Samsung SM-S938B, `RZGYB1E58CV`):** `flutter install --debug`
  (this cycled a fresh install — the device had no prior debug build with a
  matching signature — so the 5.3 onboarded state was lost), launched. Boots
  clean to onboarding, `topResumedActivity` confirms `MainActivity` foreground,
  no `sologallery`-tagged exception/error/fatal in
  `adb logcat -s flutter:V SoloGallery:V AndroidRuntime:E` or
  `dumpsys dropbox --print`. Did not re-run onboarding to reach an actual
  Memory: unlike 5.3, this task's own Verify line doesn't call for a device
  step, the change is extraction-only behind an unmodified 45-test suite, and
  reaching a real Memory needs consent + a completed indexing pass + specific
  memory-worthy content (a trip, an anniversary, a themed cluster) that isn't
  guaranteed to exist on this device's photo set — disproportionate to what it
  would additionally prove over the widget-test coverage, matching 5.1/5.2's
  same call.

---

## Phase 6 — Split the large services

**Highest risk in this document.** These files own the isolate lifecycle, the
consent race and the plugin boundary. Do not start phase 6 until phases 2 and 3
are complete and green — those tests are the safety net.

Do each task as its own commit. If anything about the isolate protocol or the
consent transaction becomes unclear mid-task, stop and ask rather than guessing.

### 6.1 Compose the photo library service's caches

- [x] **File:** `lib/services/photo_library_service.dart` (853 lines)
- **Change:** the service is correctly the single point of contact with
  `photo_manager` — that stays. What bloats it is that it also *field-owns* four
  caching concerns (disk cache wiring, two gates, two in-memory LRUs). Extract
  the thumbnail-serving path into a collaborator (e.g.
  `lib/services/thumbnail_pipeline.dart`) that owns the gate → disk cache →
  native decode chain, and have `PhotoLibraryService` delegate to it.
- **Constraints:** the public API of `PhotoLibraryService` must not change. The
  `indexing: true` path must keep calling `_thumbnailGate.whenQuiet()` before
  submitting to the indexing gate — that yield is what keeps background indexing
  from stealing decode capacity from a foreground scroll, and it is easy to lose
  in a move.
- **Verify:** `tool/check.sh`, then on device:
  `patrol test -t integration_test/thumbnail_gate_test.dart` and
  `-t integration_test/cache_live_update_test.dart`. Then scroll a large library
  by hand and confirm no jank.
- **Result:** Done. New `lib/services/thumbnail_pipeline.dart` —
  `ThumbnailPipeline` owns everything that isn't entity resolution: the two
  `ThumbnailGate`s (grid vs. indexing), the persistent `ThumbnailDiskCache`, and
  the two in-memory LRUs (`DetailPreviewCache`, `AdjacentThumbnailCache`) plus
  their pending-preview dedupe map. Entity resolution (`_entity`/`_entityCache`)
  stayed in `PhotoLibraryService` — it also backs video/detail/delete, so it is
  injected into the pipeline as a `resolveEntity` callback rather than
  duplicated (built in the constructor **body**, not the initializer list: a
  tear-off of an instance method isn't available yet during initializer-list
  evaluation).

  `PhotoLibraryService`'s six thumbnail-shaped public methods
  (`thumbnail`, `clearThumbnailDiskCache`, `previewImage`, `adjacentThumbnail`,
  `clearAdjacentThumbnailCache`, `clearDetailPreviewCache`) are now one-line
  delegates to `_thumbnailPipeline`, signatures and doc comments unchanged. The
  `indexing: true` path's `await _thumbnailGate.whenQuiet()` before the
  indexing-gate submit moved intact (verbatim, same comment) — confirmed by the
  device test below, which is the one test that would catch a starved grid
  during a burst.

  853 → **726 lines** (`photo_library_service.dart`); `thumbnail_pipeline.dart`
  is 252. `flutter analyze` on both files clean. `tool/check.sh` → all checks
  passed, 827/827 tests, **unmodified** — extraction only, no lib caller besides
  this file touches `_thumbnailGate`/`_indexingGate`/the two LRUs.

  **Device verification (Samsung SM-S938B, `RZGYB1E58CV`):**
  `flutter test integration_test/thumbnail_gate_test.dart -d RZGYB1E58CV` →
  **5/5 pass** against the real `photo_manager` — this is the direct on-device
  proof for the exact path this task moved: a burst past `maxConcurrent`
  resolves every request, cancelled requests don't starve the rest, the gate
  stays usable after a burst, and every avatar-bucket thumbnail decodes at the
  right size. Boot-clean check on a fresh install of the current build: no
  `sologallery`-tagged exception/error/fatal in
  `adb logcat -s flutter:V SoloGallery:V AndroidRuntime:E`, correct foreground
  activity.

  **`cache_live_update_test.dart` (patrol) fails, confirmed pre-existing and
  unrelated to this task.** `patrol test -t integration_test/cache_live_update_test.dart`
  fails at its delete-confirmation tap (`AndroidAutomatorClientException:
  Invalid response: 404 selector UiSelector[TEXT=Allow] found nothing`).
  Verified by `git stash`-ing this task's diff and re-running against
  unmodified `main`: **identical failure**, byte-for-byte the same exception —
  so it is not caused by this extraction. That test touches
  `startLibraryChangeNotify`/`PhotoManager.editor.deleteWithIds`, neither of
  which this task moved. Root cause is very likely that `docs/gotchas.md`'s
  documented delete-confirmation dialog text ("Allow SoloGallery to delete this
  photo?" over Deny/Allow) was verified on the primary Pixel 9 Pro XL and
  Samsung's One UI shows a differently-worded system dialog for the same
  `MediaStore.createDeleteRequest` — not confirmed further (see below), and out
  of this task's scope to fix. Filed as a gap for a future task rather than
  guessed at.

  **Did not reach a hand-scroll of the actual grid.** Reaching Library needs
  walking a *fresh* first-run onboarding (the app was reinstalled during this
  task's device verification, wiping the Drift-backed consent state), which
  needs either reading rendered on-screen text or a blind coordinate tap.
  Flutter only builds its semantics tree when a real bound `AccessibilityService`
  is active (confirmed: plain `adb shell uiautomator dump` returns "null root
  node" with none bound) — the one available on this device is Samsung's
  TalkBack, and enabling it launched TalkBack's own first-run tutorial over the
  app instead of exposing app semantics; aborted immediately and restored the
  device's original accessibility settings (`enabled_accessibility_services` /
  `accessibility_enabled`) rather than push further on the user's personal
  phone. A coordinate-blind tap at the estimated Continue-button position was
  judged not worth the risk of landing on a consent switch or the folder-picker
  sheet instead, for a purely qualitative check. Substituted the on-device
  `thumbnail_gate_test.dart` pass above, which exercises the same gate → cache →
  decode chain a real scroll would (burst concurrency, cancellation, reuse)
  with actual pass/fail assertions rather than an eyeball — matching the
  "disproportionate to what it would additionally prove" call already made for
  the equivalent step in 5.1/5.2/5.4.

  **Incidental fix, not part of the diff:** `flutter install --debug -d <id>`
  reused a stale `build/app/outputs/flutter-apk/app-debug.apk` left over from a
  `patrol test` build (same output path, different entrypoint —
  `test_bundle.dart` vs `lib/main.dart`), so the installed APK tried to launch
  the patrol harness instead of the app. Rebuilding explicitly with
  `flutter build apk --debug -t lib/main.dart` before `adb install -r` fixed
  it — worth remembering for the rest of Phase 6's device checks.

### 6.2 Extract the indexing service's consent handling

- [x] **File:** `lib/services/indexing_service.dart` (1027 lines)
- **Change:** move the consent-toggle side effects (`applyConsent` and friends,
  around lines 270–339) into a dedicated collaborator. **Read the long comment
  there before moving anything** — the single-transaction write exists to close a
  first-run race where the indexer reads flags mid-write and permanently skips a
  capability. The transaction boundary must survive the move intact.
- **Verify:** `flutter test test/services/indexing_service_test.dart`, then on
  device `patrol test -t integration_test/consent_test.dart` and
  `-t integration_test/consent_flow_test.dart`. Then **manually verify a fresh
  install**: install clean, toggle each consent combination at onboarding, and
  confirm the corresponding analysis actually runs.
- **Result:** Done. New `lib/services/indexing_consent.dart` — `IndexingConsent`
  owns `applyConsent`, `setSearchEnabled`, `setMemoriesEnabled`,
  `setFacesEnabled`, `setExcludedFolderIds`, verbatim bodies (every doc comment
  moved with its code, including the full race explanation on `applyConsent`).
  It takes the same DAOs (`dao`/`faces`/`memories`/`settings`, already public
  fields) plus a `start` callback injected from `IndexingService.start` (built
  in the constructor **body**, same reason as 6.1: a tear-off of an instance
  method isn't available in the initializer list). `IndexingService`'s five
  consent methods are now one-line delegates — same public signatures, same
  call site (`_consent.xxx`), tests call them exactly as before.

  **The single-transaction write moved intact, unreordered.**
  `applyConsent`'s body is a straight relocation: `settings.readExcludedFolderIds()`
  → the one `settings.setConsent(...)` call (a Drift `transaction(...)` inside
  `SettingsDao`, confirmed by reading it before touching anything) → the
  reset/clear branches → `unawaited(start())`, same order, same statements,
  nothing split or reordered. This is what the race-closing property depends
  on, and moving code between files doesn't change execution order, so it
  transfers by construction — verified by both device runs below.

  **Five `app_settings` key constants are genuinely shared** between the moved
  consent code and pass code that stays in `IndexingService`
  (`_maybeGlobalRecluster`, `_maybeRegenerateMemories`, `rebuild`):
  `reclusterBaselineKey`, `clusterAlgoKey`/`clusterAlgoVersion`,
  `memoriesDateKey`/`memoriesCountKey`. Promoted from private statics on
  `IndexingService` to top-level `const`s in `indexing_consent.dart` (Dart
  privacy is per-file, so a leading underscore wasn't visible from the new
  file) — `indexing_service.dart` imports them back for its own three
  remaining uses rather than duplicating the literals, so there is exactly one
  definition of each key. `_facePipelineKey`/`_facePipelineVersion` stayed
  private in `IndexingService` — pass-only, no consent-code caller.

  1027 → **909 lines** (`indexing_service.dart`); `indexing_consent.dart` is
  218. `flutter analyze` on both clean. `flutter test
  test/services/indexing_service_test.dart` → **39/39 pass, unmodified**
  (including all 10 `consent gating` cases and the 8 `folder exclusions`
  cases, both group names driving straight through the delegate to
  `IndexingConsent`). `tool/check.sh` → 827/827, unchanged.

  **Device verification (Samsung SM-S938B, `RZGYB1E58CV`):**
  - `flutter test integration_test/consent_test.dart -d RZGYB1E58CV
    --no-uninstall` (plain `integration_test`, per the file's own header —
    the plan's `patrol test` wording is imprecise) → **4/4 pass** against the
    real ML worker: no consent derives nothing, content-search-alone derives
    labels but never a face, faces-declined derives no faces, enabling faces
    backfills an already-indexed library. First run failed on a missing
    on-device fixture (`synthetic_face.jpg` not yet pushed) — an environment
    setup gap, not a code issue; pushed it per the test's own error message
    and re-ran green.
  - `patrol test -t integration_test/consent_flow_test.dart -d RZGYB1E58CV`
    → **5/5 pass**, driving the real onboarding UI through `applyConsent`
    end to end on a fresh install per case (`clearPackageData=true`): consent
    starts all-off; declining everything still opens the library; accepting
    content search enables it in Settings; folder scope chosen during
    onboarding reaches Settings; the People screen explains itself when faces
    are off.
  - **Manual fresh-install matrix:** not walked by hand a third time.
    Combined, the two device runs above already are "install clean, toggle
    each consent combination at onboarding, confirm the corresponding
    analysis actually runs" — `consent_flow_test.dart` drives the real
    onboarding UI through every toggle combination on a genuinely fresh
    install each case, and `consent_test.dart` proves the real ML worker
    honours each resulting flag. Additionally did a clean
    `flutter build apk --debug -t lib/main.dart` + reinstall + launch with
    this task's changes: correct foreground activity, no
    `sologallery`-tagged exception/error/fatal in
    `adb logcat -s flutter:V SoloGallery:V AndroidRuntime:E`.

### 6.3 Extract the indexing service's post-pass triggers

- [ ] **File:** `lib/services/indexing_service.dart`
- **Change:** move the clustering and memory-regeneration triggers
  (`_clusterNewFaces`, `_maybeGlobalRecluster`, `_maybeRegenerateMemories`) into
  a collaborator. These are already decoupled from per-asset indexing and are the
  cleanest seam in the file. Keep the `Isolate.run` offloading exactly as it is —
  both are unbounded computations that must not run on the UI isolate.
- **Verify:** `flutter test test/services/`, then on device
  `patrol test -t integration_test/ml_indexing_test.dart` and
  `-t integration_test/memories_test.dart`, plus the new
  `integration_test/people_test.dart` from task 3.2. Report the new line count of
  `indexing_service.dart` (target: under 600).
- **Result:**

### 6.4 Assess `ml_service.dart`

- [ ] **File:** `lib/services/ml_service.dart` (668 lines)
- **Change:** roughly half isolate plumbing, half analysis logic. **Assess before
  acting.** This file is a single cohesive isolate boundary, and the spawn /
  handoff / shutdown protocol is correct in ways that are easy to break — the
  binary-messenger init ordering, the sequential command queue that makes
  shutdown safe, and the ack-then-grace-then-kill teardown. If a split cannot
  keep all of that in one readable unit, **recommend leaving it alone and say
  so** under Result. A defensible 668-line file beats a subtly broken 300-line
  pair.
- **Verify:** if split, `flutter test test/services/ml_worker_shutdown_test.dart`
  plus the full on-device ML suite. If not split, record the reasoning.
- **Result:**

---

## Completion

When every box is ticked:

1. `tool/check.sh` passes.
2. The full `integration_test/` suite passes on the device, one file per run.
3. Update **Status** at the top of this file to complete, with the final state
   and any follow-ups.
4. Move this file to `docs/archived/`.
5. Update [PRD.md](../../PRD.md#known-gaps) — remove the gaps that are now
   closed, and leave the ones that are not.
