# UI System Refresh — minimalist/slick/modern pass

**PLAN COMPLETE** (2026-07-20). All five phases landed; `tool/check.sh`
green (360 host tests), 18/18 goldens byte-identical after Phase 5
(md5-verified), six on-device suites green on Pixel 9 Pro XL incl. a
reduced-motion re-run. Remaining human-eye items in "Remaining for user"
at the bottom.

## Status

- [x] **Phase 1 — Tokens + sub-themes: DONE** (`tool/check.sh` green, 348 tests).
  Landed: `app_space.dart`, `app_radius.dart`, `app_motion.dart`,
  `AppOverMedia` in `app_colors.dart`, `display`/`button` in
  `AppTextStyles`, error→ink, all five sub-themes in `AppTheme._build`,
  `filled: false` opt-outs (search field, add-to-album create row).
  Deviations from plan, deliberate (no-dead-code rule — every new token
  class needed a first consumer in the same phase):
  - DotNavBar's `AppMotion` migration pulled forward from Phase 4.
  - DurationBadge's `AppOverMedia`/`br4` sweep pulled forward from Phase 3.
  Goldens: `app_dialog_confirm` + `app_dialog_input` added; only
  `add_to_album_sheet` churned (expected — TextButton restyle);
  `exif_sheet`/`detail_action_bar`/`dot_nav_bar`/`duration_badge`
  byte-identical, confirming no theming leak.
- [x] **Phase 2 — AppButton / EmptyState / count labels / CoverRow: DONE**
  (`tool/check.sh` green, 355 tests, zero widget-test edits needed — every
  replaced widget was found by text, never by type).
  Landed: `lib/widgets/app_button.dart` (primary/secondary/quiet, spinner
  ported from onboarding), `lib/widgets/empty_state.dart` (+`.note`),
  `lib/widgets/cover_row.dart` (cover radius 6→`r4`, optional count +
  fallbackIcon), `lib/core/format/count_labels.dart` (+ unit test).
  Deleted: `_PrimaryButton`, `_NewAlbumButton`, `_AlbumsMessage`,
  `_ViewAllButton`, `_LibraryMessage`, `_SavedMessage`, `CenteredNote`
  (month_grid, all 5 importers swapped), `_CenteredNote` (album_detail),
  `_CoverRow` (search), `_AlbumTile` (add_to_album_sheet — now shows real
  covers via `Album.coverAssetId`), AlbumCard `_countLabel`. Onboarding's two
  inline 34pt heroes → `styles.display`.
  Decisions: memory_card semantics adopts `photoCountLabel` — for
  `assetCount == 1` it would read "1 photo" not the old "1 photos", a grammar
  fix unreachable in practice (`MemoryBuilder.minOnThisDayAssets = 5`).
  `AppButton.quiet` tap target is 36 high per spec (old `_ViewAllButton`
  shrink-wrapped to ~26), so Library section headers grew a few px — no golden
  covers them; `month_section_header` golden (plain-Text trailing) untouched.
  `app_button` golden uses `pumpBeforeTest: pumpOnce` — the busy spinner never
  settles.
  Goldens: new `app_button`/`empty_state`/`cover_row`; `add_to_album_sheet`
  regenerated (ListTile→CoverRow); all others verified byte-identical by hash
  diff (incl. `album_card`, `memory_card`, `exif_sheet`, `detail_action_bar`).
