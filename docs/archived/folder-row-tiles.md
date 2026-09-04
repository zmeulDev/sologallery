# Device-folder tiles → short blurred rows

**Status:** built and green on host; on-device verification (step 6) open.
**Scope:** `lib/widgets/folder_list.dart` + its tests. Nothing else in Albums
changes.
**Related:** `docs/plans/library-albums-polish.md` rewrote this widget as the
2-up tile grid this plan reshapes; that plan's DoD #2/#3 are still open.

## Brief (from the user)

On Albums → Device folders: half the height, icon on the left, bigger icon,
blurred cover as the background, title and count inside the row.

Confirmed: **stay 2 per row** (not full-width), and the left slot is the
**folder glyph only** (no sharp cover thumb).

## Design

The 2-up tile stops being "a picture with a caption under it" and becomes a
self-contained row: the cover is demoted to atmosphere behind the label, and
the folder glyph — not the photo — is what the eye lands on. That is honest
about what these are: filesystem buckets the user picks **by name**
(`Camera`, `Screenshots`, `Download`), unlike an album, which is picked by
recognizing its cover.

```
┌────────────────────┐  ┌────────────────────┐
│▓▓▓▓▓▓ blurred ▓▓▓▓▓│  │▓▓▓▓▓▓ blurred ▓▓▓▓▓│
│  ▐▛▜▌  Camera      │  │  ▐▛▜▌  Screen-     │
│  ▐▙▟▌  1204 photos │  │  ▐▙▟▌  shots       │
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  │▓▓▓▓▓▓  318 photos  │
└────────────────────┘  └────────────────────┘
   ← 96 logical px tall, r12, 2 per row →
```

| Decision | Value | Why |
|---|---|---|
| Height | `mainAxisExtent`, **96** at text scale 1 | ~half the current ~210. Fixed extent, not an aspect ratio — a row's height comes from its content, not its width. |
| Height at large text | `max(96, s12*2 + max(32, 2 name lines + gap + count line))` | Same `textScalerOf` guard as `PeopleStrip`/`MemoriesCarousel` (CLAUDE.md gotcha: a tight-height box squashes or overflows silently). |
| Name | `body` w600, **maxLines 2**, ellipsis | The text column is only ~90px wide in a 2-up cell. The extra height over the bare minimum exists precisely so `Screenshots`-length names wrap instead of ellipsizing to nothing. |
| Count | `caption`, one line | Unchanged copy (`photoCountLabel`, keeps the "1 photo" singular). |
| Glyph | `Icons.folder_rounded` at **32**, no disc | "Bigger icon". The scrim disc is dropped: over a blurred *and* scrimmed cover it is a disc on a disc — one accessory removed. |
| Background | `AssetThumbnail(size: 256)` inside `ImageFiltered(blur σ 18)` + `AppOverMedia.scrim` (0x99) | `ImageFiltered` filters the layer (no `saveLayer`, unlike `BackdropFilter`). Default `TileMode.clamp` means no transparent halo at the tile edge. 256 is the `AssetThumbnail` default, so it shares cache entries rather than minting a third size. |
| No cover | `colors.surface2` fill, glyph `textMuted`, name `onSurface`, count `textSecondary` | An empty folder has nothing to blur; a black scrim over a light surface would be the only dark block on the screen. Documented branch, mirrors `AlbumCard._EmptyCover`. |
| Radius | `AppRadius.br12` | Unchanged — it is a photo surface. |
| Grid gaps | crossAxis `s16` (unchanged), mainAxis `s20 → s12` | The s20 rhythm was sized for 210px tiles; at 96px it reads as a gap between unrelated things. |
| `Pressable` | kept | Cards may scale on press (never grid cells) — this is still a card. |

Cost of the change, accepted deliberately: the cover is no longer
recognizable. That is the point — the glyph and the name carry the tile now.
The `folder_list_test` case that asserts a >100px legible cover is replaced,
not deleted, by one asserting the blurred backdrop fills the tile.

## Steps

- [x] 1. Rewrite `_FolderTile` as the row above; delete `_FolderGlyph` (the
      disc is gone), add a `_tileHeight(context)` helper next to `FolderList`.
- [x] 2. `GridView.count` → `GridView.builder` with
      `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,
      mainAxisExtent: _tileHeight(context), mainAxisSpacing: s12,
      crossAxisSpacing: s16)`; keep the explicit padding (never null — CLAUDE.md
      gotcha) and the `shrinkWrap` + `NeverScrollableScrollPhysics` pair.
- [x] 3. Update `test/widgets/folder_list_test.dart` (10 cases, all green):
      keep the empty/2-up/count/routing cases as-is; replace the
      "cover is big enough to recognize" case; add
      (a) tile is wider than tall and ~96 high,
      (b) glyph is left of the name, both inside the tile's rect,
      (c) the blurred backdrop covers the whole tile (`ImageFiltered` present,
          thumbnail size == tile size),
      (d) a coverless folder renders no `AssetThumbnail` but still a glyph,
      (e) `textScaler: 2.0` grows the tile and overflows nothing.
- [x] 4. `test/widgets/thumbnail_radius_test.dart` — unchanged and still green:
      the blur sits inside the clip, so the folder case still finds its one
      `br12`.
- [x] 5. `tool/check.sh` — analyze clean. Tests: **599 pass / 23 fail**, and
      the same **23 fail on a stashed baseline** (594 pass / 23 fail), so this
      change adds 5 passing cases and breaks nothing. The 23 are the open
      `nav-pill-refactor` work: `albums_screen_test` expects a nav-inset
      trailing spacer `albums_screen.dart` doesn't have yet, plus goldens
      awaiting regeneration (see that plan's follow-ups).
- [ ] 6. On-device: Albums tab on the Pixel 9 Pro XL — folders legible over
      real covers, long names wrapping, tap still opens `/folder`.

**Next step:** step 6, on-device. Nothing else is outstanding.

## Follow-ups / risks

- No golden covers `FolderList` today; if one is added later it belongs with
  the design-system goldens, and CLAUDE.md's "goldens can't see icon glyphs"
  applies — the 32px folder mark will render as a box.
- Scrim strength (`scrim` 0x99 vs `scrimHeavy` 0xB3) is the one value that can
  only be judged against real photos; verify on device in step 6 and record the
  final choice here.
