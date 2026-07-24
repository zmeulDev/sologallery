# Plan: Match Album card radius to navbar (two-column compact tile)

## Goal
Tweak the Albums tab tiles so the card shape and album cover share the navbar's 30 dp corner radius, then make them compact enough that large album libraries don't require excessive scrolling.

## Decision
- User chose Option A for radius: use the navbar's 30 dp corner radius.
- User chose Option A for compactness: horizontal list tiles.
- User then asked about density for 28+ albums; chose Option A again: two-column compact cards.
- User feedback: "top and bottom padding is too big" → reduced vertical padding from `s12` to `s8`.

## Final approach
- Added `r30`/`br30` to `AppRadius` and an optional `borderRadius` parameter to `AppCard` (defaults to `br12`).
- `AlbumCard` is a compact horizontal card:
  - `AppCard(borderRadius: AppRadius.br30)`.
  - 56 dp square cover on the left, padded and clipped with `br30`.
  - Album name + photo count stacked to the right, vertically centered.
  - Inner padding: `horizontal: s12`, `vertical: s8`.
  - `onTap`/`onLongPress` cover the whole card.
- `AlbumsScreen` uses a 2-column `SliverGrid`:
  - `crossAxisCount: 2`, `mainAxisSpacing: s16`, `crossAxisSpacing: s16`.
  - `childAspectRatio: 1.9`.
  - 28 albums now render as ~14 rows.

## Files touched
- `lib/core/theme/app_radius.dart`
- `lib/widgets/app_card.dart`
- `lib/features/albums/widgets/album_card.dart`
- `lib/features/albums/albums_screen.dart`
- `test/widgets/app_card_test.dart`
- `test/features/albums/album_card_test.dart`
- `test/widgets/design_goldens_test.dart`
- `test/widgets/goldens/ci/album_card.png`
- `test/widgets/goldens/ci/people_strip.png`

## Verification
- [x] `flutter analyze` — no issues.
- [x] `flutter test test/features/albums/album_card_test.dart test/features/albums/albums_screen_test.dart test/widgets/design_goldens_test.dart` — all passed.

## Notes
- `album_card_test.dart` wraps `AlbumCard` in a `ProviderScope` with a fake `PhotoLibraryService` so `AssetThumbnail` resolves.
- `people_strip.png` golden was regenerated to account for a prior padding tweak.
- Manual end-to-end verification on the connected Pixel device is still pending.

## Next step
User should verify visually on the Pixel device and run `tool/check.sh` when convenient.
