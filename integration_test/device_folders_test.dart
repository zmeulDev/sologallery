import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof of the real `photo_manager` path behind the Search screen's
/// Folders section. This is the paired counterpart to the host tests that use
/// `FakePhotoLibraryService` (CLAUDE.md "fake-pairing rule") — the fake returns
/// canned [DeviceFolder]s and cannot exercise what actually breaks here:
///
///  * whether `getAssetPathList` accepts the Android [AdvancedCustomFilter]
///    (its ordering-only, condition-free form) rather than a
///    `FilterOptionGroup` — a rejected filter yields zero paths, not an error;
///  * whether `assetCountAsync` agrees with what `getAssetListPaged` returns;
///  * the cold-start path cache in `folderAssets`, which a deep link into
///    `/folder` hits with no prior `deviceFolders()` call.
///
/// Requires photo-library access already granted on the device (the user's
/// normal state) and at least one photo present. Run with:
///   flutter test integration_test/device_folders_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<PhotoLibraryService> grantedService() async {
    final service = PhotoLibraryService();
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access to this app before running (open the app '
          'once and allow access).',
    );
    return service;
  }

  test('lists real device folders with usable counts and covers', () async {
    final service = await grantedService();

    final folders = await service.deviceFolders();
    expect(
      folders,
      isNotEmpty,
      reason: 'Seed at least one photo on the device (see CLAUDE.md '
          '"Deterministic test assets").',
    );

    for (final folder in folders) {
      expect(folder.id, isNotEmpty);
      expect(folder.name, isNotEmpty);
      // deviceFolders() drops empty folders — an empty row would be a dead end
      // in the UI.
      expect(folder.count, greaterThan(0),
          reason: 'Folder "${folder.name}" surfaced with a zero count.');
      expect(folder.coverAssetId, isNotNull,
          reason: 'Folder "${folder.name}" reports ${folder.count} assets but '
              'its first page came back empty — count/paging disagree.');
    }

    // Sorted by count descending, the order the section renders in.
    for (var i = 1; i < folders.length; i++) {
      expect(folders[i - 1].count, greaterThanOrEqualTo(folders[i].count));
    }

    // Ids are unique — they key the route and the path cache.
    expect(
      {for (final f in folders) f.id}.length,
      folders.length,
      reason: 'Duplicate folder ids would collide in the path cache.',
    );
  });

  test('pages a folder to exactly its reported count, newest first', () async {
    final service = await grantedService();
    final folders = await service.deviceFolders();
    expect(folders, isNotEmpty, reason: 'Seed at least one photo.');

    // The largest folder — most likely to span more than one page.
    final folder = folders.first;

    final seen = <String>{};
    DateTime? previous;
    var page = 0;
    while (true) {
      final assets = await service.folderAssets(
        folderId: folder.id,
        page: page,
        pageSize: 90,
      );
      if (assets.isEmpty) break;
      for (final a in assets) {
        expect(seen.add(a.id), isTrue,
            reason: 'Asset ${a.id} paged twice in "${folder.name}".');
        if (previous != null) {
          expect(
            a.createdAt.isAfter(previous),
            isFalse,
            reason: 'Asset ${a.id} broke the newest-first ordering — the '
                'folder filter and its order column disagree.',
          );
        }
        previous = a.createdAt;
      }
      page++;
    }

    expect(seen.length, folder.count,
        reason: '"${folder.name}": paged ${seen.length} assets but '
            'assetCountAsync reported ${folder.count}.');
    expect(seen, contains(folder.coverAssetId),
        reason: 'The cover asset is not in the folder it covers.');
  });

  test('resolves a folder on a cold service (deep-link path)', () async {
    // Discover an id with one service, then page it with a *fresh* one whose
    // path cache is empty — exactly what `/folder?id=…` does after a restore.
    final discovery = await grantedService();
    final folders = await discovery.deviceFolders();
    expect(folders, isNotEmpty, reason: 'Seed at least one photo.');
    final folder = folders.first;

    final cold = PhotoLibraryService();
    final assets = await cold.folderAssets(
      folderId: folder.id,
      page: 0,
      pageSize: 10,
    );

    expect(assets, isNotEmpty,
        reason: 'A cold service failed to refill its path cache for '
            '"${folder.name}" — the folder screen would show "empty".');
  });

  test('an unknown folder id pages empty rather than throwing', () async {
    final service = await grantedService();

    final assets = await service.folderAssets(
      folderId: 'no-such-folder-id',
      page: 0,
      pageSize: 10,
    );

    expect(assets, isEmpty);
  });
}
