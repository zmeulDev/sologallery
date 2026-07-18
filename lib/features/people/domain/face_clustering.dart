import 'dart:typed_data';

// Pure-Dart face clustering — cosine similarity + an incremental nearest-centroid
// assigner. No Flutter/plugin imports (Float32List is dart:typed_data), so it is
// unit-testable on the host. The DAO persists the assignments this decides.

/// Cosine similarity of two embedding vectors, in `[-1, 1]`. Returns 0 for a
/// zero-magnitude vector. Handles un-normalized model output (divides by norms).
double cosineSimilarity(Float32List a, Float32List b) {
  assert(a.length == b.length);
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (_sqrt(na) * _sqrt(nb));
}

double _sqrt(double x) {
  // Local to avoid a dart:math import in this otherwise dependency-free file.
  if (x <= 0) return 0;
  var g = x;
  for (var i = 0; i < 20; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}

/// A running cluster centroid: the mean embedding of its assigned faces.
class Centroid {
  Centroid(this.mean, this.count);
  final Float32List mean;
  int count;
}

/// One face for global clustering: a stable [id] and its [embedding].
typedef FaceForClustering = ({int id, Float32List embedding});

/// Clusters [faces] from scratch: greedy nearest-centroid over a stable id
/// order (sorted by [FaceForClustering.id]), starting from no clusters. Returns
/// the groups as lists of face ids, each group ordered as encountered; groups
/// themselves are ordered by first-appearance. Deterministic — the same input
/// always yields the same grouping, so a periodic global re-cluster self-heals
/// the order-dependent drift the incremental assigner accumulates.
///
/// Reuses [cosineSimilarity]/[Centroid] and the same [threshold] as
/// [IncrementalClusterer], so incremental and global agree on what "same
/// person" means.
List<List<int>> clusterAll(
  List<FaceForClustering> faces, {
  double threshold = 0.65,
}) {
  final ordered = [...faces]..sort((a, b) => a.id.compareTo(b.id));
  final centroids = <int, Centroid>{}; // group index -> centroid
  final groups = <List<int>>[];
  for (final f in ordered) {
    int? best;
    var bestSim = threshold;
    centroids.forEach((group, c) {
      final sim = cosineSimilarity(f.embedding, c.mean);
      if (sim >= bestSim) {
        bestSim = sim;
        best = group;
      }
    });
    if (best == null) {
      best = groups.length;
      groups.add(<int>[]);
      centroids[best!] = Centroid(Float32List.fromList(f.embedding), 1);
    } else {
      final c = centroids[best]!;
      for (var i = 0; i < c.mean.length; i++) {
        c.mean[i] = (c.mean[i] * c.count + f.embedding[i]) / (c.count + 1);
      }
      c.count++;
    }
    groups[best!].add(f.id);
  }
  return groups;
}

/// A resolved instruction for one re-clustered group: which faces it contains,
/// which existing person to reuse (keeping its name) or `null` to mint a new
/// one, and the cover asset for the avatar.
class PlannedCluster {
  const PlannedCluster({
    required this.faceIds,
    required this.reusePersonId,
    required this.displayName,
    required this.coverAssetId,
  });

  final List<int> faceIds;

  /// Existing person id to reuse (preserves its rename), or null to create a
  /// fresh person for this group.
  final int? reusePersonId;

  /// The preserved display name when reusing a person; null for a new person.
  final String? displayName;

  /// A representative face's asset id, for the person avatar.
  final String coverAssetId;
}

/// Maps freshly-computed [groups] onto persons, preserving user renames and
/// covers. Each group (largest first) claims the most common existing
/// `personId` among its faces that no larger group already claimed — reusing
/// that person row so its name survives; groups with no unclaimed prior person
/// mint a new one. Cover keeps the reused person's cover when that asset is
/// still in the group, else the group's first (lowest face-id) asset.
///
/// Pure and deterministic. [faceMeta] maps face id → its current person + asset;
/// [persons] maps person id → its name + cover. Returned in [groups] order.
List<PlannedCluster> planClusters({
  required List<List<int>> groups,
  required Map<int, ({int? personId, String assetId})> faceMeta,
  required Map<int, ({String? displayName, String? coverAssetId})> persons,
}) {
  // Visit larger groups first so the dominant cluster keeps the shared person.
  final order = [for (var i = 0; i < groups.length; i++) i]
    ..sort((a, b) => groups[b].length.compareTo(groups[a].length));
  final claimed = <int>{};
  final planned = <int, PlannedCluster>{};

  for (final gi in order) {
    final ids = groups[gi];
    final counts = <int, int>{};
    for (final fid in ids) {
      final pid = faceMeta[fid]?.personId;
      if (pid != null) counts[pid] = (counts[pid] ?? 0) + 1;
    }
    int? reuse;
    var bestCount = 0;
    for (final pid in counts.keys.toList()..sort()) {
      // Tie-break by lowest person id (the sorted iteration) for determinism.
      if (claimed.contains(pid)) continue;
      if (counts[pid]! > bestCount) {
        bestCount = counts[pid]!;
        reuse = pid;
      }
    }
    if (reuse != null) claimed.add(reuse);

    final groupAssets = {for (final fid in ids) faceMeta[fid]!.assetId};
    final oldCover = reuse != null ? persons[reuse]?.coverAssetId : null;
    final cover = (oldCover != null && groupAssets.contains(oldCover))
        ? oldCover
        : faceMeta[ids.first]!.assetId;

    planned[gi] = PlannedCluster(
      faceIds: ids,
      reusePersonId: reuse,
      displayName: reuse != null ? persons[reuse]?.displayName : null,
      coverAssetId: cover,
    );
  }
  return [for (var i = 0; i < groups.length; i++) planned[i]!];
}

/// Greedy incremental face clustering. Each face is assigned to the nearest
/// existing person centroid whose cosine similarity clears [threshold]; if none
/// does, the caller mints a new person. Centroids update as faces are added.
///
/// Deterministic given a fixed input order — the caller feeds faces in a stable
/// order (e.g. by face id) so results are reproducible.
class IncrementalClusterer {
  IncrementalClusterer({this.threshold = 0.65, Map<int, Centroid>? initial})
      : _centroids = initial ?? {};

  /// Minimum cosine similarity to join an existing cluster. ~0.65 balances
  /// merging the same person against splitting different people (tunable).
  final double threshold;

  final Map<int, Centroid> _centroids;

  /// The personId of the nearest centroid at or above [threshold], or null when
  /// no cluster is close enough (caller should create a new person).
  int? nearest(Float32List embedding) {
    int? best;
    var bestSim = threshold;
    _centroids.forEach((personId, c) {
      final sim = cosineSimilarity(embedding, c.mean);
      if (sim >= bestSim) {
        bestSim = sim;
        best = personId;
      }
    });
    return best;
  }

  /// Records that [embedding] joined [personId], updating that centroid's
  /// running mean (creating it if new).
  void add(int personId, Float32List embedding) {
    final c = _centroids[personId];
    if (c == null) {
      _centroids[personId] = Centroid(Float32List.fromList(embedding), 1);
      return;
    }
    for (var i = 0; i < c.mean.length; i++) {
      c.mean[i] = (c.mean[i] * c.count + embedding[i]) / (c.count + 1);
    }
    c.count++;
  }
}
