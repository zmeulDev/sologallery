import 'package:flutter/material.dart';

import '../../detail/widgets/photo_page.dart';

/// A [PhotoPage] with a slow Ken Burns drift — scale 1.0→1.08 while easing
/// from a slight off-center [Alignment] back to [Alignment.center] — over
/// [duration] (the memory player's [MemoryPlayerScreen.pageDuration]).
/// Passed in rather than imported from the screen to avoid a circular
/// dependency between the two files.
///
/// One [AnimationController] per page, `forward()`-started once on mount and
/// restarted only if the same State ever gets reused for a *different*
/// asset (`PageView.builder` items aren't independently keyed, so Flutter
/// can in principle reuse a page's Element/State slot across a list change,
/// even though in normal swipe-through use each page is freshly created and
/// disposed with its own Element as usual). The drift direction alternates
/// per asset (its id's hash parity) so a run of stills doesn't all pan the
/// same way. Under reduced motion the photo is shown statically at rest —
/// the controller exists (so `dispose()` always has something real to
/// dispose of — see below) but is never started.
class KenBurnsPhoto extends StatefulWidget {
  const KenBurnsPhoto({super.key, required this.assetId, required this.duration});

  final String assetId;
  final Duration duration;

  @override
  State<KenBurnsPhoto> createState() => _KenBurnsPhotoState();
}

class _KenBurnsPhotoState extends State<KenBurnsPhoto>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState, not as a `late final` field initializer —
  // a lazy initializer only runs on first *access*, and if reduced motion
  // means build() never touches it, dispose() becomes that first access:
  // creating a Ticker that late looks up an ancestor InheritedWidget after
  // the widget has already been deactivated, which throws.
  late final AnimationController _controller;
  late Alignment _driftFrom = _alignmentFor(widget.assetId);
  bool _reducedMotionDecided = false;

  static Alignment _alignmentFor(String assetId) =>
      assetId.hashCode.isEven ? Alignment.centerLeft : Alignment.centerRight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guarded to run once: didChangeDependencies re-fires on any inherited
    // dependency change, but the drift should only ever be started once.
    if (_reducedMotionDecided) return;
    _reducedMotionDecided = true;
    if (!MediaQuery.of(context).disableAnimations) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant KenBurnsPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId == widget.assetId) return;
    _driftFrom = _alignmentFor(widget.assetId);
    _controller.duration = widget.duration;
    if (!MediaQuery.of(context).disableAnimations) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = PhotoPage(assetId: widget.assetId);
    if (MediaQuery.of(context).disableAnimations) return photo;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Transform.scale(
          scale: 1 + t * 0.08,
          alignment: Alignment.lerp(_driftFrom, Alignment.center, t)!,
          child: child,
        );
      },
      child: photo,
    );
  }
}
