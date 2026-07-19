import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/people/widgets/face_avatar.dart';

/// Where the face-box center lands on screen, given a placement. The whole job
/// of [faceAvatarPlacement] is to put this at the circle's center.
({double x, double y}) faceCenterOnScreen({
  required ({double left, double top, double dispW, double dispH}) p,
  required double boxLeft,
  required double boxTop,
  required double boxRight,
  required double boxBottom,
}) =>
    (
      x: p.left + (boxLeft + boxRight) / 2 * p.dispW,
      y: p.top + (boxTop + boxBottom) / 2 * p.dispH,
    );

void main() {
  group('faceAvatarPlacement', () {
    test('centers a centered face box in a square thumbnail', () {
      // A face spanning the middle fifth of a square thumbnail, 64px avatar.
      final p = faceAvatarPlacement(
        boxLeft: 0.4,
        boxTop: 0.4,
        boxRight: 0.6,
        boxBottom: 0.6,
        imageWidth: 512,
        imageHeight: 512,
        size: 64,
      );
      expect(p.left, closeTo(p.top, 1e-9)); // symmetric → centered
      expect(p.left, lessThan(0)); // thumbnail overflows the circle (zoomed in)
      // The face fills 64 * fill(1.3) ≈ 83px of the circle.
      expect(0.2 * p.dispW, closeTo(64 * 1.3, 0.5));
    });

    test('preserves the image aspect ratio (no oval distortion)', () {
      // A portrait thumbnail must display at its own ratio.
      final p = faceAvatarPlacement(
        boxLeft: 0.39, boxTop: 0.39, boxRight: 0.65, boxBottom: 0.59,
        imageWidth: 384, imageHeight: 512, size: 64,
      );
      expect(p.dispW / p.dispH, closeTo(384 / 512, 1e-9));
    });

    test('centers the face box of a non-square thumbnail on the circle', () {
      final p = faceAvatarPlacement(
        boxLeft: 0.26, boxTop: 0.58, boxRight: 0.52, boxBottom: 0.78,
        imageWidth: 384, imageHeight: 512, size: 64,
      );
      final c = faceCenterOnScreen(
        p: p,
        boxLeft: 0.26, boxTop: 0.58, boxRight: 0.52, boxBottom: 0.78,
      );
      expect(c.x, closeTo(32, 1e-6));
      expect(c.y, closeTo(32, 1e-6));
    });

    // The regression that produced blank, clipped and off-target avatars.
    //
    // photo_manager returns aspect-**fill** thumbnails: asking for 512×512
    // gives a 4:3 photo back at 683×512, and asking the same photo for
    // 1024×1024 gives 1365×1024. The old code stored the box in the analysis
    // thumbnail's pixels and rescaled by `longEdge / 512`, which for this
    // aspect is 1365/512 = 2.67 where the truth is 2.0 — every box came out a
    // third too large and a third too far down-and-right, dragging faces near
    // an edge right out of the circle. A normalized box is scale-free, so the
    // face must land in the same place whichever size comes back.
    test('places a face identically at any thumbnail size (aspect-fill)', () {
      const box = (l: 0.62, t: 0.55, r: 0.78, b: 0.76); // a right-of-center face
      ({double x, double y}) centerAt(double w, double h) {
        final p = faceAvatarPlacement(
          boxLeft: box.l, boxTop: box.t, boxRight: box.r, boxBottom: box.b,
          imageWidth: w, imageHeight: h, size: 64,
        );
        return faceCenterOnScreen(
          p: p,
          boxLeft: box.l, boxTop: box.t, boxRight: box.r, boxBottom: box.b,
        );
      }

      final analysis = centerAt(683, 512); // what faces were detected on
      final avatar = centerAt(1365, 1024); // what the avatar renders
      expect(avatar.x, closeTo(analysis.x, 1e-6));
      expect(avatar.y, closeTo(analysis.y, 1e-6));
      // And both are the circle's center — not merely equal to each other.
      expect(avatar.x, closeTo(32, 1e-6));
      expect(avatar.y, closeTo(32, 1e-6));
    });

    test('a higher fill factor crops tighter (larger on-screen image)', () {
      final loose = faceAvatarPlacement(
        boxLeft: 0.39, boxTop: 0.39, boxRight: 0.59, boxBottom: 0.59,
        imageWidth: 512, imageHeight: 512, size: 64, fill: 1.0,
      );
      final tight = faceAvatarPlacement(
        boxLeft: 0.39, boxTop: 0.39, boxRight: 0.59, boxBottom: 0.59,
        imageWidth: 512, imageHeight: 512, size: 64, fill: 1.3,
      );
      expect(tight.dispW, greaterThan(loose.dispW));
    });

    test('clamps a degenerate (zero-area) box without dividing by zero', () {
      final p = faceAvatarPlacement(
        boxLeft: 0.02, boxTop: 0.02, boxRight: 0.02, boxBottom: 0.02,
        imageWidth: 512, imageHeight: 512, size: 64,
      );
      expect(p.dispW.isFinite && p.dispH.isFinite, isTrue);
      expect(p.dispW, greaterThan(0));
    });
  });
}
