# Plan: App Store rejection fixes (v26.8.1, submission f8ef207c)

Review date 2026-08-06, devices iPhone 17 Pro Max + iPad Air 11" (M3). Three
guidelines cited. Two are metadata/reply-only; one is a code change.

## Status: code + privacy policy done; host-verified. Remaining = App Store
Connect metadata (user) + on-device integration tests + iOS manual verify.

---

## Issue A — Guideline 2.3.10 (Android references in App Store description)

**Type:** App Store Connect metadata. **No code change.**

The App Store *description* (entered in App Store Connect, not in this repo —
there is no fastlane/metadata dir checked in) references Android. Apple wants
all third-party/Android references removed from the App Store listing.

**Action (user, in App Store Connect):**
- Edit the App Store description (and promotional/subtitle text if any) to remove
  every Android-specific reference (device names, "Android", "Play Store", etc.).
- Use the iOS-only description drafted below, or paste the current description
  here for a targeted edit.

**Proposed clean App Store description (iOS-only, no Android mentions):**

> SoloGallery is a private photo library that stays entirely on your device.
> It organizes your photos, lets you search by what's in them, and groups
> photos of the same person — all on-device, with no cloud, no account, and no
> network.
>
> • 100% local — your photos never leave your device. No cloud, no servers, no
> analytics, no account.
> • On-device search — find photos by content and text, powered by machine
> learning that runs on your device.
> • People — group photos of the same person with face detection that runs
> entirely on your device.
> • Memories — automatically curated collections built from your library.
> • Non-destructive — your originals are never modified.
>
> Everything SoloGallery does happens on your iPhone and iPad. Nothing is
> uploaded, ever.

**Open question:** do you want to paste the current App Store description so I
can edit it in place, or use the proposed draft above as-is?

---

## Issue B — Guideline 5.1.1(iv) (pre-permission button label)

**Type:** Code + tests. This is the only code change in this plan.

Apple: a custom message appears before the OS permission request, and the
button says "Allow photo access" — pre-deciding for the user. They want neutral
wording like "Continue" or "Next".

Current flow (`lib/features/onboarding/onboarding_screen.dart`):
- Step 1 pre-permission CTA, line 181:
  `label: denied ? 'Open Settings' : 'Allow photo access'`
- Tapping it → `_requestAccess` → `permissionProvider.request()` →
  `PhotoManager.requestPermissionExtend(...)` (the real OS dialog). Unchanged.
- Post-denial CTA becomes `'Open Settings'` (unchanged — correct).
- Step 2 consent CTA already uses `'Continue'` (line 323).

