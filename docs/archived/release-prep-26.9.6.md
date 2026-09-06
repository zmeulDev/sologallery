# Release prep: v26.9.6 (App Store + Play Store update)

**Goal:** Package everything merged since the last shipped version
(`26.8.6+1`, currently live on both stores per PRD.md) into a new release,
verify it, build release artifacts for both platforms, and hand the user a
checklist for the store-console steps I cannot perform myself (no App Store
Connect / Play Console credentials in this environment).

**Context:** This is an *update* to an already-live app, not a first
submission — confirmed with the user. The last submission (`26.8.1`) was
rejected once (Guidelines 2.3.10 / 5.1.1(iv) / 2.1), fixed, and re-approved
as `26.8.6+1` (see `docs/archived/app-store-rejection-fixes.md`). Since then,
~90 commits landed: the full Swiss-UI accent-color rollout (Phases 0–7,
`docs/plans/swiss-ui-refactor.md`, already marked built/reviewed clean), an
`ExifSheet` rebuild, People-screen relabeling, and a handful of just-finished
bugfixes (album cover circle, recently-viewed placeholder, face-avatar crop
zoom, People-grid seam, semantics label, dialog test fix). None of it changes
data collection/retention — all UI/bugfix work — so the current hosted
privacy policy should not need a content update, only a sanity check.

**Out of scope for this plan** (explicitly not doing these here):
- Fixing the tracked `android/key.properties` / `upload-keystore.jks` secrets
  issue (PRD.md "Known gaps" — "remediation is being handled outside the
  engineering backlog").
- Building the non-destructive editor (unbuilt, PRD.md §5).
- Generating App Store / Play Store screenshots myself — flagged as a
  human-side task below (device screenshots for a store listing are a
  deliberate capture, not a debugging screenshot, but still device work I
  don't have a safe way to do without a live human at the device).
- Actually submitting in App Store Connect / Play Console — I can prepare
  and verify the build, I can't log into either console.

---

## Global constraints (from AGENTS.md / PRD.md)

- Zero network calls — Android release manifest must stay free of
  `INTERNET` / `READ_PHONE_STATE` / `c2dm`.
- Version scheme: CalVer `YY.M.D+N` (marketing `YY.M.D`; build `+N` is the
  Android versionCode and must only ever increase — never reset per day, see
  `docs/gotchas.md` Release/Play signing).
- `tool/check.sh` must pass (analyze + codegen + full test suite) before any
  release build.
- No dead code / no invented APIs / no unused symbols.
- Debugging via `adb logcat`, never screenshots (MediaStore pollution risk).

---

## Steps

- [x] Baseline: working tree clean, `tool/check.sh` green (884 tests) —
      done before this plan was written, as part of finishing the two
      in-progress bugfixes (album-cover-circle-fix, recently-viewed-delete-fix)
      and reverting an accidental `project.pbxproj` objectVersion downgrade.

- [x] **Bump version.** `pubspec.yaml`: `26.8.6+1` → `26.9.6+1`. `PRD.md`'s
      "Status" line updated to match.

- [x] **Re-run `tool/check.sh`** after the version bump — 884 tests, all pass.

- [x] **Android release manifest check** — `:app:processReleaseManifest` ran
      clean (only two benign "tagged to remove but nothing to remove"
      warnings for `READ_PHONE_STATE`/`WRITE_EXTERNAL_STORAGE`, expected since
      no dependency injects them to begin with). Merged manifest grep for
      `INTERNET|READ_PHONE_STATE|c2dm` returned nothing.
      `allowBackup="false"` confirmed present.

- [x] **Android release build + smoke check.**
  - `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (130.8MB).
  - `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (184.9MB).
  - No Pixel 9 Pro XL was connected; smoke-tested on the Samsung SM-S938B
    instead (real device, real photo library) with the user's approval to
    uninstall the existing debug-signed install first (signature mismatch
    blocked an in-place update). Launched via `monkey`, captured `adb logcat`
    for the app's actual PID (confirmed via `pidof`, not just tag-filtered
    noise — a `[Skylo]` location log initially looked alarming but turned out
    to belong to a *different* process on the shared device, not SoloGallery).
    **No `ComponentDiscovery` warning** appeared — the R8/ML Kit registrar
    keep rules in `proguard-rules.pro` still hold, and
    `google_mlkit_*`/`tflite_flutter` versions in `pubspec.yaml` are unchanged
    since the last verified release, consistent with a clean result. No
    on-device UI taps were attempted (real photo library; the project's own
    precedent in `recently-viewed-delete-fix.md` already ruled out blind
    coordinate taps as too risky).

- [x] **iOS release build.**
  - `flutter build ipa --release` → `build/ios/archive/Runner.xcarchive`
    (325.6MB) and `build/ios/ipa/*.ipa` (80.8MB). App Settings Validation:
    version `26.9.6`, build `1`, display name `SoloGallery`, deployment
    target `26.0`, bundle id `com.zmeul.sologallery` — all correct. One
    pre-existing, non-blocking warning: default placeholder launch image
    (already known, `ios/Runner/Assets.xcassets/LaunchImage.imageset/` is
    1×1px stock Flutter default — cosmetic, not required by Apple).
  - Spot-checked the built `Runner.app`'s `Info.plist`:
    `ITSAppUsesNonExemptEncryption=false`, `NSPhotoLibraryUsageDescription`
    present and correct, `CFBundleDisplayName=SoloGallery`. `PrivacyInfo.xcprivacy`
    present in the built bundle.
  - **Gotcha confirmed again:** `flutter build ipa` rewrote
    `project.pbxproj`'s `objectVersion` 60→54 (Xcode-26-on-every-xcodebuild
    behavior, per the `testing-device-iphone-17-sim` project memory). Reverted
    to 60 immediately after the build; `git status` shows no diff on `ios/`
    once reverted.