- [x] **Phase 3 — AppSheet / dialog helpers / literal sweep: DONE**
  (`tool/check.sh` green, 356 tests, zero widget-test edits — every dialog
  test finds TextButton+text, every sheet test finds by text).
  Landed: `lib/widgets/app_sheet.dart` (`showAppSheet` / `AppSheet` /
  `AppSheetNote`; theme's BottomSheetThemeData paints — sheets no longer
  paint their own Container/Material) and `lib/widgets/app_dialog.dart`
  (`showAppConfirmDialog` → bool, `showAppTextInputDialog` → trimmed/null;
  private `_TextInputDialog` StatefulWidget owns the controller so it is
  disposed after the route unmounts — the person_detail crash pattern).
  Deleted: exif sheet Container/handle/`_Title`/`_SheetNote`, add-to-album
  Material/handle/`_ListNote`, `_CreateAlbumDialog`, `_RenameDialog`, and
  all four inline confirm AlertDialogs (albums delete, detail delete,
  settings rebuild, memories hide) — all six inline dialog builders gone,
  strings preserved exactly (memories keeps 'Keep' via `cancelLabel`).
  Decisions/deviations:
  - `showAppTextInputDialog` gained an optional `maxLength` (not in the
    spec signature) so album create keeps its `maxLength: 200` counter.
  - Person rename now trims and treats blank as cancel (helper semantics;
    the old dialog could pop '' and rename to empty) — deliberate.
  - `AppSheet` wraps `child` in a loose `Flexible`, so AddToAlbumSheet's
    inner scrolling list stays bounded under the modal while the sheet
    still shrink-wraps in unbounded contexts (goldens).
  - ExifSheet's chips keep their old insets via an explicit
    `fromLTRB(s20, s8, s20, s24)` around the unified AppSheet header;
    notes adopt AppSheetNote's unified `(20, 24, 20, 28)` padding.
  Literal sweep done across asset_grid, library (preview gap 3→s2 and
  br4 — approved), saved, album_detail, albums, people, detail_screen +
  action bar + photo/video pages, memory_card + memory_player (`_Message`
  → `AppOverMedia.glyphFaint`, value-identical white54), onboarding
  (28→s24 — approved), settings + limited_access_banner (br12), and
  add_to_album `_CreateRow` (`styles.body.copyWith`). Durations left for
  Phase 4 (AppMotion is Phase-4 scope). Left untokenized (no exact token):
  transparent gradient ends `0x00000000`; memory_player title-card
  gradient starts `0x59000000`/`0x26000000` and count caption
  `Colors.white60` (glyphFaint is white54 — not a match); assorted
  non-scale values (10/14/18/3/6/28 gaps, positioned insets, glyph/handle
  sizes, segment radius 1).
  Goldens: new `app_sheet` (content column only — the sheet surface/shape
  come from BottomSheetThemeData and only paint inside a real modal route;
  stated in the test comment). Regenerated `exif_sheet` +
  `add_to_album_sheet` (structure churn, expected). All 17 others verified
  byte-identical by md5 diff (incl. `detail_action_bar`, `memory_card`,
  `duration_badge`, `album_card`, `filter_pill`, `dot_nav_bar`,
  `limited_access_banner`).
