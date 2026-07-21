import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/ml_service.dart';

/// The minimum-face-size gate. Without it, ML Kit's smallest hits — boxes of a
/// dozen-odd pixels in a 512-short-edge thumbnail — were embedded anyway. Their
/// embeddings are noise, so clustering could never group them and each became
/// its own one-photo "person": a real library came back with 48 people for 82
/// faces, 42 of them singletons showing gravel, hair and a wine barrel.
void main() {
  group('faceIsLargeEnough', () {
    // The analysis thumbnail for a 4:3 photo (short edge 512).
    const w = 683, h = 512;

    test('keeps a face at the threshold', () {
      final min = (512 * minFaceFraction).ceil(); // 26px
      expect(
        faceIsLargeEnough(w: min, h: min, imageWidth: w, imageHeight: h),
        isTrue,
      );
    });

    test('rejects the pixel-smear boxes that flooded the People grid', () {
      // 15×15 was the smallest box actually stored on device.
      expect(
        faceIsLargeEnough(w: 15, h: 15, imageWidth: w, imageHeight: h),
        isFalse,
      );
    });

    test('rejects a box that is wide enough but too short', () {
      expect(
        faceIsLargeEnough(w: 120, h: 12, imageWidth: w, imageHeight: h),
        isFalse,
      );
    });

    test('keeps ordinary group-photo faces', () {
      // ~35px faces in an 11-person group shot are legitimate.
      expect(
        faceIsLargeEnough(w: 35, h: 35, imageWidth: w, imageHeight: h),
        isTrue,
      );
    });

    test('measures against the short edge, so orientation does not matter', () {
      // The same face in the same photo, portrait vs landscape framing: the
      // long edge differs but the verdict must not.
      expect(
        faceIsLargeEnough(w: 30, h: 30, imageWidth: 683, imageHeight: 512),
        faceIsLargeEnough(w: 30, h: 30, imageWidth: 512, imageHeight: 683),
      );
    });

    test('rejects degenerate boxes', () {
      expect(
        faceIsLargeEnough(w: 1, h: 1, imageWidth: w, imageHeight: h),
        isFalse,
      );
    });
  });

  group('faceIsUsable', () {
    bool check({
      double? yaw = 0,
      double? roll = 0,
      bool leftEye = true,
      bool rightEye = true,
      bool nose = true,
    }) =>
        faceIsUsable(
          yawDegrees: yaw,
          rollDegrees: roll,
          hasLeftEye: leftEye,
          hasRightEye: rightEye,
          hasNoseBase: nose,
        );

    test('keeps a frontal face with a full landmark set', () {
      expect(check(), isTrue);
      expect(check(yaw: -12, roll: 8), isTrue);
    });

    test('rejects a detection missing any of the anchor landmarks', () {
      // The dog faces, the drawn face and the beer glass all came back like
      // this — a box, but no proper eye/nose geometry inside it.
      expect(check(leftEye: false), isFalse);
      expect(check(rightEye: false), isFalse);
      expect(check(nose: false), isFalse);
    });

    test('rejects a profile, in either direction', () {
      expect(check(yaw: maxFaceYaw + 1), isFalse);
      expect(check(yaw: -(maxFaceYaw + 1)), isFalse);
    });

    test('rejects a strongly tilted head, in either direction', () {
      expect(check(roll: maxFaceRoll + 1), isFalse);
      expect(check(roll: -(maxFaceRoll + 1)), isFalse);
    });

    test('keeps a face exactly at each limit', () {
      expect(check(yaw: maxFaceYaw, roll: maxFaceRoll), isTrue);
    });

    test('rejects a detection whose pose the detector could not determine', () {
      expect(check(yaw: null), isFalse);
      expect(check(roll: null), isFalse);
    });
  });
}
