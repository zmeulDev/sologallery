import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/index_dao.dart'
    show FavoriteAsset, IndexDao;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/saved/saved_providers.dart';

/// A fake [IndexDao] whose favorites stream is fully controlled by the test,
/// so `savedFavoritesProvider`'s `distinct(listEquals)` can be asserted
/// against a stream shaped exactly like Drift's real re-emission behaviour
/// (a fresh `List<FavoriteAsset>` per emission) without depending on Drift's
/// own re-emission timing.
class _FakeIndexDao extends IndexDao {
  _FakeIndexDao(super.db, this._stream);

  final Stream<List<FavoriteAsset>> _stream;

  @override
  Stream<List<FavoriteAsset>> watchFavoritesInCache() => _stream;
}

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

  test(
    'savedFavoritesProvider drops a duplicate emission and propagates a '
    'changed one',
    () async {
      final controller = StreamController<List<FavoriteAsset>>();
      addTearDown(controller.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          indexDaoProvider.overrideWithValue(
            _FakeIndexDao(db, controller.stream),
          ),
        ],
      );
      addTearDown(container.dispose);

      final emissions = <List<FavoriteAsset>>[];
      container.listen(savedFavoritesProvider, (_, next) {
        next.whenData(emissions.add);
      });

      FavoriteAsset favorite({int height = 150}) => (
        assetId: 'a1',
        favoritedAt: DateTime(2024, 1, 2),
        width: 100,
        height: height,
      );

      // Two structurally-equal but separately-allocated lists — matching how
      // Drift re-runs and re-emits the real join on every unrelated
      // photo_asset write, even when its result hasn't actually changed.
      controller.add([favorite()]);
      await pumpEventQueue();
      controller.add([favorite()]);
      await pumpEventQueue();
      expect(
        emissions.length,
        1,
        reason: 'the byte-for-byte-identical re-emission is dropped',
      );

      // A genuine change — here, cached dimensions resolving to a new value —
      // must still propagate.
      controller.add([favorite(height: 200)]);
      await pumpEventQueue();
      expect(emissions.length, 2);
      expect(emissions.last.single.height, 200);
    },
  );
}
