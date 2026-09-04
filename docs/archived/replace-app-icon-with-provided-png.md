# Replace app icon with provided artwork + surface in onboarding

## Status

**Shipped 2026-07-27.** Manual verify on Pixel 9 Pro XL (API 37)
confirmed all 5 verification points. `tool/check.sh` green (analyze +
build_runner + 779 widget/unit tests). Brand-mark row pushed the folder
card past the 800×600 test viewport — fixed by `scrollUntilVisible`
(preferred over resizing the viewport; preserves defaults for every
other test).

**Zoom-in follow-up (2026-07-27, same day).** Launcher-icon art visibly
undersized at the default — combined `flutter_launcher_icons` downscale
(1024→432) + Android launcher mask inset (~16%) left only ~37% of the
launcher footprint filled. Diagnosed with `tool/_measure_fg.dart`:
content bbox was 318×318 of 1024 = 31%. Fix: pre-pad the foreground
master to 62% canvas fill via `tool/pad_foreground.dart` (writes
`assets/icon/android_ic_launcher_foreground_1024_padded.png`, leaves the
user-supplied master untouched), point `pubspec.yaml`'s
`adaptive_icon_foreground` at the padded file, re-run
`flutter_launcher_icons`. Reinstalled on Pixel 9 Pro XL, verified the
installed foreground at xxxhdpi now contains 269×269 of 432 = 62.3%
content with 82px margin (18.9%) per side — Android safe-zone target.
Non-destructive: original master unchanged, `tool/pad_foreground.dart`
is idempotent and re-runnable if the user updates the source.

The on-device APK matches what `flutter_launcher_icons` emitted:
adaptive icon wired to all three layers (background/foreground/
monochrome) at every DPI; full-bleed `ic_launcher.png` is the new art.

**Resolved ambiguity:** the foreground master
(`android_ic_launcher_foreground_1024.png`) shows three cards only — no
red sun, no ink ridge — while the full-bleed icon and the in-app brand
mark both carry the sun + ridge. Confirmed with user: intentional.
Adaptive-icon foreground is meant to be simpler than the launcher icon
at small sizes; they don't need to match.

## What's in `assets/icon/` now (user-provided)

| File | Size | Purpose |
|---|---|---|
| `sologallery_icon_4096.png` | 180 KB | Full-bleed source PNG (with background card) |
| `sologallery_icon_1024.png` | 32 KB | 1024×1024 full-bleed (iOS master) |
| `sologallery_mark_transparent_4096.png` | 203 KB | Bare mark on transparent canvas (in-app / Android foreground candidate) |
| `sologallery_mark_transparent.svg` | 721 B | Vector source: three offset cards, red sun, ink ridge |
| `android_ic_launcher_foreground_1024.png` | 15 KB | 1024×1024 Android adaptive foreground master |
| `android_ic_launcher_foreground_432.png` | 5 KB | 432×432 Android adaptive foreground (the OS inset drops it to ~363 actual) |
| `ios_AppIcon_1024.png` | 19 KB | iOS AppIcon 1024×1024 master |

Old procedural outputs (`icon.png`, `android_background.png`,
`android_foreground.png`, `android_monochrome.png`) are gone. The
`flutter_launcher_icons` block in `pubspec.yaml` is the only thing that
still references them, and the four referenced files were also consumed
by `tool/gen_app_icon.dart` (generator). Both will be updated.

## What the Explore sweep found

- **`lib/` has zero references to `assets/icon/*`** (no `Image.asset`,
  no `AssetImage`, nothing). The only in-app brand asset usage anywhere
  is the text wordmark `"SoloGallery"`:
  - `lib/features/onboarding/onboarding_screen.dart` lines 128, 230
    (eyebrow at the top of each step)
  - `lib/features/settings/settings_screen.dart` line 203 (About row)
  - `lib/app.dart` line 73 (`MaterialApp.router(title: 'SoloGallery', ...)`)