**Change:** rename the pre-permission label `'Allow photo access'` → `'Continue'`.
Rationale: neutral, matches step-2 wording, and the explanatory body copy above
it already tells the user this is about photo access ("SoloGallery organizes
everything right here on this device…"). The screen still triggers the OS
permission prompt on tap — we are only changing the button label, not the flow.

### Files to edit (1 source + tests in lockstep)

Source:
- `lib/features/onboarding/onboarding_screen.dart:181` — `'Allow photo access'` → `'Continue'`

Integration tests (patrol, run one file per run):
- `integration_test/permission_matrix_test.dart` — lines 22, 28, 39 (this one is
  `findsNothing` after denial; still valid since the button becomes 'Open
  Settings'), 49, 60
- `integration_test/consent_flow_test.dart` — lines 25, 27
- `integration_test/folders_ui_test.dart` — lines 48, 49
- `integration_test/hero_dismiss_test.dart` — lines 30, 31
- `integration_test/saved_albums_test.dart` — lines 17, 18
- `integration_test/nav_shell_test.dart` — lines 19, 20, 237
- `integration_test/detail_actions_test.dart` — lines 23, 24
- `integration_test/video_playback_test.dart` — lines 23, 24

Unit/widget/golden tests:
- `test/features/onboarding/onboarding_screen_test.dart` — lines 58, 92, 102, 106, 149
- `test/widgets/design_goldens_test.dart:373` — golden fixture label

All `$('Allow photo access')` / `find.text('Allow photo access')` →
`$('Continue')` / `find.text('Continue')`.

**Caveat to verify at edit time:** step 2 of the same onboarding also has a
`'Continue'` button. Tests that assert `findsOneWidget` for `'Continue'` must be
on a screen where only one of the two is visible (step 1 and step 2 are never
shown simultaneously — selection is derived from permission/consent state, see
`onboarding_screen.dart:88–101`), so `findsOneWidget` stays correct. Re-check
`permission_matrix_test.dart:39` semantics after the rename: it asserts the
old label is gone after denial — `'Continue'` is indeed absent there (button is
`'Open Settings'`), so the assertion remains valid.

---

## Issue C — Guideline 2.1 (face data information needed)

**Type:** Privacy-policy doc edit + drafted reply to App Review. No app code
change (face handling is already correct and on-device; this is a disclosure
completeness issue).

Apple wants complete answers to six questions, with specific privacy-policy
sections quoted. The existing `docs/privacy-policy.md` covers face data but has
no dedicated, easily-quotable "Face data" section. Adding one makes the reply
airtight and is the only doc change here.

### C.1 — Add a "Face data" section to `docs/privacy-policy.md`

Insert a dedicated section (and bump "Last updated" to 6 August 2026). Content
to cover, derived from the actual code (see findings):

- **What is collected:** when Face detection is on (off by default), the app
  detects faces on-device via a bundled ML Kit model and stores only (a) a
  numeric face embedding (MobileFaceNet float vector) and (b) a normalized
  bounding box `[0,1]`. No face image or face crop is ever stored. Person names
  are never auto-assigned; any name is user-typed and optional.
- **Where stored:** the app's private on-device SQLite (Drift) database in the
  app sandbox. Never leaves the device.
- **Use:** only to group photos of the same person in the in-app People view.
  Not used for biometric identification or authentication, not matched against
  any external database.
- **Sharing:** never shared with any third party. The app makes no network
  requests at all.
- **Retention / deletion:** retained until the user turns Face detection off in
  Settings (deletes all face data + person clusters), uses "Rebuild index", or
  uninstalls the app. No time-based retention, no backup copy
  (`android:allowBackup="false"`).

This mirrors what the code already does (`ml_service.dart`,
`tables.dart` `FaceEmbeddings`/`Persons`, `faces_dao.dart`,
`indexing_service.dart:387–399`).

### C.2 — Drafted reply to App Review (paste into the App Review conversation)

> Thank you for the questions. SoloGallery is a privacy-first, fully on-device
> photo app — it makes no network requests, has no servers, and requires no
> account. Face detection is **off by default** and only runs if the user turns
> it on during setup or in Settings.
>
> **1. What face data does the app collect?**
> When Face detection is enabled, the app detects faces in the user's own
> photos entirely on-device using a bundled ML model. For each detected face it
> stores only: (a) a numeric face embedding — a float vector produced by the
> bundled MobileFaceNet TensorFlow Lite model, used solely to group photos of
> the same person; and (b) a normalized bounding box (left/top/right/bottom as
> fractions of the analyzed thumbnail, range 0–1). The app never stores the face
> image or any face crop. Person names are never assigned automatically; any
> name is entered manually by the user and is optional.
>
> **2. Use, sharing, retention, deletion, storage.**
> Use: face embeddings are used only to cluster photos of the same person for
> the in-app People view. No biometric identification or authentication; no
> matching against any external database. Sharing: never shared, transmitted,
> or uploaded — the app makes no network requests at all (the INTERNET
> permission is explicitly stripped from the release build; there is no HTTP
> client, Firebase, analytics, or cloud SDK). Storage: stored only in the app's
> private on-device SQLite database in the app sandbox; never leaves the
> device. Retention: persists only until the user turns Face detection off in
> Settings (immediately deletes all face data and person clusters), uses
> "Rebuild index", or uninstalls the app. Deletion: turning the feature off
> deletes the data it produced; the user can clear it at any time.
>
> **3. Will face data be shared with any third parties? Where stored?**
> No, never. It is stored only in the app's private on-device database on the
> user's own device. Nothing derived from a photo is ever sent anywhere.
>
> **4. How long is face data retained?**
> Until the user turns Face detection off in Settings, rebuilds the index, or
> uninstalls the app — any of which deletes it immediately. There is no
> time-based retention and no backup copy (cloud backup is disabled for the
> app's data).
>
> **5. Where in the privacy policy is face data explained?**
> The dedicated "Face data" section, plus "What the app creates, and where it
> stays", "What leaves your device", and "Data retention and deletion".
>
> **6. Quote of the specific text concerning face data:**
> [Insert the verbatim quotes from the updated privacy policy at edit time —
> the new "Face data" section plus the existing lines below.]

Verbatim quotes to use (from `docs/privacy-policy.md`, after the C.1 edit):
- New "Face data" section (added in C.1) — quote in full.
- "Face detection — face locations and numeric face signatures, used to group
  photos of the same person."
- "All three are off until you turn them on… Turning one off deletes the data it
  produced."
- "This analysis uses machine-learning models bundled inside the app. No
  photo, and nothing derived from a photo, is ever sent anywhere."
- "What leaves your device: Nothing, unless you explicitly share it."
- "All app data lives in the app's own storage on your device. Uninstalling
  SoloGallery removes it entirely. You can also clear derived data at any time
  by turning a feature off in Settings, or by using 'Rebuild index'."

---

## Verification (Definition of Done)

1. `flutter analyze` — zero warnings.
2. `flutter test` — unit + widget incl. `onboarding_screen_test.dart` and
   `design_goldens_test.dart` (golden images will change label text → regenerate
   goldens if the golden test diffs; otherwise update the fixture label and the
   reference image per alchemist flow).
3. Integration tests on the connected device, ONE file per run:
   `permission_matrix_test.dart`, `consent_flow_test.dart` first (most relevant).
4. Manual on device: cold launch into onboarding → step 1 button reads
   "Continue" → tap → OS photo permission dialog appears → grant → step 2.
   Then deny path → button reads "Open Settings".
5. `docs/privacy-policy.md` "Face data" section present, "Last updated" bumped.
6. App Store Connect description updated (user); App Review reply sent (user).
7. Plan doc marked complete; CLAUDE.md pruned (no task-scoped notes expected).

## Next step

Await approval. On approval: do C.1 (privacy policy) and B (code + tests) first,
run `tool/check.sh`, then run the two integration tests on the device. Hand the
user the App Review reply (C.2) and the clean App Store description (A) to paste
into App Store Connect.

---

## Completion log

- **B (code + tests):** DONE. `onboarding_screen.dart:181` → `'Continue'`.
  8 integration-test files updated via sed; `onboarding_screen_test.dart`
  updated (line-149 consent-step assertion changed to assert the step-1 headline
  `Your photos\nstay yours.` is absent, since step-2 also has a `Continue` button);
  `design_goldens_test.dart:373` sample label → `'Open Settings'` (distinct from
  the busy `Continue` below it); `app_button.png` golden regenerated.
- **C.1 (privacy policy):** DONE. Added dedicated `## Face data` section;
  bumped "Last updated" to 6 August 2026.
- **Verify:** `tool/check.sh` PASS (analyze 0 warnings, build_runner OK,
  779 tests pass). Golden: only `test/widgets/goldens/ci/app_button.png` changed.
- **Remaining (user):**
  1. App Store Connect: replace the app description with the iOS-only draft in
     Issue A; also scan subtitle/promotional text for Android mentions.
  2. App Review reply: paste the C.2 text, with the verbatim quotes filled from
     the updated `docs/privacy-policy.md` "Face data" section.
  3. On-device: run `permission_matrix_test.dart` + `consent_flow_test.dart`
     (one file per run) on a connected device, and manually verify the iOS
     onboarding flow (button reads "Continue" → tap → OS prompt → grant →
     consent step; deny path → "Open Settings"). No device was connected during
     this session.

### Final update (2026-08-06)

- Version bumped to `26.8.6+1` (CalVer YY.M.D, build 1) in `pubspec.yaml`.
- **Hosted policy is the HTML**, not the markdown: `docs/privacy-policy.html`
  (canonical `https://zmeul.com/sologallery/privacy.html`). Updated it to match
  — added Section 4 "Face Data", renumbered 5–11, date → August 2026. User
  republished; live page verified via fetch.
- The App Review reply was rewritten to quote the **HTML** verbatim (section
  names + numbers match the renumbered policy) and trimmed to **3296 chars**
  (limit 3500). Also corrected an accuracy issue: dropped the "no backup copy"
  claim (true only on Android, `allowBackup=false`); on iOS the local index may
  be in iCloud Backup — the policy's Data Backup section says so, and the reply
  now points there.
- **Status: all code/doc work done and host-verified. User is archiving
  `26.8.6+1`, updating the App Store description, and replying to the reviewer;
  then waiting for re-review.**
- **iOS usage string:** `NSPhotoLibraryUsageDescription` unchanged and correct.
  ML Kit face detection runs on-device via the bundled model; no
  `NSFaceServicesUsageDescription` is required (no Vision face-capture API used).