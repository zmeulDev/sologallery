# SoloGallery — Design system

The complete visual language: tokens, and the prose rules for what they mean.
Golden tests (`test/widgets/design_goldens_test.dart`,
`test/features/detail/detail_goldens_test.dart`) are what make this enforceable —
every new design-system widget gets one, light and dark.

The look is a warm off-white / near-black palette with no accent colour, pill
filters, and a floating nav capsule. There is no brand hue; emphasis comes from
ink, weight and space.

---

## Colors — `AppColors`

A `ThemeExtension<AppColors>` in `lib/core/theme/app_colors.dart`, with const
`.light` / `.dark` instances. Read it as:

```dart
final colors = Theme.of(context).extension<AppColors>()!;
```

| Token | Light | Dark |
|---|---|---|
| background | `#F5F5F3` | `#111110` |
| surface | `#FFFFFF` | `#1C1C1A` |
| surface2 | `#EBEBEB` | `#282826` |
| text primary | `#111110` | `#F0F0EE` |
| text secondary | `#6E6E6A` | `#8A8A84` |
| text muted | `#AEAEA9` | `#4A4A46` |
| pill active bg | `#1A1A18` | `#F0F0EE` |
| border | `rgba(0,0,0,0.07)` | `rgba(255,255,255,0.07)` |

`background`, `surface` and text primary come from the `ColorScheme`;
`surface2`, `textSecondary`, `textMuted`, `pillActiveBg`, `pillActiveText` and
`border` come from the extension.

**Error colour is ink, not red.** `AppTheme` deliberately sets `error`/`onError`
to the ink and background tones. Errors are carried by copy, never by hue.

---

## Typography — `AppTextStyles`

A `ThemeExtension<AppTextStyles>` in `lib/core/theme/app_text_styles.dart`,
addressed by semantic role rather than size:

```dart
final type = Theme.of(context).extension<AppTextStyles>()!;
```

| Role | Size | Weight | Notes |
|---|---|---|---|
| `display` | 34sp | 700 | |
| `pageTitle` | 22sp | 700 | |
| `sectionLabel` | 11sp | 600 | uppercase, 0.08em tracking |
| `filterPill` | 12sp | 500 | |
| `body` | 14sp | 400 | body and list rows |
| `button` | 15sp | 600 | |
| `exifValue` | 12sp | 600 | |
| `exifKey` | 9sp | 400 | uppercase |
| `caption` | 11sp | 400 | |

The default typeface is used deliberately — no custom font is bundled.

---

## Spacing — `AppSpace`

`s2 s4 s8 s12 s16 s20 s24 s32`.

- **s4** — photo-grid gutter (`AssetGrid`: Search results, month/folder grids).
  Cells clip to r12, so a tighter gutter puts adjacent corners on top of each
  other. Also the gutter for *inset* preview grids (Library sections, which inset
  s8 rather than s16 so the grid runs wider than its header).
- **s8** — Saved masonry gutter.
- **s16** — screen inset.
- **s20** — the Library timeline's inter-section rhythm.

**Vertical gaps between stacked sections are owned by the top edge alone.** A top
pad *and* a bottom pad makes the visible gap their sum — which is how the
Library's month rhythm silently drifted to 36px.

Never use a spacing token where a radius is meant, even when the numbers happen
to agree.

---

## Radius — `AppRadius`

Doubles `r2 r4 r12 r20 r30`, plus matching `BorderRadius` consts
`br4 br12 br20 br30`.

| Token | Use |
|---|---|
| r2 | grab handle, progress segments |
| r4 | `DurationBadge` |
| r12 | cards, banner, filled inputs, **every photo thumbnail** — grid cells, previews, row and tile covers |
| r20 | sheets **and** dialogs |
| r30 | the two full-bleed cards — `AlbumCard` and the People strip's `AppCard` |
| — | pills use `StadiumBorder` |

r12 is the rule for thumbnails, with one shape of exception: where a cover
**fills** its card rather than sitting inside it, the image takes the card's own
radius, because two different radii on the same edge read as a mistake. That is
`AlbumCard` (cover and card both r30) and the People strip's card. A thumbnail
inset *within* a card — `CoverRow`, folder tiles, every grid cell — stays r12.

---

## Motion

The app has **no decorative motion**. Every animated widget was physically
deleted. State changes are instant: filter pills, the nav-capsule knob, the
segmented thumb, the indexing dial, thumbnail reveal, chrome show/hide,
onboarding step changes, and the detail drag-dismiss and double-tap zoom all
snap. Route pushes use `NoTransitionPage`.

