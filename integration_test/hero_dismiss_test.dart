import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/detail/widgets/dismissible_photo.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

/// On-device: the grid→detail Hero flight and drag-to-dismiss gesture, the
/// UI Wow-Factor pass's signature interaction
/// (docs/plans/ui-wow-factor.md). A host widget test already covers
/// [DismissiblePhoto]'s drag-progress/threshold contract in isolation
/// (test/features/detail/widgets/dismissible_photo_test.dart) — that test
/// caught a real bug (the gesture's element tree changed shape mid-drag,
/// silently killing the recognizer before release), but never exercised the
/// real `Navigator.maybePop()` (its `onDismissed` was a plain flag), nor a
/// real [InteractiveViewer] (its `detailImageProvider` was stubbed to null
/// bytes). This is the paired real-device check of both, under actual touch
/// input (CLAUDE.md "fake-pairing rule").
///
/// Run with: `patrol test -t integration_test/hero_dismiss_test.dart`.
void main() {
  patrolTest('tap opens with a Hero flight; drag down dismisses', ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Allow photo access'), findsOneWidget);
    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    await $('Continue').tap();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);

    // Open the first photo — the Hero flight from its grid cell.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    expect($(DismissiblePhoto), findsOneWidget);

    Opacity currentOpacity() => $.tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byType(DismissiblePhoto),
            matching: find.byType(Opacity),
          ),
        )
        .first;
    expect(currentOpacity().opacity, 1, reason: 'opacity before any drag');

    // Drag well past the dismiss threshold. A manual startGesture/moveBy/up
    // sequence, not the one-shot `tester.drag` helper — the same technique
    // the paired host test uses, verified against the real gesture arena
    // (InteractiveViewer + PageView both present here, stubbed out there).
    final gesture = await $.tester.startGesture(
      $.tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 300));
    await $.tester.pump();
    expect(
      currentOpacity().opacity,
      lessThan(1),
      reason: 'opacity should drop once a 300px vertical drag is tracked',
    );
    await gesture.moveBy(const Offset(0, 300));
    await $.tester.pump();
    await gesture.up();

    // onDismissed fires synchronously from the pointer-up handler. The route
    // has no transition (NoTransitionPage — instant pop), so a single pump is
    // enough; the extra wait is harmless.
    await $.tester.pump();
    await $.tester.pump(const Duration(milliseconds: 500));

    // Back on the Library grid, not the detail viewer.
    expect($(DismissiblePhoto), findsNothing);
    expect($('Library'), findsWidgets);
  });
}
