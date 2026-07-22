import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'permission_provider.dart';

/// Identifies a thumbnail request. Value-equal so Riverpod's family cache reuses
/// the same future for the same asset+size (avoids refetching on rebuild).
class ThumbnailRequest {
  const ThumbnailRequest(this.assetId, {this.width = 256, this.height = 256});

  final String assetId;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is ThumbnailRequest &&
      other.assetId == assetId &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(assetId, width, height);
}

/// Decoded thumbnail bytes for a single asset. `autoDispose` so off-screen grid
/// cells release memory; `photo_manager` caches the bytes natively, so scrolling
/// back is cheap. Overridable in golden/widget tests with deterministic bytes.
///
/// Disposal is forwarded to the service as a cancellation signal. Riverpod
/// dropping this provider frees the *bytes*, but on its own it does nothing
/// about a decode already queued behind the concurrency cap — that request
/// would still run for a cell that scrolled away. The flag lets the gate in
/// `thumbnail_gate.dart` skip it instead.
final thumbnailProvider =
    FutureProvider.autoDispose.family<Uint8List?, ThumbnailRequest>(
  (ref, req) {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    return ref
        .read(photoLibraryServiceProvider)
        .thumbnail(
          req.assetId,
          req.width,
          req.height,
          cancelled: () => disposed,
        );
  },
);

/// Clip length for a video asset, or null for images. Drives the grid duration
/// badge (see [AssetThumbnail]). `autoDispose` and keyed by id so it rides the
/// same warm entity the thumbnail already resolved. Overridable in tests.
final videoDurationProvider =
    FutureProvider.autoDispose.family<Duration?, String>(
  (ref, assetId) =>
      ref.read(photoLibraryServiceProvider).videoDuration(assetId),
);