- [x] **Draft release notes** ("What's New" copy) — see below.

- [x] **Sanity-check store listing copy** (`docs/sologallery_store_listings.md`)
      — read in full: App Store description already has zero Android
      references (the post-rejection fix), Play description is Android-only
      and correct. **Cannot verify these match what's actually live in App
      Store Connect / Play Console** — no console access from here. Flagged
      in the handoff checklist below.

- [x] **Flag stale screenshots.** The accent-color rollout (`docs/plans/swiss-ui-refactor.md`,
      Phases 0–7) changed the visual language app-wide — nav bar, switches,
      selection rings, buttons all recolored, plus a rebuilt `ExifSheet`.
      If the live store screenshots predate this, they're stale. Flagged
      below; not generating them myself.

- [x] **Privacy policy sanity check.** Nothing in this release changes data
      collection/retention (all UI/bugfix work) — confirmed by reading the
      full commit list since `26.8.6+1`. No edit needed to
      `https://zmeul.com/sologallery/privacy.html`, and no "Last updated"
      bump warranted (it describes behavior, not app version).

- [x] **Commit the version bump** (`pubspec.yaml` + `PRD.md`).

### Release notes (drafted)

**App Store "What's New":**
> A visual refresh across the app: a new accent color on navigation, toggles,
> and selection states, plus a redesigned photo-details sheet and clearer
> labels on People actions. Also: album covers are now true circles, deleted
> photos no longer leave a placeholder behind in Recently Viewed, and People
> grid thumbnails look sharper with one less visual seam.

**Play Store release notes** (kept under ~500 chars):
> Visual refresh: new accent color throughout, redesigned photo-details
> sheet, clearer People actions. Fixes: circular album covers, deleted
> photos no longer linger in Recently Viewed, sharper People grid
> thumbnails.

- [ ] **Hand the user a submission checklist** for the console-only steps —
      see "Handoff" section below.

## Handoff — steps only the user can do

1. **Play Console:** upload `build/app/outputs/bundle/release/app-release.aab`,
   paste the Play release notes above, roll out to Production.
2. **App Store Connect:** upload `build/ios/ipa/*.ipa` (Xcode Organizer or
   Apple Transporter — the `flutter build ipa` output already printed this
   exact instruction), paste the App Store "What's New" above, submit for
   review.
3. **Recapture store screenshots** if they predate the accent-color rollout —
   not done here (needs a live person at a device).
4. **Re-verify in each console** (not checkable from here): the App Store
   description still has no Android references, and both descriptions match
   `docs/sologallery_store_listings.md`.
5. Known, deliberately-unaddressed gap carried into this release: Android
   signing material (`android/key.properties`, `upload-keystore.jks`) is
   still tracked in git (PRD.md "Known gaps" — being handled outside the
   engineering backlog, not touched by this plan).

## Next step

Done. All code-side verification and both release builds are complete and
green. Remaining work is the console-only handoff above — nothing further
for me to do here unless the user wants changes to the release notes or
runs into a build/upload issue on the console side.
