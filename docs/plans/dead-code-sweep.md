# Dead-code sweep — COMPLETE

## Context

`flutter analyze` reports zero issues, but it only flags unused **private**
symbols. A sweep of public top-level declarations and class members across
`lib/` (cross-referenced against `test/`, `integration_test/`, `tool/`) turned
up 3 symbols with zero references anywhere and 7 reachable only from tests.

CLAUDE.md Absolute rules: *"No dead code, no unused symbols — every symbol must
exist and be used."*

**Outcome: 9 symbols removed, 3 kept, 2 test assertions relocated rather than
lost. 130 lines deleted, 24 added.**

**Decisions taken** (do not re-litigate):
- **`EditInstructionsDao` stays.** Deliberate scaffolding for the spec'd but
  unbuilt `features/edit/` editor, backed by the `edit_instruction` table
  already in the schema and every migration. Only its unreferenced
  `watchForAsset` went. Not annotated — a future sweep re-flagging it is
  cheaper than a suppression that outlives the reason for it.
- **`MemoriesDao.memoryById` stays** — the plan originally said remove; that
  was **wrong**. See §2b.

---

## 1. Zero references anywhere — DONE

- [x] `appLogger` (`core/logging_config.dart`) — `configureLogging()` wires
      `Logger.root`; every call site builds its own `Logger('SoloGallery.x')`
      child. Its doc comment described the real convention, so it was **moved
      onto `configureLogging()`** rather than deleted with the symbol.
- [x] `EditInstructionsDao.watchForAsset` — reactive variant never wired.
- [x] `AssetDetail.hasGps` — the EXIF sheet null-checks `latitude`/`longitude`
      directly.

## 2. Test-only symbols — case-by-case

### 2a. Superseded by the reactive-cache migration — DONE

Commit `1887f11` replaced one-shot offset paging with the growing-window
`watch*` pattern. `git log -S` confirms it **introduced all three replacements
below and left the originals orphaned** — migration residue, not API surface.

- [x] `IndexDao.olderAssets` → `watchOlderAssets`.
      `integration_test/library_month_grouping_test.dart` rewritten. The plan
      feared losing paging coverage; on inspection the Older block never
      asserted paging — it paged only to *enumerate*, and asserted disjointness
      from month sections. The rewrite reads one `watchOlderCount()`-bounded
      window and keeps the disjointness assertion intact, plus a new
      `hasLength(olderCount)` guard so a short read can't silently shrink the
      check.
- [x] `FavoritesDao.watchAll` → `IndexDao.watchFavoritesInCache` (whose inner
      join drops dangling favorites; `watchAll` was the naive version).
      **Its ordering test was load-bearing** — `watchFavoritesInCache` had no
      ordering coverage (its only test returns a single row, so order was
      unobservable). The "most-recently-favorited first" assertion was
      **migrated onto `watchFavoritesInCache`**, i.e. onto the production path.
      Net coverage improved.
- [x] `YearMonth.descendingRange` → `IndexDao.watchMonthCounts` (month list is
      DB-derived; synthesizing a calendar range is obsolete).
- [x] **Cascade:** removing `descendingRange` orphaned `YearMonth.previous` —
      it was its only consumer. Removed with its test, else the sweep would
      just have relocated the problem.

### 2b. Speculative API — PARTIALLY DONE (one reversal)

- [x] `AlbumsDao.removeEntry` — dates to the original DAO scaffolding
      (`765c832`), never wired. Spec's detail actions are favorite / delete /
      share / **add** to album; there is no remove-from-album flow. Sibling
      `removeAssetEverywhere` covers the real case (asset deleted from device).
- [x] `SettingsDao.watchConsentRecorded` — its doc claimed *"Onboarding holds
      the user on the consent step until this is true"*; **the claim was
      false**, `consent_provider.dart:44` uses the one-shot
      `readConsentRecorded()`. Method removed and the accurate half of the
      comment moved onto `readConsentRecorded`. Its test line was redundant
      with the `readConsentRecorded` assertion directly above it.
- [x] ~~`MemoriesDao.memoryById`~~ — **KEPT. The plan's reasoning was wrong.**

  The plan proposed re-expressing its assertions through `watchActive()`. That
  is impossible:
  - `watchActive()` returns `MemorySummary`, a projection carrying only
    `id, kind, title, subtitle, coverAssetId, assetCount` — **no `seenAt`, no
    `hidden`, no `sourceKey`**, which is exactly what the assertions check.
  - `watchActive()` filters `hidden.equals(false)`, so it **structurally cannot
    distinguish "hidden" from "deleted"** — and that distinction *is* the
    assertion in `memories_dao_test.dart:96` and
    `indexing_service_test.dart:251`.

  `memoryById` is the only way to assert on persisted non-projected row state.
  It guards two real invariants — *hide is not delete* and *upsert preserves
  user state across regeneration* — whose regression would silently discard
  user dismissals. It is load-bearing test infrastructure, not dead code.

### 2c. Kept

`EditInstructionsDao.{getForAsset, upsert, deleteForAsset}` — see Decisions.

## 3. Also fixed

- [x] `PhotoLibraryService` doc comment said *"Permission flow lands in Phase 2;
      asset/thumbnail queries are added on top of this in the same phase."*
      Both shipped — removed.

---

## Verification — DONE

- [x] `tool/check.sh` passes — analyze clean, build_runner clean, **329/329
      host tests pass**
- [x] `flutter test integration_test/library_month_grouping_test.dart -d 46121FDAS008AA` — passes
- [x] **Positive control established for the rewritten branch.** The Older block
      sits behind `if (olderCount > 0)`, so a green run would prove nothing on a
      device with no undated assets (CLAUDE.md: *"a device-only assertion needs a
      positive control, or it passes vacuously"*). A temporary `fail()` probe
      reported **`olderCount=3 seen=100`** — the rewritten branch really executed
      against 3 undated assets. Probe reverted; file re-verified green after.
- [x] Sweep re-run post-change — no new orphans. Remaining hits are the
      documented keeps plus three known false positives:
      `didChangeAppLifecycleState` / `schemaVersion` (both `@override`) and
      `VideoPlayer` (package class).
- [x] No schema change → no dump/migration work (DoD #4 N/A)
- [x] No dependency change → no manifest re-verification (DoD #5 N/A)

**Manual end-to-end device verification: N/A by design.** Every change is a
symbol removal with no production call path — there is no user-facing behaviour
to drive. The one change touching a real execution path (the integration-test
rewrite) was verified on the Pixel with the positive control above.

## Follow-ups

- The sweep is a throwaway script, not committed. If dead-code drift becomes
  recurring, `tool/` is the place for a checked-in version — but three false
  positives out of ~200 declarations means it needs the `@override` handling
  hardened before it's worth automating in `check.sh`.
- `MemorySummary` omitting `hidden`/`seenAt` is *why* `memoryById` must exist.
  If that projection ever grows those fields, re-evaluate.

---

## Next step

None — task complete. Changes are unstaged in the working tree on
`feature/metadata-search`; not committed (no commit was requested).
