import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../domain/zoom_transform.dart';
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
///
/// Taps are resolved from the same raw pointer stream for the same reason. A
/// [GestureDetector] carrying `onTap` + `onDoubleTap` would put a
/// [DoubleTapGestureRecognizer] back into the arena beside
/// [InteractiveViewer]'s scale recognizer — precisely the shape that starved
/// the dismiss drag before. Here a tap is just a release that never resolved
/// an axis, travelled less than [kTouchSlop] and lasted less than
/// [kLongPressTimeout]; a second one inside [kDoubleTapTimeout] and
/// [kDoubleTapSlop] of the first is a double-tap.
///
/// The consequence is that [onTap] fires one [kDoubleTapTimeout] *after* the
/// release, not on it — a first tap can't be acted on until it's known not to
/// be the opening half of a double-tap. Toggling the chrome immediately and
/// undoing it on the second tap would be instant but would flash the whole
/// chrome in and out of every zoom, which reads as a bug. That delay is
/// gesture disambiguation, not motion, so it is deliberately *not* routed
/// through [AppMotion.of] and stays put under reduced motion.
class DismissiblePhoto extends StatefulWidget {
  const DismissiblePhoto({
    super.key,
    required this.assetId,
    required this.isVideo,
    required this.onProgress,
    required this.onDismissed,
    required this.onSwipeUp,
    required this.onTap,
  });

  final String assetId;
  final bool isVideo;
  final ValueChanged<double> onProgress;
  final VoidCallback onDismissed;
  final VoidCallback onSwipeUp;

  /// Fired one [kDoubleTapTimeout] after a tap that turned out to be single —
  /// see the class doc on why it can't be immediate.
  final VoidCallback onTap;

  @override
  State<DismissiblePhoto> createState() => _DismissiblePhotoState();
}

class _DismissiblePhotoState extends State<DismissiblePhoto>
    with TickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _dismiss = AnimationController(
    vsync: this,
    duration: AppMotion.long,
  )..addListener(() => widget.onProgress(_dismiss.value));

  /// Drives the double-tap zoom. Created unconditionally (never a `late final`
  /// only read from a conditional branch — a controller first touched in
  /// `dispose()` throws while creating its ticker).
  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: AppMotion.short,
  )..addListener(_applyZoomFrame);
  Animation<Matrix4>? _zoomAnimation;

  bool _zoomed = false;

  Offset? _pointerStart;
  int? _activePointer;
  bool? _verticalIntent; // null = undecided; true/false once slop clears.
  // Signed vertical travel of the current drag. Kept separately from
  // _dismiss.value, which clamps at 0 and so can't tell "at rest" from
  // "dragged upward".
  double _totalDy = 0;
  VelocityTracker? _velocityTracker;
  Duration _pointerDownTime = Duration.zero;
  // Read once per drag (didChangeDependencies), not per pointer-move event
  // or per animation frame — MediaQuery.sizeOf is cheap but there's no
  // reason to pay it dozens of times over one gesture.
  double _screenHeight = 0;

  // Tap tracking. _pendingTap holds the chrome toggle for kDoubleTapTimeout so
  // a second tap can claim the gesture instead; _withinDoubleTapWindow records
  // whether this touch landed while that timer was still running, since
  // arriving at all is what cancels it.
  Offset? _lastTapPosition;
  Timer? _pendingTap;
  bool _withinDoubleTapWindow = false;

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
    _pendingTap?.cancel();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _dismiss.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    // A pending single tap is stale the moment a new touch lands: it either
    // becomes the second half of a double-tap, or it becomes a drag. Either
    // way the deferred chrome toggle must not fire underneath it.
    _withinDoubleTapWindow = _pendingTap?.isActive ?? false;
    _pendingTap?.cancel();
    _pendingTap = null;
    _zoom.stop();
    // The tap path stays open while zoomed — a double-tap is how you get back
    // to fit — but the drag path does not: at scale > 1 a one-finger move is a
    // pan for [InteractiveViewer], not a dismiss.
    _activePointer = event.pointer;
    _pointerStart = event.position;
    _pointerDownTime = event.timeStamp;
    _verticalIntent = null;
    _totalDy = 0;
    if (_zoomed) return;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
    _dismiss.stop();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerStart == null) return;
    if (_velocityTracker == null) return; // zoomed: pan belongs to the viewer
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
    final travel = _pointerStart == null
        ? null
        : event.position - _pointerStart!;
    final elapsed = event.timeStamp - _pointerDownTime;
    _activePointer = null;
    _pointerStart = null;
    _verticalIntent = null;
    _totalDy = 0;
    _velocityTracker = null;

    // A release that never picked an axis, barely moved and was brief is a
    // tap — the one gesture the axis lock has nothing to say about.
    if (!wasVertical &&
        travel != null &&
        travel.distance <= kTouchSlop &&
        elapsed <= kLongPressTimeout) {
      _resolveTap(event.position);
      return;
    }
    // Anything else — a drag, a long hold, a horizontal swipe — breaks a
    // double-tap in progress, so the half-finished pair is discarded rather
    // than left to pair up with whatever taps next.
    _lastTapPosition = null;
    _withinDoubleTapWindow = false;
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

  /// Decides whether the tap that just ended at [globalPosition] is the second
  /// half of a double-tap, or a single tap whose effect has to wait one
  /// [kDoubleTapTimeout] to find out.
  void _resolveTap(Offset globalPosition) {
    final previous = _lastTapPosition;
    _lastTapPosition = null;
    if (_withinDoubleTapWindow &&
        previous != null &&
        (globalPosition - previous).distance <= kDoubleTapSlop) {
      _withinDoubleTapWindow = false;
      _handleDoubleTap(globalPosition);
      return;
    }
    _lastTapPosition = globalPosition;
    _pendingTap = Timer(kDoubleTapTimeout, () {
      _pendingTap = null;
      _lastTapPosition = null;
      widget.onTap();
    });
  }

  /// Zooms to [kDoubleTapZoomScale] about the tapped point, or back to fit if
  /// the photo is already zoomed by any amount (pinch included) — "the second
  /// double-tap always gets you back" is the rule worth being predictable
  /// about. Videos have no [InteractiveViewer] and so no transform to drive;
  /// they deliberately do nothing rather than falling through to a chrome
  /// toggle, which would make the play/pause target ambiguous.
  void _handleDoubleTap(Offset globalPosition) {
    if (widget.isVideo) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // This box is co-extensive with the InteractiveViewer whenever
    // _dismiss.value is 0, which a tap guarantees (a drag would have set
    // _verticalIntent and never reached here).
    final local = box.globalToLocal(globalPosition);
    final target = _zoomed
        ? Matrix4.identity()
        : zoomedAt(local.dx, local.dy, scale: kDoubleTapZoomScale);
    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoom, curve: AppMotion.curve));
    _zoom
      ..duration = AppMotion.of(context, AppMotion.short)
      ..forward(from: 0);
  }

  /// Writes one frame of the double-tap zoom into the shared
  /// [TransformationController]. That in turn fires [_onTransformChanged], so
  /// the drag gate tracks the zoom for free.
  void _applyZoomFrame() {
    final animation = _zoomAnimation;
    if (animation != null) _transformController.value = animation.value;
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
