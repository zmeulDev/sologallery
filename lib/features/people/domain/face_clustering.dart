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
