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
}
