# On-device analysis consent — COMPLETE

## Context

Every derived-data feature (content search, memories, face clustering) ran
unconditionally as part of the indexing pass. Face embeddings are
biometric-adjacent, memories surface inferred content, and label/OCR extraction
runs ML over every photo — none of it was ever consented to. Onboarding asked
for exactly one thing: photo-library access.

All three are now **opt-in, default off**, consented in onboarding and
changeable in Settings. Withdrawing consent deletes the derived data.

**Decisions (settled — do not re-litigate):**
- Three independent toggles: Content search, Memories, Face detection.
- Default off; nothing is derived until the user says yes.
- Asked in a second onboarding step, mirrored in Settings.
- Turning one off deletes its derived data immediately.

The third toggle was added mid-task: with only memories+faces gated, the
indexer still ran labels/OCR over every photo, and Settings still showed
"Analysing…" — inconsistent with asking permission for faces. Now with nothing
consented **no ML runs at all** and the worker isolate never spawns.

No schema migration: `AppSettings` is a generic key/value table (DoD #4 n/a).
No new Android dependency (DoD #5 n/a).

---

## What was built

**Persistence** — `lib/core/database/daos/settings_dao.dart`
Keys `search_enabled`, `memories_enabled`, `faces_enabled` (typed
`watch*`/`read*`/`set*` helpers, default false) plus `ml_consent_v1`, which
records only *that* the prompt was answered. It is deliberately separate from
the three flags: "declined everything" and "never asked" must not look alike,
or onboarding re-prompts forever.

Data deletion: `IndexDao.clearContent()` (labels + OCR),
`FacesDao.clearFaces()`, existing `clearPersons()` / `clearMemories()`.
`IndexDao.resetMlPending()` re-queues the cache without dropping labels.

**Consent state** — `lib/features/settings/consent_provider.dart`
`ConsentNotifier` (`unresolved` → `needed`/`recorded`) mirrors
`PermissionNotifier`, because the router redirect reads it **synchronously**.
`unresolved` deliberately does **not** redirect — holding there during the
Drift read would flash the consent step at every existing user on cold start.
Plus `searchEnabledProvider` / `memoriesEnabledProvider` /
`facesEnabledProvider` (app-wide streams).

**Router** — `lib/core/router/app_router.dart` redirects to `/onboarding` while
consent is `needed`; the refresh `ValueNotifier` is now a change counter fed by
both permission and consent.

**Onboarding** — a second step in `onboarding_screen.dart`, same skeleton as
step 1 (eyebrow, 34pt headline, row rhythm, pill CTA). The rows are
`_Assurance`'s anatomy with the leading dot traded for a trailing switch. The
middle section **scrolls** — three switch rows plus the headline overflow a
short screen at large font scales, and a RenderFlex overflow is a hard failure
on device.

**Settings** — `_OnDeviceGroup` with three `_SwitchRow`s. The "People" stat row
is hidden when faces are off, and the "Analysis" row reads **"Off"** rather than
"Up to date" when nothing is consented (otherwise it implies work happened).

**Shared widget** — `lib/widgets/consent_switch.dart` (`ConsentSwitch`), used by
both surfaces. Its active track is `AppColors.pillActiveBg`, the design
system's single high-contrast token, so consent introduced **no new accent
colour**. Golden-tested light + dark (`consent_switch.png`).

**Pipeline** — `lib/services/indexing_service.dart` reads all three flags once
per pass. `needsMl = search || faces`; when false the ML loop is skipped
entirely (no thumbnail render, no isolate). Face insert, clustering, global
re-cluster, memory regeneration, and the person/theme blocks of `_planMemories`
are each gated. `setSearchEnabled` / `setMemoriesEnabled` / `setFacesEnabled`
own the enable-backfill and disable-delete side effects, so Settings and
onboarding share one implementation.

**Worker** — `lib/services/ml_service.dart` `analyzeFile(..., content:, faces:)`.
Every model (labeler, recognizer, face detector, tflite interpreter) is now
built **lazily on first use**, so a declined feature costs no model load. With
`faces: false` the whole-thumbnail `img.decodeImage` is skipped — the expensive
part.

**UI gating** — `memoriesProvider` and `personSummariesProvider` return empty
when their flag is off, so every surface (Library carousel, Search people strip,
`/people`) goes quiet together. `PeopleScreen` shows "Face detection is off…"
rather than the "still indexing" note. The Search hint and idle text only
promise content matching when it is enabled.

---

## Verification (all passing)

**Host** — `tool/check.sh`: analyze clean, build_runner clean, **329 tests**.
Covers the DAO flags, `ConsentNotifier`, provider gating
(`test/features/consent_gating_test.dart`), the indexer matrix
(`consent gating` group: nothing-consented, search-only, delete-on-disable,
enable-backfill), both screens, and the `ConsentSwitch` golden.

**On device** (Pixel 9 Pro XL `46121FDAS008AA`):
- `integration_test/consent_test.dart` — 4/4. Real ML worker: nothing consented
  → zero labels/OCR/faces/persons/memories while the grid still fills; search
  only → labels but never a face; the worker honours both flags; enabling faces
  backfills an already-indexed library.
- `integration_test/consent_flow_test.dart` (**patrol**) — 4/4. Drives the real
  consent UI: step is owed after access and starts all-off, declining
  everything still opens the Library, accepting content search shows up in
  Settings, People strip absent when faces are off.
- `integration_test/permission_matrix_test.dart` — 2 pass / 1 pre-existing skip
  (updated: granting access now lands on the consent step, not the Library).
- `integration_test/memories_test.dart` — 2/2 (seeds consent explicitly).

---

## Second pass — gaps found by review and closed

A "what's left unsolved" review turned up one real bug and four smaller gaps.
All are fixed except iOS, which was explicitly deferred.

1. **Upgrade path leaked derived data (real bug).** `ConsentNotifier.record()`
   wrote the flags straight to `SettingsDao`, bypassing the `IndexingService`
   methods that own deletion. A *fresh* install has nothing to delete — which is
   why every device test passed — but an **upgrading** user reached the prompt
   with labels, faces, persons, and memories already on disk, and declining
   left all of it there. Confirmed with a throwaway probe (labels survived a
   decline-everything), then fixed by routing `record()` through
   `setSearchEnabled` / `setMemoriesEnabled` / `setFacesEnabled`. Regression
   tests: the `upgrading from a build that had no consent step` group.
2. **`ml_consent_v1` implied a re-consent mechanism that did not exist.** The
   key is now `ml_consent` holding `SettingsDao.consentVersion`; bumping that
   constant re-asks everyone, and the stored value is compared exactly.
3. **Rebuild-index dialog copy** promised to re-run "labels, text, and people"
   regardless of what was enabled. It now names only what is switched on, and
   says plainly that nothing is analyzed when nothing is.
4. **Limited access × consent** was untested — `PhotoAccess.limited` satisfies
   `canReadLibrary`, so consent is still owed. Covered by a widget test.
5. **`test_assets/` now exists**, generated by `tool/gen_test_assets.dart`
   (see `test_assets/README.md`). The face fixture is also bundled as a Flutter
   asset so `consent_test.dart` no longer samples the camera roll for its
   positive control. **A drawn face is not detectable by default** — the first
   version was rejected outright by ML Kit; realism (proportions, shading,
   Gaussian blur) is what made it work, and
   `integration_test/test_fixtures_test.dart` guards that on device.

Final state: `tool/check.sh` clean with **334 host tests**; on device
`consent_test` 4/4, `consent_flow_test` (patrol) 4/4, `test_fixtures_test` 2/2,
`memories_test` 2/2, `permission_matrix_test` 2 + 1 pre-existing skip.

---

## Follow-ups

- **iOS is entirely unverified** — deliberately out of scope for this task.
  Everything was verified on the Pixel 9 Pro XL. The router redirect, the
  consent step layout, and the lazy model construction need an iOS pass, and
  iOS's permission model differs (`notDetermined` exists, limited library
  behaves differently).
- The `test_assets/` **video** is not generated — no `ffmpeg` on this machine,
  and neither `sips` nor `package:image` encodes video. Supply any short clip by
  hand; only the video thumbnail/duration tests need it.
- The consent copy treats "content search" as one thing; labels and OCR are
  separable if that distinction ever matters to users.
- `setSearchEnabled(false)` deletes labels/OCR. Re-enabling re-analyses the
  whole library — fine at phone scale, worth a progress hint if libraries grow.
