# Full test-suite repair — bugs found by running everything

**Status:** complete. Host 634/634 (`tool/check.sh`), all 16 on-device
integration files green on the Pixel 9 Pro XL (`46121FDAS008AA`, Android 17).

**Next step:** nothing outstanding in code. Three housekeeping decisions are
still open for the repo owner — see "Open decisions". Nothing is committed; all
of this is in the working tree.

## Why this exists

`feature/metadata-search` had 22 failing host tests and 5 failing device files
on a clean tree — recent feature commits had landed without updating their
tests. Working through them surfaced four genuine product bugs that no host
test could have caught, which is the real content of this document. The stale
tests are recorded more briefly.

---

## The bugs

### 1. Albums lost the nav-capsule inset — last folder row hidden

`albums_screen.dart` ended its `CustomScrollView` with a **const**
`SizedBox(height: AppSpace.s16)`. The shell's floating nav capsule is reported
to the body as `MediaQuery.padding.bottom` (`Scaffold(extendBody: true)`), so
the last device-folder row sat behind the capsule.

- **Fix:** `SizedBox(height: AppSpace.s16 + MediaQuery.paddingOf(context).bottom)`.
- **Covered by:** `albums_screen_test.dart` — "the trailing spacer clears the
  nav capsule" (it was already asserting this and failing).
- **Note:** the same audit found `settings_screen`, `people_screen` and
  `album_detail_screen` also ignore the system inset. They are *pushed* routes
  outside the shell, so the inset there is only the gesture bar, not the
  capsule — left alone deliberately, not overlooked.

### 2. People's merge snackbar followed the user out of the screen

`_PeopleScreenState.dispose()` hid the "Merged · Undo" snackbar, which is right
for a **pop** — but `/person/:id` is *pushed*, so People is never disposed and
the banner rode along on top of the detail screen. Same family as the existing
`SnackBar.persist` gotcha: the messenger sits above the Navigator.

- **Fix:** an `_open(id)` handler that calls `_messenger?.hideCurrentSnackBar()`
  before `context.push`, wired through a new `onOpen` on `_PersonCard`
  (replacing its internal `context.push`).
- **Covered by:** `people_screen_test.dart` — "leaving People takes the
  confirmation with it". The test also needed its pump budget raised 400 → 600 ms:
  the snackbar's exit animation overlaps the push transition.

### 3. The detail viewer's Location chip was dead on every Android device

The most serious find, and invisible without a device: Android 10+ strips EXIF
GPS out of the bytes handed to an app that lacks `ACCESS_MEDIA_LOCATION`, so
`AssetEntity.latlngAsync()` returned nothing for **every** photo. No error, no
log line — the chip simply never rendered.

Two independent things were missing, and neither is the default:

- the permission was absent from `AndroidManifest.xml`;
- `PermissionRequestOption()` defaults `mediaLocation: false`, and photo_manager
  skips the permission entirely if *either* is missing.

- **Fix:** declared the permission, and added
  `PhotoLibraryService._permissionOption` (`mediaLocation: true`) applied to
  **both** `getPermissionState` and `requestPermissionExtend`.
- **Verified:** `detail_actions_test` 3/3 on device (the coordinate case is the
  proof), and the **release** merged manifest re-checked per DoD #5 — no
  `INTERNET` / `READ_PHONE_STATE` / `c2dm`; five permissions total, the new one
  included.
- **Privacy position:** it reads coordinates already inside the user's own
  photos, on device. No positioning access, no network. It does appear on the
  Play listing.
- **Dead end worth remembering:** MediaStore's own `latitude`/`longitude`
  columns read `NULL` on modern Android no matter what, so querying them is not
  a way to test this.

### 4. Folder ordering disagreed with the date the UI displays

`_androidWindow()` ordered by `DATE_TAKEN DESC`, which puts undated assets last
(SQLite sorts NULLs last on DESC) — but `createDateTime` **falls back to
`DATE_ADDED`**, so those trailing photos reported dates *newer* than everything
above them. On the test device the largest folder ("Restored", imported iOS
photos) is full of `datetaken = NULL` rows, so a flat folder grid ended with
photos dated newer than its top.

- **Fix:** order by `COALESCE(NULLIF(datetaken, 0) / 1000, date_added)` —
  deliberately the same expression photo_manager reports as `createDateTime`.
  `NULLIF` because undated assets carry `0`, not only `NULL`; `/1000` because
  `datetaken` is milliseconds and `date_added` seconds.
