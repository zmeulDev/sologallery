# Plan: People card matches AlbumCard design on Albums and Search

## Goal
The People section on the Albums tab currently sits inside an `AppCard` with the default `r12` radius, and the "People" / "See all" header lives inside that card. Make the card use the same 30 dp navbar-matched radius as `AlbumCard`, keep its content horizontally scrollable, and move the section header outside the card so it reads like a normal screen section. Because `PeopleStrip` is shared by the Search idle view, both screens update together.

## Current state
- `lib/widgets/people_strip.dart` — shared widget used by:
  - `lib/features/albums/albums_screen.dart` (Albums tab)
  - `lib/features/search/search_screen.dart` (idle Search body)
- It wraps header + horizontal `ListView` of circular `FaceAvatar` tiles in one `AppCard` (default `br12`).
- `AlbumCard` (`lib/features/albums/widgets/album_card.dart`) uses `AppCard(borderRadius: AppRadius.br30)`.
- `AppRadius.r30` is documented as matching the floating nav capsule / navbar radius.

## Proposed approach
1. Refactor `PeopleStrip` so the `SectionHeader('People' / 'See all')` is rendered **outside** the `AppCard`, with the same section-header spacing used elsewhere on Albums (`s12` top / `s8` bottom, inset `s16`).
2. Change the inner `AppCard` to `borderRadius: AppRadius.br30` so it echoes the `AlbumCard` and navbar shape.
3. Keep the existing horizontal `ListView.separated` of circular `FaceAvatar` tiles inside the card; card padding and avatar spacing stay as-is unless the new radius forces a tweak.
4. Update the `PeopleStrip` golden in `test/widgets/design_goldens_test.dart` to reflect the header-outside + `br30` card.
5. Update widget tests for `AlbumsScreen` and `SearchScreen` if they rely on the old internal structure (header inside card).
6. No schema, dependency, or manifest changes.

## Files expected to change
- `lib/widgets/people_strip.dart` (refactored)
- `test/widgets/design_goldens_test.dart` (golden scenario)
- `test/widgets/goldens/ci/people_strip.png` (regenerate)
- Possibly `test/features/albums/albums_screen_test.dart` and `test/features/search/search_screen_test.dart` if internals are asserted.

## Verification
- `flutter analyze` zero warnings.
- `flutter test` unit + widget tests pass; regenerate the `people_strip` golden.
- Manual end-to-end on Pixel 9 Pro XL: Albums tab and Search idle view both show the People section header outside a `br30` card, the circular avatars scroll horizontally inside, and taps still navigate to `/person/:id`.

## Open question / note
If the intent is to go further and render each person as a mini `AlbumCard` (square face left, name + count right, br30 per item) inside the horizontal scroll, that is a larger redesign. The plan above takes the minimal reading: the *container* card matches `AlbumCard` radius, the header moves out, and the existing avatar row stays.
