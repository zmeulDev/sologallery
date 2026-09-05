import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/onboarding/widgets/access_ring.dart';
import 'package:sologallery/features/onboarding/widgets/access_step.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/app_button.dart';

void main() {
  // Emulator/simulator resize wasn't available non-interactively in this
  // session (only one bootable iOS simulator instance, not a small/large
  // pair) — see task-1-report.md. This substitutes an automated check for
  // "does the Stack + off-screen-bleeding AccessRing break at extreme
  // widths"; it can't confirm the ring *looks* right relative to the
  // headline, only that nothing throws/overflows. A human/device pass for
  // that visual judgment call is still owed, same non-blocking backlog
  // pattern as Phases 1-3.
  Future<void> pumpAt(
    WidgetTester tester, {
    required Size physicalSize,
    required bool denied,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccessStep(
          access: denied ? PhotoAccess.denied : PhotoAccess.granted,
          attempted: denied,
          busy: false,
          onRequestAccess: () {},
          onOpenSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ~375dp-wide small phone (iPhone SE class).
  const smallWidth = Size(750, 1600);
  // ~860dp-wide tablet/large-phone class.
  const largeWidth = Size(1720, 2400);

  for (final (sizeName, size) in [
    ('small width', smallWidth),
    ('large width', largeWidth),
  ]) {
    for (final (variant, denied) in [
      ('first-run copy', false),
      ('denied copy', true),
    ]) {
      testWidgets('$variant renders without error at $sizeName', (
        tester,
      ) async {
        await pumpAt(tester, physicalSize: size, denied: denied);

        expect(tester.takeException(), isNull);
        expect(find.byType(AccessStep), findsOneWidget);

        // The actual wiring under test: the poster ring is mounted, and it's
        // genuinely an AccessRing (Task 0's painter), not just an
        // incidentally-matching widget type.
        expect(find.byType(AccessRing), findsOneWidget);
        final customPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(AccessRing),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(customPaint.painter, isA<AccessRingPainter>());
      });
    }
  }

  // Headline/CTA copy and callback branching. `AccessStep` takes raw
  // `VoidCallback`s (no Riverpod/service layer, unlike `OnboardingScreen`),
  // so recorded-callback bools are the simplest way to verify which one a
  // tap invokes.
  Future<void> pumpAccessStep(
    WidgetTester tester, {
    required PhotoAccess access,
    required bool attempted,
    required bool busy,
    required VoidCallback onRequestAccess,
    required VoidCallback onOpenSettings,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccessStep(
          access: access,
          attempted: attempted,
          busy: busy,
          onRequestAccess: onRequestAccess,
          onOpenSettings: onOpenSettings,
        ),
      ),
    );
    // `busy: true` shows an indefinitely-animating `CircularProgressIndicator`
    // (see `AppButton`), which never settles — `pumpAndSettle` would time out.
    if (busy) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('first-run: headline, CTA label and tap invoke onRequestAccess', (
    tester,
  ) async {
    var requested = false;
    var openedSettings = false;

    await pumpAccessStep(
      tester,
      access: PhotoAccess.notDetermined,
      attempted: false,
      busy: false,
      onRequestAccess: () => requested = true,
      onOpenSettings: () => openedSettings = true,
    );

    expect(find.text('Your photos\nstay yours.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(AccessRing), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(openedSettings, isFalse);
  });

  testWidgets('denied: headline, CTA label and tap invoke onOpenSettings', (
    tester,
  ) async {
    var requested = false;
    var openedSettings = false;

    await pumpAccessStep(
      tester,
      access: PhotoAccess.denied,
      attempted: true,
      busy: false,
      onRequestAccess: () => requested = true,
      onOpenSettings: () => openedSettings = true,
    );

    expect(find.text('Photo access is\nturned off.'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.byType(AccessRing), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(openedSettings, isTrue);
    expect(requested, isFalse);
  });

  for (final (variant, access, attempted) in [
    ('first-run', PhotoAccess.notDetermined, false),
    ('denied', PhotoAccess.denied, true),
  ]) {
    testWidgets('$variant: busy disables the CTA, invoking neither callback', (
      tester,
    ) async {
      var requested = false;
      var openedSettings = false;

      await pumpAccessStep(
        tester,
        access: access,
        attempted: attempted,
        busy: true,
        onRequestAccess: () => requested = true,
        onOpenSettings: () => openedSettings = true,
      );

      expect(find.byType(AccessRing), findsOneWidget);

      // Busy swaps the label for a spinner (see `AppButton`), so there's no
      // label text to tap through — hit the button's own widget instead.
      await tester.tap(find.byType(AppButton));
      // Not pumpAndSettle: the busy spinner animates indefinitely.
      await tester.pump();

      expect(requested, isFalse);
      expect(openedSettings, isFalse);
    });
  }
}
