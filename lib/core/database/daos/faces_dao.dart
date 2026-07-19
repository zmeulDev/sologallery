import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../../features/people/domain/face_clustering.dart';
import '../../../services/photo_library_service.dart' show AssetRef;
import '../app_database.dart';
import '../tables.dart';

part 'faces_dao.g.dart';

/// One detected face to persist: its bounding box (512-thumb coords) and
/// embedding vector.
typedef FaceRecord = ({
  int left,
  int top,
  int right,
  int bottom,
  Float32List embedding,
});

/// A person row for the People list: identity plus how many faces it groups.
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.displayName,
    required this.coverAssetId,
    required this.faceCount,
  });

  final int id;
  final String? displayName;
  final String? coverAssetId;
  final int faceCount;
}

/// A face awaiting clustering: its id, owning asset, and embedding.
typedef UnclusteredFace = ({int id, String assetId, Float32List embedding});

/// Data-access for face embeddings + person clusters. Pure data layer — the
/// clustering *decision* lives in `face_clustering.dart`; this persists it and
/// serves the People UI.
@DriftAccessor(tables: [Persons, FaceEmbeddings, PhotoAssets])
class FacesDao extends DatabaseAccessor<AppDatabase> with _$FacesDaoMixin {
  FacesDao(super.db);

  static Uint8List _bytes(Float32List v) => v.buffer.asUint8List(
        v.offsetInBytes,
        v.lengthInBytes,
      );

  static Float32List _floats(Uint8List b) =>
      b.buffer.asFloat32List(b.offsetInBytes, b.lengthInBytes ~/ 4);

  /// Replaces the faces stored for [assetId] (re-index safe).
  Future<void> insertFaces(String assetId, List<FaceRecord> faces) async {
    await transaction(() async {
      await (delete(faceEmbeddings)..where((f) => f.assetId.equals(assetId)))
          .go();
      for (final f in faces) {
        await into(faceEmbeddings).insert(
          FaceEmbeddingsCompanion.insert(
            assetId: assetId,
            embedding: _bytes(f.embedding),
            left: f.left,
            top: f.top,
            right: f.right,
            bottom: f.bottom,
          ),
        );
      }
    });
  }

  /// Faces not yet assigned to a person, oldest id first (stable order → the
  /// clusterer is deterministic).
  Future<List<UnclusteredFace>> unclusteredFaces() async {
    final rows = await (select(faceEmbeddings)
          ..where((f) => f.personId.isNull())
          ..orderBy([(f) => OrderingTerm.asc(f.id)]))
        .get();
    return [
      for (final r in rows)
        (id: r.id, assetId: r.assetId, embedding: _floats(r.embedding)),
    ];
  }

  /// Current per-person centroids computed from all clustered faces — the
  /// starting state for incremental clustering.
  Future<Map<int, Centroid>> clusteredCentroids() async {
    final rows = await (select(faceEmbeddings)
          ..where((f) => f.personId.isNotNull()))
        .get();
    final centroids = <int, Centroid>{};
    for (final r in rows) {
      final emb = _floats(r.embedding);
      final id = r.personId!;
      final c = centroids[id];
      if (c == null) {
        centroids[id] = Centroid(Float32List.fromList(emb), 1);
      } else {
        for (var i = 0; i < c.mean.length; i++) {
          c.mean[i] = (c.mean[i] * c.count + emb[i]) / (c.count + 1);
        }
        c.count++;
      }
    }
    return centroids;
  }

