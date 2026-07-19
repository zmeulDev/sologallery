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
}
