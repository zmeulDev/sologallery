import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/folders/folders_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  ProviderContainer containerWith(FakePhotoLibraryService fake) {
    final container = ProviderContainer(
      overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('deviceFoldersProvider', () {
    test('sorts by photo count descending and drops empty folders', () async {
      final fake = FakePhotoLibraryService(
        folders: const [
          DeviceFolder(id: 'b', name: 'Screenshots', count: 318),
          DeviceFolder(id: 'z', name: 'Empty', count: 0),
          DeviceFolder(id: 'a', name: 'Camera', count: 1204),
          DeviceFolder(id: 'c', name: 'Download', count: 12),
        ],
      );
      final container = containerWith(fake);

      final folders = await container.read(deviceFoldersProvider.future);

      expect(
        [for (final f in folders) f.name],
        ['Camera', 'Screenshots', 'Download'],
      );
      expect(folders.first.count, 1204);
    });

    test('breaks count ties by name', () async {
      final fake = FakePhotoLibraryService(
        folders: const [
          DeviceFolder(id: '1', name: 'Zebra', count: 5),
          DeviceFolder(id: '2', name: 'Apple', count: 5),
        ],
      );
      final container = containerWith(fake);

      final folders = await container.read(deviceFoldersProvider.future);

      expect([for (final f in folders) f.name], ['Apple', 'Zebra']);
    });
  });

  group('folderAssetsProvider', () {
    test('loads the first page and paginates with loadMore', () async {
      // Two full pages plus a short third, so hasMore flips exactly once.
      final all = assetsInMonth(2026, 8, 200, prefix: 'cam');
      final fake = FakePhotoLibraryService(
        folders: const [DeviceFolder(id: 'cam', name: 'Camera', count: 200)],
        folderAssetsById: {'cam': all},
      );
      final container = containerWith(fake);

      final first = await container.read(folderAssetsProvider('cam').future);
      final notifier = container.read(folderAssetsProvider('cam').notifier);
      expect(first, hasLength(90)); // PagedAssetsNotifier.pageSize
      expect(notifier.hasMore, isTrue);
      expect(first.first.id, all.first.id); // newest first, order preserved

      await notifier.loadMore();
      expect(container.read(folderAssetsProvider('cam')).value, hasLength(180));
      expect(notifier.hasMore, isTrue);

      await notifier.loadMore();
      expect(container.read(folderAssetsProvider('cam')).value, hasLength(200));
      expect(notifier.hasMore, isFalse); // short page ends pagination

      // Exhausted: further loads are a no-op rather than an error.
      await notifier.loadMore();
      expect(container.read(folderAssetsProvider('cam')).value, hasLength(200));
    });

    test('is empty for a folder that no longer resolves', () async {
      final container = containerWith(FakePhotoLibraryService());

      final assets = await container.read(folderAssetsProvider('gone').future);

      expect(assets, isEmpty);
      expect(container.read(folderAssetsProvider('gone').notifier).hasMore,
          isFalse);
    });

    test('keeps each folder id on its own independent page state', () async {
      final fake = FakePhotoLibraryService(
        folderAssetsById: {
          'cam': assetsInMonth(2026, 8, 3, prefix: 'cam'),
          'shots': assetsInMonth(2026, 7, 5, prefix: 'shots'),
        },
      );
      final container = containerWith(fake);

      expect(await container.read(folderAssetsProvider('cam').future),
          hasLength(3));
      expect(await container.read(folderAssetsProvider('shots').future),
          hasLength(5));
    });
  });
}
