import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/faces_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // A photo_asset row is required for the face FK.
  Future<void> asset(String id, {DateTime? at}) => db.indexDao.upsertIndexed(
        assetId: id,
        createdAt: at ?? DateTime(2026, 8, 1),
        isVideo: false,
        width: 100,
        height: 100,
        labels: const [],
        text: '',
      );

  FaceRecord face(List<double> emb) => (
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        embedding: Float32List.fromList(emb),
      );

  test('insertFaces stores faces; unclusteredFaces returns them', () async {
    await asset('a');
    await db.facesDao.insertFaces('a', [face([1, 0]), face([0, 1])]);

    final unclustered = await db.facesDao.unclusteredFaces();
    expect(unclustered, hasLength(2));
    expect(unclustered.first.assetId, 'a');
    expect(unclustered.first.embedding, [1, 0]);
  });

  test('insertFaces replaces the previous faces for an asset', () async {
    await asset('a');
    await db.facesDao.insertFaces('a', [face([1, 0]), face([0, 1])]);
    await db.facesDao.insertFaces('a', [face([1, 1])]);
    expect(await db.facesDao.unclusteredFaces(), hasLength(1));
  });

  test('assignPersonToFace + centroids + summaries', () async {
    await asset('a');
    await asset('b', at: DateTime(2026, 7, 1));
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await db.facesDao.insertFaces('b', [face([1, 0])]);

    final personId = await db.facesDao.createPerson(coverAssetId: 'a');
    for (final f in await db.facesDao.unclusteredFaces()) {
      await db.facesDao.assignPersonToFace(f.id, personId);
    }

    expect(await db.facesDao.unclusteredFaces(), isEmpty);
    final centroids = await db.facesDao.clusteredCentroids();
    expect(centroids.keys, [personId]);
    expect(centroids[personId]!.count, 2);

    final summaries = await db.facesDao.watchPersonSummaries().first;
    expect(summaries, hasLength(1));
    expect(summaries.first.faceCount, 2);
  });

  test('assetsForPerson lists the person\'s photos newest first', () async {
    await asset('a', at: DateTime(2026, 8, 1));
    await asset('b', at: DateTime(2026, 7, 1));
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await db.facesDao.insertFaces('b', [face([1, 0])]);
    final id = await db.facesDao.createPerson(coverAssetId: 'a');
    for (final f in await db.facesDao.unclusteredFaces()) {
      await db.facesDao.assignPersonToFace(f.id, id);
    }

    final assets = await db.facesDao.assetsForPerson(id);
    expect([for (final a in assets) a.id], ['a', 'b']);
  });

  test('renamePerson updates the display name', () async {
    final id = await db.facesDao.createPerson();
    await db.facesDao.renamePerson(id, 'Alice');
    final person = await db.facesDao.watchPerson(id).first;
    expect(person!.displayName, 'Alice');
  });

  test('summaries exclude people with no faces', () async {
    await db.facesDao.createPerson(); // orphan person, no faces
    expect(await db.facesDao.watchPersonSummaries().first, isEmpty);
  });

  test('deleting a photo_asset cascades to its faces', () async {
    await asset('a');
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await (db.delete(db.photoAssets)..where((t) => t.assetId.equals('a'))).go();
    expect(await db.select(db.faceEmbeddings).get(), isEmpty);
  });
}