- **Native splash screens reference no logo image.** Android
  `drawable/launch_background.xml` and `drawable-v21/launch_background.xml`
  both have the image-injection layer commented out — the OS shows
  pure white. iOS `LaunchScreen.storyboard` is the default 168×185
  `LaunchImage` (Apple's, not ours) on white.
- **Web manifest** still points at `web/icons/Icon-{192,512}.png` etc.
  — those exist and are unchanged. Out of scope for "Skip web entirely"
  *unless* we want to swap them too for consistency (flag below).
- **Android mipmaps + iOS AppIcon PNGs** all already exist on disk from
  the last `flutter_launcher_icons` run — those will be overwritten the
  next time it runs.

## The new mark (from the SVG, `viewBox=130 130 252 252`)

Three offset cards:
- back card at `(185, 137)` 190×190 r30, fill `#4A4A46` (text-muted dark)
- mid card at `(161, 161)` 190×190 r30, fill `#8A8A84` (text-secondary dark)
- front card at `(137, 185)` 190×190 r30, fill `#F5F5F3` (background)
- front-card art, clipped:
  - sun: `circle cx=200 cy=243 r=34` fill `#D9452E` (NEW colour, not in tokens)
  - ridge: `M137 356 L182 312 L222 344 L272 302 L327 348 L327 375 L137 375 Z`
    fill `#111110` (text-primary)

Two design observations that need the user's call:

1. **`#D9452E` is a new red.** The CLAUDE.md design-system prose says
   "Error color = ink (no red)" — the icon introduces the app's first
   red. Options:
   - add `accent: #D9452E` to the token table and use it sparingly
     (elsewhere = the in-app mark only);
   - add an `iconAccent` token that exists only for the brand mark;
   - leave it icon-only and don't surface the colour anywhere else.
2. **The bare mark** (`sologallery_mark_transparent_*`) is the three
   cards without any outer background — that's the right asset for the
   onboarding screen top, and for `android_monochrome.png` (silhouette).

## Implementation plan

### Phase 1 — wire the launcher masters (no Dart render)

1. **Update `pubspec.yaml`** (lines 81–88) so `flutter_launcher_icons`
   points at the user-provided files:
   - `image_path`: `assets/icon/sologallery_icon_1024.png` (iOS master)
   - `adaptive_icon_background`: `assets/icon/ios_AppIcon_1024.png` is
     wrong — the **background layer** for Android adaptive needs to be
     a flat tone, not the full art. The user did not provide a dedicated
     background PNG. **Decision needed**: render one from `sologallery_icon_1024.png`
     by sampling the corner pixel (corner pixel ≈ `#F5F5F3` from the SVG
     front card? Actually the full-bleed art has its own outer background
     — needs visual confirmation).
   - `adaptive_icon_foreground`: `assets/icon/android_ic_launcher_foreground_1024.png`
     (user-provided, with safe-margin built in)
   - `adaptive_icon_monochrome`: derived from the transparent mark —
     pick the user's preferred approach (see open question 3).
   - drop the comment that says "masters are generated by tool/gen_app_icon.dart"
     because that's no longer true.
2. **Keep or retire `tool/gen_app_icon.dart`** — it is now obsolete.
   Recommend `git rm` it so future readers don't try to run it.

### Phase 2 — surface the mark in the in-app start screen

**Subject:** SoloGallery's onboarding. Audience: people who chose this
app *specifically* to keep photos on their phone. Single job: make the
user feel safe enough to grant access (step 1) and opt into on-device
analysis (step 2). The mark — three offset cards with a sun and ridge —
reads as *a stack of held photos seen from above*, which is what the
app literally is. That's the design material to lean into, not
decorate around.

**Design plan (single pass, post-critique):**

- **Palette:** no new tokens. The mark carries its own three-card
  palette (`#F5F5F3` / `#4A4A46` / `#8A8A84`) and the design system
  forbids decorative accent. Adding `#D9452E` to the chrome would
  undercut the "your photos never leave the device" copy with
  unnecessary heat.
- **Type:** unchanged. The 11sp / 600 / 0.08em tracked `sectionLabel`
  wordmark *is* the project's typographic signature. Don't replace it;
  pair with it.
- **Layout: side-by-side, inline-leading.**
  ```
  ┌────────────────────────────────────────┐
  │  ▓▓  SoloGallery                        │   ← mark + wordmark
  │                                        │
  │        Your photos                     │
  │        stay yours.                     │   ← display headline
  ```
  Not a centred splash card (would make the mark fight the headline).
  Not a stacked mark-over-text (would split the identity into two
  units). The mark + wordmark is *one name for the same thing* — they
  belong on one row, with `crossAxisAlignment: center`.
- **Signature:** the pair itself. The existing screen had only the
  wordmark; the new mark now makes the brand anchor carry the project's
  visual subject (a stack of held photos). The display headline is the
  promise; the mark is the project.
- **Step 1 vs step 2:** **identical treatment.** Brand anchor doesn't
  change between steps. Only headline / body / CTA change.
- **Risk taken:** the mark is *not* a generic app-icon-as-decoration.
  It's three offset cards with visible top edges — the user reads it as
  "stack of photos" in one glance. That's the visual subject. Most
  onboarding marks don't carry that much content.
- **Critique pass — does it read as a default?**
  Not a warm-cream-and-terracotta hero (palette-forbidden).
  Not a near-black-and-acid-green callout (no accent).
  Not a broadsheet grid (this is mobile with a 24px screen inset).
  Not a centred logo-on-top hero card (would crowd the display).
  Not a letter-avatar (we have a real mark).
  The plan is a *choice made for this brief*.

**Concrete dimensions:**

- Mark render size: **56 logical px high, ~60 wide**. The mark is
  1:1 within its transparent canvas, but the offset cards make it read
  horizontally slightly wider than tall; render as `width: 60,
  height: 56` so the natural silhouette holds.
- Gap: **12px** (`AppSpace.s12`) right of the mark, before the
  wordmark text.
- The mark row replaces the single `Text('SoloGallery', …)` widget on
  both steps (lines 127–130, 229–232). Everything else is untouched.

**Theme handling:**

- The mark's two back cards are dark grey (`#4A4A46` / `#8A8A84`),
  which sit cleanly on the light `background` token.
- On the dark theme, the dark back cards vanish into the dark
  background. To preserve the silhouette, wrap the mark in a
  `Container` with `decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(12))` and a `border: Border.all(color: colors.border, width: 0.5)` — a hairline frame that reads as "card on card" using the existing tokens, not as a new colour.
  No `ColorFiltered` (filtering chrome is bad practice; the frame
  reads correctly in both themes).

**Implementation steps:**

3. **Bundle the bare mark.** Add
   `sologallery_mark_transparent_4096.png` to `pubspec.yaml`'s
   `flutter.assets:` block. The 4096 master is downscaled by Flutter's
   `Image.asset` at draw time; caching is automatic on first paint.
   Do NOT add `flutter_svg` for this — overkill for one widget.
4. **Add a private `_BrandMark` widget** to
   `lib/features/onboarding/onboarding_screen.dart` (or a small
   `widgets/` file if preferred). Accepts `height: 56` and renders the
   asset at `width: 60, height: 56`, wrapped in the themed frame
   described above. Use `Image.asset`, not `Image.memory` — Flutter's
   asset cache is the right layer here.
5. **Replace the wordmark-only row** on both `_buildAccessStep` and
   `_buildConsentStep` with a `Row` containing the `_BrandMark` and the
   existing `Text('SoloGallery', …)`. `crossAxisAlignment:
   CrossAxisAlignment.center`. `mainAxisSize: MainAxisSize.min`.
6. **Validate on device** that the mark + wordmark reads as one unit at
   the standard font scaler (1.0×), and that it survives a 1.4×
   scaler without crowding the headline below.

### Phase 3 — native splash (lower priority, optional)

6. **Android splash**: uncomment the `<bitmap>` block in
   `drawable/launch_background.xml` and `drawable-v21/launch_background.xml`,
   point at a new `mipmap/launch_image` (added to `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi`).
   This requires regenerating the bitmaps — would be a
   `flutter_native_splash`-style task; out of scope unless the user
   wants it.
7. **iOS splash**: same idea — add a transparent-mark `LaunchImage`
   set in `Assets.xcassets/LaunchImage.imageset/` and reference it from
   `LaunchScreen.storyboard`. Out of scope.

### Phase 4 — verify

8. Run `dart run flutter_launcher_icons` with the rewired
   `pubspec.yaml` and verify every Android mipmap + iOS AppIcon PNG
   updates. (Per-platform content hash differs from before — sanity check.)
9. `flutter build apk --debug && adb install -r build/...` onto the
   Pixel 9 Pro XL (`46121FDAS008AA`, API 37) per CLAUDE.md Environment notes.
10. Manual end-to-end:
    - launcher grid → adaptive icon visible
    - long-press launcher icon → themed (monochrome) layer reads cleanly
    - onboarding step 1 → mark visible above the "SoloGallery" eyebrow
    - onboarding step 2 → same
11. `tool/check.sh` passes.
12. `docs/gotchas.md`: no new traps.
13. Plan marked complete.

## Open questions for the user (resolved)

1. ~~**`#D9452E` red token.**~~ → **Keep it icon-only.** Don't add to the
   design-system colour table; the icon is the only place it appears.
2. ~~**Android adaptive background.**~~ → **Sample the corner from
   `sologallery_icon_1024.png`** (one-line Dart script, written during
   implementation). Write `assets/icon/android_background.png`.
3. ~~**Android monochrome layer.**~~ → **Derive from the transparent
   mark via luminance-to-alpha.** Tiny script using `package:image`,
   greyscale the transparent mark then map luminance → alpha, save as
   `assets/icon/android_monochrome.png`.
4. ~~**Web icons (`web/icons/Icon-192.png` etc.).**~~ → **Leave as-is.**
   Out of scope per "skip web entirely"; old six-cell grid stays in the
   web manifest.
5. ~~**Onboarding mark size / position.**~~ → **Resolved by the
   `/frontend-design:frontend-design` pass (Phase 2 above):** 56×60
   inline-leading, on the same row as the wordmark, 12px gap, themed
   hairline frame on dark. Identical treatment on both steps.

## Files touched (expected)

- `pubspec.yaml` — rewrite `flutter_launcher_icons` block, add the
  transparent mark under `flutter.assets:`
- `lib/features/onboarding/onboarding_screen.dart` — add the mark above
  the eyebrow on both steps
- `assets/icon/android_background.png` — newly written (if option a/b in
  question 2)
- `assets/icon/android_monochrome.png` — newly written (if option b in
  question 3)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` — overwritten
  by `flutter_launcher_icons`
- `android/app/src/main/res/mipmap-*dpi/ic_launcher*.png` — overwritten
- `tool/gen_app_icon.dart` — likely deleted (`git rm`), no longer the
  source of truth
- `docs/spec.md` — only if question 1 ("add `#D9452E` token") is yes
- `docs/plans/replace-app-icon-with-provided-png.md` — marked complete

## Out of scope (called out, not done)

- Native Android/iOS splash screen brand asset (Phases 3 steps 6–7)
- Web manifest update (decision pending)
- Settings → About visual brand update (it's a list row today, low value)

## Next step

Plan closed. Follow-ups (out of scope, called out earlier):

- **Native Android/iOS splash screen brand asset** (Phase 3) — would
  require uncommenting Android `<bitmap>` in `launch_background.xml`,
  regenerating `mipmap-*/launch_image.png` from the bare mark, and
  adding a transparent-mark `LaunchImage` set in
  `ios/Runner/Assets.xcassets/LaunchImage.imageset/`. Both currently
  show pure white (Android) or Apple's default 168×185 LaunchImage on
  white (iOS).
- **Web manifest update** (web/icons/Icon-{192,512}.png etc.) —
  intentionally skipped ("skip web entirely").

No new traps for `docs/gotchas.md`. No CLAUDE.md pruning needed.
