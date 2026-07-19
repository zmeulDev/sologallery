# Rename to com.zmeul.sologallery + prepare for publication — COMPLETE

## Context

The app still carries the `flutter create` defaults: application id
`com.example.sologallery`, description "A new Flutter project.", a lowercase
`sologallery` launcher label, and stock blue Flutter icons. None of that can
ship. The id must become **`com.zmeul.sologallery`** and the app must be brought
to a submittable state.

Exploration also turned up one substantive privacy defect (below) that
contradicts the app's core promise, plus two Apple submission blockers.

**Decisions taken** (do not re-litigate):
- **Signing: skipped.** The debug-key TODO stays. Everything else is done; the
  app cannot be uploaded to Play until a keystore exists.
- **OS floors raised to match CLAUDE.md**: Android `minSdk 35`, iOS deployment
  target `26.0`. Verified buildable — Xcode 26.6 / iOS 26.5 SDK is installed.
  *Understood consequence:* an iOS 26 floor excludes almost the entire current
  installed base. This is deliberate.
- **Icons generated** from the design-system palette, wired via
  `flutter_launcher_icons` (adaptive + themed on Android).
- **Desktop dirs kept**, with the id renamed in `linux/`, `macos/`, `windows/`.

---

## 1. The privacy defect — fix first

`android/app/src/main/AndroidManifest.xml` sets **no `android:allowBackup`**, so
it defaults to `true`. Android Auto Backup therefore uploads
`app_flutter/sologallery.sqlite` — the entire local photo index, including
face embeddings and OCR text — **to Google's servers**. This directly
contradicts "Zero network calls" and "100% local" (CLAUDE.md Absolute rules).

Fix: `android:allowBackup="false"` plus explicit
`android:dataExtractionRules="@xml/data_extraction_rules"` and
`android:fullBackupContent="@xml/backup_rules"` in a new
`android/app/src/main/res/xml/`, both excluding the database outright. Belt and
braces: even with backup off, the rules document the intent.

## 2. The id rename

Two **directory moves** (`git mv`, so history follows):
- `android/app/src/main/kotlin/com/example/sologallery/` → `.../com/zmeul/sologallery/`
- `android/app/src/androidTest/java/com/example/sologallery/` → `.../com/zmeul/sologallery/`

Then the text references — `package` lines in `MainActivity.kt` /
`MainActivityTest.java`; `namespace` + `applicationId` in
`android/app/build.gradle.kts`; six `PRODUCT_BUNDLE_IDENTIFIER` values in
`ios/Runner.xcodeproj/project.pbxproj` (three are `…​.RunnerTests`);
`patrol.android.package_name` and `patrol.ios.bundle_id` in `pubspec.yaml`
(**load-bearing** — `patrol test` installs by these); `linux/CMakeLists.txt`,
`macos/Runner/Configs/AppInfo.xcconfig` (id + the `com.example.` copyright
string), `macos/.../project.pbxproj`, `windows/runner/Runner.rc`.

Docs carrying copy-pasteable `pm grant` / `run-as` snippets must be updated, not
deleted: `CLAUDE.md` (lines ~483, ~589–590, and the Environment-notes bullet at
~640 which should now record the real id), `docs/manual-device-test-plan.md`,
`docs/plans/CHECKPOINT.md`.

The old package must be **uninstalled from the Pixel** or both apps sit
side-by-side during device testing.

## 3. App identity

| Surface | Now | Becomes |
|---|---|---|
| `AndroidManifest.xml` `android:label` | `sologallery` | `SoloGallery` |
| `ios/Runner/Info.plist` `CFBundleDisplayName` | `Sologallery` | `SoloGallery` |
| `ios/Runner/Info.plist` `CFBundleName` | `sologallery` | `SoloGallery` |
| `pubspec.yaml` `description` | "A new Flutter project." | real one-line description |

`version: 1.0.0+1` is correct for a first release — left alone.

## 4. Apple submission blockers

- **`ios/Runner/PrivacyInfo.xcprivacy` does not exist** — required. Declares no
  tracking, no data collection, and the required-reason API usages the app
  genuinely has: file timestamp (`C617.1`) via path_provider/Drift,
  `UserDefaults` (`CA92.1`) via package_info_plus/share_plus, disk space
  (`E174.1`).