- [x] **Phase 4 — Micro-motion: DONE** (`tool/check.sh` green, 360 tests;
  all 18 goldens verified byte-identical by md5 diff before/after — zero
  churn, zero regens).
  Landed:
  - **Thumbnail fade-in** (`asset_thumbnail.dart`): `AnimatedSwitcher` on
    `AppMotion.of(context, AppMotion.medium)`; placeholder keyed
    `ValueKey('ph')`, image keyed by assetId (same-asset byte refresh never
    re-fades; `gaplessPlayback` kept); static `_fillLayout` layoutBuilder
    (`Stack` + `StackFit.expand`) preserves fill-the-cell geometry; cached
    bytes on first build show instantly (switcher never animates its
    initial child). Pure opacity — no extra decode, no per-frame closure.
  - **FilterPill selection ease** — **deviation:** NOT `AnimatedContainer`
    + `AnimatedDefaultTextStyle`. That structure was built first and the
    `filter_pill`/`theme_mode_picker` goldens churned twice: (1) replacing
    `Text(style:)` with `AnimatedDefaultTextStyle` loses the merge over
    Material's ambient `bodyMedium` (pill shrank 3px/row — merge must be
    reproduced explicitly); (2) after fixing size, a residual ~140-pixel
    diff remained on the unselected pill's curved caps only (±1–3/255):
    `Material` strokes the hairline inside its `PhysicalShape` AA clip,
    `ShapeDecoration` strokes unclipped — not reproducible pixel-exact.
    Also `Container` applies `ShapeDecoration.padding` (the 1px side)
    around its child, which `Material` never did. Final shape: one
    `TweenAnimationBuilder<double>` (the plan's sanctioned implicit
    fallback) lerps fill/side/label colors on one `AppMotion.short` +
    `AppMotion.curve`, still building the ORIGINAL `Material` + `InkWell`
    pill → end states byte-identical by construction. The selected side is
    a transparent width-1 stroke (not `BorderSide.none`) so the lerp never
    pops between border styles; `animationDuration: Duration.zero` stops
    Material's own 200ms shape animation chasing the per-frame values.
  - **`lib/widgets/pressable.dart`**: `Listener` (pointer down/up/cancel
    drives the visual — held through a long-press, unlike `onTapDown`
    which cancels when the long-press wins) over `GestureDetector`
    (semantics + arena, `HitTestBehavior.opaque` as the cards had) over
    `AnimatedScale` 0.97 @ `AppMotion.pressed`/`curve`. Adopted on
    `AlbumCard`, `MemoryCard`, `_PersonCard` only — grid cells excluded
    per plan (neighbor jitter / 60fps). All card tap + long-press tests
    passed unmodified. Minor deviation: `_PersonCard`'s old detector used
    default (deferToChild) hit testing; Pressable is opaque like the other
    cards — gaps in the card column are now tappable (an improvement).
  - **Off-token sweep:** detail `_Chrome` 180ms → `medium`, video page
    play-glyph 150ms → `short`, memory-player progress dim 180ms →
    `medium` (values unchanged, now reduced-motion gated). Memory player
    auto-advance 320ms: no token matches (deliberate story pacing) — kept
    320ms but routed through `AppMotion.of`, with a `jumpToPage` branch
    when it gates to zero (`ScrollPosition.animateTo` forbids
    `Duration.zero`). Left untouched, not motion: Search 280ms debounce,
    memory `pageDuration` 3s timer, indexing 50/200ms isolate yields + 2s
    resweep debounce, photo_library 1s date-window math.
  - **Tests:** `asset_thumbnail_test.dart` moved to bounded pumps
    (`pump()` + `pump(200ms)`, never `pumpAndSettle`) for the fade; new
    `test/widgets/pressable_test.dart` (tap, long-press, scale while
    held, `disableAnimations` → `AnimatedScale.duration == zero` + tap
    still forwards). No goldens added or regenerated.
