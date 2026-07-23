import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;
  late FakePhotoLibraryService fake;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fake = FakePhotoLibraryService(
      details: {
        'a1': AssetDetail(
          id: 'a1',
          width: 4000,
          height: 3000,
          createdAt: _sample,
          orientationDegrees: 0,
          isVideo: false,
        ),
      },
    );
  });

  tearDown(() async => db.close());

  test('toggleFavorite adds then removes', () async {
    final actions = makeContainer().read(detailActionsProvider);
    await actions.toggleFavorite('a1');
    expect(await db.favoritesDao.isFavorite('a1'), isTrue);
    await actions.toggleFavorite('a1');
    expect(await db.favoritesDao.isFavorite('a1'), isFalse);
  });

  test('createAlbum then addToAlbum writes an entry', () async {
    final actions = makeContainer().read(detailActionsProvider);
    final id = await actions.createAlbum('Trip');
    await actions.addToAlbum(id, 'a1');
    final entries = await db.albumsDao.watchEntries(id).first;
    expect(entries.map((e) => e.assetId), ['a1']);
  });

  test('delete purges favorites and album entries and reports true', () async {
    final container = makeContainer();
    final actions = container.read(detailActionsProvider);
    await db.favoritesDao.add('a1');
    final album = await db.albumsDao.createAlbum('Trip');
    await db.albumsDao.addEntry(album, 'a1');

    final ok = await actions.delete('a1');

    expect(ok, isTrue);
    expect(fake.deleteCalls, [
      ['a1']
    ]);
    expect(await db.favoritesDao.isFavorite('a1'), isFalse);
    expect(await db.albumsDao.watchEntries(album).first, isEmpty);
  });

  test('delete leaves rows intact when the OS deletion is cancelled', () async {
    fake = FakePhotoLibraryService(deleteResultOverride: const []);
    final actions = makeContainer().read(detailActionsProvider);
    await db.favoritesDao.add('a1');

    final ok = await actions.delete('a1');

    expect(ok, isFalse);
    expect(await db.favoritesDao.isFavorite('a1'), isTrue);
  });

  test('assetDetailProvider surfaces the service projection', () async {
    final detail = await makeContainer().read(assetDetailProvider('a1').future);
    expect(detail?.width, 4000);
  });

  test('detailImageProvider uses the current max edge override', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(fake),
        detailImageMaxEdgeProvider.overrideWithValue(1024),
      ],
    );
    addTearDown(container.dispose);

    await container.read(detailImageProvider('a1').future);

    expect(fake.previewMaxEdges, [1024]);
  });
}

final _sample = DateTime(2026, 7, 12, 14, 33);
