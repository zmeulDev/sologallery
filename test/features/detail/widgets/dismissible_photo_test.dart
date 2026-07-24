import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/domain/zoom_transform.dart';
import 'package:sologallery/features/detail/widgets/dismissible_photo.dart';
import 'package:sologallery/features/detail/widgets/photo_page.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../../../support/fake_photo_library_service.dart';

void main() {
  // Default 800x600 test surface — 30% dismiss threshold is 180px down.
  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onDismissed,
    VoidCallback? onSwipeUp,
    VoidCallback? onTap,
    bool isVideo = false,
  }) {
    final fake = FakePhotoLibraryService();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          detailImageProvider.overrideWith((ref, id) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: DismissiblePhoto(
              assetId: 'a1',
              isVideo: isVideo,
              onDismissed: onDismissed ?? () {},
              onSwipeUp: onSwipeUp ?? () {},
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  /// A single down/up at [at] (defaults to the widget's centre) with no
  /// intervening move, which is what makes it read as a tap rather than a
  /// zero-distance drag. Raw pointers, not `tester.tap`, so the down and up
  /// stay separate events — the coalescing kind has hidden gesture bugs in
  /// this widget before.
  Future<void> tapAt(WidgetTester tester, [Offset? at]) async {
    final gesture = await tester.startGesture(
      at ?? tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.up();
    await tester.pump();
  }

  /// The live zoom/pan matrix the widget hands down to [PhotoPage].
  Matrix4 transformOf(WidgetTester tester) {
    final page = tester.widget<PhotoPage>(find.byType(PhotoPage));
    return page.transformController!.value;
  }

  testWidgets('a small drag below the threshold does not dismiss', (
    tester,
  ) async {
    var dismissed = false;
    await pump(tester, onDismissed: () => dismissed = true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 60)); // well under the 180px/30% mark
    await tester.pump();
    await gesture.up();
    // The photo never visually moves and there is no spring-back animation,
    // so a sub-threshold release leaves it at rest — no pump needed to settle.
    expect(dismissed, isFalse);
  });

  testWidgets('a drag past the threshold dismisses immediately, with no exit '
      'animation to wait out', (tester) async {
    var dismissed = false;
    await pump(tester, onDismissed: () => dismissed = true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 250)); // past the 180px/30% mark
    await gesture.up();

    // No pump at all: onDismissed fires synchronously from the pointer-up
    // handler. The photo never visually moved, so there is no separate
    // shrink-to-nothing animation to finish before popping — the route's own
    // (instant) pop transition is the only motion.
    expect(dismissed, isTrue);
  });

  // The 600px-tall test surface puts the swipe-up threshold at 90px (15%).
  // `moveBy` stamps every event at the same instant, so the velocity tracker
  // reports zero — these exercise the distance path deliberately, leaving the
  // fling path (velocity < -300) to the on-device pass.
  testWidgets('an upward drag past the threshold opens the details sheet', (
    tester,
  ) async {
    var swipedUp = false;
    var dismissed = false;
    await pump(
      tester,
      onDismissed: () => dismissed = true,
      onSwipeUp: () => swipedUp = true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, -150)); // past the 90px/15% mark
    await tester.pump();
    await gesture.up();
    expect(swipedUp, isTrue);
    expect(dismissed, isFalse);
  });

  testWidgets('a short upward drag opens nothing', (tester) async {
    var swipedUp = false;
    await pump(tester, onSwipeUp: () => swipedUp = true);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, -40)); // under the 90px/15% mark
    await gesture.up();
    expect(swipedUp, isFalse);
  });

  testWidgets('a downward drag dismisses without opening the sheet', (
    tester,
  ) async {
    var swipedUp = false;
    var dismissed = false;
    await pump(
      tester,
      onDismissed: () => dismissed = true,
      onSwipeUp: () => swipedUp = true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 250));
    await gesture.up();
    expect(dismissed, isTrue);
    expect(swipedUp, isFalse);
  });

  testWidgets('a horizontal drag opens nothing — the axis lock defers to the '
      'PageView', (tester) async {
    var swipedUp = false;
    var dismissed = false;
    await pump(
      tester,
      onDismissed: () => dismissed = true,
      onSwipeUp: () => swipedUp = true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    // Dominant-axis horizontal, but with enough vertical drift to clear slop
    // on its own had the lock not resolved to horizontal first.
    await gesture.moveBy(const Offset(-200, -120));
    await gesture.up();
    expect(swipedUp, isFalse);
    expect(dismissed, isFalse);
  });

  // ---- Taps -------------------------------------------------------------
  //
  // Tap and double-tap are resolved from the same raw pointer stream as the
  // drags above rather than by a GestureDetector, so these have to prove both
  // that the tap path works *and* that it left the drag paths alone.

  void expectMatrix(Matrix4 actual, Matrix4 expected) {
    for (var i = 0; i < 16; i++) {
      expect(
        actual.storage[i],
        closeTo(expected.storage[i], 1e-6),
        reason: 'matrix entry $i',
      );
    }
  }

  testWidgets('a single tap toggles the chrome once the double-tap window '
      'closes', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);

    await tapAt(tester);
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
    expect(taps, 1);
  });

  testWidgets('a single tap does nothing until the double-tap window closes', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);

    await tapAt(tester);
    // Deliberate: the first tap of a possible pair cannot be acted on yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(taps, 0);

    await tester.pump(kDoubleTapTimeout);
    expect(taps, 1);
  });

  testWidgets('a double tap zooms to the tapped point and never toggles the '
      'chrome', (tester) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    expectMatrix(transformOf(tester), Matrix4.identity());

    final at = tester.getCenter(find.byType(DismissiblePhoto));
    await tapAt(tester, at);
    await tapAt(tester, at);
    // The zoom is an instant transform write, so the target matrix is in
    // place on the next frame — no travel to pump out.
    await tester.pump();

    // The widget fills the surface from the origin, so its local coordinates
    // are the global ones.
    expectMatrix(
      transformOf(tester),
      zoomedAt(at.dx, at.dy, scale: kDoubleTapZoomScale),
    );

    // The pending single tap was claimed by the second tap, so the chrome
    // never toggled — waiting out the window must not resurrect it.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
    expect(taps, 0);
  });

  testWidgets('a second double tap returns to fit', (tester) async {
    await pump(tester);
    final at = tester.getCenter(find.byType(DismissiblePhoto));

    await tapAt(tester, at);
    await tapAt(tester, at);
    await tester.pump();
    expect(transformOf(tester), isNot(Matrix4.identity()));

    // Deliberately a different point: the rule is "the second double-tap
    // always gets you back", not "back only if you tap where you zoomed".
    final elsewhere = at + const Offset(60, -40);
    await tapAt(tester, elsewhere);
    await tapAt(tester, elsewhere);
    await tester.pump();
    expectMatrix(transformOf(tester), Matrix4.identity());
  });

  testWidgets('two taps far apart are two single taps, not a double tap', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    final at = tester.getCenter(find.byType(DismissiblePhoto));

    await tapAt(tester, at);
    await tapAt(tester, at + const Offset(kDoubleTapSlop + 20, 0));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

    expectMatrix(transformOf(tester), Matrix4.identity());
    // The first tap's toggle was dropped when the second touch landed; the
    // second one stands on its own.
    expect(taps, 1);
  });

  testWidgets('a double tap on a video does nothing at all', (tester) async {
    var taps = 0;
    // Video pages have no InteractiveViewer to drive, and falling through to a
    // chrome toggle would make the play/pause target ambiguous.
    await pump(tester, isVideo: true, onTap: () => taps++);

    final at = tester.getCenter(find.byType(DismissiblePhoto));
    await tapAt(tester, at);
    await tapAt(tester, at);
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 200));

    expect(taps, 0);
    expect(find.byType(PhotoPage), findsNothing);
  });

  testWidgets('a drag cancels a pending single tap', (tester) async {
    var taps = 0;
    var dismissed = false;
    await pump(tester, onTap: () => taps++, onDismissed: () => dismissed = true);

    await tapAt(tester);
    // Second touch inside the window, but it turns into a drag rather than a
    // tap — the deferred toggle must not fire underneath it.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 250));
    await gesture.up();
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

    expect(dismissed, isTrue);
    expect(taps, 0);
  });

  testWidgets('a tap, a drag and a tap do not pair up into a double tap', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    final at = tester.getCenter(find.byType(DismissiblePhoto));

    await tapAt(tester, at);
    final gesture = await tester.startGesture(at);
    await gesture.moveBy(const Offset(-200, -120)); // horizontal: no-op drag
    await gesture.up();
    await tester.pump();
    await tapAt(tester, at);
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));

    expectMatrix(transformOf(tester), Matrix4.identity());
    expect(taps, 1); // only the last tap survived
  });

  testWidgets('a pending single tap is cancelled when the tree goes away', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    await tapAt(tester);

    // Disposing inside the window: the timer must be cancelled, or the
    // "a Timer is still pending" teardown invariant fails and the callback
    // reaches an unmounted widget.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(taps, 0);
  });
}