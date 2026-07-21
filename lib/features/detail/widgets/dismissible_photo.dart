import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import 'detail_stage.dart';

/// Wraps one detail page with an interactive drag-down-to-dismiss gesture:
/// the photo follows the finger, scaling and fading as it goes, and on
/// release either springs back (animated here) or pops the route
/// immediately, handing off to the page route's own Hero return-flight
/// rather than finishing a separate exit animation first — see
/// [_onPointerEnd].
///
/// Tracked via raw [Listener] pointer events, not a competing
/// [GestureDetector] recognizer. [InteractiveViewer] (photo pages only —
/// video has none) needs to be ready to recognize a pinch from the very
/// first touch, so its own scale recognizer stays a candidate in the arena
/// even at rest with `panEnabled: false` — it can still win the arena and
/// simply do nothing, which would silently swallow a sibling
/// `VerticalDragGestureRecognizer`'s whole gesture before it ever saw an
/// update. [Listener] sidesteps this: raw pointer events are routed to every
/// widget in the hit-test chain regardless of which recognizer wins the
/// arena, so this always sees the touch. It self-gates instead — ignoring
/// pointers while [PhotoPage]'s [TransformationController] (owned here,
/// photo pages only) reports a zoomed matrix, and locking onto whichever
/// axis (vertical vs horizontal) the drag reads as dominant once it clears
/// touch slop, deferring to the [PageView]'s own horizontal swipe rather
/// than fighting it.
///
/// [onProgress] mirrors the live 0 (settled) → 1 (dismissed) value up to the
/// parent screen so its chrome — a sibling of the [PageView], not a
/// descendant of any one page — can fade in lockstep.
///
/// The same axis lock serves the opposite direction: an upward fling has
/// nothing to dismiss, so it opens the details sheet via [onSwipeUp]. Both
/// directions therefore go through one recognizer-free gesture path and
/// can't starve each other in the arena.
class DismissiblePhoto extends StatefulWidget {
  const DismissiblePhoto({
    super.key,
    required this.assetId,
    required this.isVideo,
    required this.onProgress,
    required this.onDismissed,
    required this.onSwipeUp,
  });

  final String assetId;
  final bool isVideo;
  final ValueChanged<double> onProgress;
  final VoidCallback onDismissed;
  final VoidCallback onSwipeUp;

  @override
  State<DismissiblePhoto> createState() => _DismissiblePhotoState();
}

class _DismissiblePhotoState extends State<DismissiblePhoto>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _dismiss = AnimationController(
    vsync: this,
    duration: AppMotion.long,
  )..addListener(() => widget.onProgress(_dismiss.value));
  bool _zoomed = false;

  Offset? _pointerStart;
  int? _activePointer;
  bool? _verticalIntent; // null = undecided; true/false once slop clears.
  // Signed vertical travel of the current drag. Kept separately from
  // _dismiss.value, which clamps at 0 and so can't tell "at rest" from
  // "dragged upward".
  double _totalDy = 0;
  VelocityTracker? _velocityTracker;
  // Read once per drag (didChangeDependencies), not per pointer-move event
  // or per animation frame — MediaQuery.sizeOf is cheap but there's no
  // reason to pay it dozens of times over one gesture.
  double _screenHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenHeight = MediaQuery.sizeOf(context).height;
  }

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final zoomed = _transformController.value != Matrix4.identity();
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _dismiss.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_zoomed || _activePointer != null) return;
    _activePointer = event.pointer;
    _pointerStart = event.position;
    _verticalIntent = null;
    _totalDy = 0;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
    _dismiss.stop();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerStart == null) return;
    _velocityTracker!.addPosition(event.timeStamp, event.position);
    final total = event.position - _pointerStart!;
    _verticalIntent ??= total.distance > kTouchSlop
        ? total.dy.abs() > total.dx.abs()
        : null;
    if (_verticalIntent != true) return;
    _totalDy = total.dy;
    // Only downward drag moves the photo; an upward one leaves it in place
    // (clamped at 0) and is resolved on release as a details-sheet swipe.
    _dismiss.value = (total.dy / _screenHeight).clamp(0.0, 1.0);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final wasVertical = _verticalIntent == true;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0.0;
    final totalDy = _totalDy;
    _activePointer = null;
    _pointerStart = null;
    _verticalIntent = null;
    _totalDy = 0;
    _velocityTracker = null;
    if (!wasVertical) return;

    // Upward: nothing was displaced (_dismiss stayed clamped at 0), so this
    // resolves purely from the gesture — a flick, or a deliberate drag past
    // a fraction of the screen.
    if (totalDy < 0) {
      if (velocity < -300 || totalDy < -_screenHeight * 0.15) {
        widget.onSwipeUp();
      }
      return;
    }

    final shouldDismiss = _dismiss.value > 0.3 || velocity > 800;
    if (shouldDismiss) {
      // Hand off to the route's own Hero return-flight immediately, rather
      // than first finishing this drag's own shrink-to-nothing animation
      // and popping only once it completes. Running both in sequence reads
      // as two disconnected motions — the photo fades out to a black
      // screen, a pause, and only then does a *second*, seemingly
      // unrelated animation fly it back into the grid. Popping right away
      // means there's exactly one motion: the Hero flight takes over
      // wherever the drag left off.
      widget.onDismissed();
    } else {
      final duration = AppMotion.of(context, AppMotion.long);
      _dismiss.animateTo(0, duration: duration, curve: AppMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = DetailStage(
      assetId: widget.assetId,
      isVideo: widget.isVideo,
      transformController: widget.isVideo ? null : _transformController,
      // Harmless either way now that the dismiss gesture no longer competes
      // for the arena, but there's still nothing to pan to at scale 1.
      panEnabled: _zoomed,
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _dismiss,
          builder: (context, child) {
            final t = _dismiss.value;
            // One Transform with a composed matrix, not two nested ones —
            // each Transform with a non-identity matrix forces its own
            // compositing layer, so nesting translate-then-scale paid for
            // two layers every frame of the drag for no visual difference
            // over one. (Alignment.center wraps the *whole* matrix in an
            // origin shift, equivalent to nesting since a pure translation
            // commutes with itself — it doesn't need to wrap only the scale
            // part separately.)
            return Opacity(
              opacity: 1 - t,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(0.0, t * _screenHeight * 0.4, 0.0, 1.0)
                  ..scaleByDouble(
                    1 - t * 0.25,
                    1 - t * 0.25,
                    1 - t * 0.25,
                    1.0,
                  ),
                child: child,
              ),
            );
          },
          child: stage,
        ),
      ),
    );
  }
}
