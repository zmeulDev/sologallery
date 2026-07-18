import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/services/indexing_service.dart';

import '../support/asset_fixtures.dart';
import '../support/fake_ml_worker.dart';
import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  IndexingService serviceFor(
    FakePhotoLibraryService photos,
    FakeMlWorker worker,
  ) =>
      IndexingService(
        dao: db.indexDao,
        faces: db.facesDao,
        photos: photos,
        worker: worker,
        tempDir: Directory.systemTemp,
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

    expect(await db.indexDao.indexedAssetIds(), hasLength(3));
    expect(worker.calls, hasLength(3));
    final labels = await db.select(db.photoLabels).get();
    expect(labels, hasLength(6)); // 2 per asset
    final texts = await db.select(db.photoTexts).get();
    expect(texts, hasLength(3)); // OCR text stored per asset
    expect(texts.first.content, 'Hello world');
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

    expect(await db.indexDao.indexedAssetIds(), hasLength(1));
    expect(worker.calls, isEmpty);
    expect(await db.select(db.photoLabels).get(), isEmpty);
  });

  test('empty library does no work and ends idle', () async {
    final photos = FakePhotoLibraryService(thumbnailBytes: Uint8List(0));
    final worker = FakeMlWorker();
    final service = serviceFor(photos, worker);

    await service.start();

    expect(await db.indexDao.indexedAssetIds(), isEmpty);
    expect(worker.calls, isEmpty);
    expect((await service.watchStatus().first).isIndexing, isFalse);
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
