import 'dart:math' show sqrt;
import 'dart:typed_data';

// Pure-Dart face clustering — average-linkage agglomeration for the global
// re-cluster plus an exemplar-based incremental assigner. No Flutter/plugin
// imports (Float32List is dart:typed_data), so it is unit-testable on the host.
// The DAO persists the assignments this decides.

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
  return dot / (sqrt(na) * sqrt(nb));
}

/// An L2-normalized copy of [v]. A zero vector comes back unchanged (all
/// zeros), so it stays similarity-0 against everything.
Float32List _normalized(Float32List v) {
  var n = 0.0;
  for (var i = 0; i < v.length; i++) {
    n += v[i] * v[i];
  }
  final out = Float32List(v.length);
  if (n == 0) return out;
  final inv = 1 / sqrt(n);
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] * inv;
  }
  return out;
}

double _dot(Float32List a, Float32List b) {
  var d = 0.0;
  for (var i = 0; i < a.length; i++) {
    d += a[i] * b[i];
  }
  return d;
}

/// Minimum *average-linkage* similarity for two clusters to be the same person.
/// Measured against a real 223-face device library: 0.45 recovers 41 of the 42
/// faces of the most-photographed person as one cluster with no contamination,
/// where the old centroid pass split them across six (see
/// `docs/plans/people-clustering-oversplit.md`).
const double clusterMergeThreshold = 0.45;

/// Minimum similarity to a person's *nearest stored exemplar* for the
/// incremental assigner to hand a fresh face to that person. Higher than
/// [clusterMergeThreshold] because a single-face match is a weaker signal than
/// a whole-cluster average: between global re-clusters it is cheaper to mint a
/// short-lived duplicate than to fuse two people.
const double incrementalAssignThreshold = 0.62;

/// One face for global clustering: a stable [id] and its [embedding].
typedef FaceForClustering = ({int id, Float32List embedding});

