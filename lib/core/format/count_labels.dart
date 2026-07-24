/// Shared count-label formatting (pure Dart — no Flutter imports).
library;

/// `'1 photo'` / `'$count photos'`. When [zero] is non-null it is returned
/// for a count of 0 (e.g. AlbumCard's `'Empty'`); otherwise 0 reads
/// `'0 photos'`.
String photoCountLabel(int count, {String? zero}) {
  if (count == 0 && zero != null) return zero;
  return count == 1 ? '1 photo' : '$count photos';
}

/// `'1 item'` / `'$count items'` — for a set that mixes photos and videos, where
/// [photoCountLabel]'s wording would undercount what the user can see. Library
/// month and year sections use this; an album or folder cover row, which counts
/// entries the user filed, stays on [photoCountLabel].
String itemCountLabel(int count) => count == 1 ? '1 item' : '$count items';

/// `'142'` / `'1.2k'` / `'12k'` — a count shortened to at most four glyphs, for
/// somewhere it has to fit rather than read: the indexing dial's 44px disc,
/// where a five-digit library would otherwise overflow the ring.
///
/// One decimal below 10k (`1.2k`) so the first order of magnitude keeps some
/// resolution, whole thousands above it; a trailing `.0` is dropped so 1000
/// reads `1k`, not `1.0k`.
String compactCount(int count) {
  if (count < 1000) return '$count';
  if (count < 10000) {
    final k = (count / 1000).toStringAsFixed(1);
    return '${k.endsWith('.0') ? k.substring(0, k.length - 2) : k}k';
  }
  return '${count ~/ 1000}k';
}
