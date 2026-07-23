import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../domain/zoom_transform.dart';
import 'detail_stage.dart';

/// Wraps one detail page with an interactive drag-down-to-dismiss gesture:
/// a downward drag past a threshold (or a fast-enough flick) pops the route
/// immediately on release. The photo no longer visually tracks the finger —
/// decorative motion was removed app-wide (Part 1) — so a sub-threshold
/// release leaves it exactly where it was, with nothing to spring back from.
/// The gesture itself, its threshold, its velocity check and its axis lock
/// all stay; only the visual output is gone.
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
/// gesture disambiguation, not motion, so it stays put regardless of any
/// reduced-motion setting.
class DismissiblePhoto extends StatefulWidget {
  const DismissiblePhoto({
    super.key,
    required this.assetId,
    required this.isVideo,
    required this.onDismissed,
    required this.onSwipeUp,
    required this.onTap,
  });

  final String assetId;
  final bool isVideo;
  final VoidCallback onDismissed;
  final VoidCallback onSwipeUp;

  /// Fired one [kDoubleTapTimeout] after a tap that turned out to be single —
  /// see the class doc on why it can't be immediate.
  final VoidCallback onTap;

  @override
  State<DismissiblePhoto> createState() => _DismissiblePhotoState();
}

class _DismissiblePhotoState extends State<DismissiblePhoto> {
  final _transformController = TransformationController();

  bool _zoomed = false;

  Offset? _pointerStart;
  int? _activePointer;
  bool? _verticalIntent; // null = undecided; true/false once slop clears.
  // Signed vertical travel of the current drag. Kept separately from
  // _progress, which clamps at 0 and so can't tell "at rest" from
  // "dragged upward".
  double _totalDy = 0;
  // 0 (settled) → 1 (dismissed). Purely the threshold the release handler
  // tests — there is no visual output and no listener on the drag path, so
  // dragging does no frame work at all until release.
  double _progress = 0;
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
    // The tap path stays open while zoomed — a double-tap is how you get back
    // to fit — but the drag path does not: at scale > 1 a one-finger move is a
    // pan for [InteractiveViewer], not a dismiss.
    _activePointer = event.pointer;
    _pointerStart = event.position;
    _pointerDownTime = event.timeStamp;
    _verticalIntent = null;
    _totalDy = 0;
    _progress = 0;
    if (_zoomed) return;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
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
    // Only downward drag counts toward dismiss; an upward one clamps at 0
    // and is resolved on release as a details-sheet swipe.
    _progress = (total.dy / _screenHeight).clamp(0.0, 1.0);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    final wasVertical = _verticalIntent == true;
    final velocity = _velocityTracker?.getVelocity().pixelsPerSecond.dy ?? 0.0;
    final totalDy = _totalDy;
    final progress = _progress;
    final travel = _pointerStart == null
        ? null
        : event.position - _pointerStart!;
    final elapsed = event.timeStamp - _pointerDownTime;
    _activePointer = null;
    _pointerStart = null;
    _verticalIntent = null;
    _totalDy = 0;
    _progress = 0;
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

    // Upward: nothing was displaced (_progress stayed clamped at 0), so this
    // resolves purely from the gesture — a flick, or a deliberate drag past
    // a fraction of the screen.
    if (totalDy < 0) {
      if (velocity < -300 || totalDy < -_screenHeight * 0.15) {
        widget.onSwipeUp();
      }
      return;
    }

    final shouldDismiss = progress > 0.3 || velocity > 800;
    if (shouldDismiss) {
      // Pop immediately. The photo never visually moved, so there is no
      // separate exit animation to finish first — handing off to the route's
      // own pop transition (instant, NoTransitionPage) is exactly one motion.
      widget.onDismissed();
    }
    // Sub-threshold release: nothing to animate back. The photo was never
    // displaced, so it is already at rest.
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
  ///
  /// The zoom is an instant transform write — the 150 ms travel is gone with
  /// the rest of the decorative motion — so the photo snaps to the tapped
  /// point on the second tap of the pair. Writing the [TransformationController]
  /// fires [_onTransformChanged], so the drag gate tracks the zoom for free.
  void _handleDoubleTap(Offset globalPosition) {
    if (widget.isVideo) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // This box is co-extensive with the InteractiveViewer whenever
    // _progress is 0, which a tap guarantees (a drag would have set
    // _verticalIntent and never reached here).
    final local = box.globalToLocal(globalPosition);
    final target = _zoomed
        ? Matrix4.identity()
        : zoomedAt(local.dx, local.dy, scale: kDoubleTapZoomScale);
    _transformController.value = target;
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
      // Opaque so the stage is hit-testable across its full bounds even when
      // the page underneath paints nothing there — the broken-image fallback
      // (`_Unavailable`) is a 44 px icon centred on the stage, and the
      // default `deferToChild` would let taps off that icon fall through to
      // nothing, so the drag/tap gesture never saw them. A real photo's
      // `Image.memory(width/height: double.infinity)` already fills the stage,
      // so this only changes the error/empty path — and makes tap-to-toggle
      // chrome work on a missing image too.
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: RepaintBoundary(child: stage),
    );
  }
}