- **Windowed queries are unaffected:** their `WHERE` already excludes undated
  assets, and for a dated asset the expression is just `datetaken` in seconds.
- **Verified:** `device_folders_test` passes; MediaStore accepted the
  expression on Android 17.
- **Residual risk:** MediaStore validates sort order on some versions. This is
  one device. Re-check on another Android version before release.

---

## Stale tests (feature work that outran its tests)

| Test | Was asserting | Reality |
|---|---|---|
| `nav_bottom_inset_test` | `AppSpace.s2` grid gutter | `AssetGrid` uses `s4` |
| `folders_ui_test` | Folders on **Search** | moved to **Albums** by design (`search_screen.dart` `_IdleView`) |
| `video_playback_test` | tapped "View all" | the whole `SectionHeader` row is the target |
| `library_screen_test` | `MemoriesCarousel` visible | empty ⇒ zero height ⇒ a viewport reports it **offstage** |
| `library` / `albums` screen tests | multi-year / below-grid content | lazy scrollers never build it on an 800×600 surface |
| `detail_goldens`, `design_goldens` | 11 goldens | action bar is 3 icons now, covers are r12, theme picker is a `SegmentedControl`; 6 goldens had never been generated |

Two of these were **passing vacuously** before: Albums' "People is hidden when
face detection is off" was green only because the strip was off-screen, and the
`detail_actions` GPS case could not distinguish "no geotagged photo" from
"GPS reading is broken" until the fixture was seeded.

Also fixed in the harness: Albums' faces/people streams land on Riverpod's
scheduler (a real timer), so the tests need `pump(10ms)` **then** a bare `pump()`
— the first elapses the timer, the second renders the rebuild it scheduled.

---

## Test-infrastructure changes

- **`cache_live_update_test` converted to `patrol`.** Its assertion always
  passed (~88 ms); the *teardown* hung forever, because
  `PhotoManager.editor.deleteWithIds` goes through `MediaStore.createDeleteRequest`
  on Android 11+ — a system dialog a plain `integration_test` cannot tap. The
  probe row still vanished (uninstall takes app-owned media with it), so the
  cleanup *looked* like it worked.
- **`gps_exif.jpg` now carries a `DateTimeOriginal`** (`tool/gen_test_assets.dart`).
  MediaStore fills `DATE_TAKEN` from it; without one the seeded asset is
  *undated* and can never appear in `libraryMetadataPage(dated: true)` — so
  seeding alone would not have fixed bug #3's test. Stamped at generation time
  so the fixture sorts near the top of a real camera roll. Only that one fixture
  changed; the generator is otherwise deterministic.

## Gotchas recorded in CLAUDE.md

1. `ACCESS_MEDIA_LOCATION` + `mediaLocation: true` are both required, the
   failure is silent, and MediaStore's `latitude` column is not a valid check.
2. Patrol native selectors: use exact `text:`, never `textContains:`, for a
   dialog button. Android's delete dialog is titled *"Allow SoloGallery to
   delete this photo?"* over `Deny`/`Allow`, so `textContains: 'Allow'` matches
   the **title** — a non-clickable `TextView`. Patrol reports that dead tap as
   ✅ and the run then hangs with an all-green step trace, which reads like a
   slow test rather than a missed tap. Corollary: `uiautomator dump` returns
   nothing while patrol holds the UiAutomation connection, so you must kill the
   run to inspect a stuck dialog — it outlives the run.

---

## Verification performed

- `tool/check.sh` → analyze clean, codegen clean, **634/634** host tests.
- All 8 plain `integration_test` files and all 8 `patrol` files pass on device,
  run one file per invocation with a reinstall + `pm grant` between each (the
  documented teardown-uninstall gotcha).
- Release merged manifest re-verified (DoD #5).

## Open decisions (repo owner)

1. **`test/{widgets,features/detail}/failures/*.png`** — I deleted these tracked
   files; they are stale golden-diff artifacts committed in 80e89e0 and are
   regenerated on any golden failure. Restore, or add to `.gitignore`?
2. **`patrol_test/test_bundle.dart`** is tracked but rewritten by every patrol
   run to name whichever test ran last — pure churn, worth gitignoring.
3. **`gps_exif.jpg` is seeded into the real device library** at
   `/sdcard/Pictures/SoloGalleryTest/`. Leave it for future runs, or remove it?

## Follow-ups not done

- Re-check the `COALESCE` sort order on a second Android version (bug #4).
- `detail_actions_test` still carries two `skip:`ped cases (share sheet, delete)
  from before this work.
