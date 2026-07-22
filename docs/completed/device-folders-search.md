# Device Folders on Search

## Context

The Search screen's idle state (`_IdleView`, `lib/features/search/search_screen.dart:300`)
currently shows only a People strip and a one-line hint. Users have no way to browse
their library by the folders the device already organises it into (Camera, Screenshots,
WhatsApp Images, Downloads on Android; albums/smart-albums on iOS) — a familiar entry
point every stock gallery offers.

Note: `lib/features/albums/` is **not** this. It is user-created Drift albums
(`album` / `album_entry`, int ids). `AssetPathEntity` appears nowhere in the codebase
outside one private helper. So this is new capability, built by copying existing patterns.

**Outcome:** below People, a `FOLDERS` section listing every device folder with its photo
count, sorted by count descending. Tapping one opens a paged grid of that folder's photos.

**Decisions taken (user-confirmed):** vertical scrollable list · header reads "Folders"
(avoids collision with the existing `ALBUMS` header in search results) · all folders,
sorted by count desc · photo count only as the statistic.

---

## Status: COMPLETE (2026-07-19)

- [x] 0. Plan doc saved here (living handoff log)
- [x] 1. Service — `DeviceFolder`, `deviceFolders()`, `folderAssets()`, `_pathCache`
- [x] 2. Providers — `lib/features/folders/folders_providers.dart`
- [x] 3. Detail screen — `folder_detail_screen.dart`
- [x] 4. Route — `/folder?id=&name=`
- [x] 5. Search screen — `_CoverRow` extract + `_IdleView` restructure
- [x] 6. Tests — fake extended, 8 unit, 5 widget, 3 search-screen, 4 service
      integration, 1 patrol UI
- [x] 7. `tool/check.sh` green (245 tests) + on-device verification

**Next step:** none — feature is done. Follow-ups are listed at the bottom.

### Decisions made during implementation

- **Error state on `folderAssetsProvider` is driven by a throwing fake, not a
  provider override.** An `AsyncNotifierProvider` has no `overrideWithValue`
  (unlike `StreamProvider`/`FutureProvider`), so `FakePhotoLibraryService` got a
  `failFolderAssets` flag. Its Future-backed `build()` does surface the error
  under fake-async, so the StreamProvider gotcha in CLAUDE.md doesn't bite here.
- **No thousands separator on counts.** Considered for 4-digit folder counts,
  rejected: the app has no number formatting anywhere and no `intl` dependency,
  so a hand-rolled locale-naive grouper would make Folders inconsistent with
  `AlbumCard` and `_PersonCard`. Listed as a follow-up instead.
- **`deviceFolders()` cost measured on device: 141 ms for 6 folders**, all covers
  resolved. The plan's "drop the cover fetch to a lazy per-row provider if it
  lags" contingency was therefore **not** needed — do not pre-optimise this.
  (An early patrol failure looked like folder latency but was app-boot time; the
  UI test now polls for `FOLDERS` rather than using a fixed pump budget.)

### Verification record

- `tool/check.sh`: analyze clean, build_runner clean, **245 host tests pass**.
- `flutter test integration_test/device_folders_test.dart -d 46121FDAS008AA`: 4/4.
- `patrol test -t integration_test/folders_ui_test.dart -d 46121FDAS008AA`: 1/1 —
  real app, real library: Search → FOLDERS → folder grid → detail viewer → back.
- Regression: `search_test.dart` 3/3, `library_month_grouping_test.dart` 1/1.
- Real device data observed: Camera 60 · Restored 15 · Download 12 ·
  WhatsApp Images 3 · Instagram 1 · Pictures 1 — sorted desc, covers all present.
