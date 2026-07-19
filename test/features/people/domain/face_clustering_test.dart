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

    test('centroid tracks the running mean', () {
      final c = IncrementalClusterer(threshold: 0.99);
      c.add(1, vec([1, 0]));
      c.add(1, vec([0, 1])); // centroid now ~ (0.5, 0.5)
      // A vector along the mean direction matches; one orthogonal-ish does not.
      expect(c.nearest(vec([1, 1])), 1);
      expect(c.nearest(vec([1, -1])), isNull);
    });

    test('picks the nearest of several clusters', () {
      final c = IncrementalClusterer(threshold: 0.5);
      c.add(1, vec([1, 0, 0]));
      c.add(2, vec([0, 1, 0]));
      expect(c.nearest(vec([0.1, 0.9, 0])), 2);
      expect(c.nearest(vec([0.9, 0.1, 0])), 1);
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
}
