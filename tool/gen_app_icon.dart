// One-off regenerator for the launcher-icon masters that the user didn't
// provide themselves. Reads the artwork in `assets/icon/` and writes:
//
//   - assets/icon/android_background.png
//       Flat tone sampled from the outer frame of `sologallery_icon_1024.png`
//       so the foreground's 16% inset doesn't reveal a contrasting fill
//       behind the launcher mask.
//
//   - assets/icon/android_monochrome.png
//       Luminance-to-alpha silhouette derived from
//       `sologallery_mark_transparent_4096.png`. Android 13+ tints the themed
//       layer by alpha, so the geometry of the stack (three cards + sun +
//       ridge) reads against any launcher tint.
//
// Run from repo root:
//
//   dart run tool/gen_app_icon.dart
//
// Then:
//
//   dart run flutter_launcher_icons
//
// `flutter_launcher_icons` reads the masters and emits every platform size.
// The user-provided files (`sologallery_icon_1024.png`,
// `android_ic_launcher_foreground_1024.png`) are used as-is and not touched
// here.
import 'dart:io';

import 'package:image/image.dart' as img;

const _outDir = 'assets/icon';
const _size = 1024;

void main() {
  Directory(_outDir).createSync(recursive: true);

  // ── android_background ──────────────────────────────────────────────────
  // Sample the outer frame of the full-bleed 1024 PNG. The full-bleed art has
  // its own background card; we want the launcher background layer to match
  // it so the foreground's 16% inset reveals the same tone, not a contrasting
  // fill. We average four corner samples (the very corner pixel can be
  // anti-aliasing fringe from the rounded card) to get a stable tone.
  final fullBleed = img.decodePng(
    File('$_outDir/sologallery_icon_1024.png').readAsBytesSync(),
  )!;
  final bg = _sampleOuterFrame(fullBleed);
  _write('android_background.png', _solid(bg));

  // ── android_monochrome ───────────────────────────────────────────────────
  // Themed icons are tinted by alpha. Map luminance → opacity so the
  // silhouette of the three-card stack reads against any theme tint. The
  // transparent mark is already on a transparent canvas, so this is just a
  // greyscale + alpha re-pack — no chroma key needed.
  final transparent = img.decodePng(
    File('$_outDir/sologallery_mark_transparent_4096.png').readAsBytesSync(),
  )!;
  _write('android_monochrome.png', _luminanceToAlpha(transparent));

  stdout.writeln('\nNext: dart run flutter_launcher_icons');
}

/// Sample the outer frame of [image] by averaging the four corners (a small
/// inset past the very edge so anti-aliasing fringe doesn't bias the sample).
/// Returns the design-system paper tone when the source's outer frame is that
/// tone (which it is — the full-bleed icon's outer card is `#F5F5F3`).
img.ColorRgb8 _sampleOuterFrame(img.Image image) {
  const inset = 8;
  final positions = <List<int>>[
    [inset, inset],
    [image.width - 1 - inset, inset],
    [inset, image.height - 1 - inset],
    [image.width - 1 - inset, image.height - 1 - inset],
  ];

  var r = 0, g = 0, b = 0;
  for (final p in positions) {
    final px = image.getPixel(p[0], p[1]);
    r += px.r.toInt();
    g += px.g.toInt();
    b += px.b.toInt();
  }
  final n = positions.length;
  return img.ColorRgb8(r ~/ n, g ~/ n, b ~/ n);
}

img.Image _solid(img.ColorRgb8 color) =>
    img.Image(width: _size, height: _size)..clear(color);

img.Image _luminanceToAlpha(img.Image src) {
  final dst = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      // Rec. 709 luminance. The transparent canvas gives alpha=0 → output
      // alpha=0; opaque art gives alpha=luma. The tinted layer therefore
      // carries the silhouette of the mark and nothing more.
      final luma = (0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b).round();
      dst.setPixelRgba(x, y, 0, 0, 0, luma);
    }
  }
  return dst;
}

void _write(String name, img.Image image) {
  File('$_outDir/$name').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $_outDir/$name (${image.width}x${image.height})');
}