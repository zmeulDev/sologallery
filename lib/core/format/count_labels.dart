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
