import 'dart:typed_data';

/// Arguments passed to the photo detail viewer via GoRouter `extra`: the ordered
/// sequence of asset ids the viewer swipes through and which one to open first.
///
/// The sequence is the originating context (a month's previews, or a full-month
/// grid page). When absent (deep link / restore), the route falls back to a
/// single-asset sequence built from the path id.
///
/// [initialBytes] is the already-decoded grid thumbnail for the tapped asset,
/// passed so the detail viewer can paint it instantly while the higher-resolution
/// preview loads.
class PhotoViewerArgs {
  const PhotoViewerArgs(this.assetIds, this.initialIndex, {this.initialBytes});

  final List<String> assetIds;
  final int initialIndex;

  /// Optional low-res thumbnail bytes for the initially shown asset, typically
  /// the grid cell the user just tapped.
  final Uint8List? initialBytes;
}
