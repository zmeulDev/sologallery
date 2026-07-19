// Generates the SoloGallery launcher icon masters, then `flutter_launcher_icons`
// derives every platform size from them:
//
//   dart run tool/gen_app_icon.dart
//   dart run flutter_launcher_icons
//
// ## The mark
//
// The app's own month grid — six cells, the first one filled. SoloGallery's
// main view is "first 6 photos per month, newest first", so the icon is a
// reduction of the actual product, not generic photo-app iconography (no
// aperture, no mountain-and-sun, no overlapping photo stack). The single filled
// cell is the "Solo": one photo, distinguished, top-left where the newest sits.
//
// Colours come only from the design system (CLAUDE.md → Design system):
// near-black ground, warm off-white mark.
//
// ## Why outlines, and why near-black
//
// Two things were tried and rejected by looking at them at launcher size:
//   * Off-white ground with six *filled* cells read as the Android app-drawer
//     glyph, and the quiet cells nearly vanished at 96px.
//   * Filling the five quiet cells in a muted grey collapses to one flat shape
//     in Android's themed ("monochrome") layer, which is a single-colour alpha
//     mask — the hierarchy would be lost exactly where it is needed.
// Stroking the five and filling the sixth encodes the hierarchy in *alpha*, so
// it survives the themed layer unchanged, and the near-black ground gives the
// icon presence on a light launcher.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _outDir = 'assets/icon';
const _size = 1024;

// Design-system tokens (CLAUDE.md → Design system → Colors).
final _paper = img.ColorRgb8(0xF5, 0xF5, 0xF3); // background, light — the mark
final _ink = img.ColorRgb8(0x11, 0x11, 0x10); // text primary, light — the ground

/// Fraction of the canvas the grid spans, for a layer drawn at final scale
/// (iOS). Comfortably inside Android's adaptive-icon safe zone — the inner
/// 72/108 (≈66%) — so no launcher mask (circle, squircle, teardrop) clips it.
const _gridSpan = 0.56;

/// `flutter_launcher_icons` writes the adaptive-icon XML with a 16% inset on
/// both the foreground and monochrome layers, which would render the same mark
/// ~32% smaller on Android than on iOS. Pre-compensate so the two platforms
/// look identical. Keep in step with the `android:inset` in
/// `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`.
const _adaptiveInset = 0.16;
const _adaptiveGridSpan = _gridSpan / (1 - _adaptiveInset * 2);

void main() {
  Directory(_outDir).createSync(recursive: true);

  // iOS: no alpha allowed, corners are masked by the OS.
  _write('icon.png', _compose(background: _ink, span: _gridSpan));
  // Android adaptive: background and foreground are separate layers, and the
  // launcher parallaxes them independently.
  _write('android_background.png', _solid(_ink));
  _write(
    'android_foreground.png',
    _compose(background: null, span: _adaptiveGridSpan),
  );
  // Themed layer: the system tints this by alpha, so the geometry is identical
  // and only the coverage carries meaning.
  _write(
    'android_monochrome.png',
    _compose(background: null, span: _adaptiveGridSpan),
  );

  stdout.writeln('\nNext: dart run flutter_launcher_icons');
}

void _write(String name, img.Image image) {
  File('$_outDir/$name').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $_outDir/$name (${image.width}x${image.height})');
}

img.Image _solid(img.Color color) =>
    img.Image(width: _size, height: _size)..clear(color);

/// Draws the six-cell grid. [background] null leaves the layer transparent
/// (Android foreground / themed layers).
img.Image _compose({required img.Color? background, required double span}) {
  final image = img.Image(width: _size, height: _size, numChannels: 4);
  if (background != null) {
    image.clear(background);
  } else {
    // Fully transparent, not black-with-zero-alpha: some launchers composite
    // premultiplied and would fringe the mark dark.
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  }

  final gridW = _size * span;
  final gap = gridW * 0.070;
  final cell = (gridW - gap * 2) / 3; // 3 columns
  final gridH = cell * 2 + gap; // 2 rows
  final left = (_size - gridW) / 2;
  final top = (_size - gridH) / 2;

  // Matches the 12px radius the design system uses on a ~340px-wide card.
  final radius = cell * 0.17;
  final stroke = cell * 0.10;

  for (var row = 0; row < 2; row++) {
    for (var col = 0; col < 3; col++) {
      final x = left + col * (cell + gap);
      final y = top + row * (cell + gap);
      final isSolo = row == 0 && col == 0; // newest-first: the top-left cell

      if (isSolo) {
        _roundedRect(image, x, y, cell, cell, radius, _paper, fill: true);
      } else {
        _roundedRect(image, x, y, cell, cell, radius, _paper,
            fill: false, strokeWidth: stroke);
      }
    }
  }
  return image;
}

/// Anti-aliased rounded rectangle via a signed-distance field — `package:image`
/// has no radiused primitive, and hard-edged rasterization looks cheap at the
/// sizes a launcher actually renders.
void _roundedRect(
  img.Image image,
  double x,
  double y,
  double w,
  double h,
  double radius,
  img.Color color, {
  required bool fill,
  double strokeWidth = 0,
}) {
  final cx = x + w / 2, cy = y + h / 2;
  final halfW = w / 2, halfH = h / 2;

  // Bounding box, padded for the stroke and the anti-aliasing ramp.
  final pad = strokeWidth + 2;
  final x0 = math.max(0, (x - pad).floor());
  final x1 = math.min(image.width - 1, (x + w + pad).ceil());
  final y0 = math.max(0, (y - pad).floor());
  final y1 = math.min(image.height - 1, (y + h + pad).ceil());

  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      // Sample at pixel centre.
      final dx = (px + 0.5 - cx).abs() - (halfW - radius);
      final dy = (py + 0.5 - cy).abs() - (halfH - radius);
      final outside = math.sqrt(
        math.pow(math.max(dx, 0), 2) + math.pow(math.max(dy, 0), 2),
      );
      final sd = outside + math.min(math.max(dx, dy), 0) - radius;

      // Coverage: 1 well inside, 0 well outside, ramped across one pixel.
      final d = fill ? sd : sd.abs() - strokeWidth / 2;
      final coverage = (0.5 - d).clamp(0.0, 1.0);
      if (coverage <= 0) continue;

      _blend(image, px, py, color, coverage);
    }
  }
}

/// Source-over blend of [color] at [alpha] onto the pixel, so overlapping
/// shapes and the anti-aliased edges composite correctly on any layer.
void _blend(img.Image image, int x, int y, img.Color color, double alpha) {
  final dst = image.getPixel(x, y);
  final da = dst.a / 255.0;
  final outA = alpha + da * (1 - alpha);
  if (outA <= 0) return;

  double mix(num src, num dstC) =>
      (src * alpha + dstC * da * (1 - alpha)) / outA;

  image.setPixelRgba(
    x,
    y,
    mix(color.r, dst.r).round().clamp(0, 255),
    mix(color.g, dst.g).round().clamp(0, 255),
    mix(color.b, dst.b).round().clamp(0, 255),
    (outA * 255).round().clamp(0, 255),
  );
}