  /// Creates a new (unnamed) person with an optional cover; returns its id.
  Future<int> createPerson({String? coverAssetId}) {
    return into(persons).insert(
      PersonsCompanion.insert(
        displayName: const Value.absent(),
        coverAssetId: Value(coverAssetId),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> assignPersonToFace(int faceId, int personId) {
    return (update(faceEmbeddings)..where((f) => f.id.equals(faceId)))
        .write(FaceEmbeddingsCompanion(personId: Value(personId)));
  }

  Future<void> renamePerson(int personId, String? name) {
    return (update(persons)..where((p) => p.id.equals(personId))).write(
      PersonsCompanion(displayName: Value(name)),
    );
  }

  /// Deletes all person clusters — used by Settings' "Rebuild index" after the
  /// `photo_asset` wipe (which already cascades face embeddings away). Clustering
  /// re-runs from scratch on the next indexing pass.
  Future<int> clearPersons() => delete(persons).go();

  /// Deletes every stored face embedding, leaving the `photo_asset` cache (and
  /// so labels and OCR text) intact. Used when the user withdraws face-detection
  /// consent — unlike "Rebuild index" there is no asset wipe to cascade from, so
  /// the embeddings have to go explicitly.
  Future<int> clearFaces() => delete(faceEmbeddings).go();

  // --- Global re-cluster ---------------------------------------------------

  /// Every stored face with its current person + asset + embedding, ordered by
  /// id (a stable order for deterministic global clustering).
  Future<List<({int id, int? personId, String assetId, Float32List embedding})>>
      allFacesForClustering() async {
    final rows =
        await (select(faceEmbeddings)..orderBy([(f) => OrderingTerm.asc(f.id)]))
            .get();
    return [
      for (final r in rows)
        (
          id: r.id,
          personId: r.personId,
          assetId: r.assetId,
          embedding: _floats(r.embedding),
        ),
    ];
  }

  /// Total number of stored faces — the indexer's signal for when enough new
  /// faces have accrued to justify a global re-cluster.
  Future<int> faceCount() async {
    final c = faceEmbeddings.id.count();
    final q = selectOnly(faceEmbeddings)..addColumns([c]);
    return (await q.map((r) => r.read(c) ?? 0).getSingle());
  }

  /// All person rows — the source of names/covers a global re-cluster preserves.
  Future<List<Person>> allPersons() => select(persons).get();

  /// Applies a global re-cluster [plan]: removes persons no cluster reuses,
  /// reassigns every face to its planned person (reusing existing rows so
  /// renames survive, minting new ones otherwise), and refreshes covers — all in
  /// one transaction.
  Future<void> rebuildClusters(List<PlannedCluster> plan) async {
    await transaction(() async {
      final keep = {
        for (final c in plan)
          if (c.reusePersonId != null) c.reusePersonId!,
      };
      // Drop persons no cluster reuses (their faces are reassigned below; the FK
      // set-null means the delete never orphans a face reference).
      if (keep.isEmpty) {
        await delete(persons).go();
      } else {
        await (delete(persons)..where((p) => p.id.isNotIn(keep))).go();
      }

      for (final c in plan) {
        int personId;
        if (c.reusePersonId != null) {
          personId = c.reusePersonId!;
          await (update(persons)..where((p) => p.id.equals(personId)))
              .write(PersonsCompanion(coverAssetId: Value(c.coverAssetId)));
        } else {
          personId = await into(persons).insert(
            PersonsCompanion.insert(
              displayName: Value(c.displayName),
              coverAssetId: Value(c.coverAssetId),
              createdAt: DateTime.now(),
            ),
          );
        }
        await (update(faceEmbeddings)..where((f) => f.id.isIn(c.faceIds)))
            .write(FaceEmbeddingsCompanion(personId: Value(personId)));
      }
    });
  }

  /// People with at least one face, most-photographed first.
  Stream<List<PersonSummary>> watchPersonSummaries() {
    final count = faceEmbeddings.id.count();
    final q = select(persons).join([
      innerJoin(faceEmbeddings, faceEmbeddings.personId.equalsExp(persons.id)),
    ])
      ..addColumns([count])
      ..groupBy([persons.id])
      ..orderBy([OrderingTerm.desc(count)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            PersonSummary(
              id: r.readTable(persons).id,
              displayName: r.readTable(persons).displayName,
              coverAssetId: r.readTable(persons).coverAssetId,
              faceCount: r.read(count)!,
            ),
        ]);
  }

  Stream<Person?> watchPerson(int id) {
    return (select(persons)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Distinct assets containing a face assigned to [personId], newest first.
  Future<List<AssetRef>> assetsForPerson(int personId) async {
    final q = select(faceEmbeddings).join([
      innerJoin(
        photoAssets,
        photoAssets.assetId.equalsExp(faceEmbeddings.assetId),
      ),
    ])
      ..where(faceEmbeddings.personId.equals(personId))
      ..groupBy([photoAssets.assetId])
      ..orderBy([OrderingTerm.desc(photoAssets.createdAt)]);
    final rows = await q.get();
    return [
      for (final r in rows)
        AssetRef(
          id: r.readTable(photoAssets).assetId,
          createdAt: r.readTable(photoAssets).createdAt,
        ),
    ];
  }

  /// The bounding box of a representative face for [personId], to crop the
  /// avatar. Newest face first; null if the person has no faces.
  Future<({String assetId, int left, int top, int right, int bottom})?>
      coverFace(int personId) async {
    final row = await (select(faceEmbeddings)
          ..where((f) => f.personId.equals(personId))
          ..orderBy([(f) => OrderingTerm.desc(f.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return (
      assetId: row.assetId,
      left: row.left,
      top: row.top,
      right: row.right,
      bottom: row.bottom,
    );
  }
}
