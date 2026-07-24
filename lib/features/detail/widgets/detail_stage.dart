import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'photo_page.dart';
import 'video_page.dart';

/// One page of the detail [PageView]: the interactive content ([PhotoPage] or
/// [VideoPage]) for this asset, branching on its kind.
///
/// Route transitions were removed in Part 1 A1 (the push is an instant
/// `NoTransitionPage`), and Part 1 A4 rewrites the drag-dismiss double-tap
/// zoom to an instant transform write. With no push transition to cross-fade
/// against and no animation frame-timing to couple to, the 1080 base-thumbnail
/// underlay that used to sit beneath the real page is retired here — it had
/// been at opacity 0 since A1, so this only frees the ~6 MB it held per live
/// page. The kind (`isVideo`) resolves async from a provider; a video briefly
/// builds a [PhotoPage] until it resolves, exactly as it already did under A1.
///
/// [transformController] and [panEnabled] are forwarded to [PhotoPage]
/// (ignored for video) so an ancestor drag-dismiss gesture can read the live
/// zoom state and disable single-finger pan while it's not zoomed.
class DetailStage extends StatelessWidget {
  const DetailStage({
    super.key,
    required this.assetId,
    required this.isVideo,
    this.placeholderBytes,
    this.transformController,
    this.panEnabled = true,
  });

  final String assetId;
  final bool isVideo;
  final Uint8List? placeholderBytes;
  final TransformationController? transformController;
  final bool panEnabled;

  @override
  Widget build(BuildContext context) {
    return isVideo
        ? VideoPage(assetId: assetId)
        : PhotoPage(
            assetId: assetId,
            placeholderBytes: placeholderBytes,
            transformController: transformController,
            panEnabled: panEnabled,
          );
  }
}