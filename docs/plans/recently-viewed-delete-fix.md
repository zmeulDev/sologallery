# Fix: Recently Viewed shows placeholder after photo deletion

## Bug

When a photo is deleted, its entry in the "Recently Viewed" strip
(`RecentlyViewedRow`, search idle screen) stays in place and renders as a
blank placeholder instead of disappearing.

## Root cause

`RecentlyViewed` (`lib/core/database/tables.dart:268-276`) is a standalone
Drift table (`assetId`, `viewedAt`) with **no FK relationship to
`photoAssets`**, and `IndexDao.watchRecentlyViewed`
(`lib/core/database/daos/index_dao.dart:463-480`) selects straight from it
with no join — unlike `watchFavoritesInCache`
(`index_dao.dart:441-456`), which inner-joins `photoAssets` so a row vanishes
the moment its cache row is gone.

`IndexDao.deleteAssets` (`index_dao.dart:98-101`) only deletes from
`photoAssets` (cascading via FK to labels/OCR/faces). It never touches
`recentlyViewed`, so a deleted asset's `recentlyViewed` row survives forever.
`AssetThumbnail` (`lib/widgets/asset_thumbnail.dart:40-66`) then can't resolve
the now-gone `photo_manager` asset and falls back to `_Placeholder`
indefinitely.

`deleteAssets` is the single DB-level choke point for asset removal, called
from both:
- `DetailActions.delete` (`lib/features/detail/detail_providers.dart:119`) —
  in-app single-photo delete, alongside explicit favorites/album purges.
- `IndexingService`'s reconciliation sweep
  (`lib/services/indexing_service.dart:541`) — prunes cache rows for assets
  removed from the OS library (e.g. deleted outside the app).

Both paths currently leak a stale `recentlyViewed` row.

## Fix

Extend `IndexDao.deleteAssets` to also delete matching rows from
`recentlyViewed`, in the same method (ideally the same transaction), for
`ids`. This fixes the root cause at the one place both delete paths already
go through — no schema/FK migration needed, no caller changes required, and
it matches the existing pattern where favorites/albums are explicitly purged
alongside a photoAssets delete.

```dart
Future<int> deleteAssets(List<String> ids) async {
  if (ids.isEmpty) return 0;
  return transaction(() async {
    await (delete(recentlyViewed)..where((r) => r.assetId.isIn(ids))).go();
    return (delete(photoAssets)..where((a) => a.assetId.isIn(ids))).go();
  });
}
```

(Exact Drift API names to be confirmed against the generated table accessor
during implementation — `recentlyViewed` table getter should already exist
since `watchRecentlyViewed`/`recordView` use it.)

## Test plan

- Update/extend `test/core/database/index_dao_test.dart` "deleteAssets prunes
  rows and cascades to labels/text" (or add a sibling test) to also assert a
  `recordView`'d id is gone from `watchRecentlyViewed`/the `recentlyViewed`
  table after `deleteAssets`.
- Update `test/features/detail/detail_providers_test.dart` "delete purges
  favorites and album entries and reports true" to also assert
  recently-viewed purge for the deleted id (since it goes through the same
  `deleteAssets` call).
- No widget-level test planned unless the DAO-level coverage above doesn't
  satisfy Definition of Done — the placeholder rendering itself
  (`AssetThumbnail`) is correct behavior for a missing asset; the bug is
  purely that the row isn't removed from the query results.

## Steps

- [x] Add `recentlyViewed` purge to `IndexDao.deleteAssets` (transactional).
- [x] Extend `index_dao_test.dart` to cover recently-viewed purge on delete.
- [x] Extend `detail_providers_test.dart` to cover recently-viewed purge on
      in-app delete.
- [x] Run `tool/check.sh` — analyze, drift codegen, full test suite all pass.
- [~] Manually verify on device/simulator: attempted on the connected Samsung
      SM S938B (physical device, real photo library) via the running debug
      session (DTD) + `adb input tap`. Aborted: the app has no
      `flutter_driver` extension wired in, so taps could only be sent by
      blind screen coordinates, not by widget/text. One coordinate guess
      missed the bottom-nav search icon and opened a real photo's detail
      screen instead (backed out immediately, nothing deleted). Continuing to
      guess tap coordinates near a delete button against a real, non-test
      photo library was judged too risky to continue. A disposable synthetic
      test image was pushed and fully cleaned up (file + MediaStore row) with
      no lasting trace; no screenshots were left on device (captured only to
      `/data/local/tmp`, pulled, then removed — never `/sdcard`).
- [x] iOS: re-checked whether the iPhone 17 simulator could run the app for a
      live check (2026-09-06). Confirmed still blocked — `xcodebuild
      -workspace ios/Runner.xcworkspace -scheme Runner -showdestinations`
      lists zero simulator destinations for `Runner`, only the physical
      device + placeholders (same MLKit arm64-sim-slice/scheme gap recorded
      2026-09-05, see [[testing-device-iphone-17-sim]] in agent memory).
      Given the choice between a physical-device tap session, fixing the
      Xcode scheme, or trusting automated coverage, the user chose to trust
      the unit tests. Re-ran `index_dao_test.dart` +
      `detail_providers_test.dart`: all pass (60/60), including the
      recently-viewed-purge assertions added for this fix.

## Next step

Done. Fix implemented, unit/widget-level tests cover the exact code path the
delete button calls (`DetailActions.delete` → `IndexDao.deleteAssets`), and
the user has explicitly opted to rely on that automated coverage rather than
a live device/simulator check — the iOS simulator remains unable to build
this app (untouched Xcode-scheme gap), and a blind-tap session against a real
device's photo library was judged too risky in the prior attempt. No further
action planned unless the user reopens this.
