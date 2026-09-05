import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/onboarding/widgets/access_step.dart';
import 'package:sologallery/services/photo_library_service.dart';

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
      });
    }
  }
}