- [x] **Phase 5 — Icons + docs + device pass: DONE** (`tool/check.sh`
  green, 360 tests; all 18 goldens byte-identical by md5 before/after —
  zero churn).
  **Icon swaps (every symbol verified against the SDK's `icons.dart`
  before use, `flutter analyze` zero issues):** `arrow_back`→
  `arrow_back_rounded`, `add`→`add_rounded`, `close`→`close_rounded`,
  `chevron_right`→`chevron_right_rounded`, `search`→`search_rounded`,
  `favorite`→`favorite_rounded`, `favorite_border`→
  `favorite_border_rounded`, `photo_library`→`photo_library_rounded`,
  `photo_album`→`photo_album_rounded`, `settings_outlined`→
  `settings_rounded`, `edit_outlined`→`edit_rounded`, `info_outline`→
  `info_outline_rounded`, `delete_outline`→`delete_outline_rounded`,
  `ios_share`→`ios_share_rounded` (it exists — the documented exception
  wasn't needed). Test finders (host + integration) swapped in lockstep.
  Plus: `ThemeData.actionIconTheme.backButtonIconBuilder` →
  `arrow_back_rounded`, so the *automatic* AppBar BackButtons (Settings,
  album/folder/person detail) join the family — surfaced on device when
  the nav_shell finder found no `arrow_back_rounded` on Settings.
  **Kept (deliberate — the rounded family has no outlined forms for
  these; the only `_rounded` variant is filled):**
  `photo_library_outlined` + `photo_album_outlined` (dot-nav inactive
  glyphs — the filled `_rounded` would equal the active glyph; also the
  album-cover fallbacks), `add_to_photos_outlined` (would be the only
  filled glyph in the all-outline detail action bar),
  `videocam_off_outlined`, `broken_image_outlined` (lightweight error
  glyphs). `play_arrow_rounded`/`close_rounded` were already rounded.
  **Golden churn: none — and that is correct, not a missed regen.**
  Alchemist's CI variant obscures fonts, so every `Icon` renders as a
  solid box regardless of codepoint; icon-family changes are invisible
  to goldens (now a CLAUDE.md gotcha). 18/18 md5-identical also proves
  the sweep changed no layout/color.
  **Docs:** CLAUDE.md Design system gained Spacing/Radius/Motion/
  Over-media tables, Display+Button typography rows, and System notes
  (error=ink, r20 dialogs/sheets, ink-pill snackbar, rounded icon
  family + kept-outlined list, shared components). One new gotcha
  (goldens can't see glyphs). No other CLAUDE.md sections touched;
  additions only (verified via git diff).
  **Device pass (Pixel 9 Pro XL 46121FDAS008AA, Android 17):**
  - `flutter build apk --debug` ✓
  - patrol `nav_shell_test` ✓ (2/2) — after fixes below
  - patrol `saved_albums_test` ✓ (2/2)
  - patrol `detail_actions_test` ✓ (1 ran, 2 skip-by-design: share
    sheet, destructive delete)
  - patrol `consent_flow_test` ✓ (pre-existing coverage of the consent
    step, untouched)
  - patrol `folders_ui_test` ✓, patrol `video_playback_test` ✓
  - plain `memories_test` ✓ (pre-grant procedure per CLAUDE.md)
  - Reduced motion: all three system animation scales → 0,
    `nav_shell_test` re-run ✓, scales restored to 1 (verified).
  **Pre-existing failure found and fixed (not an icon regression):** the
  consent feature added an onboarding step 2 ("Continue"), but the
  `bootAndGrant` helpers in nav_shell / saved_albums / detail_actions /
  folders_ui / video_playback still expected the grid straight after the
  permission grant — every suite failed with 0 `AssetThumbnail` while
  parked on the consent screen (the silent-empty shape from CLAUDE.md's
  gotchas). All five helpers now decline-and-continue through step 2.

## Remaining for user (human-eye, not automatable)

- 60fps fling smoothness in the Library grid with the thumbnail fade-in
  active (Phase 4) — judge for jank by eye.
- Thumbnail fade-in look during a fling; filter-pill selection ease.
- Card press scale (Albums / Memories / People cards).
- Ink-pill snackbar over the black detail stage ("Added to …").
- Dialog + sheet styling in **both** themes (r20, hairline border,
  TextButton actions; EXIF sheet, add-to-album sheet).
- Onboarding margins + display type on a cold install.
- Rounded icon family overall read — especially dot-nav inactive
  (outlined default family) vs active (rounded filled) pairing, and the
  kept-outlined glyphs listed above.
- System "Remove animations" by hand: memory player should jump-cut
  (`jumpToPage` branch) — only the nav_shell suite was re-run under
  zeroed scales.
- Release-manifest re-verify not repeated (no deps changed; DoD #5 n/a).

**Next step:** none — plan complete. Follow-ups: none beyond the
human-eye list above.

## Context

A UI audit found the theme core (`lib/core/theme/`) exact to CLAUDE.md, but the
component layer is fragmented: 5 different button treatments, 6 raw M3
`AlertDialog` call sites, ~8 duplicate empty/error message widgets, no
spacing/radius token scale (grid gaps 2 vs 3 vs 16, ad-hoc section rhythm), two
bottom-sheet idioms with duplicated grab handles, untokenized over-media scrims,
default `SnackBar`, mixed icon families, and `ColorScheme.error` still Material
red. Goal: consolidate into one design system with a visual step-up.

**User decisions (locked):** system refresh (layouts unchanged) · platform-default
typeface (no bundled font) · subtle micro-motion only (no hero transitions).

**Design stance:** the inverted-ink pill (`pillActiveBg`) becomes the unifying
motif of every action surface (primary buttons, dialog actions, snackbar).
Everything else stays quiet. No red anywhere — errors are carried by copy, as
they already are today.

## Phase 1 — Tokens + component sub-themes (`lib/core/theme/` only)

- **`app_space.dart`** — `abstract final class AppSpace`: const doubles
  `s2 s4 s8 s12 s16 s20 s24 s32`. Const class, NOT a ThemeExtension (theme-
  invariant, keeps `const EdgeInsets` const).
- **`app_radius.dart`** — `AppRadius`: `r2` (grab handle/segments), `r4` (grid
  cells, DurationBadge), `r12` (cards, banner, filled inputs), `r20` (sheets AND
  dialogs — dialogs drop M3's 28). Pills = `StadiumBorder`. Plus
  `br4/br12/br20` BorderRadius consts.
- **`app_motion.dart`** — `AppMotion`: `pressed 110ms`, `short 150ms`,
  `medium 180ms`, `nav 260ms` (tokenize DotNavBar's existing value),
  `curve = easeOutCubic`, and `AppMotion.of(context, d)` → `Duration.zero` when
  `MediaQuery.disableAnimations` (single reduced-motion gate; DotNavBar's inline
  check at `dot_nav_bar.dart:39` migrates to it in Phase 4).
- **`AppOverMedia`** static-const class in `app_colors.dart` (NOT a
  ThemeExtension — over-media values are theme-invariant and must stay const):
  `scrim 0x99000000`, `scrimHeavy 0xB3000000`, `scrimDeep 0xD9000000`,
  `glyph white`, `glyphSoft white70`, `glyphFaint white54`, `glyphDim white24`,
  `glyphGhost white12`, `segment 0x8CFFFFFF`, `segmentOff 0x40FFFFFF`,
  `playScrim 0x66000000` (values harvested from existing literals).
- **`app_text_styles.dart`** — add `display` (34/w700/ls −0.4/height 1.08) and
  `button` (15/w600) to `AppTextStyles` (constructor + `copyWith` + `lerp` +
  `standard`).
- **`ColorScheme.error` → ink**: light `#111110`/on `#F5F5F3`, dark
  `#F0F0EE`/on `#111110`, with a comment documenting the no-accent rationale.
- **Sub-themes in `AppTheme._build`:**
  - `DialogThemeData`: surface bg, no tint, `br20` + hairline border side,
    title `body` 16/w700, content `body`/textSecondary → all 6 AlertDialog
    sites restyle with zero call-site edits.
  - `TextButtonThemeData`: onSurface fg, `StadiumBorder`, `button` style at 14,
    h16/v8 padding. Dialog actions stay plain `TextButton` (test finders
    `widgetWithText(TextButton, 'Create'/'Delete')` in
    `albums_screen_test.dart:87,104` survive).
  - `InputDecorationTheme`: `filled` surface2, `br12`, no border side, focused
    side textMuted, hint `body`/textMuted. **Opt-outs required:** Search app-bar
    field (`search_screen.dart:99`) and AddToAlbumSheet create row
    (`add_to_album_sheet.dart:158`) add `filled: false`.
  - `BottomSheetThemeData`: surface, no tint, vertical-top `r20`, antiAlias
    (sheets adopt in Phase 3; harmless before).
  - `SnackBarThemeData`: floating, `pillActiveBg` bg + `pillActiveText` text,
    `StadiumBorder` — the inverted-ink pill snackbar (fixes default M3 snack in
    `detail_screen.dart`).
- **Normalization decisions (applied in Phase 3):** Library preview gap 3→2
  (`library_screen.dart:187-188`); onboarding horizontal 28→`s24`;
  People/Albums 16px card gaps stay (different density class).
- **Tests:** new goldens `app_dialog_confirm` + `app_dialog_input` in
  `test/widgets/design_goldens_test.dart` (build AlertDialog directly, light+
  dark). Regen `add_to_album_sheet` (button restyle); verify
  `limited_access_banner`. `exif_sheet`/`detail_action_bar` must be
  byte-identical — unexpected churn = bug. Full `tool/check.sh`.

## Phase 2 — AppButton, EmptyState, count labels, CoverRow (+ all adoptions)

No-dead-code rule: each widget lands with all its adoptions in the same step.

- **`lib/widgets/app_button.dart`** — `Material`+`InkWell` based (not M3
  buttons), three constructors:
  - `.primary` — inverted-ink pill, `button` style, h52, `busy` spinner ported
    from onboarding `_PrimaryButton`, `expand` flag.
  - `.secondary` — surface2 fill + hairline side, h40, optional leading icon
    (replaces Albums' `FilledButton.tonalIcon`).
  - `.quiet` — no fill, textSecondary `filterPill` label, optional trailing
    chevron (replaces Library `_ViewAllButton` + Search bare "See all").
  - Adopt in: `onboarding_screen.dart` (also inline 34pt heroes →
    `styles.display`), `albums_screen.dart`, `library_screen.dart`,
    `search_screen.dart`. Delete the four old implementations.
- **`lib/core/format/count_labels.dart`** — pure-Dart
  `photoCountLabel(int, {String? zero})` (`'1 photo'/'N photos'`; AlbumCard
  passes `zero: 'Empty'`). Adopt: `album_card.dart`, `people_screen.dart:100`,
  `search_screen.dart:313`, `memory_player_screen.dart:254`,
  `memory_card.dart:46`. Unit test.
- **`lib/widgets/empty_state.dart`** — replaces 5 of the 8 message widgets:
  - `EmptyState({title, detail, action})` — title `body`/w600, detail
    `caption`/textSecondary, optional CTA slot (Albums keeps its CTA, now
    `AppButton.secondary`).
  - `EmptyState.note(text)` — the single centered note (current `CenteredNote`),
    `textAlign: center`.
  - Deletes: `_LibraryMessage`, `_SavedMessage`, `_AlbumsMessage`,
    `CenteredNote` (imported by search/people/person_detail/folder_detail/
    older_grid — swap all), `_CenteredNote` (album_detail). NOT folded in:
    `_SheetNote`/`_ListNote` (Phase 3 `AppSheetNote`), memory `_Message`
    (over-media, retinted Phase 3). **No icon** — the system is text-led; none
    of the existing states has one.
- **`lib/widgets/cover_row.dart`** — promote Search's `_CoverRow`; `count`
  optional, optional `fallbackIcon`; cover radius normalized to `r4`. Adopt in
  `search_screen.dart` (albums + folders) and `add_to_album_sheet.dart`
  (`_AlbumTile` → CoverRow; kills stock ListTile + hardcoded 14pt style, shows
  real covers via `Album.coverAssetId`).
- **Tests:** new goldens `app_button` (3 variants + busy), `empty_state`
  (±CTA), `cover_row` (cover/placeholder/no-count), light+dark.
  `album_card` golden byte-identical. Grep albums empty-state test for
  `FilledButton`-by-type finders.

## Phase 3 — AppSheet + dialog helpers + literal sweep

- **`lib/widgets/app_sheet.dart`** — `AppSheet({label, child})`: theme-painted
  surface (BottomSheetTheme), 36×4 textMuted `r2` grab handle (deduped from
  `exif_sheet.dart:47-54` / `add_to_album_sheet.dart:82-89`), optional
  `sectionLabel` header, `SafeArea(top: false)`, keyboard inset.
  `AppSheetNote(text)` replaces `_SheetNote`/`_ListNote`.
  `showAppSheet<T>(...)` wraps `showModalBottomSheet` (drop the
  transparent-background idiom). `showExifSheet`/`showAddToAlbumSheet`
  signatures unchanged.
- **`lib/widgets/app_dialog.dart`** — helpers, not a widget class (visuals come
  from DialogTheme):
  - `showAppConfirmDialog(...) → Future<bool>` — albums delete, detail delete,
    settings rebuild, memories hide.
  - `showAppTextInputDialog(...) → Future<String?>` — album create, person
    rename; owns controller lifecycle once (gotcha at
    `person_detail_screen.dart:59-62`), trims, null on blank.
- **Literal sweep** (mechanical; only Phase-1e normalizations visibly change):
  `asset_grid.dart` → `s2`; `library_screen.dart` (gap 3→2, `br4`, section
  tokens); `saved_screen.dart`; `album_detail_screen.dart`;
  `albums_screen.dart`; `people_screen.dart`; `asset_thumbnail.dart`
  (`AppOverMedia.scrim`/`glyph`, `br4`); `detail_screen.dart` +
  `detail_action_bar.dart` + `photo_page.dart` + `video_page.dart` (scrims →
  `AppOverMedia.*`); `memory_card.dart` + `memory_player_screen.dart`;
  `onboarding_screen.dart` (28→`s24`); `settings_screen.dart` +
  `limited_access_banner.dart` (`br12`, tokens).
- **Tests:** new golden `app_sheet`; regen `exif_sheet` + `add_to_album_sheet`
  (structure changed). `memory_card`/`detail_action_bar`/`duration_badge`
  goldens byte-identical (token transcription check). AddToAlbumSheet test:
  ListTile → CoverRow finders. Bounded pumps everywhere per gotchas.

## Phase 4 — Micro-motion (no new packages; all durations via `AppMotion.of`)

- **Thumbnail fade-in** (`asset_thumbnail.dart`): `AnimatedSwitcher` 180ms,
  placeholder keyed `'ph'`, image keyed by assetId, `layoutBuilder` preserving
  `StackFit.expand`. Initial build with cached bytes shows instantly (switcher
  never animates initial child); `gaplessPlayback` stays. Pure opacity on the
  existing thumbnail — no extra decode.
- **FilterPill** (`filter_pill.dart`): `AnimatedContainer` 150ms
  (ShapeDecoration, StadiumBorder+side) + `AnimatedDefaultTextStyle`. End
  states pixel-identical → `filter_pill`/`theme_mode_picker` goldens must NOT
  churn.
- **`lib/widgets/pressable.dart`**: `AnimatedScale` 0.97 @110ms on
  pointer-down; forwards tap/long-press; instant under `disableAnimations`.
  Adopt on cards only: `AlbumCard`, `MemoryCard`, `_PersonCard` (long-press
  forwarding must survive delete/hide tests). Grid cells deliberately excluded
  (neighbor jitter; 60fps guarantee).
- DotNavBar migrates inline reduced-motion check to `AppMotion.of`.
- **Tests:** `asset_thumbnail_test.dart` adds bounded 200ms pump after data;
  new `Pressable` widget test (forwards gestures, no animation under
  disableAnimations). No golden churn expected — verify byte-identical.

## Phase 5 — Icon family, docs, device verification

- **Rounded family** (fits stadium/r12 system; `play_arrow_rounded`/
  `close_rounded` already used). Swap `arrow_back`, `add`, `close`,
  `chevron_right`, `search`, `favorite(_border)`, `photo_library(_outlined)`,
  `photo_album(_outlined)`, `settings_outlined`, `info_outline`,
  `edit_outlined`, `delete_outline`, `add_to_photos_outlined`,
  `videocam_off_outlined`, `broken_image_outlined` → `_rounded` variants.
  **Confirm each symbol exists in `Icons` before use** (no hallucinated
  glyphs). `ios_share` kept (universal share affordance) unless
  `ios_share_rounded` exists with matching metrics.
- **Docs:** CLAUDE.md Design system gains Spacing/Radius/Motion/Over-media
  tables + `display`/`button` rows + error-color note + icon-family note;
  prune task-scoped notes; close out plan doc.
- **Device (Pixel 9 Pro XL `46121FDAS008AA`):** `tool/check.sh`; patrol
  (pre-grant gotcha, one file at a time): `saved_albums_test`,
  `detail_actions_test`, `nav_shell_test`, `memories_test`,
  `consent_flow_test`. Manual: 60fps fling with fade-in active; dialogs +
  sheet + snackbar light+dark; system "Remove animations" → everything
  instant; onboarding flow.

## Phasing

| Phase | Content | Size |
|---|---|---|
| 1 | Tokens + sub-themes + error color | M |
| 2 | AppButton / EmptyState / count labels / CoverRow + adoptions | L |
| 3 | AppSheet / dialog helpers / literal sweep | M-L |
| 4 | Micro-motion | M |
| 5 | Icons + docs + device pass | S-M |

Each phase: land → `--update-goldens` for listed files only → review that ONLY
those churned → `tool/check.sh` → update handoff doc.

## Risks

- `AppTextStyles` `copyWith`/`lerp` growth is typo-prone — goldens are the net.
- Touched screen tests must keep bounded pumps, dispose-tree teardown for
  DB-watching screens, 500ms shell pump before nav taps (CLAUDE.md gotchas).
- `AnimatedSwitcher` in grids: verify no fling jank on device; fallback =
  one-shot `TweenAnimationBuilder` in a keyed StatefulWidget.
- Unexpected golden churn on `filter_pill`/`limited_access_banner`/
  `memory_card` = theming leak, treat as bug not regen.

## Verification (Definition of Done)

1. `tool/check.sh` green after every phase
2. Patrol suite for touched areas on device
3. Manual end-to-end on device incl. reduced-motion setting
4. No schema changes (DoD #4 n/a); no new Android deps (DoD #5 n/a)
5. New gotchas → CLAUDE.md; plan doc closed; CLAUDE.md pruned
