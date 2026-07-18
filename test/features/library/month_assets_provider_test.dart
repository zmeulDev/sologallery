import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/library/domain/year_month.dart';
import 'package:sologallery/features/library/month_assets_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/asset_fixtures.dart';

void main() {
  const month = YearMonth(2026, 7);

  /// A container over an in-memory DB seeded with [assets] as cached dated rows
  /// — the full-month grid now paginates the `photo_asset` cache via the DAO.
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
    final container = await containerWith(assetsInMonth(2026, 7, 200));
    final first = await container.read(monthAssetsProvider(month).future);

    expect(first, hasLength(90)); // WatchedAssetsNotifier.pageSize
    expect(container.read(monthAssetsProvider(month).notifier).hasMore, isTrue);
  });

  test('loadMore appends pages until exhausted', () async {
    final container = await containerWith(assetsInMonth(2026, 7, 200));
    await container.read(monthAssetsProvider(month).future);
    final notifier = container.read(monthAssetsProvider(month).notifier);

    await notifier.loadMore();
    expect(container.read(monthAssetsProvider(month)).value, hasLength(180));
    expect(notifier.hasMore, isTrue);

    await notifier.loadMore(); // final partial page (20)
    expect(container.read(monthAssetsProvider(month)).value, hasLength(200));
    expect(notifier.hasMore, isFalse);

    await notifier.loadMore(); // no-op once exhausted
    expect(container.read(monthAssetsProvider(month)).value, hasLength(200));
  });

  test('short month reports no more after the first page', () async {
    final container = await containerWith(assetsInMonth(2026, 7, 5));
    final first = await container.read(monthAssetsProvider(month).future);

    expect(first, hasLength(5));
    expect(container.read(monthAssetsProvider(month).notifier).hasMore, isFalse);
  });

  test('grid re-emits when a new asset is cached (reactive)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.indexDao.upsertMetadata([
      (id: 'a', createdAt: DateTime(2026, 7, 1), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Keep the autoDispose provider alive so the live window stays subscribed.
    container.listen(monthAssetsProvider(month), (_, __) {});

    final first = await container.read(monthAssetsProvider(month).future);
    expect(first.map((a) => a.id), ['a']);

    // A newer capture lands in the same month → the window re-emits with it
    // at the front, no reload.
    await db.indexDao.upsertMetadata([
      (id: 'b', createdAt: DateTime(2026, 7, 2), isVideo: false, width: 1, height: 1, isDated: true),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(monthAssetsProvider(month)).value?.map((a) => a.id).toList(),
      ['b', 'a'],
    );
  });
}
