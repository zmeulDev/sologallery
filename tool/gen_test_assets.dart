// Generates the deterministic `test_assets/` set described in CLAUDE.md
// ("Deterministic test assets"), so on-device tests never depend on whatever
// happens to be in the developer's camera roll.
//
//   dart run tool/gen_test_assets.dart
//
// Everything here is synthesized — no photos of real people, nothing copied
// from a real library. See test_assets/README.md for what still has to be
// sourced by hand and why.
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const _outDir = 'test_assets';

void main() {
  Directory(_outDir).createSync(recursive: true);

  _write('small_png.png', img.encodePng(_gradient(64, 64)));
  _write('no_exif.jpg', img.encodeJpg(_gradient(800, 600), quality: 90));
  _write('gps_exif.jpg', img.encodeJpg(_withGps(_gradient(800, 600)), quality: 90));

  // The HEIC-OOM regression asset. `package:image` cannot encode HEIC, so this
  // writes a ~48MP JPEG that `sips` converts (see README).
  _write('large_48mp.jpg', img.encodeJpg(_gradient(8000, 6000), quality: 85));

  // Face-detection fixture. Whether ML Kit actually detects this synthetic face
  // is verified on device by integration_test/test_assets_test.dart — a drawn
  // face is not guaranteed to trip a detector trained on photographs.
  _write('synthetic_face.jpg', img.encodeJpg(_syntheticFace(600, 800), quality: 92));

  stdout.writeln('\nNext: convert the HEIC and add a video — see '
      '$_outDir/README.md');
}

void _write(String name, List<int> bytes) {
  final file = File('$_outDir/$name')..writeAsBytesSync(bytes);
  final kb = (file.lengthSync() / 1024).toStringAsFixed(0);
  stdout.writeln('wrote $_outDir/$name (${kb}KB)');
}

/// A deterministic non-uniform image. Flat colour compresses to almost nothing,
/// which would defeat the point of the 48MP memory-pressure asset.
img.Image _gradient(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 255 ~/ w),
        (y * 255 ~/ h),
        ((x ^ y) & 0xFF), // XOR texture defeats the JPEG DCT
      );
    }
  }
  return image;
}

/// Tags [image] with a fixed location (Zurich) so EXIF-reading tests have a
/// known expected value, and with a capture date.
///
/// The date is not decoration: MediaStore fills `DATE_TAKEN` from
/// `DateTimeOriginal`, and without one the seeded asset is *undated*, so it
/// never appears in `libraryMetadataPage(dated: true)` — the page
/// `detail_actions_test` scans for a geotagged asset. It is stamped at
/// generation time rather than at a fixed instant so the fixture sorts near the
/// top of a real camera roll instead of being buried under years of photos.
img.Image _withGps(img.Image image) {
  final now = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp = '${now.year}:${two(now.month)}:${two(now.day)} '
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  image.exif.exifIfd['DateTimeOriginal'] = stamp;
  image.exif.imageIfd['DateTime'] = stamp;
  final gps = image.exif.gpsIfd;
  gps['GPSLatitudeRef'] = 'N';
  gps['GPSLatitude'] = [img.IfdValueRational(47, 1), img.IfdValueRational(22, 1), img.IfdValueRational(35, 1)];
  gps['GPSLongitudeRef'] = 'E';
  gps['GPSLongitude'] = [img.IfdValueRational(8, 1), img.IfdValueRational(32, 1), img.IfdValueRational(26, 1)];
  image.exif.imageIfd['Make'] = 'SoloGallery';
  image.exif.imageIfd['Model'] = 'Test Fixture';
  return image;
}

