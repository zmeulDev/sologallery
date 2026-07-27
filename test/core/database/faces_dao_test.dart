import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/faces_dao.dart';
import 'package:sologallery/features/people/domain/face_clustering.dart';

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

  // Boxes are fractions of the image, so these are plausible normalized values
  // rather than pixels.
  FaceRecord face(List<double> emb, {double left = 0.1, double top = 0.1}) => (
        left: left,
        top: top,
        right: left + 0.2,
        bottom: top + 0.2,
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

  test('assignPersonToFace + exemplars + summaries', () async {
    await asset('a');
    await asset('b', at: DateTime(2026, 7, 1));
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await db.facesDao.insertFaces('b', [face([1, 0])]);

    final personId = await db.facesDao.createPerson(coverAssetId: 'a');
    for (final f in await db.facesDao.unclusteredFaces()) {
      await db.facesDao.assignPersonToFace(f.id, personId);
    }

    expect(await db.facesDao.unclusteredFaces(), isEmpty);
    final exemplars = await db.facesDao.clusteredExemplars();
    expect(exemplars.keys, [personId]);
    expect(exemplars[personId], hasLength(2));
    expect(exemplars[personId]!.first, [1, 0]);

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

  test('clearPersons removes every person cluster', () async {
    await db.facesDao.createPerson();
    await db.facesDao.createPerson();
    expect(await db.select(db.persons).get(), hasLength(2));

    final cleared = await db.facesDao.clearPersons();
    expect(cleared, 2);
    expect(await db.select(db.persons).get(), isEmpty);
  });

  test('faceCount and allFacesForClustering expose stored faces', () async {
    await asset('a');
    await asset('b', at: DateTime(2026, 7, 1));
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await db.facesDao.insertFaces('b', [face([0, 1])]);

    expect(await db.facesDao.faceCount(), 2);
    final all = await db.facesDao.allFacesForClustering();
    expect(all.map((f) => f.assetId), ['a', 'b']); // ordered by id
    expect(all.first.embedding, [1, 0]);
    expect(all.every((f) => f.personId == null), isTrue);
  });

  test('rebuildClusters reassigns faces, drops empty persons, keeps names',
      () async {
    await asset('a');
    await asset('b', at: DateTime(2026, 7, 1));
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await db.facesDao.insertFaces('b', [face([1, 0])]);
    final faces = await db.facesDao.allFacesForClustering();
    final faceA = faces.firstWhere((f) => f.assetId == 'a').id;
    final faceB = faces.firstWhere((f) => f.assetId == 'b').id;

    // Two incremental persons that are really one; person 'p1' was renamed.
    final p1 = await db.facesDao.createPerson(coverAssetId: 'a');
    final p2 = await db.facesDao.createPerson(coverAssetId: 'b');
    await db.facesDao.assignPersonToFace(faceA, p1);
    await db.facesDao.assignPersonToFace(faceB, p2);
    await db.facesDao.renamePerson(p1, 'Alice');

    // Re-cluster collapses them into one, reusing the renamed p1.
    await db.facesDao.rebuildClusters([
      PlannedCluster(
        faceIds: [faceA, faceB],
        reusePersonId: p1,
        displayName: 'Alice',
        coverAssetId: 'a',
      ),
    ]);

    final persons = await db.facesDao.allPersons();
    expect(persons, hasLength(1)); // p2 (now empty) removed
    expect(persons.single.id, p1);
    expect(persons.single.displayName, 'Alice'); // rename preserved
    final regrouped = await db.facesDao.allFacesForClustering();
    expect(regrouped.every((f) => f.personId == p1), isTrue);
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

  group('coverFace', () {
    // Sets up a person whose curated cover is 'a' but who also has a face on a
    // later-indexed asset 'b'.
    Future<int> personAcrossTwoAssets() async {
      await asset('a');
      await asset('b', at: DateTime(2026, 7, 1));
      await db.facesDao.insertFaces('a', [face([1, 0], left: 0.1)]);
      final personId = await db.facesDao.createPerson(coverAssetId: 'a');
      for (final f in await db.facesDao.unclusteredFaces()) {
        await db.facesDao.assignPersonToFace(f.id, personId);
      }
      // 'b' is indexed afterwards — a higher face id than the cover's.
      await db.facesDao.insertFaces('b', [face([1, 0], left: 0.7)]);
      for (final f in await db.facesDao.unclusteredFaces()) {
        await db.facesDao.assignPersonToFace(f.id, personId);
      }
      return personId;
    }

    // Ordering by newest face instead re-pointed the avatar at a different
    // photo every time a pass added a face to this person, so the People grid
    // visibly reshuffled while indexing ran.
    test('uses the curated cover asset, not the newest face', () async {
      final personId = await personAcrossTwoAssets();
      final cover = await db.facesDao.coverFace(personId);
      expect(cover!.assetId, 'a');
      expect(cover.left, closeTo(0.1, 1e-9));
    });

    test('is stable as later faces are added to the person', () async {
      final personId = await personAcrossTwoAssets();
      final before = await db.facesDao.coverFace(personId);

      await asset('c', at: DateTime(2026, 6, 1));
      await db.facesDao.insertFaces('c', [face([1, 0], left: 0.4)]);
      for (final f in await db.facesDao.unclusteredFaces()) {
        await db.facesDao.assignPersonToFace(f.id, personId);
      }

      final after = await db.facesDao.coverFace(personId);
      expect(after!.assetId, before!.assetId);
      expect(after.left, closeTo(before.left, 1e-9));
    });

    test('falls back to the newest face when no cover is set', () async {
      await asset('a');
      await db.facesDao.insertFaces('a', [face([1, 0])]);
      final personId = await db.facesDao.createPerson(); // no cover
      for (final f in await db.facesDao.unclusteredFaces()) {
        await db.facesDao.assignPersonToFace(f.id, personId);
      }
      expect((await db.facesDao.coverFace(personId))!.assetId, 'a');
    });

    test('falls back when the cover asset no longer holds a face', () async {
      final personId = await personAcrossTwoAssets();
      // The cover photo is deleted from the library; its face cascades away.
      await (db.delete(db.photoAssets)..where((t) => t.assetId.equals('a')))
          .go();
      final cover = await db.facesDao.coverFace(personId);
      expect(cover!.assetId, 'b');
    });

    test('returns null for a person with no faces', () async {
      final personId = await db.facesDao.createPerson();
      expect(await db.facesDao.coverFace(personId), isNull);
    });
  });

  // The People grid/strip resolve every visible avatar's cover in one batch
  // instead of one `coverFace` query per cell as it scrolls in (B2). This just
  // reuses `coverFace`, so these pin that the batch agrees with it face-for-
  // face rather than re-testing cover selection itself.
  group('coverFacesFor', () {
    test('returns the same cover coverFace would, for each id', () async {
      await asset('a');
      await asset('b', at: DateTime(2026, 7, 1));
      await db.facesDao.insertFaces('a', [face([1, 0])]);
      await db.facesDao.insertFaces('b', [face([0, 1])]);
      final p1 = await db.facesDao.createPerson(coverAssetId: 'a');
      final p2 = await db.facesDao.createPerson(coverAssetId: 'b');
      for (final f in await db.facesDao.unclusteredFaces()) {
        await db.facesDao.assignPersonToFace(f.id, f.assetId == 'a' ? p1 : p2);
      }

      final batch = await db.facesDao.coverFacesFor([p1, p2]);
      final individually = {
        p1: await db.facesDao.coverFace(p1),
        p2: await db.facesDao.coverFace(p2),
      };
      expect(batch[p1]!.assetId, individually[p1]!.assetId);
      expect(batch[p1]!.left, closeTo(individually[p1]!.left, 1e-9));
      expect(batch[p2]!.assetId, individually[p2]!.assetId);
      expect(batch[p2]!.left, closeTo(individually[p2]!.left, 1e-9));
    });

    test('omits people with no face', () async {
      final withFace = await db.facesDao.createPerson(coverAssetId: 'a');
      await asset('a');
      await db.facesDao.insertFaces('a', [face([1, 0])]);
      for (final f in await db.facesDao.unclusteredFaces()) {
        await db.facesDao.assignPersonToFace(f.id, withFace);
      }
      final orphan = await db.facesDao.createPerson(); // no faces at all

      final batch = await db.facesDao.coverFacesFor([withFace, orphan]);
      expect(batch.keys, [withFace]);
      expect(batch.containsKey(orphan), isFalse);
    });

    test('an empty id list returns an empty map', () async {
      expect(await db.facesDao.coverFacesFor(const []), isEmpty);
    });
  });

  group('user merges', () {
    // Two clusters of the same person that clustering keeps apart — the real
    // case is one man with and without sunglasses.
    Future<(int, int)> twoClusters() async {
      await asset('a');
      await asset('b', at: DateTime(2026, 7, 1));
      await db.facesDao.insertFaces('a', [face([1, 0])]);
      await db.facesDao.insertFaces('b', [face([0, 1])]);
      final faces = await db.facesDao.allFacesForClustering();
      final big = await db.facesDao.createPerson(coverAssetId: 'a');
      final small = await db.facesDao.createPerson(coverAssetId: 'b');
      await db.facesDao.renamePerson(big, 'Zml');
      await db.facesDao.renamePerson(small, 'ZmlG');
      await db.facesDao.assignPersonToFace(
        faces.firstWhere((f) => f.assetId == 'a').id,
        big,
      );
      await db.facesDao.assignPersonToFace(
        faces.firstWhere((f) => f.assetId == 'b').id,
        small,
      );
      return (big, small);
    }

    test('folds the absorbed cluster into the survivor', () async {
      final (big, small) = await twoClusters();
      await db.facesDao.mergePersons(into: big, from: small);

      final summaries = await db.facesDao.watchPersonSummaries().first;
      expect(summaries, hasLength(1));
      expect(summaries.single.id, big);
      expect(summaries.single.displayName, 'Zml');
      expect(summaries.single.faceCount, 2); // counts add up
    });

    test('the survivor owns both clusters\' photos', () async {
      final (big, small) = await twoClusters();
      await db.facesDao.mergePersons(into: big, from: small);

      final assets = await db.facesDao.assetsForPerson(big);
      expect(assets.map((a) => a.id), ['a', 'b']);
      // The absorbed row is not a person any more, so it has no photos of its
      // own to show.
      expect(await db.facesDao.assetsForPerson(small), isEmpty);
    });

    test('unmerge restores the absorbed person', () async {
      final (big, small) = await twoClusters();
      await db.facesDao.mergePersons(into: big, from: small);
      await db.facesDao.unmergePerson(small);

      final summaries = await db.facesDao.watchPersonSummaries().first;
      expect(summaries, hasLength(2));
      expect(await db.facesDao.assetsForPerson(small), hasLength(1));
    });

    test('mergedPeopleOf lists what the survivor absorbed', () async {
      final (big, small) = await twoClusters();
      expect(await db.facesDao.mergedPeopleOf(big), isEmpty);
      await db.facesDao.mergePersons(into: big, from: small);
      final absorbed = await db.facesDao.mergedPeopleOf(big);
      expect(absorbed.map((p) => p.displayName), ['ZmlG']);
    });

    test('chains stay one hop deep, so reads never have to recurse', () async {
      final (big, small) = await twoClusters();
      await asset('c', at: DateTime(2026, 6, 1));
      await db.facesDao.insertFaces('c', [face([1, 1])]);
      final third = await db.facesDao.createPerson(coverAssetId: 'c');
      final cFace = (await db.facesDao.allFacesForClustering())
          .firstWhere((f) => f.assetId == 'c');
      await db.facesDao.assignPersonToFace(cFace.id, third);

      // Merging into an already-merged person redirects to its root instead.
      await db.facesDao.mergePersons(into: big, from: small);
      await db.facesDao.mergePersons(into: small, from: third);

      final rows = await db.facesDao.allPersons();
      expect(rows.firstWhere((p) => p.id == third).mergedInto, big);
      final summaries = await db.facesDao.watchPersonSummaries().first;
      expect(summaries, hasLength(1));
      expect(summaries.single.faceCount, 3);
    });

    test('merging a person into its own descendant is refused', () async {
      final (big, small) = await twoClusters();
      await db.facesDao.mergePersons(into: big, from: small);
      // `small` already resolves to `big`; this would otherwise make a cycle.
      await db.facesDao.mergePersons(into: small, from: big);

      final rows = await db.facesDao.allPersons();
      expect(rows.firstWhere((p) => p.id == big).mergedInto, isNull);
      expect(await db.facesDao.watchPersonSummaries().first, hasLength(1));
    });

    test('deleting the survivor resurfaces the absorbed person', () async {
      final (big, small) = await twoClusters();
      await db.facesDao.mergePersons(into: big, from: small);
      await (db.delete(db.persons)..where((p) => p.id.equals(big))).go();

      final rows = await db.facesDao.allPersons();
      expect(rows.single.id, small);
      expect(rows.single.mergedInto, isNull, reason: 'setNull, not cascade');
    });

    test('a global re-cluster does not undo the merge', () async {
      // The whole reason the merge is a redirect rather than a move of faces:
      // rebuildClusters reassigns every face from scratch, and the two
      // embeddings are far apart, so clustering re-derives the same two groups.
      final (big, small) = await twoClusters();
      await db.facesDao.mergePersons(into: big, from: small);

      final all = await db.facesDao.allFacesForClustering();
      final groups = clusterAll(
        [for (final f in all) (id: f.id, embedding: f.embedding)],
      );
      expect(groups, hasLength(2), reason: 'clustering still splits them');
      await db.facesDao.rebuildClusters(
        planClusters(
          groups: groups,
          faceMeta: {
            for (final f in all) f.id: (personId: f.personId, assetId: f.assetId),
          },
          persons: {
            for (final p in await db.facesDao.allPersons())
              p.id: (displayName: p.displayName, coverAssetId: p.coverAssetId),
          },
        ),
      );

      final summaries = await db.facesDao.watchPersonSummaries().first;
      expect(summaries, hasLength(1), reason: 'still one person to the user');
      expect(summaries.single.displayName, 'Zml');
      expect(summaries.single.faceCount, 2);
    });
  });

  // The incremental clustering batch: `_clusterNewFaces` decides every face's
  // person in memory, then applies the whole plan in one transaction so the
  // People strip's `watchPersonSummaries` emits once for the pass instead of
  // once per face. This proves the emission collapse at the DAO layer.
  test('applyIncrementalClusters mints new persons and assigns in one batch',
      () async {
    for (final id in const ['a', 'b', 'c']) {
      await asset(id);
      await db.facesDao.insertFaces(id, [face([1, 0])]);
    }
    final unclustered = await db.facesDao.unclusteredFaces();
    expect(unclustered, hasLength(3));

    final emits = <List<PersonSummary>>[];
    final sub = db.facesDao.watchPersonSummaries().listen(emits.add);
    await Future<void>.delayed(Duration.zero); // drain the initial empty emit

    // Three new persons (no existing exemplars to reuse), one face each.
    await db.facesDao.applyIncrementalClusters([
      IncrementalClusterPlan(
        faceIds: [unclustered[0].id],
        coverAssetId: 'a',
      ),
      IncrementalClusterPlan(
        faceIds: [unclustered[1].id],
        coverAssetId: 'b',
      ),
      IncrementalClusterPlan(
        faceIds: [unclustered[2].id],
        coverAssetId: 'c',
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // drain

    await sub.cancel();

    // Exactly one non-empty emission: the whole batch landed in one
    // transaction, so the summaries went from empty straight to three — not
    // 1, then 2, then 3.
    final nonEmpty = emits.where((l) => l.isNotEmpty).toList();
    expect(nonEmpty, hasLength(1), reason: 'one batch → one summary emission');
    expect(nonEmpty.single, hasLength(3));
    // The unassigned faces are all gone.
    expect(await db.facesDao.unclusteredFaces(), isEmpty);
  });

  test('applyIncrementalClusters reuses an existing person without touching it',
      () async {
    await asset('a');
    await asset('b');
    await db.facesDao.insertFaces('a', [face([1, 0])]);
    await db.facesDao.insertFaces('b', [face([1, 0])]);
    final existing = await db.facesDao.createPerson(coverAssetId: 'a');
    await db.facesDao.renamePerson(existing, 'Alice');

    final unclustered = await db.facesDao.unclusteredFaces();
    await db.facesDao.applyIncrementalClusters([
      IncrementalClusterPlan(
        faceIds: unclustered.map((f) => f.id).toList(),
        reusePersonId: existing,
      ),
    ]);

    final persons = await db.select(db.persons).get();
    expect(persons, hasLength(1), reason: 'no new person minted');
    expect(persons.single.id, existing);
    expect(persons.single.displayName, 'Alice', reason: 'name preserved');
    expect(persons.single.coverAssetId, 'a', reason: 'cover preserved');
    expect(await db.facesDao.unclusteredFaces(), isEmpty);
  });
}
