import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../../../features/people/domain/face_clustering.dart';
import '../../../services/photo_library_service.dart' show AssetRef;
import '../app_database.dart';
import '../tables.dart';

part 'faces_dao.g.dart';

/// One detected face to persist: its bounding box (normalized `[0, 1]` against
/// the analyzed image — see [FaceEmbeddings]) and embedding vector.
typedef FaceRecord = ({
  double left,
  double top,
  double right,
  double bottom,
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

/// One incremental cluster's worth of faces, and where to put them: either an
/// existing person to reuse ([reusePersonId]) or `null` to mint a fresh
/// unnamed one with [coverAssetId]. Built by `_clusterNewFaces` after an
/// in-memory decision pass, then applied in one batch.
class IncrementalClusterPlan {
  const IncrementalClusterPlan({
    required this.faceIds,
    this.reusePersonId,
    this.coverAssetId,
  });

  final List<int> faceIds;

  /// Existing person id to reuse (its name/cover stay untouched), or null to
  /// create a new unnamed person.
  final int? reusePersonId;

  /// The cover asset for a *new* person only — unused when [reusePersonId] is
  /// set, since a reused person keeps its curated cover.
  final String? coverAssetId;
}

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

  /// Every already-clustered face grouped by person — the starting state for
  /// incremental clustering. [IncrementalClusterer] thins each list down to its
  /// exemplar budget; handing it the full set lets it pick which faces to keep.
  Future<Map<int, List<Float32List>>> clusteredExemplars() async {
    final rows = await (select(faceEmbeddings)
          ..where((f) => f.personId.isNotNull())
          ..orderBy([(f) => OrderingTerm.asc(f.id)]))
        .get();
    final byPerson = <int, List<Float32List>>{};
    for (final r in rows) {
      byPerson.putIfAbsent(r.personId!, () => []).add(_floats(r.embedding));
    }
    return byPerson;
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

  /// One incremental cluster's worth of faces, and where to put them: either an
  /// existing person to reuse ([reusePersonId]) or `null` to mint a fresh
  /// unnamed one with [coverAssetId]. Sent to [applyIncrementalClusters] in a
  /// batch so a whole `_clusterNewFaces` pass is one transaction (and so
  /// [watchPersonSummaries] emits once, not once per face).
  Future<void> applyIncrementalClusters(List<IncrementalClusterPlan> plan) async {
    if (plan.isEmpty) return;
    await transaction(() async {
      for (final c in plan) {
        final personId = c.reusePersonId ??
            await into(persons).insert(
              PersonsCompanion.insert(
                coverAssetId: Value(c.coverAssetId),
                createdAt: DateTime.now(),
              ),
            );
        if (c.faceIds.isNotEmpty) {
          await (update(faceEmbeddings)..where((f) => f.id.isIn(c.faceIds)))
              .write(FaceEmbeddingsCompanion(personId: Value(personId)));
        }
      }
    });
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

  // --- User merges ----------------------------------------------------------

  /// The person a row resolves to: itself, or whoever it was merged into.
  ///
  /// A single `COALESCE` is enough because [mergePersons] keeps `merged_into`
  /// pointing straight at a root, so chains are never deeper than one hop and
  /// cycles cannot form.
  Expression<int> get _effectivePersonId =>
      coalesce([persons.mergedInto, persons.id]);

  /// Declares [from] to be the same person as [into] — see [Persons.mergedInto]
  /// for why this is a redirect rather than a move of faces.
  ///
  /// Normalizes as it writes: [into] is resolved to its root first, and anything
  /// already pointing at [from] is re-pointed to that root. Merging a person
  /// into itself (directly or through a chain) is a no-op, so the chain stays
  /// one hop deep and acyclic and every read can resolve with one `COALESCE`.
  Future<void> mergePersons({required int into, required int from}) async {
    await transaction(() async {
      final target = await (select(persons)..where((p) => p.id.equals(into)))
          .getSingleOrNull();
      if (target == null) return;
      final root = target.mergedInto ?? target.id;
      if (root == from) return; // would point a root at its own descendant
      await (update(persons)..where((p) => p.id.equals(from)))
          .write(PersonsCompanion(mergedInto: Value(root)));
      await (update(persons)..where((p) => p.mergedInto.equals(from)))
          .write(PersonsCompanion(mergedInto: Value(root)));
    });
  }

  /// Undoes a merge: [id] becomes its own person again. Nothing points at [id]
  /// while it is merged (the normalization above guarantees it), so this needs
  /// no repair pass.
  Future<void> unmergePerson(int id) {
    return (update(persons)..where((p) => p.id.equals(id)))
        .write(const PersonsCompanion(mergedInto: Value(null)));
  }

  /// The person rows the user merged into [id] — drives the "separate" action.
  Future<List<Person>> mergedPeopleOf(int id) =>
      (select(persons)..where((p) => p.mergedInto.equals(id))).get();

  /// People with at least one face, most-photographed first. User-merged
  /// clusters are folded into their survivor: the counts add up and the
  /// absorbed rows never appear as entries of their own.
  Stream<List<PersonSummary>> watchPersonSummaries() {
    final count = faceEmbeddings.id.count();
    // The row whose name and cover the entry shows, which is not necessarily
    // the row the faces hang off once a merge is involved.
    final survivor = alias(persons, 'survivor');
    final q = select(persons).join([
      innerJoin(faceEmbeddings, faceEmbeddings.personId.equalsExp(persons.id)),
      innerJoin(survivor, survivor.id.equalsExp(_effectivePersonId)),
    ])
      ..addColumns([count])
      ..groupBy([survivor.id])
      ..orderBy([OrderingTerm.desc(count)]);
    return q.watch().map((rows) => [
          for (final r in rows)
            PersonSummary(
              id: r.readTable(survivor).id,
              displayName: r.readTable(survivor).displayName,
              coverAssetId: r.readTable(survivor).coverAssetId,
              faceCount: r.read(count)!,
            ),
        ]);
  }

  Stream<Person?> watchPerson(int id) {
    return (select(persons)..where((p) => p.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Distinct assets containing a face that resolves to [personId], newest
  /// first — including the faces of anyone merged into them.
  Future<List<AssetRef>> assetsForPerson(int personId) async {
    final q = select(faceEmbeddings).join([
      innerJoin(persons, persons.id.equalsExp(faceEmbeddings.personId)),
      innerJoin(
        photoAssets,
        photoAssets.assetId.equalsExp(faceEmbeddings.assetId),
      ),
    ])
      ..where(_effectivePersonId.equals(personId))
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

  /// The bounding box of the representative face for [personId], to crop the
  /// avatar. Null if the person has no faces.
  ///
  /// Prefers the face on the person's curated [Persons.coverAssetId] — the photo
  /// clustering deliberately picked and preserves across re-clusters
  /// (`planClusters`). Ordering by newest face instead would re-point the avatar
  /// at a different photo every time indexing added a face to this person, so
  /// the grid visibly reshuffled as a pass progressed. Newest is kept only as
  /// the fallback for a person whose cover asset is unset or whose face on it
  /// has since gone.
  Future<({String assetId, double left, double top, double right, double bottom})?>
      coverFace(int personId) async {
    final person = await (select(persons)..where((p) => p.id.equals(personId)))
        .getSingleOrNull();

    final q = select(faceEmbeddings)
      ..where((f) => f.personId.equals(personId))
      ..orderBy([(f) => OrderingTerm.desc(f.id)])
      ..limit(1);
    final cover = person?.coverAssetId;
    var row = cover == null
        ? null
        : await (select(faceEmbeddings)
              ..where(
                (f) => f.personId.equals(personId) & f.assetId.equals(cover),
              )
              ..orderBy([(f) => OrderingTerm.asc(f.id)])
              ..limit(1))
            .getSingleOrNull();
    row ??= await q.getSingleOrNull();
    if (row == null) return null;
    return (
      assetId: row.assetId,
      left: row.left,
      top: row.top,
      right: row.right,
      bottom: row.bottom,
    );
  }

  /// The cover face for each of [personIds], resolved concurrently — the People
  /// grid/strip fetch all covers once instead of one query fan-out per avatar
  /// cell as it scrolls in. People with no face are omitted from the map.
  Future<Map<int, ({String assetId, double left, double top, double right, double bottom})>>
      coverFacesFor(List<int> personIds) async {
    final entries = await Future.wait([
      for (final id in personIds)
        coverFace(id).then((c) => c == null ? null : MapEntry(id, c)),
    ]);
    return {for (final e in entries) if (e != null) e.key: e.value};
  }
}
