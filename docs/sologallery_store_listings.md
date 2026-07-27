# SoloGallery — store listing copy

Character counts verified against 2026 limits. Counts shown as `(n/max)`.

---

## Positioning

The differentiator is not "photo gallery" — that category is unwinnable against Google Photos and Apple Photos. It is **offline / no-cloud / no-account**, a query people type deliberately after a privacy scare or a storage-upsell prompt.

Primary terms: `offline`, `private`, `local`, `no cloud`
Secondary: `photo vault`, `gallery`, `photo manager`, `face`, `album`
Deliberately avoided: `backup`, `sync`, `free storage` — wrong intent, and the app does the opposite.

---

## App Store

### App name (27/30)

```
SoloGallery: Offline Photos
```

Alternate, if "private" tests better than "offline":

```
SoloGallery: Private Photos
```

### Subtitle (27/30)

```
Private local photo manager
```

No word repeats the name. Adds `private`, `local`, `manager` to the index.

### Keywords (96/100)

```
album,vault,image,picture,organizer,viewer,face,memory,folder,secure,storage,camera roll,library
```

No spaces after commas — Apple counts them. Singular forms only; the algorithm stems. Nothing here repeats the name or subtitle, since those are already indexed.

### Promotional text (129/170)

Editable without a review submission — use it for launch messaging and swap it later.

```
Now on Android and iPhone. A gallery that ships without internet permission — your photos are read on your device and stay there.
```

### Description (1,742/4,000)

```
SoloGallery is a photo gallery that runs entirely on your phone.

No account. No sync. No cloud. The app makes no network calls at all — on Android it ships without the INTERNET permission, so the claim is verifiable rather than promised.

YOUR LIBRARY, IN PLACE
SoloGallery reads the photos already on your device. It never copies, moves, uploads, or duplicates a single file, so it costs you almost no extra storage.

BROWSE BY TIME
Filter your library by This Week, Months, or Year. Each section shows recent photos first, and one tap opens the full grid.

MEMORIES, BUILT ON DEVICE
Rediscovered moments, assembled by your phone from your own library. Nothing is sent anywhere to make them.

PEOPLE AND SEARCH
Faces are grouped and photos are made searchable by on-device machine learning. Your face data is never uploaded, because there is nowhere for it to go.

SAVED AND ALBUMS
Keep the photos that matter in a flowing two-column view, and organise the rest into albums.

FAST
Built for smooth scrolling through libraries of tens of thousands of photos, with instant taps and no waiting.

WHAT SOLOGALLERY DOES NOT DO
- No sign-in
- No analytics or tracking
- No advertising
- No cloud backup or subscription upsell
- No third-party SDKs collecting anything

Requires Android 15 or later, or iOS 26 or later.
```

---

## Google Play

### Title (27/30)

```
SoloGallery: Offline Photos
```

### Short description (72/80)

```
A private, offline photo gallery. On-device search, faces, and memories.
```

Above the fold, indexed, and the line most users actually read. Carries `private`, `offline`, `gallery`, `on-device`, `search`, `faces`, `memories`.

### Full description (2,412/4,000)

Indexed by Google, so key terms recur naturally 3–5 times. Written to read like prose, not a keyword list — stuffing gets suppressed.

```
SoloGallery is an offline photo gallery for people who would rather their photos stayed on their phone.

There is no account to create, no cloud to sync with, and no server to trust. SoloGallery makes no network calls whatsoever — the release build ships without the INTERNET permission, so you can verify the claim instead of taking our word for it.

NOTHING LEAVES YOUR DEVICE
Most gallery apps upload your library, back it up, or analyse it in the cloud. SoloGallery does none of these. Every feature — search, face grouping, memories — runs locally on your own hardware.

YOUR PHOTOS STAY WHERE THEY ARE
SoloGallery reads the photo library already on your device. It never copies, moves, or duplicates your files, so installing it costs you almost no additional storage. Uninstall it and your photos are exactly where they were.

BROWSE BY TIME
Filter the gallery by This Week, Months, or Year. Photos group into clean sections, newest first, and a single tap on any section header opens the full grid.

MEMORIES
Your phone quietly assembles moments from your own photo library and surfaces them at the top of the gallery. Built on device, from your photos, seen by nobody.

PEOPLE
On-device machine learning groups the faces in your library so you can find every photo of someone in one tap. The face data lives in a local database on your phone and is never uploaded.

SEARCH
Find photos by what is in them, using on-device image understanding. No query ever reaches a server.

SAVED
Keep the photos that matter in a two-column view that preserves each photo's shape instead of cropping it into a square.

ALBUMS
Organise your photo library into albums, with fast covers and no waiting.

BUILT FOR SPEED
SoloGallery is designed for smooth 60fps scrolling through libraries of tens of thousands of photos. Thumbnails load fast, taps respond instantly, and heavy work pauses the moment you leave the app.

WHAT SOLOGALLERY DOES NOT DO
- No sign-in or account
- No analytics, telemetry, or crash reporting
- No advertising or ad SDKs
- No cloud backup, and no subscription upsell
- No third-party SDKs collecting data

PERMISSIONS
SoloGallery asks for photo library access, and nothing else. It does not request internet, location, contacts, or phone state.

Requires Android 15 or later.
```

---

## Beyond the text

**Privacy labels are ASO here.** A clean App Privacy nutrition label ("Data Not Collected") and a Play Data Safety section declaring no collection and no sharing are the strongest possible proof of the listing's central claim. Both stores surface these prominently. Fill them out before the copy.

**Screenshot text is indexed on iOS.** Apple's OCR now reads screenshot captions as a discovery signal, so put the value props in large type on the first two screenshots rather than shipping bare device frames. Suggested captions: "Everything stays on your phone" · "Search without a server" · "Faces grouped on device" · "No account. No cloud."

**Don't claim what isn't built.** The editor is specified but not shipped — keep it out of both descriptions until it exists. Store review will not catch it, but a one-star review saying "there's no edit button" will.

**Play blocker.** The release build is still signed with the debug key, so an upload keystore has to exist before any of this can be submitted.

**Revisit quarterly.** The keyword field is the cheap experiment — it changes with a version submission and moves rankings faster than description edits.
