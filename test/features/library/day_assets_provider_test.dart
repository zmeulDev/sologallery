import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/library/day_assets_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

void main() {
  final day = DateTime(2026, 7, 23);

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
    final container = await containerWith(assetsOnDay(day, 200));
    final first = await container.read(dayAssetsProvider(day).future);

    expect(first, hasLength(90)); // WatchedAssetsNotifier.pageSize
    expect(container.read(dayAssetsProvider(day).notifier).hasMore, isTrue);
  });

  test('loadMore appends pages until exhausted', () async {
    final container = await containerWith(assetsOnDay(day, 200));
    await container.read(dayAssetsProvider(day).future);
    final notifier = container.read(dayAssetsProvider(day).notifier);

    await notifier.loadMore();
    expect(container.read(dayAssetsProvider(day)).value, hasLength(180));
    expect(notifier.hasMore, isTrue);

    await notifier.loadMore(); // final partial page (20)
    expect(container.read(dayAssetsProvider(day)).value, hasLength(200));
    expect(notifier.hasMore, isFalse);

    await notifier.loadMore(); // no-op once exhausted
    expect(container.read(dayAssetsProvider(day)).value, hasLength(200));
  });

  test('short day reports no more after the first page', () async {
    final container = await containerWith(assetsOnDay(day, 5));
    final first = await container.read(dayAssetsProvider(day).future);

    expect(first, hasLength(5));
    expect(container.read(dayAssetsProvider(day).notifier).hasMore, isFalse);
  });

  test('grid re-emits when a new asset is cached (reactive)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      (id: 'a', createdAt: day, isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.listen(dayAssetsProvider(day), (_, _) {});

    final first = await container.read(dayAssetsProvider(day).future);
    expect(first.map((a) => a.id), ['a']);

    await db.indexDao.upsertMetadata([
      (id: 'b', createdAt: day.add(const Duration(minutes: 1)), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(dayAssetsProvider(day)).value?.map((a) => a.id).toList(),
      ['b', 'a'],
    );
  });
}

List<AssetRef> assetsOnDay(DateTime day, int count) {
  return [
    for (var i = 0; i < count; i++)
      AssetRef(
        id: 'day-${day.day}-$i',
        // Spread across the day, newest first.
        createdAt: DateTime(day.year, day.month, day.day, 23, 59).subtract(Duration(minutes: i)),
      ),
  ];
}