- No schema change (DoD #4 n/a). No new dependency (DoD #5 n/a).
- New CLAUDE.md gotcha recorded: integration runs uninstall the app and wipe the
  photo permission; pre-grant via `adb shell pm grant`, one test file per run.

## 1. Service — `lib/services/photo_library_service.dart`

photo_manager types must never leave this service (architecture rule), so add a
plugin-free projection next to `AssetRef`:

```dart
class DeviceFolder {
  const DeviceFolder({required this.id, required this.name,
                      required this.count, this.coverAssetId});
  final String id;          // Android: MediaStore BUCKET_ID · iOS: localIdentifier
  final String name;
  final int count;
  final String? coverAssetId;
}
```

**`Future<List<DeviceFolder>> deviceFolders()`**
- `PhotoManager.getAssetPathList(hasAll: false, onlyAll: false, type: RequestType.common,
  filterOption: _isDarwin ? _darwinFilter() : _androidWindow())` — reuses the existing
  filter split so cover assets come back newest-first. `_androidWindow()` with no
  min/max emits only `addOrderBy(dateTaken, isAsc: false)`; SQLite sorts NULLs last on
  DESC, so undated assets fall to the end rather than becoming the cover. Verified: all
  four named params exist in photo_manager 3.10.0.
- Drop `albumType != 1` entries on Darwin — on iOS `albumType == 2` is a *folder of
  albums*, which holds no assets (`AssetPathEntity` doc comment, `types/entity.dart:88`).
- Per path: `await path.assetCountAsync`; skip `count == 0`; cover from
  `(await path.getAssetListPaged(page: 0, size: 1)).firstOrNull?.id`.
- Sort by `count` desc, then `name` asc for stability.
- Populate a `final Map<String, AssetPathEntity> _pathCache = {}` keyed by id.

**`Future<List<AssetRef>> folderAssets({required String folderId, required int page,
required int pageSize})`**
- Resolve from `_pathCache`; on miss, re-run the listing above to refill it, then look up
  again; return `const []` if still absent (folder deleted).
- **Do not use `AssetPathEntity.fromId`** — it takes a `FilterOptionGroup`, which cannot
  express the Android `AdvancedCustomFilter` this project relies on, and it asserts
  `albumType == 1 || isDarwin`. The cache avoids the re-list on every page anyway.
- `path.getAssetListPaged(page:, size:)` → map to `AssetRef(id:, createdAt: a.createDateTime)`,
  exactly as `searchAssets` does.

Both methods get doc comments in the style of their neighbours, including the
capture-date-axis note.

---

## 2. Providers — new `lib/features/folders/folders_providers.dart`

```dart
final deviceFoldersProvider = FutureProvider.autoDispose<List<DeviceFolder>>(
  (ref) => ref.read(photoLibraryServiceProvider).deviceFolders(),
);

class FolderAssetsNotifier extends PagedAssetsNotifier {
  FolderAssetsNotifier(this.folderId);
  final String folderId;
  @override
  Future<List<AssetRef>> fetchPage(int page, int pageSize) =>
      ref.read(photoLibraryServiceProvider).folderAssets(
            folderId: folderId, page: page, pageSize: pageSize);
}

final folderAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<FolderAssetsNotifier, List<AssetRef>, String>(FolderAssetsNotifier.new);
```

`PagedAssetsNotifier` (`lib/services/paged_assets_notifier.dart`) is the right base — this
pages photo_manager directly, not the Drift cache, so `WatchedAssetsNotifier` does not
apply. Family-constructor shape copied from `MonthAssetsNotifier`
(`lib/features/library/month_assets_provider.dart`).

---

## 3. Detail screen — new `lib/features/folders/folder_detail_screen.dart`

Clone the shape of `PersonDetailScreen` (`lib/features/people/person_detail_screen.dart`),
minus the rename action and with real paging:

```dart
class FolderDetailScreen extends ConsumerWidget {
  const FolderDetailScreen({super.key, required this.folderId, this.folderName});
  // AppBar(Text(folderName ?? 'Folder'))
  // ref.watch(folderAssetsProvider(folderId)).when(
  //   loading:  CircularProgressIndicator
  //   error:    CenteredNote("Couldn't load this folder.")
  //   data:     items.isEmpty ? CenteredNote('This folder is empty.')
  //                           : AssetGrid(items:, hasMore:, onLoadMore:))
}
```

Reuses `AssetGrid` (`lib/widgets/asset_grid.dart` — handles the 3-col layout, load-more
threshold and `/photo/:id` push with `PhotoViewerArgs`) and `CenteredNote` (exported from
`month_grid_screen.dart`). `hasMore` / `onLoadMore` wired from
`ref.watch(folderAssetsProvider(id).notifier)`, per `month_grid_screen.dart:25-38`.

---

## 4. Route — `lib/core/router/app_router.dart`

Add beside `/album/:id`:

```dart
GoRoute(
  path: '/folder',
  parentNavigatorKey: _rootNavigatorKey,
  builder: (context, state) {
    final id = state.uri.queryParameters['id'];
    if (id == null || id.isEmpty) {
      return const _NotFound(message: 'That folder couldn\'t be found.');
    }
    return FolderDetailScreen(folderId: id, folderName: state.uri.queryParameters['name']);
  },
),
```

**Query params, not a path param.** An iOS folder id is a PHAssetCollection
`localIdentifier` containing `/`, which breaks `/folder/:id` matching even percent-encoded.
Carrying the name too keeps the app bar titled without re-listing every folder on the
detail screen; `?? 'Folder'` covers a deep link that omits it.

Push with `Uri(path: '/folder', queryParameters: {'id': f.id, 'name': f.name}).toString()`.

---

## 5. Search screen — `lib/features/search/search_screen.dart`

**Extract a shared row.** `_AlbumRow` (line 232) is already exactly the target visual
(44×44 rounded cover · name · trailing count). Generalise it to a private
`_CoverRow({String? coverAssetId, required String name, required int count,
required VoidCallback onTap})` that owns the `count == 1 ? '1 photo' : '$count photos'`
formatting, and have both the Albums result rows and the new Folders rows use it. No new
widget, no duplicated styling.

**Restructure `_IdleView`** (currently a `Column` where nothing scrolls) into a
`ListView`, since the folder list is unbounded:

```
final people  = ref.watch(personSummariesProvider).value ?? const [];
final foldersAsync = ref.watch(deviceFoldersProvider);
final folders = foldersAsync.value ?? const [];

if (people.isEmpty && folders.isEmpty) return const _IdleHint();   // also covers loading

ListView(children: [
  if (people.isNotEmpty)  _PeopleStrip(people: people),
  if (folders.isNotEmpty) ...[
    const Padding(EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: MonthSectionHeader(label: 'Folders')),
    for (final f in folders) _CoverRow(...),
  ],
]);
```

`_PeopleStrip` keeps its existing padding and its `SizedBox(height: 72)` comment — the
horizontal-ListView cross-axis constraint still applies inside a vertical `ListView`.
`_IdleHint` becomes the both-empty fallback rather than a permanent `Expanded`.

Per CLAUDE.md, invoke `/frontend-design:frontend-design` before touching this file.

---

## 6. Tests

**`test/support/fake_photo_library_service.dart`** — add a
`List<DeviceFolder> folders` ctor param plus `Map<String, List<AssetRef>> folderAssetsById`,
and override `deviceFolders()` (sorted, count>0 filtered) and `folderAssets(...)` (sliced
like the existing `searchAssets` override). Every other test constructs the fake with
named optional args, so this is additive.

| Tier | File | Covers |
|---|---|---|
| Unit | `test/features/folders/folders_providers_test.dart` | `ProviderContainer` + fake: folder list sorts by count desc; `folderAssetsProvider` first page; `loadMore()` appends and flips `hasMore` false on a short page |
| Widget | `test/features/folders/folder_detail_screen_test.dart` | loading / error / empty / data-grid states; app-bar title from `folderName` and the `'Folder'` fallback |
| Widget | `test/features/search/search_screen_test.dart` (extend) | `FOLDERS` header + rows render in idle; count label text; tap pushes `/folder?id=…`; existing cases still pass with the `ListView` restructure |
| Integration | `integration_test/device_folders_test.dart` (patrol) | **Fake-pairing rule** — real `photo_manager`: Search idle lists ≥1 folder with a non-zero count, tapping opens a non-empty grid |

Widget-test gotchas that apply here (CLAUDE.md):
- Search has an autofocused `TextField` → **bounded pumps only**, never `pumpAndSettle`.
- `FolderDetailScreen`'s `.when(loading:)` spinner makes `pumpAndSettle` hang → bounded pumps.
- Force the error branch with `folderAssetsProvider(id).overrideWithValue(AsyncError(...))`;
  a throwing `overrideWith` stays `AsyncLoading` under fake-async.
- Search's existing harness already overrides `databaseProvider` with an in-memory DB and
  ends with the dispose-tree teardown — keep both.

No schema change, so DoD #4 does not apply. No new dependency, so DoD #5 does not apply.

---

## Verification

1. `tool/check.sh` — analyze (zero warnings), build_runner, unit + widget tests.
2. `patrol test -t integration_test/device_folders_test.dart -d 46121FDAS008AA`.
3. Manual on the Pixel 9 Pro XL: open Search → confirm `FOLDERS` lists real device
   buckets (Camera / Screenshots / Download) with plausible counts and covers, that the
   list scrolls, that counts match the folder contents, and that tapping opens the grid,
   scrolls past page 1 (>90 assets in Camera), and opens the detail viewer. Debug via
   `flutter run` console — `developer.log` does not reach `adb logcat`.
4. Sanity-check idle-state first paint isn't janky: `deviceFolders()` does 2 platform
   calls per folder. If it visibly lags on a device with many buckets, drop the cover
   fetch to a lazy per-row provider — but measure first, don't pre-optimise.

## Follow-ups (not in scope)

- The `'1 photo' / '$n photos'` string is still duplicated in `AlbumCard._countLabel` and
  `_PersonCard`; a shared helper would fold in three call sites.
- Media-type facet does not apply to folders (the idle state is `MediaTypeFilter.all` by
  definition), so `deviceFolders()` takes no type param — no dead parameter.
