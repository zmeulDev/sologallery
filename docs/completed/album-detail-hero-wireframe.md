# Plan: Redesign Album detail screen to match wireframe

## Goal
Make the `/album/:id` detail view match the supplied wireframe: a full-bleed hero header of the album cover with the album title and photo count overlaid, a back button on the header, and a three-column photo grid whose thumbnails use the same `br12` radius as the Library screen.

## User decision
- The wireframe's top-right **Select** button is **omitted** for this pass (user chose "Omit Select button"). Selection mode will be a follow-up feature if needed.

## Implementation

### Hero header
- Replace the plain `AppBar` + body split with a `CustomScrollView` containing a `SliverAppBar`.
- The cover shown in the hero uses the album's explicit `coverAssetId` when set; otherwise it falls back to the most recently added entry (the first item from `albumEntriesProvider`, which orders by `addedAt DESC`). This matches the `AlbumSummary` cover logic used by the album card.
- `SliverAppBar`:
  - `expandedHeight`: 320 dp (about the top third of a phone, matching the wireframe proportions).
  - `floating: false`, `pinned: true`, `snap: false` — header stays as a collapsing bar while scrolling.
  - `backgroundColor`: scaffold background color; the cover photo fills the flexible space.
  - `flexibleSpace`: `FlexibleSpaceBar` with a `Stack`:
    - Full-bleed `AssetThumbnail(assetId: coverAssetId, size: 1000)` as background, or a `surface2` placeholder if the album is empty and has no explicit cover.
    - A `surface2` placeholder overlays the cover until the first decoded frame paints (`Image.frameBuilder` on `AssetThumbnail`), then it snaps off with no animation (per the app's "no decorative motion" rule).
    - Bottom gradient (`LinearGradient` from transparent to `AppOverMedia.scrimHeavy`) so white title text holds against any photo.
    - Title block at `bottom: 28`, `left: 20`, `right: 20`:
      - Album name in `AppTextStyles.pageTitle` colored `AppOverMedia.glyph`.
      - Photo count label in `AppTextStyles.caption` colored `AppOverMedia.glyphSoft`.
    - Top-left back button: `CircleIconButton.overMedia(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: context.pop)`.
    - Top safe-area inset handled via `MediaQuery.paddingOf(context).top`.
  - No bottom radius on the flexible space; the cover extends to the grid. (The wireframe's rounded bottom corners belong to a sheet-style album view; this app uses full-bleed photos, so we keep the cover rectangular to avoid conflicting with the grid edge.)

### Photo grid
- Move the existing 3-column grid into the `CustomScrollView` as a `SliverPadding` + `SliverGrid` (or keep `GridView` inside the body of a `NestedScrollView` if simpler).
- Reuse the same visual treatment as `AssetGrid` and Library previews:
  - `crossAxisCount: 3`
  - `mainAxisSpacing: AppSpace.s4`
  - `crossAxisSpacing: AppSpace.s4`
  - Each cell wrapped in `ClipRRect(borderRadius: AppRadius.br12, child: AssetThumbnail(..., showVideoBadge: true))`.
- Grid padding: `all: AppSpace.s4` with extra bottom for the system gesture bar (`MediaQuery.paddingOf(context).bottom`). No floating nav capsule here because `/album/:id` is a pushed route outside the shell.
- Keep the existing tap behavior: push `/photo/:id` with `PhotoViewerArgs(assetIds, i)`.

### Loading / empty states
- `albumProvider` still drives the name/cover; `albumEntriesProvider` drives the grid.
- Loading: keep centered spinner.
- Empty album: keep the existing `EmptyState.note` centered below the collapsed header (or show it in the scrollable body if that is simpler).
- If the album is deleted while on the screen, `albumProvider` returns null and the screen pops itself (current behaviour, preserve it).

### Files touched
- `lib/features/albums/album_detail_screen.dart` — main redesign + latest-entry cover fallback + cover-loading placeholder.
- `lib/widgets/asset_thumbnail.dart` — optional `frameBuilder` parameter forwarded to `Image.memory`.
- `test/features/albums/album_detail_screen_test.dart` — updated assertions for the hero header, `ClipRRect` count, cover-fallback behavior, explicit cover, and placeholder-swap behavior.

### Verification
- [x] `flutter analyze` zero warnings on touched files.
- [ ] `flutter test test/features/albums/album_detail_screen_test.dart` (tests written; user asked not to run them in this turn).
- [ ] `flutter test test/widgets/design_goldens_test.dart` (no album-detail golden added).
- [ ] Manual end-to-end on the connected Pixel device.
- [ ] `tool/check.sh` passes.

## Next step
Run tests and full `tool/check.sh` when convenient, then verify visually on the device.
