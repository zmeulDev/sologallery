# SoloGallery — Manual Device Test Plan

Step-by-step end-to-end verification on a **real device**. Work top to bottom;
each check has an action, an expected result, and a box to tick. Fill the
**Result** line with PASS / FAIL + a note.

- **Device:** Pixel 9 Pro XL — id `46121FDAS008AA` (Android 17). Substitute your
  own id where you see `$DEV`.
- **App id:** `com.example.sologallery`
- **Privacy contract:** after install the app makes **zero network calls**. Keep
  that in mind — nothing here should ever require connectivity.

---

## 0. Setup (do this once)

```bash
# adb isn't on PATH by default:
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
export DEV=46121FDAS008AA

adb devices                 # confirm your device is listed & authorized
flutter devices             # confirm Flutter sees it
```

Run the app in a way that streams app-side logs (our logger goes to the Dart VM
service, **not** `adb logcat`, so use `flutter run`):

```bash
flutter run -d $DEV         # keep this terminal open; app logs stream here
```

- [ ] App launches to onboarding (first run) or the Library (if already granted).
  **Result:** ____________________________________________

> Tip: to watch indexing/ML logs, filter the `flutter run` output for
> `SoloGallery.ml`. For native crashes only: `adb shell dumpsys dropbox --print`.

### Optional — deterministic photos
If your library is sparse, add a few varied photos before testing (a couple of
scenes, one with **visible small text** — a sign/receipt — and at least one with
**faces**, ideally the same person in 2+ shots). This makes Search, OCR, and
People checks meaningful.

---

## 1. Onboarding & permissions

| # | Action | Expected |
|---|--------|----------|
|1.1| Fresh install → open app | Onboarding screen with an **Allow** button (not "Open Settings") |
|1.2| Tap **Allow** → choose **Allow all** in the native dialog | Lands on Library; photos begin appearing within a few seconds |
|1.3| Relaunch app | Goes straight to Library (no onboarding) |

- [ ] 1.1 **Result:** ______________________
- [ ] 1.2 **Result:** ______________________
- [ ] 1.3 **Result:** ______________________

**Limited access (Android photo-picker subset):**
| # | Action | Expected |
|---|--------|----------|
|1.4| Settings → Photo access → this app → choose **Select photos** and pick a few | App shows only the selected subset |
|1.5| In-app **Settings → "Select more photos"** | System picker reopens; adding photos widens the set on return |

- [ ] 1.4 **Result:** ______________________
- [ ] 1.5 **Result:** ______________________

**Denied / revoke mid-session:**
| # | Action | Expected |
|---|--------|----------|
|1.6| Deny access at the native prompt | App shows an empty/permission state, offering **Open Settings** |
|1.7| Grant in system Settings, return to app | Library populates without a manual restart |
|1.8| While app is backgrounded, revoke access in system Settings, reopen | App detects the revocation on resume and returns to onboarding |

- [ ] 1.6 **Result:** ______________________
- [ ] 1.7 **Result:** ______________________
- [ ] 1.8 **Result:** ______________________

---

## 2. Library home & month grouping

| # | Action | Expected |
|---|--------|----------|
|2.1| Look at the Library home | Sections grouped **by month**, newest month first |
|2.2| Each month section | Shows up to **6 newest** photos + a **"View all N"** control; count matches |
|2.3| Photos captured near a month boundary | Appear in the month they were **captured** (not date-added) — no photo in the wrong month |
|2.4| If you have undated photos (Android) | A trailing **"Older"** section exists; iOS shows none |
|2.5| Scroll the whole list | 60fps, no jank, thumbnails load progressively (no full-res decode stalls) |

- [ ] 2.1 ____ 2.2 ____ 2.3 ____ 2.4 ____ 2.5 ____
  **Notes:** ______________________________________________

---

## 3. Full-month / Older grids + live updates

| # | Action | Expected |
|---|--------|----------|
|3.1| Tap **View all** on a month | Full grid for that month; scroll pages in more without a loading flash |
|3.2| Tap **View all** on Older (if present) | Full grid of undated photos |
|3.3| **Live add:** keep app foregrounded; add a photo to that month via another app (Files/another gallery) | Within ~2s the new photo appears in the home + grid **without** backgrounding the app |
|3.4| **Live delete:** open a photo from a month grid, delete it (§4.4), return | It's gone from the grid immediately |

- [ ] 3.1 ____ 3.2 ____ 3.3 ____ 3.4 ____
  **Notes:** ______________________________________________

---

## 4. Detail viewer & actions

Open any photo (tap a thumbnail).

