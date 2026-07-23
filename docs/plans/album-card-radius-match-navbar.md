# Plan: Match Album card radius to navbar

## Goal
Tweak the Albums grid tiles so the card shape and the album cover share the same rounding vocabulary as the floating bottom-nav capsule, then make them compact enough that large album libraries don't require excessive scrolling.

## Decision (first pass)
User chose **Option A**: use the navbar's 30 dp corner radius while keeping the current card proportions. That version is implemented and passing tests.

## New requirement
User feedback: "make it more compact — maybe the cover should be half of the height; when you have a lot of albums it's hard to scroll."

## Compact redesign options

### Option A — Horizontal list tile (recommended)
- Switch the Albums grid from 2-column cards to a single-column list of horizontal tiles.
- Each tile is a short horizontal row: square cover on the left (same 30 dp radius, `s12` padding), album name + count stacked to the right.
- Keeps the navbar-matched 30 dp radius on both the card and the cover.
- Most compact: each item is roughly 80–90 dp tall, so far more albums fit on screen than the current ~208 dp cards.
- Trade-off: loses the dense 2-column photo-grid feel; reads more like a list.

### Option B — Shorter 2-column card
- Keep the 2-column grid but make each card shorter by giving the cover a fixed landscape aspect ratio (cover takes roughly the top half of the card, text below).
- Card still uses 30 dp radius and padded cover.
- Example: ~158 dp tall cards (down from ~208 dp).
- Trade-off: the cover becomes a wide landscape rectangle rather than a square album cover; may look less like a photo album.

## Open question
Which direction do you want? My recommendation is **Option A** (horizontal list tiles) because it maximizes visible albums and "cover is half the height" maps naturally to a square thumbnail beside the text.

## Files that will change once direction is chosen
- `lib/features/albums/albums_screen.dart` (grid delegate / list structure)
- `lib/features/albums/widgets/album_card.dart` (layout)
- `test/features/albums/album_card_test.dart`
- `test/features/albums/albums_screen_test.dart`
- `test/widgets/design_goldens_test.dart` + golden PNGs

## Current verification (already complete for first pass)
- [x] `flutter analyze` — no issues.
- [x] `flutter test test/widgets/app_card_test.dart test/features/albums/album_card_test.dart` — all passed.
- [x] `flutter test test/features/albums/albums_screen_test.dart` — all passed.
- [x] `flutter test test/widgets/design_goldens_test.dart` — all passed after regenerating affected goldens.

## Next step
Wait for user to pick Option A or B (or propose a third option) before editing.
