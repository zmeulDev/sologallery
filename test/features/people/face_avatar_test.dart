import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/people/widgets/face_avatar.dart';

void main() {
  group('faceAvatarPlacement', () {
    test('centers a centered face box in a square thumbnail', () {
      // A 100px box centered in a 512×512 thumbnail, 64px avatar.
      final p = faceAvatarPlacement(
        boxLeft: 206,
        boxTop: 206,
        boxRight: 306,
        boxBottom: 306,
        imageWidth: 512,
        imageHeight: 512,
        size: 64,
      );
      expect(p.left, closeTo(p.top, 1e-9)); // symmetric → centered
      expect(p.left, lessThan(0)); // thumbnail overflows the circle (zoomed in)
      // 100px face fills 64*fill(1.3) ≈ 83px of the circle.
      final faceOnScreen = 100 * (p.dispW / 512);
      expect(faceOnScreen, closeTo(64 * 1.3, 0.5));
    });

    test('preserves the image aspect ratio (no oval distortion)', () {
      // A portrait thumbnail (384×512) must display at the same ratio.
      final p = faceAvatarPlacement(
        boxLeft: 150, boxTop: 200, boxRight: 250, boxBottom: 300,
        imageWidth: 384, imageHeight: 512, size: 64,
      );
      expect(p.dispW / p.dispH, closeTo(384 / 512, 1e-9));
    });

    test('centers the face box of a non-square thumbnail on the circle', () {
      const w = 384.0, h = 512.0;
      final p = faceAvatarPlacement(
        boxLeft: 100, boxTop: 300, boxRight: 200, boxBottom: 400,
        imageWidth: w, imageHeight: h, size: 64,
      );
      // The face-box center, mapped through the placement, lands at the circle
      // center (32, 32).
      final scale = p.dispW / w;
      final faceCenterXOnScreen = p.left + ((100 + 200) / 2) * scale;
      final faceCenterYOnScreen = p.top + ((300 + 400) / 2) * scale;
      expect(faceCenterXOnScreen, closeTo(32, 1e-6));
      expect(faceCenterYOnScreen, closeTo(32, 1e-6));
    });

    test('a higher fill factor crops tighter (larger on-screen image)', () {
      final loose = faceAvatarPlacement(
        boxLeft: 200, boxTop: 200, boxRight: 300, boxBottom: 300,
        imageWidth: 512, imageHeight: 512, size: 64, fill: 1.0,
      );
      final tight = faceAvatarPlacement(
        boxLeft: 200, boxTop: 200, boxRight: 300, boxBottom: 300,
        imageWidth: 512, imageHeight: 512, size: 64, fill: 1.3,
      );
      expect(tight.dispW, greaterThan(loose.dispW));
    });

    test('clamps a degenerate (zero-area) box without dividing by zero', () {
      final p = faceAvatarPlacement(
        boxLeft: 10, boxTop: 10, boxRight: 10, boxBottom: 10,
        imageWidth: 512, imageHeight: 512, size: 64,
      );
      expect(p.dispW.isFinite && p.dispH.isFinite, isTrue);
      expect(p.dispW, greaterThan(0));
    });
  });
}
