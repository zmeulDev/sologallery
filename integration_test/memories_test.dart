import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/memories/domain/memory_builder.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/ml_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof that memory generation works against the **real** photo
/// library and the real Drift connection — the path host tests only see
/// through `FakePhotoLibraryService` (CLAUDE.md fake-pairing rule).
///
/// Host tests plan memories from synthetic dates. Only a device can show that
/// `photo_manager`'s reported capture dates actually cluster (the Android
/// DATE_TAKEN vs DATE_ADDED trap lives on this axis) and that the local-time
/// `STRFTIME` day matching agrees with `DateTime.now()` in the device's zone.
///
/// Requires photo access already granted. Run with:
///   flutter test integration_test/memories_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the indexer generates memories from the real library', () async {
    final photos = PhotoLibraryService();
    final access = await photos.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access before running (open the app once and allow).',
    );

    // A real schema on a throwaway in-memory connection: the generation path is
    // under test, not the app's persisted database.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Memories are opt-in — without consent the indexer generates none, which
    // is exactly what `consent_test.dart` asserts. Here we want them.
    await db.settingsDao.setMemoriesEnabled(true);
    await db.settingsDao.setFacesEnabled(true);

    final service = IndexingService(
      dao: db.indexDao,
      faces: db.facesDao,
      memories: db.memoriesDao,
      settings: db.settingsDao,
      photos: photos,
      worker: MlWorkerController(),
    );
    addTearDown(service.dispose);

    await service.start();

    final cached = await db.indexDao.allCachedIds();
    expect(cached, isNotEmpty,
        reason: 'the metadata sweep must see the real library first');

    // Whether any memory qualifies depends on what is actually on the device,
    // so assert the invariants that must hold for whatever was produced rather
    // than a fixed count.
    final cards = await db.memoriesDao.watchActive().first;
    for (final card in cards) {
      expect(card.assetCount, greaterThan(0));
      expect(card.assetCount,
          lessThanOrEqualTo(MemoryBuilder.maxAssetsPerMemory));
      expect(card.title, isNotEmpty);

      final assets = await db.memoriesDao.assetsFor(card.id);
      expect(assets, hasLength(card.assetCount));
      // Every id must resolve against the real library, and the story must
      // read forward in time.
      for (var i = 1; i < assets.length; i++) {
        expect(
          assets[i].createdAt.isBefore(assets[i - 1].createdAt),
          isFalse,
          reason: 'entries are ordered oldest-first',
        );
      }
      expect(cached, containsAll([for (final a in assets) a.id]));
    }

    // The regeneration baseline must be stamped, or every launch would redo it.
    expect(await db.settingsDao.read('memories_generated_on'), isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('on-this-day matching agrees with the device timezone', () async {
    final photos = PhotoLibraryService();
    expect((await photos.currentAccess()).canReadLibrary, isTrue);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // Seed a row at local midnight today — the exact case Drift's UTC
    // `.month`/`.day` extraction gets wrong outside UTC.
    final now = DateTime.now();
    final localMidnight = DateTime(now.year, now.month, now.day, 0, 30);
    await db.indexDao.upsertIndexed(
      assetId: 'tz-probe',
      createdAt: localMidnight,
      isVideo: false,
      width: 10,
      height: 10,
      labels: const [],
      text: '',
    );

    final hits = await db.memoriesDao.onThisDay(now.month, now.day);
    expect(hits.map((h) => h.assetId), contains('tz-probe'));
  });
}
