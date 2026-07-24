# Plan: Albums screen card redesign

## Goal
Redesign the Albums tab grid tiles to match the supplied wireframe:
- 2-column square-cover cards, rounded `r12`.
- Album name as title, photo count as subtitle below it.
- Empty albums show a themed placeholder instead of a cover.
- Use only existing app tokens (colors, spacing, typography, radii); no new palette entries.
- Write widget + provider tests; do not run them yet per user request.

## Current state (from exploration)
- `lib/features/albums/albums_screen.dart` already renders a `CustomScrollView` with a 2-column `SliverGrid` of `AlbumCard`.
- `lib/features/albums/widgets/album_card.dart` is the existing tile: cover thumbnail, name, count label.
- Data comes from `albumSummariesProvider` → `AlbumsDao.watchAlbumSummaries()`, yielding `AlbumSummary(id, name, entryCount, coverAssetId)`.
- Shared widgets already available: `AssetThumbnail`, `ClipRRect(br12)`, `AppCard`, `EmptyState`, count formatters in `lib/core/format/count_labels.dart`.
- Existing tests:
  - `test/features/albums/albums_screen_test.dart`
  - `test/features/albums/album_detail_screen_test.dart`
  - `test/features/albums/albums_providers_test.dart`
- Integration: `integration_test/saved_albums_test.dart` covers album create/open/delete on device.

## Approach
1. Update `lib/features/albums/widgets/album_card.dart`:
   - Keep the 2-column card proportions.
   - Square cover fills the card width, clipped `r12`.
   - Title = album name (`body` / 14sp / weight 600).
   - Subtitle = `photoCountLabel(entryCount)` (`caption` / 11sp / `textSecondary`).
   - Empty cover: `ColoredBox(color: surface2)` + `photo_album_outlined` muted icon, all `r12`.
   - Tap target is the whole card and continues to push `/album/${summary.id}`.
2. Keep `albums_screen.dart` largely as-is; only adjust grid gutters/spacing if the wireframe demands it (wireframe implies `s16` horizontal inset and `s20` vertical gutter, which already match).
3. Update `test/features/albums/albums_screen_test.dart`:
   - Assert title and subtitle text appear on the tile.
   - Assert empty-album placeholder renders.
   - Keep existing create/delete/folder/People tests.
4. Add/update golden tests if needed (user said “write tests but don’t run”; we can add a golden test file but skip execution).
5. No schema changes, no new dependencies, no manifest re-verification needed.

## Out of scope
- People strip, device-folder chips, album detail, create/delete dialogs — unchanged unless the existing layout breaks with the new tile metrics.
- No new album creation flow.
- No new colors or typography tokens.

## Risks / open questions
- The subtitle phrasing: wireframe looks like “42 photos”. Existing `photoCountLabel` already produces that form; confirm in code.
- Empty-state placeholder style: use the current `surface2` + muted icon so it stays on-token.

## Implementation (completed)
- [x] Redesigned `lib/features/albums/widgets/album_card.dart`:
  - Wraps tile in `AppCard` (surface + `r12` + hairline border).
  - Cover fills card width via `Expanded`; empty cover keeps `surface2` + muted icon.
  - Title and count use existing `body`/`caption` tokens with `AppSpace.s12` padding.
- [x] Adjusted `lib/features/albums/albums_screen.dart` grid `childAspectRatio` from `0.82` → `0.75` to account for the padded labels while keeping the cover near-square.
- [x] Improved `lib/widgets/people_strip.dart`:
  - Tighter `AppCard` inner padding (`s12` vs `s16`).
  - Slightly wider avatar spacing (`s20` vs `s16`).
  - `RepaintBoundary` around the scrolling list.
- [x] Added `test/features/albums/album_card_test.dart` covering title/count, empty placeholder, and tap/long-press.
- [x] `flutter analyze` passes.

## Verification not run (per user request)
- `flutter test` not run.
- Integration / device tests not run.

## Next step
User requested not to run tests; remaining work is manual device verification and running the full test suite when desired.
