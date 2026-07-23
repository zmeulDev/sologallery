import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/library/year_assets_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

void main() {
  const year = 2026;

  Future<ProviderContainer> containerWith(List<AssetRef> assets) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      for (final a in assets)
        (
          id: a.id,
          createdAt: a.createdAt,
          isVideo: false,
          width: 1,
          height: 1,
          isDated: true,
        ),
    ]);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('first page is capped at the page size with more available', () async {
    final container = await containerWith(assetsInYear(year, 200));
    final first = await container.read(yearAssetsProvider(year).future);

    expect(first, hasLength(90)); // WatchedAssetsNotifier.pageSize
    expect(container.read(yearAssetsProvider(year).notifier).hasMore, isTrue);
  });

  test('loadMore appends pages until exhausted', () async {
    final container = await containerWith(assetsInYear(year, 200));
    await container.read(yearAssetsProvider(year).future);
    final notifier = container.read(yearAssetsProvider(year).notifier);

    await notifier.loadMore();
    expect(container.read(yearAssetsProvider(year)).value, hasLength(180));
    expect(notifier.hasMore, isTrue);

    await notifier.loadMore(); // final partial page (20)
    expect(container.read(yearAssetsProvider(year)).value, hasLength(200));
    expect(notifier.hasMore, isFalse);

    await notifier.loadMore(); // no-op once exhausted
    expect(container.read(yearAssetsProvider(year)).value, hasLength(200));
  });

  test('short year reports no more after the first page', () async {
    final container = await containerWith(assetsInYear(year, 5));
    final first = await container.read(yearAssetsProvider(year).future);

    expect(first, hasLength(5));
    expect(container.read(yearAssetsProvider(year).notifier).hasMore, isFalse);
  });

  test('grid re-emits when a new asset is cached (reactive)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      (id: 'a', createdAt: DateTime(year, 7, 1), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(yearAssetsProvider(year), (_, _) {});

    final first = await container.read(yearAssetsProvider(year).future);
    expect(first.map((a) => a.id), ['a']);

    await db.indexDao.upsertMetadata([
      (id: 'b', createdAt: DateTime(year, 7, 2), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(yearAssetsProvider(year)).value?.map((a) => a.id).toList(),
      ['b', 'a'],
    );
  });
}

List<AssetRef> assetsInYear(int year, int count) {
  return [
    for (var i = 0; i < count; i++)
      AssetRef(
        id: '$year-$i',
        // Spread across the year, newest first.
        createdAt: DateTime(year, 12, 31, 12).subtract(Duration(minutes: i)),
      ),
  ];
}
