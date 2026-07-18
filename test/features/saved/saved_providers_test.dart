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

  test('savedFavoritesProvider yields favorites newest-favorited first',
      () async {
    await db.favoritesDao.add('old', at: DateTime(2020, 1, 1));
    await db.favoritesDao.add('new', at: DateTime(2024, 1, 1));

    final rows = await makeContainer().read(savedFavoritesProvider.future);
    expect(rows.map((f) => f.assetId).toList(), ['new', 'old']);
  });

  test('savedFavoritesProvider is empty with no favorites', () async {
    final rows = await makeContainer().read(savedFavoritesProvider.future);
    expect(rows, isEmpty);
  });
}
