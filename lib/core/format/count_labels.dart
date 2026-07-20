/// Shared count-label formatting (pure Dart — no Flutter imports).
library;

/// `'1 photo'` / `'$count photos'`. When [zero] is non-null it is returned
/// for a count of 0 (e.g. AlbumCard's `'Empty'`); otherwise 0 reads
/// `'0 photos'`.
String photoCountLabel(int count, {String? zero}) {
  if (count == 0 && zero != null) return zero;
  return count == 1 ? '1 photo' : '$count photos';
}
