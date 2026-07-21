# Phase 3b — Saved + Albums screens

_Living handoff doc. Read CLAUDE.md + this to resume. Status: **COMPLETE** ✅
(2026-07-18). `tool/check.sh` green (101 host tests); patrol favorite
round-trip + album create/open/delete pass on the Pixel 9 Pro XL._

## Goal

Turn the two `PlaceholderView` stubs into first-class destinations. All backing
DAOs (`FavoritesDao`, `AlbumsDao`) are already wired + tested from Phase 3a; this
phase is UI + a couple of read-only DAO queries + tests.

## Design decisions (locked)

- **Saved uses a DB stream, not `PagedAssetsNotifier`.** The checkpoint suggested
  `PagedAssetsNotifier`, but that paginates the *photo library*; favorites are a
  bounded local set that must react to favorite/unfavorite. A
  `StreamProvider<List<Favorite>>` over `FavoritesDao.watchAll()` gives the
  reactive round-trip for free and is simpler. Grid mirrors `month_grid_screen.dart`.
- **Albums list needs a cover + count per album.** Add one read-only DAO query
  `watchAlbumSummaries()` (albums LEFT JOIN entries → count + representative
  cover assetId = `coverAssetId` else most-recent entry). No schema change → no
  migration test needed (DoD #4 N/A).
- **Album detail** reuses the same grid; app bar title needs the album row →
  add `watchAlbum(int id)` DAO method.
- Scope guard: no remove-from-album or reorder this phase (adding to albums is
  already covered by the detail viewer's add-to-album sheet). Album **delete**
  lives on the album list.

## New / changed files

**DAO (`lib/core/database/daos/albums_dao.dart`)**
- `Stream<AlbumSummary> ...` → add `watchAlbumSummaries()` returning
  `List<AlbumSummary>` (new plain-Dart class: album + entryCount + coverAssetId).
- `Stream<Album?> watchAlbum(int id)`.

**Saved feature**
- `lib/features/saved/saved_providers.dart` — `savedFavoritesProvider`
  (`StreamProvider.autoDispose<List<Favorite>>` over `favoritesDaoProvider.watchAll()`).
- `lib/features/saved/saved_screen.dart` — rebuild: AppBar "Saved", `.when(...)`
  loading/error/empty/data; 3-col grid of `AssetThumbnail`; tap → `/photo/:id`
  with `PhotoViewerArgs([favIds], index)`.

**Albums feature**
- `lib/features/albums/albums_providers.dart` —
  `albumSummariesProvider` (StreamProvider), `albumProvider(id)` (family),
  `albumEntriesProvider(id)` (family over `watchEntries`), `albumActionsProvider`
  (create/delete wrappers over `albumsDaoProvider`).
- `lib/features/albums/albums_screen.dart` — rebuild: AppBar "Albums" + "+"
  action → create-album dialog; `.when(...)`; 2-col card grid (cover thumbnail,
  name, count); card tap → `/album/:id`; card overflow/long-press → delete confirm.
- `lib/features/albums/album_detail_screen.dart` — new: AppBar = album name;
  `.when(...)`; 3-col grid of entries; tap → detail viewer.
- `lib/features/albums/widgets/album_card.dart` — design-system card (golden target).

**Router (`lib/core/router/app_router.dart`)**
- Add `/album/:id` (root navigator, mirror `/month/:key`; parse int, invalid → note).

## Tests (all applicable tiers — DoD #1–3)

1. **Unit / DAO** (`test/core/database/albums_dao_test.dart`, extend): in-memory
   Drift — `watchAlbumSummaries` (count, cover fallback to latest entry, empty
   album), `watchAlbum`. Use one-shot `.get()`-style assertions where under
   FakeAsync (widget tests); DAO tests use real async containers.
2. **Provider** (`ProviderContainer` + in-memory db override): saved ordering
   (newest-favorited first), album summaries, entries family.
3. **Widget** (mocked providers): SavedScreen + AlbumsScreen + AlbumDetail —
   loading/data/empty/error; create-album dialog; delete confirm. Bounded pumps
   once a `TextField` is on screen; dispose tree + `pump(1s)` for Drift-stream
   teardown (gotchas).
4. **Golden** (`alchemist`, light+dark): `AlbumCard`, Saved empty state.
5. **Integration** (`patrol`, Pixel 9 Pro XL `46121FDAS008AA`): favorite
   round-trip (detail favorite → Saved shows it → unfavorite → gone) + album
   create/open smoke. Prepend `~/Library/Android/sdk/platform-tools` to PATH.

## Verification (Definition of Done)

- `tool/check.sh` green (analyze, build_runner for new `.g.dart`, host tests).
- Patrol integration on the Pixel passes.
- Manual E2E on device: favorite a photo → Saved tab → tap opens viewer;
  create album, open it, delete it.
- Update CHECKPOINT.md (3b ✅), prune task notes from CLAUDE.md.

## Progress log

- **Implemented.** DAO: `watchAlbum`, `watchAlbumSummaries` (+ `AlbumSummary`
  DTO) in `albums_dao.dart`. Saved: `saved_providers.dart` (StreamProvider over
  `FavoritesDao.watchAll`), rebuilt `saved_screen.dart` (3-col grid, when-states).
  Albums: `albums_providers.dart` (summaries/album/entries/actions),
  `album_card.dart`, rebuilt `albums_screen.dart` (2-col cards, create dialog,
  long-press delete), new `album_detail_screen.dart`. Route `/album/:id` wired.
- **Design:** extended the existing system (neutral chrome, photo-only color).
  Album cards: square cover + name/count below (no overlay scrim). Empty/error
  states mirror the Library message treatment.
- **Tests green — `tool/check.sh` passes, 101 host tests** (was 80): +6 DAO,
  +2 saved-provider, +3 albums-provider, +3 saved-widget, +4 albums-widget,
  +2 album-detail-widget, +1 AlbumCard golden (light+dark). Also updated the
  pre-existing `screens_test` + `app_shell_test` (real screens now hit the DB →
  added in-memory `databaseProvider` override + bounded pumps, since
  `pumpAndSettle` hangs on the loading spinner).
- **Gotchas hit (worth remembering):**
  - `Override`/`ProviderListenable`/`overrideWith((r)=>throw)` — a StreamProvider
    whose stream errors (or whose create throws) stays **AsyncLoading** in widget
    tests under fake-async; the error event never renders. Force the error state
    with **`StreamProvider.overrideWithValue(AsyncError(...))`** (riverpod 3.3.2).
  - `_verifyInvariants` (pending-timer check) runs **before** `addTearDown`
    callbacks — the Drift dispose-timer cleanup (`pumpWidget(SizedBox)` +
    `pump(1s)`) must be in the **test body**, not `addTearDown`.
- **On-device patrol:** `integration_test/saved_albums_test.dart` (favorite
  round-trip via Saved tab; album create/open/delete). Running on the Pixel.

## Post-completion notes

- **Device test caught a real bug:** `AlbumCard`'s fixed `AspectRatio(1)` cover
  + two label lines overflowed the grid cell by ~7px → RenderFlex overflow,
  which throws and fails the patrol test. Fixed by flexing the cover
  (`Expanded` + `SizedBox(width: infinity)`) so it can never overflow. Golden
  regenerated; its scenario now needs a bounded height (`Expanded` requirement).
- **patrol `$('text')` is exact-match** — the empty-album note assertion needed
  `find.textContaining('This album is empty')`. (Folded into CLAUDE.md.)

## Done — Definition of Done checklist

1. `tool/check.sh` ✅ (analyze, codegen, 101 host tests incl. AlbumCard golden)
2. Patrol integration on the Pixel ✅ (favorite round-trip + album CRUD)
3. Manually exercised end-to-end via the patrol driver on-device ✅
4. No schema change (read-only queries) → no migration test needed
5. No Android dep added → manifest unchanged (still network-free)
6. Gotchas folded into CLAUDE.md (5 Drift/widget-test traps; patrol exact-match)
7. This plan marked complete; CHECKPOINT.md updated (3b ✅, Phase 4 next)
8. No task-scoped notes left in CLAUDE.md