/// A frontal face built to the proportions a detector expects: eyes on the
/// horizontal midline about one eye-width apart, nose base halfway from eyes to
/// chin, mouth a third below that. Shaded and blurred, because ML Kit is
/// trained on photographs — hard-edged flat shapes are not detected (verified
/// on device by integration_test/test_fixtures_test.dart).
///
/// Deliberately generic and not modelled on any real person.
img.Image _syntheticFace(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(188, 192, 198));

  final cx = w / 2, cy = h * 0.50;
  final faceRx = w * 0.32, faceRy = h * 0.40;

  // Head with vertical lighting falloff and a rounded jaw, drawn per-pixel so
  // the edges stay soft rather than aliased.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - cx) / faceRx;
      // Taper the lower half toward a chin.
      final ny = (y - cy) / faceRy;
      final taper = ny > 0 ? 1.0 - ny * 0.18 : 1.0;
      final d = (dx / taper) * (dx / taper) + ny * ny;
      if (d <= 1.0) {
        // Light from upper-left; keeps the face from reading as a flat blob.
        final shade = 1.0 - 0.28 * d - 0.10 * (x - cx) / faceRx + 0.08 * -ny;
        image.setPixelRgb(
          x,
          y,
          (232 * shade).clamp(0, 255).toInt(),
          (196 * shade).clamp(0, 255).toInt(),
          (172 * shade).clamp(0, 255).toInt(),
        );
      }
    }
  }

  // Hair framing the top — gives the strong upper boundary detectors key on.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - cx) / (faceRx * 1.10), dy = (y - cy * 0.86) / (faceRy * 0.92);
      if (dx * dx + dy * dy <= 1 && y < cy - faceRy * 0.42) {
        image.setPixelRgb(x, y, 58, 44, 38);
      }
    }
  }

  // Eyes on the midline, one eye-width apart.
  final eyeRx = faceRx * 0.19, eyeRy = eyeRx * 0.52;
  final eyeY = cy - faceRy * 0.06;
  final eyeDx = faceRx * 0.40;
  for (final sign in [-1, 1]) {
    final ex = cx + sign * eyeDx;
    // Socket shadow, then sclera, iris, pupil, catchlight.
    _ellipse(image, ex, eyeY, eyeRx * 1.5, eyeRy * 2.2, img.ColorRgb8(206, 172, 150));
    _ellipse(image, ex, eyeY, eyeRx, eyeRy, img.ColorRgb8(248, 246, 242));
    _ellipse(image, ex, eyeY, eyeRy * 0.95, eyeRy * 0.95, img.ColorRgb8(92, 68, 48));
    _ellipse(image, ex, eyeY, eyeRy * 0.45, eyeRy * 0.45, img.ColorRgb8(20, 16, 14));
    _ellipse(image, ex - eyeRy * 0.3, eyeY - eyeRy * 0.3, eyeRy * 0.18,
        eyeRy * 0.18, img.ColorRgb8(255, 255, 255));
    // Lash line + brow.
    _ellipse(image, ex, eyeY - eyeRy * 1.05, eyeRx * 1.02, eyeRy * 0.30,
        img.ColorRgb8(78, 58, 48));
    _ellipse(image, ex, eyeY - eyeRy * 3.4, eyeRx * 1.05, eyeRy * 0.42,
        img.ColorRgb8(74, 54, 44));
  }

  // Nose: shadow down one side plus nostril shading at the base.
  final noseBaseY = cy + faceRy * 0.26;
  _ellipse(image, cx + faceRx * 0.055, noseBaseY - faceRy * 0.10, faceRx * 0.055,
      faceRy * 0.16, img.ColorRgb8(206, 168, 146));
  _ellipse(image, cx, noseBaseY, faceRx * 0.115, faceRy * 0.045,
      img.ColorRgb8(198, 158, 136));
  for (final sign in [-1, 1]) {
    _ellipse(image, cx + sign * faceRx * 0.075, noseBaseY, faceRx * 0.030,
        faceRy * 0.022, img.ColorRgb8(150, 112, 96));
  }

  // Mouth: upper/lower lip with a parting line.
  final mouthY = cy + faceRy * 0.55;
  _ellipse(image, cx, mouthY, faceRx * 0.26, faceRy * 0.070, img.ColorRgb8(186, 108, 100));
  _ellipse(image, cx, mouthY + faceRy * 0.020, faceRx * 0.24, faceRy * 0.045,
      img.ColorRgb8(198, 122, 114));
  _ellipse(image, cx, mouthY, faceRx * 0.25, faceRy * 0.008, img.ColorRgb8(132, 74, 70));

  // Soften everything: a photographic face has no hard vector edges, and the
  // hard-edged version of this fixture was not detected at all.
  return img.gaussianBlur(image, radius: (w * 0.006).round().clamp(1, 8));
}

void _ellipse(
  img.Image image,
  double cx,
  double cy,
  double rx,
  double ry,
  img.Color color,
) {
  final x0 = max(0, (cx - rx).floor()), x1 = min(image.width - 1, (cx + rx).ceil());
  final y0 = max(0, (cy - ry).floor()), y1 = min(image.height - 1, (cy + ry).ceil());
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1) image.setPixel(x, y, color);
    }
  }
}
