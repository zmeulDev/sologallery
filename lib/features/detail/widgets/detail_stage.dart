import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../widgets/asset_hero_tag.dart';
import '../../../widgets/asset_thumbnail.dart';
import 'photo_page.dart';
import 'video_page.dart';

/// One page of the detail [PageView]: the [Hero]-flown base thumbnail — the
/// literal widget that grows from the grid cell — with the real interactive
/// content ([PhotoPage] or [VideoPage]) cross-fading in once the page's own
/// push transition lands. This way a cropped, square, possibly-lower-res
/// thumbnail never has to un-crop mid-flight; the full photo (or video)
/// simply reveals on top of it once still, and fades back out underneath if
/// the page is popped before it or during a drag-dismiss.
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
    return Hero(
      tag: assetHeroTag(widget.assetId),
      child: Stack(
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
      ),
    );
  }
}
