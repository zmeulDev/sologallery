import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/people/domain/face_clustering.dart';

Float32List vec(List<double> v) => Float32List.fromList(v);

void main() {
  group('cosineSimilarity', () {
    test('is 1 for identical direction (scale-invariant)', () {
      expect(cosineSimilarity(vec([1, 0, 0]), vec([2, 0, 0])), closeTo(1, 1e-6));
    });

    test('is 0 for orthogonal vectors', () {
      expect(cosineSimilarity(vec([1, 0]), vec([0, 1])), closeTo(0, 1e-6));
    });

    test('is negative for opposite vectors', () {
      expect(cosineSimilarity(vec([1, 0]), vec([-1, 0])), closeTo(-1, 1e-6));
    });

    test('is 0 for a zero-magnitude vector', () {
      expect(cosineSimilarity(vec([0, 0]), vec([1, 1])), 0);
    });
  });

  group('IncrementalClusterer', () {
    test('assigns a close vector to the existing cluster', () {
      final c = IncrementalClusterer(threshold: 0.65);
      c.add(1, vec([1, 0, 0]));
      expect(c.nearest(vec([0.95, 0.05, 0])), 1);
    });

    test('rejects a far vector (caller mints a new person)', () {
      final c = IncrementalClusterer(threshold: 0.65);
      c.add(1, vec([1, 0, 0]));
      expect(c.nearest(vec([0, 1, 0])), isNull);
    });

    test('nearest returns null before any cluster exists', () {
      expect(IncrementalClusterer().nearest(vec([1, 0, 0])), isNull);
    });

    test('matches the nearest exemplar, not the mean of them', () {
      // The mean of these two is ~(0.5, 0.5, 0) — far from either. A centroid
      // assigner loses the person here; scoring against the faces themselves
      // is what keeps recall up as a person accumulates varied photos.
      final c = IncrementalClusterer(threshold: 0.9);
      c.add(1, vec([1, 0, 0]));
      c.add(1, vec([0, 1, 0]));
      expect(c.nearest(vec([0.99, 0.1, 0])), 1);
      expect(c.nearest(vec([0.1, 0.99, 0])), 1);
      expect(c.nearest(vec([0, 0, 1])), isNull);
    });

    test('picks the person holding the single most similar exemplar', () {
      final c = IncrementalClusterer(threshold: 0.5);
      c.add(1, vec([1, 0, 0]));
      c.add(2, vec([0, 1, 0]));
      expect(c.nearest(vec([0.1, 0.9, 0])), 2);
      expect(c.nearest(vec([0.9, 0.1, 0])), 1);
    });

    test('seeds from stored faces per person', () {
      final c = IncrementalClusterer(
        threshold: 0.9,
        initial: {
          7: [vec([1, 0, 0])],
        },
      );
      expect(c.nearest(vec([0.99, 0.05, 0])), 7);
    });

    test('caps exemplars per person, keeping the spread', () {
      final c = IncrementalClusterer(threshold: 0.9, maxExemplars: 2);
      c.add(1, vec([1, 0, 0]));
      c.add(1, vec([0, 1, 0]));
      c.add(1, vec([1, 0.01, 0])); // near-duplicate of the first
      // One of the two near-identical vectors was evicted, not the outlier: the
      // orthogonal pose still matches.
      expect(c.nearest(vec([0.05, 1, 0])), 1);
      expect(c.nearest(vec([1, 0.05, 0])), 1);
    });
  });

  group('clusterAll', () {
    test('merges near-duplicates and splits distinct people', () {
      final groups = clusterAll([
        (id: 1, embedding: vec([1, 0, 0])),
        (id: 2, embedding: vec([0.97, 0.03, 0])), // ~ id 1
        (id: 3, embedding: vec([0, 1, 0])), // distinct
      ]);
      expect(groups, hasLength(2));
      expect(groups[0], [1, 2]);
      expect(groups[1], [3]);
    });

    test('is deterministic regardless of input order (sorts by id)', () {
      final faces = [
        (id: 3, embedding: vec([0, 1, 0])),
        (id: 1, embedding: vec([1, 0, 0])),
        (id: 2, embedding: vec([0.97, 0.03, 0])),
      ];
      expect(clusterAll(faces), clusterAll(faces.reversed.toList()));
    });

    test('returns nothing for no faces', () {
      expect(clusterAll(const []), isEmpty);
    });

    test('reunites two clusters of one person that a greedy pass would split',
        () {
      // Two tight sub-groups of the same person (each pair ~0.995 similar to
      // itself, the two sides ~0.6 to each other). A single greedy pass that
      // creates both and never merges leaves the person duplicated; average
      // linkage joins them.
      final groups = clusterAll([
        (id: 1, embedding: vec([1, 0, 0])),
        (id: 2, embedding: vec([1, 0.1, 0])),
        (id: 3, embedding: vec([0.8, 0.6, 0])),
        (id: 4, embedding: vec([0.75, 0.66, 0])),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single, [1, 2, 3, 4]);
    });

    test('does not chain two people through a borderline in-between face', () {
      // A—B and B—C each clear the threshold, A—C does not. Single linkage
      // would fuse all three; average linkage must keep A and C apart.
      final groups = clusterAll(
        [
          (id: 1, embedding: vec([1, 0, 0])),
          (id: 2, embedding: vec([0.71, 0.71, 0])),
          (id: 3, embedding: vec([0, 1, 0])),
        ],
        threshold: 0.6,
      );
      expect(groups, hasLength(2));
      expect(groups.map((g) => g.length).toList()..sort(), [1, 2]);
      expect(groups.expand((g) => g).toSet(), {1, 2, 3});
    });

    test('keeps every face exactly once', () {
      final faces = [
        for (var i = 1; i <= 12; i++)
          (id: i, embedding: vec([i.isEven ? 1.0 : 0.0, i % 3, i % 5])),
      ];
      final groups = clusterAll(faces);
      expect(groups.expand((g) => g).toList()..sort(), [
        for (var i = 1; i <= 12; i++) i,
      ]);
    });
  });

  group('planClusters', () {
    test('reuses the dominant person and preserves its name', () {
      // One group of 3 faces, two of which belonged to person 5 ("Alice").
      final plan = planClusters(
        groups: [
          [10, 11, 12],
        ],
        faceMeta: {
          10: (personId: 5, assetId: 'a'),
          11: (personId: 5, assetId: 'b'),
          12: (personId: 9, assetId: 'c'),
        },
        persons: {
          5: (displayName: 'Alice', coverAssetId: 'a'),
          9: (displayName: null, coverAssetId: 'c'),
        },
      );
      expect(plan, hasLength(1));
      expect(plan.single.reusePersonId, 5);
      expect(plan.single.displayName, 'Alice');
      expect(plan.single.coverAssetId, 'a'); // old cover still in the group
    });

    test('largest group claims the shared person; the other mints a new one', () {
      final plan = planClusters(
        groups: [
          [1], // smaller — visited second
          [2, 3, 4], // larger — claims person 7 first
        ],
        faceMeta: {
          1: (personId: 7, assetId: 'x'),
          2: (personId: 7, assetId: 'y'),
          3: (personId: 7, assetId: 'z'),
          4: (personId: 7, assetId: 'w'),
        },
        persons: {7: (displayName: 'Bob', coverAssetId: 'y')},
      );
      expect(plan[1].reusePersonId, 7); // big group keeps Bob
      expect(plan[0].reusePersonId, isNull); // small group is new
      expect(plan[0].coverAssetId, 'x'); // first face's asset
    });

    test('falls back to the first face asset when the old cover left', () {
      final plan = planClusters(
        groups: [
          [20, 21],
        ],
        faceMeta: {
          20: (personId: 3, assetId: 'p'),
          21: (personId: 3, assetId: 'q'),
        },
        persons: {3: (displayName: 'Cara', coverAssetId: 'gone')},
      );
      expect(plan.single.coverAssetId, 'p');
    });
  });

  group('clusterAll + planClusters composition', () {
    // `IndexingTriggers.maybeGlobalRecluster` in indexing_triggers.dart moves
    // the whole planning pass — `planClusters(groups: clusterAll(input), ...)`
    // — into a single Isolate.run, rather than running clusterAll in the
    // isolate and planClusters back on the caller. Both functions are pure and
    // deterministic, so composing them nested (as the isolate closure now
    // does) must produce exactly the same plan as calling them as two
    // separate steps (as the old two-call code did). This is the seam that
    // stands in for actually exercising the isolate boundary.
    test('nested composition matches the two-step call', () {
      final input = [
        (id: 1, embedding: vec([1, 0, 0])),
        (id: 2, embedding: vec([0.97, 0.03, 0])), // ~ id 1
        (id: 3, embedding: vec([0, 1, 0])), // distinct
      ];
      final faceMeta = {
        1: (personId: 5, assetId: 'a'),
        2: (personId: 9, assetId: 'b'),
        3: (personId: null, assetId: 'c'),
      };
      final persons = {
        5: (displayName: 'Alice', coverAssetId: 'a'),
        9: (displayName: null, coverAssetId: 'b'),
      };

      // Two-step form, as the calling isolate used to run it.
      final groups = clusterAll(input);
      final twoStep = planClusters(
        groups: groups,
        faceMeta: faceMeta,
        persons: persons,
      );

      // Composed form, exactly as the Isolate.run closure now calls it.
      final composed = planClusters(
        groups: clusterAll(input),
        faceMeta: faceMeta,
        persons: persons,
      );

      expect(composed, hasLength(twoStep.length));
      for (var i = 0; i < composed.length; i++) {
        expect(composed[i].faceIds, twoStep[i].faceIds);
        expect(composed[i].reusePersonId, twoStep[i].reusePersonId);
        expect(composed[i].displayName, twoStep[i].displayName);
        expect(composed[i].coverAssetId, twoStep[i].coverAssetId);
      }
    });
  });
}
