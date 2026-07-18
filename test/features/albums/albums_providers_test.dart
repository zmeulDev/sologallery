import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/albums/albums_providers.dart';

void main() {
  late AppDatabase db;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('albumActions.create then albumSummariesProvider reflects it', () async {
    final container = makeContainer();
    final id = await container.read(albumActionsProvider).create('Trip');
    await db.albumsDao.addEntry(id, 'a1');

    // Hold a listener so the autoDispose stream isn't torn down before `.future`.
    container.listen(albumSummariesProvider, (_, _) {});
    final summaries = await container.read(albumSummariesProvider.future);
    expect(summaries.single.name, 'Trip');
    expect(summaries.single.entryCount, 1);
    expect(summaries.single.coverAssetId, 'a1');
  });

  test('albumActions.delete removes the album', () async {
    final container = makeContainer();
    final id = await container.read(albumActionsProvider).create('Trip');

    await container.read(albumActionsProvider).delete(id);

    container.listen(albumSummariesProvider, (_, _) {});
    container.listen(albumProvider(id), (_, _) {});
    expect(await container.read(albumSummariesProvider.future), isEmpty);
    expect(await container.read(albumProvider(id).future), isNull);
  });

  test('albumEntriesProvider yields entries newest-added first', () async {
    final container = makeContainer();
    final id = await container.read(albumActionsProvider).create('Trip');
    await db.albumsDao.addEntry(id, 'old', at: DateTime(2020, 1, 1));
    await db.albumsDao.addEntry(id, 'new', at: DateTime(2024, 1, 1));

    container.listen(albumEntriesProvider(id), (_, _) {});
    final entries = await container.read(albumEntriesProvider(id).future);
    expect(entries.map((e) => e.assetId).toList(), ['new', 'old']);
  });
}