- **`ITSAppUsesNonExemptEncryption`** missing from `Info.plist` → forces a
  manual export-compliance answer on every upload. Add `<false/>`.
- **`NSPhotoLibraryAddUsageDescription`** — check whether the favorite / delete /
  add-to-album paths in `lib/features/detail/` actually invoke a `photo_manager`
  write that triggers it; add only if a real write path exists.

## 5. OS floors + dead permission

`android/app/build.gradle.kts`: `minSdk = 35` (drop the `maxOf(..., 23)` and its
now-wrong "patrol requires >= 23" comment). At minSdk 35 the
`READ_EXTERNAL_STORAGE` / `maxSdkVersion="32"` line in the manifest is
unreachable — remove it.

iOS: `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in all three build configs of
`ios/Runner.xcodeproj/project.pbxproj`, and set `platform :ios, '26.0'` in
`ios/Podfile` (currently commented out).

## 6. Release build hygiene

`android/app/build.gradle.kts` relies on a Flutter-internal default for R8 —
`FlutterPlugin.kt` enables `isMinifyEnabled`/`isShrinkResources` when
`shouldShrinkResources` is true. Make both explicit on the release buildType so
it does not silently change under a Flutter upgrade. The existing
`proguardFiles(...)` duplicates what the plugin already adds; keep one.

`android/app/proguard-rules.pro` currently only holds ML Kit `-dontwarn` lines.
A release-mode smoke run on device is the check that Drift/sqlite3/tflite/
photo_manager survive R8 — no speculative keep rules without evidence.

## 7. Icons

Add `flutter_launcher_icons` (dev dep) + `assets/icon/`. Generate the source art
with a new `tool/gen_app_icon.dart` using `package:image` (already a dependency,
same approach as the working `tool/gen_test_assets.dart`), drawing from the
design-system palette — near-black `#111110` on warm off-white `#F5F5F3`.
Configure an Android adaptive icon (separate foreground/background) and a
monochrome layer for Android 13+ themed icons, plus the iOS 1024 set.

**Invoke `/frontend-design:frontend-design` before designing the mark** — it is
the single most visible design artifact in the project.

## 8. Stop shipping the test fixture

`pubspec.yaml` bundles `assets/test_fixtures/synthetic_face.jpg` into the
**production** app; nothing in `lib/` reads it — only `consent_test.dart` and
`test_fixtures_test.dart` do, via `rootBundle`. 29 KB is trivial, but a file
named `synthetic_face.jpg` inside a shipped privacy-first photo app invites
exactly the wrong question.

Remove it from `flutter: assets:` and have the two integration tests read it
from the app-private external dir instead, pushed before the run:
`adb push assets/test_fixtures/synthetic_face.jpg /sdcard/Android/data/com.zmeul.sologallery/files/`
(app-private, **not** MediaStore-indexed, so it still does not pollute the real
photo library — which was the original reason for bundling it). Document the
step in `test_assets/README.md` and the CLAUDE.md integration-test recipe, next
to the existing pre-grant instructions.

`assets/models/mobilefacenet.tflite` (5 MB) stays — a real production asset.
Confirm `assets/models/README.md` records a redistribution-compatible license.

## 9. Privacy policy

Google Play requires a hosted privacy policy URL for any app declaring photo
access. Write `docs/privacy-policy.md` — for this app it is unusually short and
strong (no collection, no network, no analytics, no third parties). Hosting it
is the user's step; the document is the deliverable.

---

## Outcome

All nine work items done. `tool/check.sh` clean (334 host tests).

**The rename** landed everywhere: two `git mv`'d package dirs, Gradle
namespace/applicationId, six iOS `PRODUCT_BUNDLE_IDENTIFIER`s, the two
load-bearing `patrol:` ids, the three desktop scaffolds, and the docs (whose
`pm grant` / `run-as` snippets stay copy-pasteable). Verified end-to-end: the
merged manifest reports `package="com.zmeul.sologallery"`, the iOS bundle builds
under it, and `patrol test` still installs and drives the app.

**Two defects were found and fixed by actually running a release build**, not by
reading config:

1. **Auto Backup was uploading the photo index to Google.** No
   `android:allowBackup` meant the platform default (`true`), so
   `sologallery.sqlite` — labels, OCR text, face embeddings — was eligible for
   cloud backup, flatly contradicting the app's core promise. Now
   `allowBackup="false"` plus `res/xml/{backup_rules,data_extraction_rules}.xml`
   excluding everything. Confirmed in the merged manifest.
2. **R8 was silently disabling all of ML Kit.** `MlKitInitProvider` instantiates
   `*Registrar` classes reflectively; R8 stripped their constructors, so every
   component failed to register with only a `W ComponentDiscovery` warning — no
   crash. Labels, OCR and faces would have returned empty *in production* while
   every debug test passed. Keep rules added to `proguard-rules.pro`; the
   warning is gone from a fresh release build. This is why the plan insisted on
   a real release run — nothing else would have caught it.

**Merged release manifest** requests exactly: `READ_MEDIA_IMAGES`,
`READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`, `WAKE_LOCK` (playback,
documented), and an app-scoped AndroidX receiver token. No `INTERNET`, no
`READ_PHONE_STATE`, no `c2dm`, no storage permission — the injected
`READ_EXTERNAL_STORAGE` is now stripped too (inert at minSdk 35, but it would
have shown in the Play listing).

**Builds:** `app-release.apk` 183.6 MB (all ABIs), `app-release.aab` 129.7 MB.
Native libs dominate (arm64 56 MB + x86_64 40 MB + v7a 22 MB) because the ML Kit
AARs ship every ABI. Play's per-ABI splits mean a real arm64 device downloads
roughly **70 MB**, not 129 MB. `flutter build ios --release --no-codesign`
compiles against the iOS 26 floor; the built bundle carries the right id,
`SoloGallery` display name, `MinimumOSVersion 26.0`,
`ITSAppUsesNonExemptEncryption`, and `PrivacyInfo.xcprivacy`.

**Icon:** the app's own month grid — six cells, the first filled — in
off-white on near-black. Two earlier directions were rejected *by looking at them
at launcher size*: an off-white ground with six filled cells read as the Android
app-drawer glyph and the quiet cells vanished at 96 px. Outlining five and
filling one also survives Android's themed layer, which is an alpha mask and
would flatten a colour-only hierarchy. Regenerate with
`dart run tool/gen_app_icon.dart && dart run flutter_launcher_icons`.

**On device** (Pixel 9 Pro XL, new id): `consent_test` 4/4, `test_fixtures_test`
2/2 (proves the un-bundled fixture path), `consent_flow_test` patrol 4/4.

---

## Verified how

1. `tool/check.sh` — 334 host tests.
2. Merged release manifest asserted for both absence (network/privacy
   permissions) and presence (`allowBackup="false"`, new package, minSdk 35).
3. `flutter build apk --release` + `appbundle` + install and run on device.
4. `flutter build ios --release --no-codesign`, then `plutil` on the built
   `Runner.app` for every identity/privacy key.
5. On-device integration + patrol suites under the new id.

## Known limits and next steps

- **Release signing is still the debug key** (deferred by choice). The app
  cannot be uploaded to Play until an upload keystore exists. `key.properties`
  and `*.jks` are already gitignored; wire a `signingConfigs.release` block
  reading it. **Losing that keystore means never updating the app again**, so
  generate and back it up deliberately.
- **ML-under-R8 is verified only indirectly.** The registrar bug was observed
  and confirmed fixed, and the release build indexes without ML errors — but the
  DB could not be read to confirm labels were written, because `run-as` refuses
  non-debuggable packages and Flutter forces `isDebuggable = false` on release.
  A `releaseTest` build type (minified *and* debuggable) would close this.
- **iOS is unverified on hardware** — no iOS device available; config is
  compile-verified only. The iOS 26 floor is deliberate and excludes almost the
  entire current installed base.
- **Still needed for the stores:** hosting `docs/privacy-policy.md` at a public
  URL (Play requires it for photo access), screenshots, a feature graphic, and
  Play Console / App Store Connect setup.
- `test_assets/` still has **no video** — no `ffmpeg` on this machine.
