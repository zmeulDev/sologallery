import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/ml_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

import 'support/fixture_file.dart';

/// On-device proof that the consent gates hold against the **real** ML worker.
///
/// Host tests gate a `FakeMlWorker`, which can only prove the flag was passed.
/// Only a device can show that the real isolate honours it — that no face
/// detector or tflite interpreter runs, and that no embeddings reach the
/// database — which is the whole point of the consent (CLAUDE.md fake-pairing
/// rule).
///
/// Requires photo access already granted. Run with:
///   flutter test integration_test/consent_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<PhotoLibraryService> grantedLibrary() async {
    final photos = PhotoLibraryService();
    expect(
      (await photos.currentAccess()).canReadLibrary,
      isTrue,
      reason: 'Grant photo access before running (open the app once and allow).',
    );
    return photos;
  }

  IndexingService serviceFor(AppDatabase db, PhotoLibraryService photos) =>
      IndexingService(
        dao: db.indexDao,
        faces: db.facesDao,
        memories: db.memoriesDao,
        settings: db.settingsDao,
        photos: photos,
        worker: MlWorkerController(),
      );

  test('without consent the real pipeline derives nothing at all', () async {
    final photos = await grantedLibrary();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final service = serviceFor(db, photos);
    addTearDown(service.dispose);

    // No consent recorded at all — the default state of a fresh install.
    await service.start();

    expect(
      await db.indexDao.allCachedIds(),
      isNotEmpty,
      reason: 'the metadata sweep must still run — consent gates analysis, not '
          'the library cache that fills the grid',
    );
    // Not one inference is stored, and every asset is still pending, because
    // no ML ran to stamp it.
    expect(await db.select(db.photoLabels).get(), isEmpty);
    expect(await db.select(db.photoTexts).get(), isEmpty);
    expect(await db.select(db.faceEmbeddings).get(), isEmpty);
    expect(await db.select(db.persons).get(), isEmpty);
    expect(await db.memoriesDao.watchActive().first, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('content search alone derives labels but never a face', () async {
    final photos = await grantedLibrary();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.settingsDao.setSearchEnabled(true);
    final service = serviceFor(db, photos);
    addTearDown(service.dispose);

    await service.start();

    expect(await db.select(db.photoLabels).get(), isNotEmpty);
    expect(
      await db.select(db.faceEmbeddings).get(),
      isEmpty,
      reason: 'the face detector must not run for a content-only consent',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('the real worker returns no faces when the job declines them', () async {
    // The pushed fixture, not the camera roll: faces are sparse in a real
    // library (~1 in 10 photos), so sampling device assets made this test
    // pass-or-fail on whatever the developer happened to have photographed.
    // `test_fixtures_test.dart` separately proves this image *is* detectable,
    // which is what stops the empty expectations below from being vacuous.
    final file = await fixtureFile('synthetic_face.jpg');
    final bytes = await file.readAsBytes();

    final worker = MlWorkerController();
    addTearDown(() async => await worker.dispose());

    // The positive control, in this same run.
    final accepted = await worker.analyze(bytes: bytes);
    expect(
      accepted.faces,
      isNotEmpty,
      reason: 'the fixture must be detectable, or the gate assertions below '
          'prove nothing — see test_fixtures_test.dart',
    );

    // faces: false must skip detection *and* the thumbnail decode entirely.
    final declined = await worker.analyze(bytes: bytes, faces: false);
    expect(declined.faces, isEmpty);

    // Declining content must likewise yield no labels and no OCR text,
    // independently of the face flag.
    final noContent = await worker.analyze(bytes: bytes, content: false);
    expect(noContent.labels, isEmpty);
    expect(noContent.text, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('enabling face detection backfills an already-indexed library', () async {
    final photos = await grantedLibrary();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Content search on, faces off: the pass stamps `indexed_at`, which is the
    // exact state that would make a naive re-enable a silent no-op.
    await db.settingsDao.setSearchEnabled(true);
    final service = serviceFor(db, photos);
    addTearDown(service.dispose);

    await service.start();
    expect(await db.select(db.faceEmbeddings).get(), isEmpty);
    expect(
      await db.indexDao.pendingMlIds(),
      isEmpty,
      reason: 'the first pass marked everything indexed',
    );

    // The trap this guards: without resetMlPending those assets would never be
    // revisited, so turning the feature on would silently do nothing.
    //
    // setFacesEnabled kicks the backfill pass fire-and-forget (the Settings
    // toggle must not block on a full re-index), and `start()` no-ops while a
    // pass is already running — so awaiting it here would return immediately.
    // Poll for the outcome instead.
    await service.setFacesEnabled(true);

    final deadline = DateTime.now().add(const Duration(minutes: 10));
    var faces = await db.select(db.faceEmbeddings).get();
    while (faces.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      faces = await db.select(db.faceEmbeddings).get();
    }

    expect(faces, isNotEmpty, reason: 'the backfill pass never stored a face');
    // Clustering runs at the end of the pass, so give it the tail of the pass.
    var persons = await db.select(db.persons).get();
    while (persons.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      persons = await db.select(db.persons).get();
    }
    expect(persons, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
