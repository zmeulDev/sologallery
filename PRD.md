# SoloGallery — Product Requirements

**Status:** Live on Google Play and the App Store.
**Version scheme:** CalVer `YY.M.D+N` — currently `26.8.6+1`.
**Platforms:** Android 15+ (API 35) and iOS 26+. No compatibility code for older
releases.

This document is the internal source of truth for *what SoloGallery is and what
it must do*. How it is built is in [ARCHITECTURE.md](ARCHITECTURE.md); how to
work on it is in [AGENTS.md](AGENTS.md).

---

## 1. The product

SoloGallery is a photo gallery that runs entirely on the phone. No account, no
sync, no cloud, no network calls at all.

**The user.** Someone privacy-conscious who wants a normal, complete photo
gallery — browsing, search, faces, memories, albums — and does not want their
library uploaded, analysed in a data centre, or used to sell them storage. They
are not necessarily technical. They usually arrive after a privacy scare or a
storage-upsell prompt.

**The category insight.** "Photo gallery" is unwinnable against Google Photos and
Apple Photos, both of which are preinstalled, free and excellent. SoloGallery
does not compete on features. It competes on a promise those apps structurally
cannot make: *nothing leaves the device, and you can check.*

**Positioning terms.** Primary: `offline`, `private`, `local`, `no cloud`.
Secondary: `photo vault`, `gallery`, `photo manager`, `face`, `album`.
Deliberately avoided: `backup`, `sync`, `free storage` — wrong intent, and the
app does the opposite. Store copy lives in
[docs/sologallery_store_listings.md](docs/sologallery_store_listings.md).

---

## 2. Product guarantees

These are the reasons the product exists. A change that breaks one is not a
regression to weigh against other priorities — it is disqualifying.

| # | Guarantee | How it is enforced |
|---|---|---|
| G1 | **Zero network calls.** No HTTP client, Firebase, analytics or cloud SDK. | The Android release manifest ships **without** `INTERNET`. ML/tflite/video dependencies that request it have it stripped with `tools:node="remove"`, and the merged manifest is re-verified after any such dependency bump. |
| G2 | **Photos are never duplicated.** | Everything references `photo_manager` asset ids. Favorites, album membership, faces, memories and edits are all keyed by asset id. No file is ever copied. |
| G3 | **Edits are non-destructive.** | Edits are serialized JSON in `edit_instructions`. The original file is never modified. |
| G4 | **All ML is on-device.** | ML Kit and a bundled MobileFaceNet TFLite model, running on a background isolate. Face embeddings never leave the database. |
| G5 | **ML is opt-in and separable.** | Three independent consent flags — search, memories, faces — set at onboarding and changeable at any time in Analysis settings. Declining any of them leaves a fully working gallery. |
| G6 | **No account, ever.** | There is nothing to sign into. |

G1 is the one that makes the rest credible: the claim is *verifiable* rather than
promised, because a user or reviewer can inspect the manifest and see that the
app cannot reach the network even if it wanted to.

---

## 3. Features

Ten shipped feature areas. Each is stated as a user capability with the criteria
that define "working".

### 3.1 Onboarding and consent

Two steps on first run: request photo-library access, then collect the three ML
consent toggles plus the folder scope for analysis.

- Photo access is requested with a pre-permission explanation before the native
  dialog; the button is neutrally labelled ("Continue"), not persuasive.
- Each ML capability is a separate switch. Declining all three is a supported
  end state.
- The user picks which device folders analysis may read; exclusions persist and
  are honoured by the indexer.
- Consent is written in **one database transaction** — a partial write would let
  the indexer read flags mid-update and permanently skip a capability.
- Re-consent is triggered by a consent-version bump, not by app version.

### 3.2 Library — the home gallery

Four filter pills: **All** (default) · **This week** · **Months** · **Year**.

- `All` and `Months` group into month sections; `Months` adds a year hero header.
  `Year` groups into year sections. `This week` is one flat grid of the rolling
  last 7 days.
- Each section shows ≤6 previews, newest first.
- The section header row — label + count + chevron — is **one tap target** that
  opens the full grid. There is no separate "view all".
- The memories carousel sits at the top, under `All` only.
- Undated assets (Android only, `datetaken` null or 0) land in a trailing
  **Older** section.
- Settings is reached from the app-bar gear, not a tab.
- Limited/partial photo access shows a banner and still works.
- While the first metadata sweep runs, the screen shows a loading state — never a
  false "No photos" empty state.

### 3.3 Detail viewer

Full-screen photo and video viewing.

- Top bar (outbound actions, scrim discs): back · add-to-album · share.
- Action bar below (actions on the photo): favorite · info · delete.
- Gestures: swipe left/right for previous/next · swipe down to close · swipe up
  for details · pinch and double-tap to zoom (2× at the tap point) · single tap
  toggles chrome.
- Neighbours are pre-warmed: ±5 full-resolution, ±7 thumbnail placeholders.
- Opening a photo is instant — a cached placeholder renders immediately rather
  than a spinner.
- EXIF is presented in a sheet; assets with no EXIF render correctly.

### 3.4 Search

- Free-text search over on-device OCR content and ML labels.
- Metadata search: date phrases (year, month-year), media type, favorites.
- Browsable ML-label chips for discovery without typing.
- People and album matches appear inline.
- A recently-viewed row on the idle screen, hidden as soon as a query is active.
- The People strip appears here (and on Albums), not on Library.
- Search results paginate.

### 3.5 Saved

