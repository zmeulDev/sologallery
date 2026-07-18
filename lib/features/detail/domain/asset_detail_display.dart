/// Pure display formatting for the EXIF sheet. No Flutter or plugin imports —
/// host-unit-testable (see docs/spec.md#architecture). Keeps the number/date
/// vocabulary out of the widgets so the sheet just lays out key/value pairs.
library;

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Pixel dimensions, e.g. `6048 × 8064`.
String formatDimensions(int width, int height) => '$width × $height';

/// Megapixels to one decimal, e.g. `48.8 MP`. Empty when either edge is 0.
String formatMegapixels(int width, int height) {
  if (width <= 0 || height <= 0) return '';
  return '${(width * height / 1e6).toStringAsFixed(1)} MP';
}

/// Human file size (`820 KB`, `2.1 MB`), or null when the size is unknown.
String? formatFileSize(int? bytes) {
  if (bytes == null || bytes < 0) return null;
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  return '${(bytes / mb).toStringAsFixed(1)} MB';
}

/// Short type label from a mime string, e.g. `image/heic` → `HEIC`. Null-safe.
String? formatType(String? mimeType) {
  if (mimeType == null || mimeType.isEmpty) return null;
  final slash = mimeType.lastIndexOf('/');
  final sub = slash >= 0 ? mimeType.substring(slash + 1) : mimeType;
  return sub.toUpperCase();
}

/// Capture date, e.g. `Jul 12, 2026 · 14:33` (24-hour, zero-padded).
String formatTakenDate(DateTime dt) {
  final month = _monthAbbr[dt.month - 1];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day}, ${dt.year} · $hh:$mm';
}

/// Clip length as `m:ss` (or `h:mm:ss` past an hour), or null for a still.
String? formatDuration(Duration? duration) {
  if (duration == null) return null;
  final seconds = duration.inSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Coordinate pair to four decimals, or null when there is no location.
String? formatCoordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return null;
  return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}
