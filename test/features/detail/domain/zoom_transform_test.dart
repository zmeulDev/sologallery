import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/detail/domain/zoom_transform.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  /// Where the child point ([x], [y]) lands once [m] is applied.
  ({double x, double y}) mapPoint(Matrix4 m, double x, double y) {
    final v = m.transform3(Vector3(x, y, 0));
    return (x: v.x, y: v.y);
  }

  group('zoomedAt', () {
    test('scales by exactly the requested factor on both axes', () {
      final m = zoomedAt(100, 200, scale: 2);
      expect(m.entry(0, 0), 2.0);
      expect(m.entry(1, 1), 2.0);
    });

    test('pins the focal point — it maps to itself', () {
      final m = zoomedAt(120, 340, scale: 2);
      final mapped = mapPoint(m, 120, 340);
      expect(mapped.x, closeTo(120, 1e-9));
      expect(mapped.y, closeTo(340, 1e-9));
    });

    test('pins a top-left focal point', () {
      final m = zoomedAt(0, 0, scale: kDoubleTapZoomScale);
      final mapped = mapPoint(m, 0, 0);
      expect(mapped.x, closeTo(0, 1e-9));
      expect(mapped.y, closeTo(0, 1e-9));
    });

    test('pins a bottom-right focal point', () {
      const w = 400.0;
      const h = 800.0;
      final m = zoomedAt(w, h, scale: kDoubleTapZoomScale);
      final mapped = mapPoint(m, w, h);
      expect(mapped.x, closeTo(w, 1e-9));
      expect(mapped.y, closeTo(h, 1e-9));
    });

    test('everything else moves — the focal point is not a no-op transform', () {
      final m = zoomedAt(100, 100, scale: 2);
      final mapped = mapPoint(m, 0, 0);
      expect(mapped.x, closeTo(-100, 1e-9));
      expect(mapped.y, closeTo(-100, 1e-9));
    });

    // The safety argument in zoom_transform.dart's doc: assigning a
    // TransformationController directly bypasses InteractiveViewer's clamping,
    // so the matrix has to land inside the bounds on its own. For a
    // viewport-sized child those bounds are [-(scale - 1) * edge, 0].
    test('translation stays inside InteractiveViewer bounds for any focal '
        'point in the viewport', () {
      const w = 400.0;
      const h = 800.0;
      const scale = kDoubleTapZoomScale;
      const minX = -(scale - 1) * w;
      const minY = -(scale - 1) * h;
      for (final focal in const [
        (0.0, 0.0),
        (w / 2, h / 2),
        (w, h),
        (1.0, h - 1),
        (w - 1, 1.0),
      ]) {
        final m = zoomedAt(focal.$1, focal.$2, scale: scale);
        final tx = m.entry(0, 3);
        final ty = m.entry(1, 3);
        expect(tx, inInclusiveRange(minX, 0), reason: 'focal $focal x');
        expect(ty, inInclusiveRange(minY, 0), reason: 'focal $focal y');
      }
    });

    test('scale 1 is the identity, whatever the focal point', () {
      expect(zoomedAt(37, 91, scale: 1), Matrix4.identity());
    });

    test('the double-tap scale stays under InteractiveViewer maxScale of 5', () {
      expect(kDoubleTapZoomScale, greaterThan(1));
      expect(kDoubleTapZoomScale, lessThan(5));
    });
  });
}
