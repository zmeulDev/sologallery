import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/people/domain/face_clustering.dart';
import 'package:sologallery/services/ml_service.dart';

import 'support/fixture_file.dart';

/// On-device proof of the People merge invariant against the **real**
/// MobileFaceNet embedder: a user merge is stored as a redirect
/// (`Persons.mergedInto`) rather than a move of faces, so it must survive the
/// periodic global re-cluster that reassigns every face from scratch.
///
/// The paired real-path counterpart to the host tests that use `FakeMlWorker`
/// (AGENTS.md fake-pairing rule):
///   * `test/core/database/faces_dao_test.dart` — "a global re-cluster does not
///     undo the merge"
///   * `test/services/indexing_service_test.dart` — "a pass past the threshold
///     globally re-clusters, preserving the rename"
/// Both feed clustering hand-crafted `[1,0]` / `[0,1]` vectors. Only a device
/// can show that the real embedder actually separates two different faces into
/// two clusters — and that the redirect still resolves after a real re-cluster.
///
/// The `clusterAll` → `planClusters` → `rebuildClusters` trio driven here is
/// exactly what `IndexingService._maybeGlobalRecluster` runs internally
/// (`indexing_service.dart`), minus the `Isolate.run` offload and the metadata
/// sweep — so this needs no photo library and never touches the camera roll.
///
/// **Fixtures.** `synthetic_face.jpg` (a drawn face) and `photo_face.jpg` (a
/// StyleGAN-generated face — no real person, no EXIF) are pushed to the app's
/// private storage (not bundled, not the photo library — see
/// `support/fixture_file.dart`). Two drawn synthetic faces embed too close
/// together for the real MobileFaceNet to split them (~0.6 cosine, threshold
/// 0.45), so the second identity has to be a photographic face. Push once
/// before running:
///
///   adb push test_assets/synthetic_face.jpg test_assets/photo_face.jpg \
///     /sdcard/Android/data/com.zmeul.sologallery/files/
///
/// Run with:
///   flutter test integration_test/people_test.dart -d DEVICE_ID --no-uninstall
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a user merge survives the global re-cluster (real MobileFaceNet embeddings)',
    () async {
      final faceABytes =
          await (await fixtureFile('synthetic_face.jpg')).readAsBytes();
      final faceBBytes =
          await (await fixtureFile('photo_face.jpg')).readAsBytes();

      // In-memory DB so the test never touches the real app database.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final worker = MlWorkerController();
      addTearDown(() async => await worker.dispose());

      // --- Real embeddings for two synthetic people -----------------------
      final analysisA = await worker.analyze(bytes: faceABytes);
      final analysisB = await worker.analyze(bytes: faceBBytes);
      expect(
        analysisA.faces,
        isNotEmpty,
        reason: 'synthetic_face.jpg not detected by the real detector',
      );
      expect(
        analysisB.faces,
        isNotEmpty,
        reason: 'photo_face.jpg not detected by the real detector',
      );

      // The premise of a *merge* test: the two fixtures must read as two
      // different people to the real embedder. If this regresses, the two
      // clusters below collapse into one and the rest of the test is vacuous —
      // replace photo_face.jpg with a more dissimilar face.
      final simAB = cosineSimilarity(
        analysisA.faces.first.embedding,
        analysisB.faces.first.embedding,
      );
      expect(
        simAB,
        lessThan(clusterMergeThreshold),
        reason: 'the two face fixtures embed as the same person '
            '(similarity $simAB >= $clusterMergeThreshold) — a merge test needs '
            'two distinct people',
      );

      // --- Seed two assets, one face each --------------------------------
      const assetA = 'sg-people-face-a';
      const assetB = 'sg-people-face-b';
      final seeded = <(String, ImageAnalysis, DateTime)>[
        (assetA, analysisA, DateTime(2026, 1, 2)),
        (assetB, analysisB, DateTime(2026, 1, 1)),
      ];
      for (final (id, analysis, createdAt) in seeded) {
        await db.indexDao.upsertIndexed(
          assetId: id,
          createdAt: createdAt,
          isVideo: false,
          width: 600,
          height: 800,
          labels: const [],
          text: '',
        );
        final f = analysis.faces.first;
        await db.facesDao.insertFaces(id, [
          (
            left: f.left,
            top: f.top,
            right: f.right,
            bottom: f.bottom,
            embedding: f.embedding,
          ),
        ]);
      }

      // The global re-cluster, verbatim from `_maybeGlobalRecluster`.
      Future<int> recluster() async {
        final all = await db.facesDao.allFacesForClustering();
        final groups = clusterAll(
          [for (final f in all) (id: f.id, embedding: f.embedding)],
        );
        await db.facesDao.rebuildClusters(
          planClusters(
            groups: groups,
            faceMeta: {
              for (final f in all)
                f.id: (personId: f.personId, assetId: f.assetId),
            },
            persons: {
              for (final p in await db.facesDao.allPersons())
                p.id: (
                  displayName: p.displayName,
                  coverAssetId: p.coverAssetId,
                ),
            },
          ),
        );
        return groups.length;
      }

      // --- Cluster into two people --------------------------------------
      expect(
        await recluster(),
        2,
        reason: 'the real embeddings did not cluster into two people',
      );
      var summaries = await db.facesDao.watchPersonSummaries().first;
      expect(summaries, hasLength(2));

      // --- Rename one, merge the two -----------------------------------
      final survivor = summaries.first.id;
      final absorbed = summaries.last.id;
      await db.facesDao.renamePerson(survivor, 'Alice');
      await db.facesDao.mergePersons(into: survivor, from: absorbed);

      summaries = await db.facesDao.watchPersonSummaries().first;
      expect(summaries, hasLength(1), reason: 'the merge did not fold the two');
      expect(summaries.single.displayName, 'Alice');
      expect(summaries.single.faceCount, 2);

      // --- The invariant: the merge must survive a global re-cluster ---
      expect(await recluster(), 2, reason: 'clustering still splits the faces');

      summaries = await db.facesDao.watchPersonSummaries().first;
      expect(
        summaries,
        hasLength(1),
        reason: 'the global re-cluster undid the user merge',
      );
      expect(summaries.single.displayName, 'Alice', reason: 'rename lost');
      expect(summaries.single.faceCount, 2);

      expect(
        (await db.facesDao.assetsForPerson(survivor)).map((a) => a.id).toSet(),
        {assetA, assetB},
        reason: 'the survivor no longer owns both clusters\' photos',
      );
      expect(
        await db.facesDao.assetsForPerson(absorbed),
        isEmpty,
        reason: 'the absorbed person resurfaced with photos of its own',
      );

      final persons = await db.facesDao.allPersons();
      expect(persons, hasLength(2), reason: 'both person rows must persist');
      expect(
        persons.firstWhere((p) => p.id == absorbed).mergedInto,
        survivor,
        reason: 'the redirect chain no longer resolves absorbed -> survivor',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
