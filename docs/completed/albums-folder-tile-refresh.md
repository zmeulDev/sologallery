# Plan: Albums — device folder tile refresh

## Status
Completed.

## Brief
Further simplify the `Device folders` tiles on the Albums screen:

1. Move the photo count so it sits on the same baseline as the folder name, at the end of the label row.
2. Remove the pill/badge background behind the count — render it as plain text only.
3. Drop the outer pill background from the tile itself, leaving a clean row: circled folder icon, folder name, plain count.

## Final design

- **Tile shape:** no `StadiumBorder`/pill background; the tile is a tappable `Row` with a circled folder icon, folder name, and count.
- **Icon:** folder glyph inside a solid circle stays unchanged.
- **Name + count:** a single text row where the folder name expands/ellipsizes and the compact count follows it, both baseline-aligned.
- **Count style:** `AppTextStyles.body` in `textSecondary` color, reading as metadata.
- **Count format:** `compactCount` (e.g. `1.2k`) kept for large libraries.
- **Height:** a compact 44 dp minimum that grows with text scale so large type never clips.

## Files changed

- `lib/widgets/folder_list.dart` — rewrote `_FolderTile` to a plain row, removed outer pill and count pill, kept circular icon backdrop, restored dynamic `tileHeight` for accessibility.
- `test/widgets/folder_list_test.dart` — updated finder to match the new row shape; asserted count is aligned with name, not top-right; scoped icon finder to the first tile; verified no `StadiumBorder` tile background.
- `integration_test/folders_ui_test.dart` — updated folder-tile finder to match the new row shape.
- `test/features/albums/albums_screen_test.dart` — no changes needed.

## Verification results

- `flutter analyze` — zero warnings.
- `tool/check.sh` — passed (analyze, build_runner, all unit/widget tests).
- `flutter test test/widgets/folder_list_test.dart test/features/albums/albums_screen_test.dart` — passed.
- `patrol test -t integration_test/folders_ui_test.dart -d 46121FDAS008AA` — passed on the connected Pixel 9 Pro XL.

## Notes

- No schema or native/manifest changes were needed.
- The row now uses `CrossAxisAlignment.baseline` + `TextBaseline.alphabetic` for name/count alignment; the inner row is nested inside `Expanded` so the name ellipsizes before the count is pushed out.
