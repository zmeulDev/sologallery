import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../support/asset_fixtures.dart';
import '../support/fake_ml_worker.dart';
import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  IndexingService serviceFor(
    FakePhotoLibraryService photos,
    FakeMlWorker worker, {
    Duration debounce = const Duration(seconds: 2),
    int reclusterThreshold = 20,
  }) =>
      IndexingService(
        dao: db.indexDao,
        faces: db.facesDao,
        settings: db.settingsDao,
        photos: photos,
        worker: worker,
        tempDir: Directory.systemTemp,
        resweepDebounce: debounce,
        reclusterThreshold: reclusterThreshold,
      );

  test('indexes every library asset and persists labels', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 3),
      thumbnailBytes: Uint8List.fromList([1, 2, 3]),
    );
    final worker = FakeMlWorker(
      labels: const [('Dog', 0.9), ('Grass', 0.6)],
      text: 'Hello world',
    );

    await serviceFor(photos, worker).start();

    expect(await db.indexDao.allCachedIds(), hasLength(3));
    expect(worker.calls, hasLength(3));
    final labels = await db.select(db.photoLabels).get();
    expect(labels, hasLength(6)); // 2 per asset
    final texts = await db.select(db.photoTexts).get();
    expect(texts, hasLength(3)); // OCR text stored per asset
    expect(texts.first.content, 'Hello world');
  });

  test('OCR runs on a distinct higher-res image path', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 1),
      thumbnailBytes: Uint8List.fromList([1, 2, 3]),
    );
    final worker = FakeMlWorker(text: 'tiny caption text');

    await serviceFor(photos, worker).start();

    expect(worker.calls, hasLength(1));
    // OCR got its own (larger) temp, separate from the label/face 512 image.
    expect(worker.ocrCalls.single, isNotNull);
    expect(worker.ocrCalls.single, isNot(worker.calls.single));
    final texts = await db.select(db.photoTexts).get();
    expect(texts.single.content, 'tiny caption text');
  });

  test('detected faces are stored and clustered into a person', () async {
    final emb = Float32List.fromList(List.filled(192, 0.1));
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 2),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    // Same embedding on both assets → should merge into one person.
    final worker = FakeMlWorker(
      faces: [(left: 0, top: 0, right: 10, bottom: 10, embedding: emb)],
    );

    await serviceFor(photos, worker).start();

    final faceRows = await db.select(db.faceEmbeddings).get();
    expect(faceRows, hasLength(2)); // one face per asset
    final persons = await db.select(db.persons).get();
    expect(persons, hasLength(1)); // clustered together
    expect(faceRows.every((f) => f.personId == persons.first.id), isTrue);
  });

  test('a second pass skips already-indexed assets', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 2),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    final worker = FakeMlWorker();

    await serviceFor(photos, worker).start();
    expect(worker.calls, hasLength(2));

    // Same service instance, nothing new in the library.
    await serviceFor(photos, worker).start();
    expect(worker.calls, hasLength(2)); // no re-work
  });

  test('records an asset even when it has no thumbnail (no labels)', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 1),
      // thumbnailBytes null → labeling is skipped, asset still marked indexed.
    );
    final worker = FakeMlWorker();

    await serviceFor(photos, worker).start();

    expect(await db.indexDao.allCachedIds(), hasLength(1));
    expect(worker.calls, isEmpty);
    expect(await db.select(db.photoLabels).get(), isEmpty);
  });

  test('empty library does no work and ends idle', () async {
    final photos = FakePhotoLibraryService(thumbnailBytes: Uint8List(0));
    final worker = FakeMlWorker();
    final service = serviceFor(photos, worker);

    await service.start();

    expect(await db.indexDao.allCachedIds(), isEmpty);
    expect(worker.calls, isEmpty);
    expect((await service.watchStatus().first).isIndexing, isFalse);
  });

  test('a foreground library change re-sweeps in the new asset', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 1),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    final worker = FakeMlWorker();
    final service =
        serviceFor(photos, worker, debounce: const Duration(milliseconds: 5));
    addTearDown(service.dispose);

    await service.start();
    expect(await db.indexDao.allCachedIds(), hasLength(1));
    expect(photos.startChangeNotifyCount, 1); // listener registered once

    // A new photo lands while the app is foregrounded.
    photos.assets.add(
      AssetRef(id: 'new-asset', createdAt: DateTime(2026, 8, 15)),
    );
    photos.fireLibraryChange();
    await Future<void>.delayed(const Duration(milliseconds: 60)); // debounce + sweep

    expect(await db.indexDao.allCachedIds(), containsAll(<String>['new-asset']));
  });

  test('rebuild clears the index (incl. persons) and re-sweeps', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 2),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    final service = serviceFor(photos, FakeMlWorker());
    addTearDown(service.dispose);

    await service.start();
    expect(await db.indexDao.allCachedIds(), hasLength(2));
    // A stale person cluster a rebuild must wipe.
    await db.facesDao.createPerson();
    expect(await db.select(db.persons).get(), hasLength(1));

    final swept = <bool>[];
    final sub = service.watchSwept().listen(swept.add);

    await service.rebuild();
    await Future<void>.delayed(const Duration(milliseconds: 10)); // flush events
    await sub.cancel();

    expect(await db.indexDao.allCachedIds(), hasLength(2)); // re-swept
    expect(await db.select(db.persons).get(), isEmpty); // cluster cleared
    // Cache flips not-ready → ready during the rebuild (drives the spinner).
    expect(swept, containsAllInOrder([false, true]));
  });

  // Seeds two assets already indexed, each with an identical-embedding face
  // assigned to a *separate* person (p1 renamed) — the order-drift a global
  // re-cluster should heal. Returns (p1, p2).
  Future<(int, int)> seedTwoDriftedPersons() async {
    for (final id in const ['a', 'b']) {
      await db.indexDao.upsertIndexed(
        assetId: id,
        createdAt: DateTime(2026, 8, 1),
        isVideo: false,
        width: 1,
        height: 1,
        labels: const [],
        text: '',
      );
      await db.facesDao.insertFaces(id, [
        (left: 0, top: 0, right: 1, bottom: 1, embedding: Float32List.fromList([1, 0])),
      ]);
    }
    final faces = await db.facesDao.allFacesForClustering();
    final p1 = await db.facesDao.createPerson(coverAssetId: 'a');
    final p2 = await db.facesDao.createPerson(coverAssetId: 'b');
    await db.facesDao
        .assignPersonToFace(faces.firstWhere((f) => f.assetId == 'a').id, p1);
    await db.facesDao
        .assignPersonToFace(faces.firstWhere((f) => f.assetId == 'b').id, p2);
    await db.facesDao.renamePerson(p1, 'Alice');
    return (p1, p2);
  }

  FakePhotoLibraryService photosWithAbAnd(String extraId) =>
      FakePhotoLibraryService(assets: [
        AssetRef(id: 'a', createdAt: DateTime(2026, 8, 3)),
        AssetRef(id: 'b', createdAt: DateTime(2026, 8, 2)),
        AssetRef(id: extraId, createdAt: DateTime(2026, 8, 1)),
      ]);

  test('a pass past the threshold globally re-clusters, preserving the rename',
      () async {
    final (p1, _) = await seedTwoDriftedPersons();
    final service = serviceFor(
      photosWithAbAnd('c'),
      FakeMlWorker(), // no thumbnail bytes → c indexed, adds no faces
      reclusterThreshold: 1,
    );
    addTearDown(service.dispose);

    await service.start();

    final persons = await db.select(db.persons).get();
    expect(persons, hasLength(1)); // the two drifted persons collapsed to one
    expect(persons.single.id, p1); // reused the renamed person
    expect(persons.single.displayName, 'Alice'); // rename preserved
    final faceRows = await db.select(db.faceEmbeddings).get();
    expect(faceRows.every((f) => f.personId == p1), isTrue);
  });

  test('below the threshold the global re-cluster does not run', () async {
    await seedTwoDriftedPersons();
    final service = serviceFor(
      photosWithAbAnd('c'),
      FakeMlWorker(),
      reclusterThreshold: 100, // 2 faces never reaches it
    );
    addTearDown(service.dispose);

    await service.start();

    expect(await db.select(db.persons).get(), hasLength(2)); // untouched
  });

  test('dispose stops the change listener', () async {
    final photos = FakePhotoLibraryService(thumbnailBytes: Uint8List(0));
    final service = serviceFor(photos, FakeMlWorker());
    await service.start();
    await service.dispose();
    expect(photos.stopChangeNotifyCount, 1);
  });

  test('dispose tears down the worker', () async {
    final worker = FakeMlWorker();
    final service = serviceFor(
      FakePhotoLibraryService(thumbnailBytes: Uint8List(0)),
      worker,
    );
    await service.dispose();
    expect(worker.disposed, isTrue);
  });
}
