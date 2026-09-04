# SoloGallery

A privacy-first photo gallery for Android and iOS that runs entirely on the
device. No account, no sync, no cloud — and no network calls at all.

Live on Google Play and the App Store.

---

## The claim, and how to check it

Most gallery apps ask you to trust a privacy policy. SoloGallery is built so the
claim is verifiable instead:

- The Android release build ships **without the `INTERNET` permission**. ML,
  TFLite and video dependencies that request it have it stripped with
  `tools:node="remove"`, and the merged manifest is re-verified after every
  dependency bump. The app cannot reach the network even if it wanted to.
- There is no HTTP client, no Firebase, no analytics and no cloud SDK in the
  dependency tree.
- Photos are never copied, moved or uploaded. Everything is an asset-id
  reference into the system photo library.
- Every ML feature — search, memories, face grouping — runs on-device via ML Kit
  and a bundled MobileFaceNet model, on a background isolate. Each is a separate
  opt-in switch, and declining all three leaves a fully working gallery.

Verify the manifest yourself:

```bash
(cd android && ./gradlew :app:processReleaseManifest) \
  && grep -R "INTERNET\|READ_PHONE_STATE\|c2dm" \
     build/app/intermediates/merged_manifests/release/
# returns nothing
```

---

## What it does

**Library** — browse by All, This week, Months or Year, with month and year
sections that open into full grids. **Search** — free text over on-device OCR
and image labels, plus date, media-type and favorite filters. **Saved** —
favorites in an aspect-preserving masonry. **Albums** — user albums and device
folders. **People** — faces grouped on-device, renameable and mergeable.
**Memories** — auto-curated collections played as a timed story. **Detail** — a
full-screen viewer with swipe navigation, pinch and double-tap zoom, EXIF, share
and delete.

Full feature requirements: [PRD.md](PRD.md).

---

## Build and run

Requires the Flutter stable SDK (Dart `^3.12.2`), Android 15+ (API 35) or
iOS 26+.

```bash
flutter pub get
dart run build_runner build     # Drift code generation
flutter run -d <device-id>
```

Checks:

```bash
tool/check.sh                   # analyze + build_runner + unit/widget tests
```

On-device tests run one file at a time under Patrol — teardown uninstalls the
app:

```bash
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH" \
  ~/.pub-cache/bin/patrol test -t integration_test/<file>.dart -d <device-id>
```

---

## Documentation

| Doc | What it covers |
|---|---|
| [PRD.md](PRD.md) | What the product is, its guarantees, features, roadmap |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, data model, routing, isolates, caching, ML pipeline, test strategy |
| [AGENTS.md](AGENTS.md) | Rules and conventions for anyone (or any agent) changing the code |
| [CLAUDE.md](CLAUDE.md) | Claude Code specifics — defers to AGENTS.md |
| [docs/design-system.md](docs/design-system.md) | Tokens and the rules behind them |
| [docs/gotchas.md](docs/gotchas.md) | Traps that have already cost a day |
| [docs/plans/](docs/plans/) | In-flight task state and handoff logs |

---

## Stack

Flutter · Riverpod (manual providers) · Drift/SQLite · `go_router` ·
`photo_manager` · ML Kit + `tflite_flutter` · `alchemist` goldens ·
`integration_test` + `patrol`.
