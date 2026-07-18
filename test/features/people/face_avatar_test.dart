import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/people/widgets/face_avatar.dart';

void main() {
  group('faceAvatarPlacement', () {
    test('centers a centered face box in the avatar', () {
      // A 100px box centered in the 512 thumbnail, 64px avatar.
      final p = faceAvatarPlacement(
        boxLeft: 206,
        boxTop: 206,
        boxRight: 306,
        boxBottom: 306,
        size: 64,
      );
      // The scaled thumbnail is centered, so its top-left is symmetric.
      expect(p.left, closeTo(p.top, 1e-9));
      expect(p.left, lessThan(0)); // thumbnail overflows the circle (zoomed in)
      // Face box (100px) fills 64*fill(1.3) ≈ 83px of the circle.
      final faceSideOnScreen = 100 * (p.side / 512);
      expect(faceSideOnScreen, closeTo(64 * 1.3, 0.5));
    });

    test('a higher fill factor crops tighter (larger on-screen face)', () {
      final loose = faceAvatarPlacement(
        boxLeft: 200, boxTop: 200, boxRight: 300, boxBottom: 300,
        size: 64, fill: 1.0,
      );
      final tight = faceAvatarPlacement(
        boxLeft: 200, boxTop: 200, boxRight: 300, boxBottom: 300,
        size: 64, fill: 1.3,
      );
      expect(tight.side, greaterThan(loose.side)); // more zoom
    });

    test('scales by the longer box side and clamps degenerate boxes', () {
      // Zero-area box clamps to 1px sides without dividing by zero.
      final p = faceAvatarPlacement(
        boxLeft: 10, boxTop: 10, boxRight: 10, boxBottom: 10, size: 64,
      );
      expect(p.side.isFinite, isTrue);
      expect(p.side, greaterThan(0));
    });
  });
}
