import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/detail/widgets/dismissible_photo.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

/// On-device: the grid→detail open and drag-to-dismiss gesture. A host widget
/// test already covers [DismissiblePhoto]'s threshold/axis contract in
/// isolation (test/features/detail/widgets/dismissible_photo_test.dart) —
/// that test caught a real bug (the gesture's element tree changed shape
/// mid-drag, silently killing the recognizer before release), but never
/// exercised the real `Navigator.maybePop()` (its `onDismissed` was a plain
/// flag), nor a real [InteractiveViewer] (its `detailImageProvider` was
/// stubbed to null bytes). This is the paired real-device check of both,
/// under actual touch input (AGENTS.md "fake-pairing rule").
///
/// Decorative motion was removed app-wide (Part 1): the open is a hard cut
/// (no Hero flight) and the drag no longer visually tracks the finger — it
/// pops the instant the threshold is crossed on release. So this asserts the
/// route pops back to the grid, not any in-flight opacity.
///
/// Run with: `patrol test -t integration_test/hero_dismiss_test.dart`.
void main() {
  patrolTest('tap opens detail; drag down past the threshold dismisses', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Continue'), findsOneWidget);
    await $('Continue').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    await $('Continue').tap();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);

    // Open the first photo. With route transitions removed (Part 1 A1) this
    // is a hard cut, no Hero flight.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    expect($(DismissiblePhoto), findsOneWidget);

    // Drag well past the dismiss threshold. A manual startGesture/moveBy/up
    // sequence, not the one-shot `tester.drag` helper — the same technique
    // the paired host test uses, verified against the real gesture arena
    // (InteractiveViewer + PageView both present here, stubbed out there).
    final gesture = await $.tester.startGesture(
      $.tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 300));
    await $.tester.pump();
    await gesture.moveBy(const Offset(0, 300));
    await $.tester.pump();
    await gesture.up();

    // onDismissed fires synchronously from the pointer-up handler; the route
    // has no transition (NoTransitionPage — instant pop).
    await $.tester.pump();
    await $.tester.pump(const Duration(milliseconds: 100));

    // Back on the Library grid, not the detail viewer.
    expect($(DismissiblePhoto), findsNothing);
    expect($('Library'), findsWidgets);
  });
}