Favorites, in a two-column aspect-preserving masonry — deliberately different
from the square grids elsewhere, because this is a small kept set to be *looked
at*, not a haystack to be scanned.

### 3.6 Albums

- User-created albums as a two-column card grid; create, rename, delete, set cover.
- Album detail is a collapsing hero over a three-column grid.
- Album membership is asset-id references only.
- Device folders are browsable from this screen.
- The People strip appears here.

### 3.7 People

- Faces detected on-device are clustered into person identities.
- A person can be renamed, given a cover, merged with another, or separated.
- **A user merge survives the periodic global re-cluster** — merges are stored as
  a redirect, not a move, so the absorbed cluster keeps its faces.
- Faces are filtered by pose before embedding (yaw ≤35°, roll ≤25°, both eyes and
  a nose landmark required), so profile and motion-blurred faces do not pollute
  clusters.
- Requires the faces consent flag; with it off, the People surfaces are absent.

### 3.8 Memories

- Auto-curated collections built on-device from dates, labels and face clusters:
  on-this-day, trips, themes, people.
- Presented as a carousel on the Library screen and played as a timed story
  player with tap / hold / swipe controls.
- **Regeneration upserts on a stable source key** rather than wiping the table,
  so seen and hidden state survives and the carousel does not reshuffle under
  the user.
- Requires the memories consent flag.

### 3.9 Background analysis

- A metadata sweep populates the local index; an ML pass then backfills labels,
  OCR and faces.
- Progress is shown by a small dial riding at the right of the nav capsule,
  carrying the remaining photo count. It disappears when idle. It is shown in
  exactly one place, app-wide.
- Analysis **pauses when the app is not in the foreground** and resumes on return.
- Analysis never blocks the UI: grids are usable throughout.
- Analysis honours folder exclusions and the three consent flags.
- The index can be rebuilt from scratch in Analysis settings.

### 3.10 Settings

- Photo access status and a route to system settings.
- Library statistics.
- Analysis settings: the three consent switches, folder scope, index rebuild.
- Appearance: system / light / dark.
- About.

---

## 4. Non-functional requirements

| Requirement | Target |
|---|---|
| Scroll performance | 60fps through libraries of tens of thousands of photos |
| Tap latency | Instant — a detail view opens on a cached placeholder, never a spinner |
| UI isolate | Never blocked. All ML and every unbounded computation runs on a background isolate |
| Idle behaviour | Indexing, ML and thumbnail warming pause on lifecycle `inactive`/`paused` and resume on `resumed` |
| Grid decoding | Never decode an original for a grid cell — request a sized thumbnail |
| Storage cost | Near zero beyond the database and a capped 200 MB thumbnail disk cache |
| Accessibility | Reduced-motion respected (the one animation jump-cuts); no information carried by colour alone |

---

## 5. Forward

### Planned: non-destructive editor

The only spec'd-but-unbuilt feature. The data layer already exists: the
`edit_instructions` table (schema v1) and `EditInstructionsDao`, which is
registered on the database but currently has **no provider and no callers** —
scaffolding waiting for the feature, and the one knowing exception to the
no-dead-code rule.

Requirements when it is built:

- Edits are stored as JSON instructions keyed by asset id. The original file is
  never touched (G3).
- Editing is reversible: removing the instruction restores the original view.
- The edited rendition is what the app shows; export/share applies instructions
  to a copy rather than to the original.
- A `lib/features/edit/` folder with a pure-Dart domain layer for the instruction
  model, per the standard feature shape.

### Known gaps

The 2026-09-04 audit's findings were closed by
[docs/archived/2026-09-04-remediation.md](docs/archived/2026-09-04-remediation.md)
(test determinism, the People integration test, the missing video fixture, the
red host test, and the eight oversized files — see that document for detail).
Three more were found while closing it out; two remain below. The third —
`cache_live_update_test.dart` failing on the Samsung SM-S938B — turned out to
be a locale bug, not a device one: its delete-confirmation-dialog tap matched
on localized button text (`Selector(text: 'Allow')`), which doesn't hold on a
device set to a non-English locale. Fixed by matching the dialog's stable
framework resource id instead (`Selector(resourceId: 'android:id/button1')`);
see `docs/gotchas.md` ("Patrol / on-device testing") for the diagnosis method.

- **Two on-device Patrol/`integration_test` files assert removed UI behaviour.**
  `integration_test/nav_shell_test.dart`'s "bottom nav" case expects the Search
  field to autofocus when its tab is selected; that behaviour was deliberately
  removed on 2026-07-23 (the doc comment in `search_screen.dart` still explains
  why: "do not auto-focus on entry so the idle screen opens calm"), six weeks
  before the remediation. `integration_test/video_playback_test.dart` looks for
  a `SectionHeader` widget to open the newest month's full grid; Library moved
  to its own `MonthHeader`/`YearHeader` widgets the same day. Neither test was
  updated after that UI change, so both fail reproducibly, unrelated to any
  other code. Confirmed via `git log -L` against the pre-remediation commit
  that changed each behaviour. Needs the test bodies updated to match current
  UI, not a product fix.
- **Signing material is committed to the repository.**
  `android/key.properties` (plaintext store and key passwords) and
  `android/app/upload-keystore.jks` are tracked in git and pushed to the remote;
  `.gitignore` does not exclude either. Anyone with read access to the
  repository can sign builds as this developer. Recorded here as a known issue;
  remediation is being handled outside the engineering backlog.
