// Pre-pads `assets/icon/android_ic_launcher_foreground_1024.png` so its
// artwork fills ~62% of the canvas instead of ~31%.
//
// Why: `flutter_launcher_icons` downscales the foreground to a fixed
// 432×432 (Android's adaptive-icon foreground spec) and Android's
// launcher mask then applies another ~16% inset. The user-supplied
// master only fills 318×318 of the 1024 source (31%); after the
// downscale-and-mask pipeline the visible art occupies ~37% of the
// launcher footprint — visibly too small. Android documents 66dp of
// safe zone in a 108dp icon (~61% content area). We target 62% here.
//
// How: crop the master to its content bbox, upscale to ~635×635 with
// cubic resampling, paste centered on a fresh 1024×1024 transparent
// canvas. Writes a new file; the user-supplied master is untouched
// (non-destructive — if the user updates the source, this script is
// idempotent and just gets re-run).
//
// Run from repo root:
//
//   dart run tool/pad_foreground.dart
//
// Then re-emit the launcher PNGs:
//
//   dart run flutter_launcher_icons
import 'dart:io';

import 'package:image/image.dart' as img;

const _src = 'assets/icon/android_ic_launcher_foreground_1024.png';
const _dst = 'assets/icon/android_ic_launcher_foreground_1024_padded.png';
const _size = 1024;
// Android adaptive-icon safe zone: 66dp in 108dp ≈ 0.611; round up a hair
// for sampling headroom. Result: ~62% content area, ~19% margin each side.
const _contentFraction = 0.62;
const _alphaThreshold = 8;

void main() {
  final src = img.decodePng(File(_src).readAsBytesSync())!;
  if (src.width != _size || src.height != _size) {
    stderr.writeln(
      'expected ${_size}x$_size source, got ${src.width}x${src.height}',
    );
    exit(1);
  }

  final bbox = _contentBbox(src);
  if (bbox == null) {
    stderr.writeln('source has no opaque content (alpha > $_alphaThreshold)');
    exit(1);
  }
  final contentW = bbox.maxX - bbox.minX + 1;
  final contentH = bbox.maxY - bbox.minY + 1;

  final targetSide = (_size * _contentFraction).round();
  // The source's content bbox is square-ish (the three-card silhouette),
  // but defend against non-square by scaling to the larger axis.
  final scale = targetSide / (contentW > contentH ? contentW : contentH);
  final scaledW = (contentW * scale).round();
  final scaledH = (contentH * scale).round();

  final cropped = img.copyCrop(
    src,
    x: bbox.minX,
    y: bbox.minY,
    width: contentW,
    height: contentH,
  );
  final scaled = img.copyResize(
    cropped,
    width: scaledW,
    height: scaledH,
    interpolation: img.Interpolation.cubic,
  );

  // Compose onto a fresh 1024×1024 transparent canvas, centered.
  final dst = img.Image(width: _size, height: _size, numChannels: 4);
  final offsetX = ((_size - scaledW) / 2).round();
  final offsetY = ((_size - scaledH) / 2).round();
  img.compositeImage(dst, scaled, dstX: offsetX, dstY: offsetY);

  File(_dst).writeAsBytesSync(img.encodePng(dst));
  stdout.writeln(
    'wrote $_dst  '
    'content=${scaledW}x$scaledH '
    '(${(scaledW / _size * 100).toStringAsFixed(1)}% of canvas)  '
    'margin=${offsetX}px each side '
    '(${(offsetX / _size * 100).toStringAsFixed(1)}%)',
  );
  stdout.writeln(
    'next: dart run flutter_launcher_icons '
    '(pubspec already points at the padded file)',
  );
}

/// Returns the (minX, minY, maxX, maxY) bounding box of pixels whose alpha
/// exceeds [_alphaThreshold]. Anti-aliasing fringe at the silhouette edge
/// can register as nearly-transparent pixels — the threshold filters those
/// out so the bbox hugs the real art, not its anti-aliased halo.
({int minX, int minY, int maxX, int maxY})? _contentBbox(img.Image src) {
  var minX = src.width;
  var minY = src.height;
  var maxX = 0;
  var maxY = 0;
  var found = false;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      if (px.a.toInt() > _alphaThreshold) {
        found = true;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }
  return found ? (minX: minX, minY: minY, maxX: maxX, maxY: maxY) : null;
}