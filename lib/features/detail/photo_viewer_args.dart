/// Arguments passed to the photo detail viewer via GoRouter `extra`: the ordered
/// sequence of asset ids the viewer swipes through and which one to open first.
///
/// The sequence is the originating context (a month's previews, or a full-month
/// grid page). When absent (deep link / restore), the route falls back to a
/// single-asset sequence built from the path id.
class PhotoViewerArgs {
  const PhotoViewerArgs(this.assetIds, this.initialIndex);

  final List<String> assetIds;
  final int initialIndex;
}
