# Remediation plan — findings from the 2026-09-04 audit

**Status:** Phase 1 complete (1.1–1.7). Phase 2 complete (2.1 + 2.2 green on the
physical iPhone; 2.3 done as a host widget test — see its Result). Phase 3 not
started.
**Next step:** Task 3.1 — unit-test the two pagination bases
(`PagedAssetsNotifier`, `WatchedAssetsNotifier`). Host tests, no device.

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

- [ ] **Files:** new `test/services/paged_assets_notifier_test.dart`,
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
- **Result:**

### 3.2 Add a People integration test

- [ ] **File:** new `integration_test/people_test.dart`
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
- **Result:**

### 3.3 Fill the widget-test gaps

- [ ] **Files:** new tests under `test/widgets/` and `test/features/settings/`
- **Change:** add behavioural widget tests (not just goldens) for
  `lib/widgets/app_button.dart` (all three voices, `compact`, leading icon, tap
  and disabled) and `lib/features/settings/widgets/settings_rows.dart` (all five
  row primitives, which are used by three screens and have no direct test).
- **Verify:** `flutter test test/widgets/ test/features/settings/`
- **Result:**

---

## Phase 4 — Deduplication

Mechanical, behaviour-preserving. Do these before the screen and service splits:
they shrink the files those phases touch.

### 4.1 Extract one generic LRU

- [ ] **Files:** `lib/services/adjacent_thumbnail_cache.dart`,
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
- **Result:**

### 4.2 Collapse the repeated IndexDao query shapes

- [ ] **File:** `lib/core/database/daos/index_dao.dart` (634 lines)
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
- **Result:**

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

- [ ] **File:** `lib/features/search/search_screen.dart` (621 lines)
- **Change:** extract into `lib/features/search/widgets/`: the search field, the
  facet/filter bar, the browsable label chips, the idle body, the results body,
  and the album/label match rows. `search_screen.dart` keeps the scaffold and the
  idle-vs-results branch.
- **Verify:** `flutter test test/features/search/`; report the new line count of
  `search_screen.dart` (target: under 200).
- **Result:**

### 5.2 Split the Library screen

- [ ] **File:** `lib/features/library/library_screen.dart` (612 lines)
- **Change:** extract the four filter-scoped bodies (`_MonthTimeline`,
  `_ThisWeekList`, `_YearList`, and the day sections) plus the section and
  preview-grid widgets into `lib/features/library/widgets/`. The screen keeps the
  scaffold, the app bar and the filter switch.
- **Verify:** `flutter test test/features/library/`, including
  `library_spacing_test.dart` — the s20 inter-section rhythm is easy to break
  during extraction, and that test is what catches it. Report the new line count.
- **Result:**

### 5.3 Split the Onboarding screen

- [ ] **File:** `lib/features/onboarding/onboarding_screen.dart` (586 lines)
- **Change:** this is the only feature with no `widgets/` folder. Create one and
  extract: the brand mark, the assurance rows, the permission step body, the
  consent step body, and the folder-scope card. Keep the `InheritedWidget` that
  fans state to the folder-scope card — it is deliberate, and prop-drilling it
  instead would be a behaviour-adjacent change.
- **Verify:** `flutter test test/features/onboarding/`, then **manually re-run
  first-run onboarding on the device** — this screen gates the entire app and its
  consent write is transactional for a reason. Report the new line count.
- **Result:**

### 5.4 Trim the memory player

- [ ] **File:** `lib/features/memories/memory_player_screen.dart` (402 lines)
- **Change:** borderline. Extract the title card and the progress-segment row into
  `lib/features/memories/widgets/`. Leave the scene-transition logic and its
  reduced-motion guard in the screen — it is the app's one sanctioned animation
  and splitting it across files would make it easier to break.
- **Verify:** `flutter test test/features/memories/`
- **Result:**

---

## Phase 6 — Split the large services

**Highest risk in this document.** These files own the isolate lifecycle, the
consent race and the plugin boundary. Do not start phase 6 until phases 2 and 3
are complete and green — those tests are the safety net.

Do each task as its own commit. If anything about the isolate protocol or the
consent transaction becomes unclear mid-task, stop and ask rather than guessing.

### 6.1 Compose the photo library service's caches

- [ ] **File:** `lib/services/photo_library_service.dart` (853 lines)
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
- **Result:**

### 6.2 Extract the indexing service's consent handling

- [ ] **File:** `lib/services/indexing_service.dart` (1027 lines)
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
- **Result:**

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