/// Clusters [faces] from scratch with **average-linkage agglomeration**,
/// merging while the closest pair of clusters is at least [threshold] similar.
/// Returns the groups as lists of face ids (each sorted ascending), the groups
/// themselves ordered by their lowest face id. Deterministic — the same input
/// always yields the same grouping, so a periodic global re-cluster self-heals
/// the order-dependent drift the incremental assigner accumulates.
///
/// Average linkage, not nearest-centroid: a cluster's mean drifts away from
/// every individual face as it grows, so a centroid pass silently loses recall
/// on exactly the people with the most photos, and — being a single greedy pass
/// — can never reunite two clusters of the same person once both exist. It is
/// also not single linkage, which chains unrelated people together through one
/// borderline pair.
///
/// The cost of a merge test is a dot product, not a pairwise scan: for
/// L2-normalized embeddings the average of all cross-pair cosine similarities
/// equals the dot product of the two cluster *mean* vectors,
/// `(ΣA/|A|)·(ΣB/|B|)`, so a cluster only carries a running sum and a count.
/// (That dot product must stay un-normalized — re-normalizing the means is
/// centroid linkage again, not average linkage.)
List<List<int>> clusterAll(
  List<FaceForClustering> faces, {
  double threshold = clusterMergeThreshold,
}) {
  final ordered = [...faces]..sort((a, b) => a.id.compareTo(b.id));
  final n = ordered.length;
  if (n == 0) return [];

  final members = [
    for (final f in ordered) [f.id],
  ];
  final sums = [for (final f in ordered) _normalized(f.embedding)];
  final counts = List<int>.filled(n, 1);
  final alive = List<bool>.filled(n, true);

  // Cached best partner per cluster. Merging can only ever *lower* a cluster's
  // similarity to an outsider — the merged mean is a weighted average of its
  // children's, so it is bounded by the larger of their two similarities —
  // which means a cluster's cached best stays valid unless that best was one of
  // the clusters just merged.
  final bestOf = List<int>.filled(n, -1);
  final bestSim = List<double>.filled(n, -2);
  var stale = {for (var i = 0; i < n; i++) i};

  while (true) {
    for (final i in stale) {
      if (!alive[i]) continue;
      var partner = -1;
      var best = -2.0;
      final si = sums[i];
      final ci = counts[i];
      for (var j = 0; j < n; j++) {
        if (j == i || !alive[j]) continue;
        final s = _dot(si, sums[j]) / (ci * counts[j]);
        if (s > best) {
          best = s;
          partner = j;
        }
      }
      bestOf[i] = partner;
      bestSim[i] = best;
    }

    // Merge every reciprocal-nearest pair at or above the threshold. Each
    // cluster names exactly one best partner, so the pairs are disjoint and can
    // all be applied in this round.
    final touched = <int>{};
    for (var i = 0; i < n; i++) {
      if (!alive[i] || bestSim[i] < threshold) continue;
      final j = bestOf[i];
      if (j <= i || !alive[j] || bestOf[j] != i) continue;
      members[i] = [...members[i], ...members[j]]..sort();
      final si = sums[i];
      final sj = sums[j];
      for (var k = 0; k < si.length; k++) {
        si[k] += sj[k];
      }
      counts[i] += counts[j];
      alive[j] = false;
      touched.add(i);
      touched.add(j);
    }
    if (touched.isEmpty) break;

    stale = {
      for (var i = 0; i < n; i++)
        if (alive[i] && (touched.contains(i) || touched.contains(bestOf[i]))) i,
    };
  }

  return [
    for (var i = 0; i < n; i++)
      if (alive[i]) members[i],
  ];
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

/// Greedy incremental face clustering against each person's stored **exemplar
/// faces**: a face joins the person holding the single most similar exemplar at
/// or above [threshold]; if none does, the caller mints a new person.
///
/// Scoring against individual faces rather than a running centroid is what
/// keeps recall from decaying as a person accumulates photos — the mean of a
/// large, varied cluster ends up further from every one of its own faces than
/// the threshold allows, so a centroid assigner kept minting duplicates of the
/// most-photographed people.
///
/// Each person keeps at most [maxExemplars] faces; when full, the more
/// redundant half of the closest exemplar pair is dropped, so what is retained
/// spans the person's appearance rather than repeating one pose.
///
/// Deterministic given a fixed input order — the caller feeds faces in a stable
/// order (e.g. by face id) so results are reproducible.
class IncrementalClusterer {
  IncrementalClusterer({
    this.threshold = incrementalAssignThreshold,
    this.maxExemplars = 12,
    Map<int, List<Float32List>>? initial,
  }) : _exemplars = {} {
    if (initial != null) {
      for (final e in initial.entries) {
        _exemplars[e.key] = [for (final v in e.value) _normalized(v)];
        _prune(_exemplars[e.key]!);
      }
    }
  }

  /// Minimum cosine similarity to an exemplar to join that person.
  final double threshold;

  /// How many faces are kept per person to compare against.
  final int maxExemplars;

  final Map<int, List<Float32List>> _exemplars;

  /// The personId whose nearest exemplar clears [threshold] by the widest
  /// margin, or null when no person is close enough (caller creates one).
  int? nearest(Float32List embedding) {
    final v = _normalized(embedding);
    int? best;
    var bestSim = threshold;
    for (final person in _exemplars.keys.toList()..sort()) {
      for (final e in _exemplars[person]!) {
        final s = _dot(v, e);
        if (s >= bestSim) {
          bestSim = s;
          best = person;
        }
      }
    }
    return best;
  }

  /// Records that [embedding] joined [personId], keeping it as an exemplar for
  /// later faces (evicting a redundant one once the person is at capacity).
  void add(int personId, Float32List embedding) {
    final list = _exemplars.putIfAbsent(personId, () => []);
    list.add(_normalized(embedding));
    _prune(list);
  }

  /// Drops the second half of the most-similar exemplar pair until the person
  /// is back at [maxExemplars] — evicting redundancy, not history.
  void _prune(List<Float32List> list) {
    while (list.length > maxExemplars) {
      var drop = list.length - 1;
      var closest = -2.0;
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          final s = _dot(list[i], list[j]);
          if (s > closest) {
            closest = s;
            drop = j;
          }
        }
      }
      list.removeAt(drop);
    }
  }
}
