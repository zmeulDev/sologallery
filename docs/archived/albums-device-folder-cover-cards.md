# Plan: Albums — device folder cover cards

## Status
Superseded by `docs/plans/albums-device-folder-compact-chips.md`.

## Brief
Refresh the `Device folders` tiles on the Albums screen to a cover-first card
layout that matches the visual language of `AlbumCard`. Functionality is
unchanged: each tile opens the folder grid at `/folder?id=&name=`, count stays
visible, and accessibility (text-scale growth, no overflow) is preserved.

## Final design (chosen: A — cover-first cards)

- **Tile shape:** a two-column grid of square-ish cards, same rhythm as the
  Albums grid above (`crossAxisSpacing: AppSpace.s16`, `mainAxisSpacing:
  AppSpace.s20`). The tile is one tappable surface.
- **Cover:** a square `AssetThumbnail` clipped to `AppRadius.br12`. When a
  `coverAssetId` is present the newest photo fills the cover; when it is null a
  recessed `surface2` placeholder with a neutral folder glyph is shown.
- **Labels:** folder name below the cover in `AppTextStyles.body` / `onSurface`
  at `FontWeight.w600`, single-line ellipsis. A compact count caption sits one
  line below in `AppTextStyles.caption` / `textSecondary`.
- **Count format:** keep `compactCount` (e.g. `1.2k`) — device folders can be
  very large, and the compact form has already proven quiet and readable.
- **Height:** `tileHeight(context)` computes the tile width from the screen
  insets, adds a square cover plus the caption block, and scales with
  `TextScaler` so large-type users never clip. The cover itself stays 1:1.
- **Motion:** none beyond the default Material tap ripple. No Hero, no slide.
- **Accessibility:** the whole card is a single tappable `GestureDetector` with
  `HitTestBehavior.opaque`; labels use `maxLines: 1` with ellipsis so layouts
  remain predictable at high text scale.

## Files to change

- `lib/widgets/folder_list.dart` — replace the current icon+name row with a
  `_FolderTile` card. Keep the sliver layout and the existing route. Remove the
  private icon/circle constants that are no longer needed.
- `test/widgets/folder_list_test.dart` — update `isFolderTile` to match the new
  `ClipRRect`+`Column` card shape; assert cover shows when `coverAssetId` is
  present and placeholder shows when absent; verify count is still visible;
  keep the text-scale and routing tests.
- `integration_test/folders_ui_test.dart` — update the folder-tile finder to
  match the new card shape.
- `test/features/albums/albums_screen_test.dart` — no expected changes.

## Verification plan (on hold until you say so)

1. `tool/check.sh` — analyze, build_runner, unit + widget tests.
2. `flutter test test/widgets/folder_list_test.dart test/features/albums/albums_screen_test.dart`
3. `patrol test -t integration_test/folders_ui_test.dart -d 46121FDAS008AA`
4. Manual end-to-end on the Pixel: open Albums, scroll to Device folders, tap a
   folder card, view its grid, navigate back.

## Notes

- No schema or native/manifest changes are expected.
- The `DeviceFolder` model already carries `coverAssetId`, so no provider
  changes are needed.
- We will not change the count formatter or routing behavior.

## Next step
Run the verification plan once you give the signal.