Two exceptions:

1. **Material defaults** — `showDialog`, `showModalBottomSheet` and `SnackBar`
   keep Flutter's built-in transitions.
2. **The memory-player scene change** — a 320 ms `easeOutCubic` cross-slide
   between story photos, inlined as file-private consts in
   `memory_player_screen.dart`, with a `MediaQuery.disableAnimations` guard that
   jump-cuts under reduced motion.

---

## Over-media — `AppOverMedia`

Theme-invariant consts for chrome sitting on top of photos and video, in
`app_colors.dart`. These are plain statics, **not** a `ThemeExtension` — read
them as `AppOverMedia.scrim`, never through `Theme.of`.

| Group | Tokens |
|---|---|
| Scrims | `scrim` `0x99` · `scrimHeavy` `0xB3` · `scrimDeep` `0xD9` · `playScrim` `0x66` |
| Glyphs | `glyph` · `glyphSoft` · `glyphFaint` · `glyphDim` · `glyphGhost` |
| Progress | `segment` · `segmentOff` |

Never reach for a bare `Colors.white*` over media — there is a token for it.

---

## System notes

- **Dialogs and sheets** share r20 and a hairline border; their actions are
  themed `TextButton`s.
- **Snackbar** is an inverted-ink floating pill (`pillActiveBg`).
- **Icons** are the Material **rounded** family; `ios_share_rounded` for share.
  Outlined glyphs with no rounded-outline variant stay on the default family —
  nav inactive `photo_library_outlined` / `photo_album_outlined`,
  `videocam_off_outlined`, `broken_image_outlined`.
- **Grids differ by job.** Library and Search are square multi-column grids for
  *finding* one photo among thousands — a uniform scan pattern. Saved is a
  two-column aspect-preserving masonry (`layoutMasonry` + `MasonryGridDelegate`),
  because it is a small, deliberately-kept set.

---

## Shared components — `lib/widgets/`

Twenty files, all in active use. Reuse these; do not hand-roll an equivalent.

| Component | What it is |
|---|---|
| `AppButton` | the one button, in three voices: `.primary` / `.secondary` / `.quiet`. Primary takes `compact` for the 40-high app-bar metric and an optional leading icon |
| `AppCard` | surface + r12 + hairline — the one grouping container. `.divided` for hairline-separated rows |
| `app_dialog` | `showAppConfirmDialog`, `showAppTextInputDialog` |
| `AppSheet` / `AppSheetNote` | via `showAppSheet` |
| `AppShell` | the bottom-nav `Scaffold` hosting the shell branch, `NavPillBar` and `IndexingDial` |
| `NavPillBar` | the floating inverted-ink capsule; the active destination is marked by a circular knob that teleports to it. A `trailing` slot pins a companion beside the capsule |
| `IndexingDial` | the app-wide "analysis is running" indicator — a 44 disc in the capsule's own inverted ink carrying the remaining count and a progress ring. Mounted **once**, as `NavPillBar`'s `trailing` in `AppShell`; shows nothing when idle. Never say it a second time on an individual screen. It rides *beside* the capsule, not as a slot inside it, so no destination shifts under the thumb when a pass starts or ends |
| `AssetGrid` | the paginating square thumbnail grid shared by month/year/day/older/folder/person/search-results |
| `AssetThumbnail` + `DurationBadge` | the single photo-cell primitive |
| `CircleIconButton` | `.overMedia` scrim disc / `.surface` themed disc |
| `SegmentedControl<T>` | one value, mutually exclusive choices — distinct from a `FilterPill` row of independent facets |
| `FilterPill` | independent facets: Library filter bar, Search facets, browse-label chips |
| `SectionHeader` | uppercase section label. `onTap` makes the whole row the destination and adds a chevron — never a separate "view all" |
| `EmptyState` / `EmptyState.note` | loading, error and empty copy |
| `CoverRow` | list row with a cover; `showChevron` for rows that stand alone in a card |
| `FolderList` | a sliver of device-folder chips (Albums screen) |
| `PeopleStrip` | the horizontal avatar row (Search and Albums — **not** Library) |
| `ConsentSwitch` | onboarding toggles and `SettingsSwitchRow` |
| `LimitedAccessBanner` | limited-photo-access banner on Library |
| `PrecacheAdjacent` | neighbour warm-up for the detail viewer and memory player |
