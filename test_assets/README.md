# Deterministic test assets

The set CLAUDE.md ("Test strategy → Deterministic test assets") requires, so
on-device tests never depend on whatever happens to be in the developer's
camera roll. Regenerate with:

```bash
dart run tool/gen_test_assets.dart
cd test_assets && sips -s format heic large_48mp.jpg --out large_48mp.heic
```

Everything here is synthesized — no photos of real people, nothing copied from a
real library. `large_48mp.jpg` is an intermediate for the HEIC and can be
deleted after conversion.

| File | Covers | Status |
|---|---|---|
| `small_png.png` (64×64) | labeling fast path | generated |
| `no_exif.jpg` (800×600) | EXIF-absent rendering | generated |
| `gps_exif.jpg` (800×600) | GPS EXIF chips — tagged 47°22'35"N 8°32'26"E | generated |
| `large_48mp.heic` (8000×6000) | HEIC OOM regression | generated (via `sips`) |
| `synthetic_face.jpg` (600×800) | face detection + clustering | generated |
| a video | thumbnail + duration badge | **must be supplied by hand** |

## The face fixture is a positive control

`synthetic_face.jpg` exists so that "no faces were detected" in
`integration_test/consent_test.dart` means *the consent gate held*, rather than
*there was nothing to find*. Without it that assertion passes on any library
without faces — which is most small ones. (A probe over a real camera roll found
faces in only 6 of 60 photos.)

It lives in `assets/test_fixtures/` but is **not** bundled into the app — a file
called `synthetic_face.jpg` inside a shipped privacy-first photo app invites the
wrong question. Push it to the app-private external directory before running the
face tests (that path is **not** MediaStore-indexed, so it still never pollutes
the real photo library):

```bash
adb shell mkdir -p /sdcard/Android/data/com.zmeul.sologallery/files
adb push assets/test_fixtures/synthetic_face.jpg \
  /sdcard/Android/data/com.zmeul.sologallery/files/
```

`integration_test/support/fixture_file.dart` resolves it and fails with this
exact command if it is missing.

**A drawn face is not automatically detectable.** The first version — flat
shapes, hard edges — was not detected by ML Kit at all. What made it work was
photographic realism: correct proportions (eyes on the horizontal midline about
one eye-width apart), directional shading, and a final Gaussian blur so there
are no vector-sharp edges. `integration_test/test_fixtures_test.dart` asserts on
device that it is still detected, so if a future ML Kit bump stops recognizing
it, that test fails loudly instead of quietly hollowing out the consent tests.

## The video is not generated

`ffmpeg` is not installed on this machine and neither `sips` nor
`package:image` can encode video, so the video asset has to be supplied by
hand — any short local clip works. It is only needed by the video
thumbnail/duration-badge tests, not by the consent tests.

## Seeding a device (only for library-level tests)

The consent and fixture tests do **not** need this — they read the bundled
asset. Only tests that go through `photo_manager` need the files in MediaStore:

```bash
adb push test_assets/ /sdcard/Pictures/SoloGalleryTest/
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d file:///sdcard/Pictures/SoloGalleryTest/
```

This writes into the device's real photo library. Remove with
`adb shell rm -r /sdcard/Pictures/SoloGalleryTest` plus a rescan.
