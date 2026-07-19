import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/saved/saved_providers.dart';

void main() {
  late AppDatabase db;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Keep the autoDispose stream alive across the `.future` read below.
    container.listen(savedFavoritesProvider, (_, _) {});
    return container;
  }

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Caches lean photo_asset rows for [ids] so the favorites→cache join resolves.
  Future<void> cache(List<String> ids) => db.indexDao.upsertMetadata([
        for (final id in ids)
          (
            id: id,
            createdAt: DateTime(2024),
            isVideo: false,
            width: 1,
            height: 1,
            isDated: true,
          ),
      ]);

  test('savedFavoritesProvider yields favorites newest-favorited first',
      () async {
    await cache(['old', 'new']);
    await db.favoritesDao.add('old', at: DateTime(2020, 1, 1));
    await db.favoritesDao.add('new', at: DateTime(2024, 1, 1));

    final rows = await makeContainer().read(savedFavoritesProvider.future);
    expect(rows.map((f) => f.assetId).toList(), ['new', 'old']);
  });

  test('savedFavoritesProvider is empty with no favorites', () async {
    final rows = await makeContainer().read(savedFavoritesProvider.future);
    expect(rows, isEmpty);
  });

  test('savedFavoritesProvider drops a favorite whose asset is not cached',
      () async {
    await cache(['kept']); // 'gone' is favorited but never cached (deleted)
    await db.favoritesDao.add('kept', at: DateTime(2024, 1, 2));
    await db.favoritesDao.add('gone', at: DateTime(2024, 1, 3));

    final rows = await makeContainer().read(savedFavoritesProvider.future);
    expect(rows.map((f) => f.assetId).toList(), ['kept']);
  });
}