| # | Action | Expected |
|---|--------|----------|
|4.1| Swipe left/right | Moves between photos horizontally; smooth |
|4.2| Pinch to zoom | Zooms a screen-sized preview (not full original — that's a known limit) |
|4.3| **Favorite** toggle | Heart fills; photo now appears in **Saved** (§6) |
|4.4| **Delete** | OS trash dialog appears; on confirm the photo leaves the app and the device |
|4.5| **Share** | OS share sheet opens with the original file |
|4.6| **Add to album** | Prompts to pick an existing album; photo joins it (§7) |
|4.7| **EXIF** button | Reveals a metadata sheet: dimensions, date, size, mime, GPS (if present), etc. |

- [ ] 4.1 ____ 4.2 ____ 4.3 ____ 4.4 ____ 4.5 ____ 4.6 ____ 4.7 ____
  **Notes:** ______________________________________________

---

## 5. Videos

| # | Action | Expected |
|---|--------|----------|
|5.1| Find a video in the grid | Shows a **duration badge** (e.g. `1:05`) |
|5.2| Open it in the detail viewer | Plays **locally** (no buffering/network); controls work |
|5.3| EXIF sheet for the video | Shows duration + video metadata |

- [ ] 5.1 ____ 5.2 ____ 5.3 ____
  **Notes:** ______________________________________________

---

## 6. Saved

| # | Action | Expected |
|---|--------|----------|
|6.1| Bottom nav → **Saved** | 3-column grid of favorited photos, most-recent first |
|6.2| Unfavorite one (open → toggle heart) | It drops out of Saved immediately |
|6.3| Delete a favorited photo from the device | It disappears from Saved (no broken thumbnail) |

- [ ] 6.1 ____ 6.2 ____ 6.3 ____
  **Notes:** ______________________________________________

---

## 7. Albums

| # | Action | Expected |
|---|--------|----------|
|7.1| Bottom nav → **Albums** | 2-column album cards |
|7.2| Create an album (＋ / create dialog) | New album appears; naming works |
|7.3| Add photos to it via detail **Add to album** (§4.6) | Album cover + count update |
|7.4| Open the album | Album detail grid shows its photos |
|7.5| Long-press an album → delete | Album removed; the **photos themselves are not deleted** |

- [ ] 7.1 ____ 7.2 ____ 7.3 ____ 7.4 ____ 7.5 ____
  **Notes:** ______________________________________________

---

## 8. Search

Tap the **search** action in the Library app bar.

**Metadata facets:**
| # | Action | Expected |
|---|--------|----------|
|8.1| Filter by **date** (a range/period) | Only photos captured in range show |
|8.2| Filter by **media type** (Photos / Videos) | Grid narrows accordingly |
|8.3| Filter by **Favorites only** | Only favorited photos show |
|8.4| Filter by **album name** | Only that album's photos show |

**Content search (needs indexing to have run — see §11):**
| # | Action | Expected |
|---|--------|----------|
|8.5| Type a common object in your photos (e.g. `dog`, `beach`, `food`) | Photos the on-device labeler tagged with it appear |
|8.6| Type text that appears **in** a photo (a sign/receipt word) | The photo is found via **OCR** |
|8.7| Combine a content query with a facet (e.g. `dog` + Videos) | Intersection is correct |

- [ ] 8.1 ____ 8.2 ____ 8.3 ____ 8.4 ____ 8.5 ____ 8.6 ____ 8.7 ____
  **Notes:** ______________________________________________

---

## 9. People & avatars

Requires indexing to have processed faces (§11). Reach People via the **People
strip** on the Search idle screen.

| # | Action | Expected |
|---|--------|----------|
|9.1| Open **People** | Grid of person circles, most-photographed first |
|9.2| **Avatar crop** | Each circle **frames the face tightly** (little background in the corners) |
|9.3| Open a person | Detail shows their photos, newest first |
|9.4| **Rename** the person | Name persists; visible back in the People grid |
|9.5| Reopen after more indexing | The same person isn't split into duplicates (see §11.4) |

- [ ] 9.1 ____ 9.2 ____ 9.3 ____ 9.4 ____ 9.5 ____
  **Notes:** ______________________________________________

> If avatars feel too tight or too loose, that's the tunable `kFaceFill` (1.3)
> in `face_avatar.dart` — note your preference here: ______________________

---

## 10. Settings

Bottom nav → **Settings**.

| # | Action | Expected |
|---|--------|----------|
|10.1| **Photo access** row | Correct status (Full / Limited / No access) + matching caption |
|10.2| **Manage limited** actions | Only present when access is Limited (§1.5) |
|10.3| **Library stats** | Photos / Videos / People counts match reality; "Analysis" reads "Up to date" (or "Analyzing… N left" mid-index) |
|10.4| **Appearance → Light** | Whole app switches to light immediately |
|10.5| **Appearance → Dark** | Whole app switches to dark immediately |
|10.6| **Appearance → System**, then flip the OS dark-mode toggle | App follows the system |
|10.7| Set a theme, **force-quit and relaunch** | The chosen theme **persists** |
|10.8| **Rebuild index** → confirm | Library briefly shows a spinner, then repopulates; stats recount |
|10.9| **About** | Shows version + the "100% on-device… never leave this device" line |

- [ ] 10.1 ____ 10.2 ____ 10.3 ____ 10.4 ____ 10.5 ____ 10.6 ____ 10.7 ____ 10.8 ____ 10.9 ____
  **Notes:** ______________________________________________

---

## 11. On-device ML quality

Indexing runs in the background after access is granted / on resume / on library
change. Give it a minute on a fresh library (watch `SoloGallery.ml` logs in the
`flutter run` terminal). Rebuild index (§10.8) forces a clean pass.

| # | Action | Expected |
|---|--------|----------|
|11.1| **Labels** | §8.5 finds photos by object — the bundled labeler ran |
|11.2| **OCR (higher-res)** | §8.6 finds a photo by **small/distant** text that a tiny thumbnail would miss (OCR runs at 1024px) |
|11.3| **Faces** | People (§9) is populated; avatars are real face crops |
|11.4| **Global re-cluster** | After enough new faces are indexed, duplicate persons of the same face **collapse into one**, and any rename you set is **kept** |

- [ ] 11.1 ____ 11.2 ____ 11.3 ____ 11.4 ____
  **Notes:** ______________________________________________

> §11.4 triggers automatically after ~20 new faces accrue since the last
> re-cluster. To exercise it deliberately: add several new face photos, let
> indexing run, then check People.

---

## 12. Background / lifecycle behavior

| # | Action | Expected |
|---|--------|----------|
|12.1| While indexing, background the app | Indexing **pauses** (no battery/CPU churn in the background) |
|12.2| Foreground again | Indexing resumes; new photos are swept in |
|12.3| Add photos while app is open (§3.3) | Picked up live, no restart needed |

- [ ] 12.1 ____ 12.2 ____ 12.3 ____
  **Notes:** ______________________________________________

---

## 13. Automated on-device integration tests (optional but recommended)

These drive the **real** ML/photo paths. **Photo access must be granted** to the
app first (open it once and Allow) or they abort on the permission precondition.

```bash
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
export DEV=46121FDAS008AA

# Real ML worker: labels + higher-res OCR + faces + tflite embeddings end-to-end
flutter test integration_test/ml_indexing_test.dart -d $DEV

# Month grouping axis (capture-date vs date-added) over real device metadata
flutter test integration_test/library_month_grouping_test.dart -d $DEV

# Foreground library-change listener fires (adds + deletes one app-owned probe img)
flutter test integration_test/cache_live_update_test.dart -d $DEV
```

- [ ] `ml_indexing_test` PASS/FAIL: ______________________
- [ ] `library_month_grouping_test` PASS/FAIL: ______________________
- [ ] `cache_live_update_test` PASS/FAIL: ______________________

> Patrol-driven cases (permission dialogs, seeded delete/share) are `skip:true`
> pending `test_assets/` seeding — not part of this pass.

---

## 14. Privacy / network-free check (release build)

Confirms no dependency injected a network permission. Debug builds legitimately
add `INTERNET` (hot reload) — always verify the **release** merged manifest:

```bash
(cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:processReleaseManifest) \
  && grep -R "INTERNET\|READ_PHONE_STATE\|c2dm" \
     build/app/intermediates/merged_manifests/release/
```

- [ ] The `grep` returns **nothing**. **Result:** ______________________

---

## Known limitations (not bugs)

- Detail **zoom** shows a screen-capped preview, not the full-resolution original.
- **Patrol** permission-matrix + seeded delete/share smokes are skipped until
  `test_assets/` is populated.
- **App id** is still `com.example.sologallery` (pre-release default).

## Troubleshooting

- **No photos after granting:** give indexing a few seconds; check the
  `SoloGallery.ml` logs in the `flutter run` terminal.
- **Integration test says "grant photo access":** open the app once, Allow, rerun.
- **`adb: command not found`:** re-run the `export PATH=…platform-tools` line.
- **Nothing in `adb logcat` from the app:** expected — app logs go to
  `flutter run` / `flutter logs` / DevTools, not `adb logcat`.
