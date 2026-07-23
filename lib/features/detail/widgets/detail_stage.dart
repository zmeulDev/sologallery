import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../widgets/asset_thumbnail.dart';
import 'photo_page.dart';
import 'video_page.dart';

/// One page of the detail [PageView]: the base thumbnail — the literal widget
/// that grew from the grid cell — with the real interactive content
/// ([PhotoPage] or [VideoPage]) cross-fading in once the page's own push
/// transition lands. This way a cropped, square, possibly-lower-res thumbnail
/// never has to un-crop mid-flight; the full photo (or video) simply reveals
/// on top of it once still, and fades back out underneath if the page is
/// popped before it or during a drag-dismiss.
///
/// With route transitions removed (Part 1 A1) the cross-fade is effectively
/// instant — `_revealed` flips the moment the (zero-duration) route animation
/// completes, so the real page takes the stage on the first frame and the base
/// thumbnail sits underneath at opacity 0. The Hero flight that used to wrap
/// this stage is gone (A1); the two `AnimatedOpacity` layers and the 1080
/// underlay are deliberately kept for now — retiring the underlay is entangled
/// with the drag-dismiss zoom animation's frame timing (exercised by
/// `dismissible_photo_test`), so it folds into Part 1 A4, which rewrites that
/// zoom to an instant transform write and removes the timing coupling.
///
/// [transformController] and [panEnabled] are forwarded to [PhotoPage]
/// (ignored for video) so an ancestor drag-dismiss gesture can read the live
/// zoom state and disable single-finger pan while it's not zoomed.
class DetailStage extends StatefulWidget {
  const DetailStage({
    super.key,
    required this.assetId,
    required this.isVideo,
    this.transformController,
    this.panEnabled = true,
  });

  final String assetId;
  final bool isVideo;
  final TransformationController? transformController;
  final bool panEnabled;

  @override
  State<DetailStage> createState() => _DetailStageState();
}

class _DetailStageState extends State<DetailStage> {
  bool _revealed = false;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) {
      // No enclosing route transition to wait for (e.g. a bare widget test,
      // or this page pumped directly) — nothing to reveal after.
      _revealed = true;
      return;
    }
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = animation;
    if (animation.isCompleted) {
      _revealed = true;
    } else {
      animation.addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _revealed = true);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context, AppMotion.medium);
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: _revealed ? 0 : 1,
          duration: duration,
          child: AssetThumbnail(assetId: widget.assetId, size: 1080),
        ),
        AnimatedOpacity(
          opacity: _revealed ? 1 : 0,
          duration: duration,
          child: widget.isVideo
              ? VideoPage(assetId: widget.assetId)
              : PhotoPage(
                  assetId: widget.assetId,
                  transformController: widget.transformController,
                  panEnabled: widget.panEnabled,
                ),
        ),
      ],
    );
  }
}