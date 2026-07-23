# Plan: Albums — device folder compact chips

## Status
Implemented; tests written but not run (waiting for your go-ahead).

## Brief
Replace the cover-first folder cards on the Albums screen with compact, two-column chips so the Device folders section takes less vertical space and does not compete visually with the Albums photo grid. Functionality is unchanged: each chip opens the folder grid at `/folder?id=&name=`, the compact count stays visible, and accessibility (text-scale growth, no overflow) is preserved.

## Final design (chosen: B — compact 2-column chips)

- **Tile shape:** a two-column grid of tappable `surface2` rounded chips (r8). Each chip is a compact horizontal row: a small folder glyph, the folder name (ellipsized), and the compact count caption.
- **Background:** a subtle `surface2` fill with no border, keeping the tile quiet against the page background. No photo, no blur, no cover.
- **Icon:** a small `Icons.folder_rounded` glyph in `textSecondary` (not on a separate circle) — folders are recognized by name, so the icon is just a role marker.
- **Name:** `AppTextStyles.body` / `onSurface` at `FontWeight.w600`, single-line ellipsis.
- **Count:** `AppTextStyles.caption` / `textSecondary`, compact format (`compactCount`), pushed to the right by the expanding name.
- **Height:** `tileHeight(context)` is a compact minimum that grows with `TextScaler` so large-type users never clip. The chip fills its grid cell width.
- **Spacing:** `crossAxisSpacing: AppSpace.s12`, `mainAxisSpacing: AppSpace.s12` — tight but still distinct from the Albums grid above.
- **Motion:** none beyond the default Material tap ripple.
- **Accessibility:** the whole chip is a single tappable `GestureDetector` with `HitTestBehavior.opaque`; labels use `maxLines: 1` with ellipsis.

## Files to change

- `lib/widgets/folder_list.dart` — replace the current cover-first `_FolderTile` with a compact chip. Keep the sliver layout and the existing route. Remove the cover/placeholder helpers and the `AssetThumbnail` import.
- `test/widgets/folder_list_test.dart` — update `isFolderTile` to match the `surface2` chip shape; assert the compact chip count is visible; verify text-scale growth and routing still work; remove cover/placeholder assertions.
- `integration_test/folders_ui_test.dart` — update the folder-tile finder to match the new chip shape.
- `test/features/albums/albums_screen_test.dart` — no expected changes.
- `docs/plans/albums-device-folder-cover-cards.md` — mark superseded by this plan.

## Verification plan (on hold until you say so)

1. `tool/check.sh` — analyze, build_runner, unit + widget tests.
2. `flutter test test/widgets/folder_list_test.dart test/features/albums/albums_screen_test.dart`
3. `patrol test -t integration_test/folders_ui_test.dart -d 46121FDAS008AA`
4. Manual end-to-end on the Pixel: open Albums, scroll to Device folders, tap a folder chip, view its grid, navigate back.

## Notes

- No schema or native/manifest changes are expected.
- The `DeviceFolder` model still carries `coverAssetId`, but we deliberately do not use it.
- We will not change the count formatter or routing behavior.

## Next step
Implement the chip refactor and update tests.
