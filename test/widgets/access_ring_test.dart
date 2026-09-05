import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/onboarding/widgets/access_ring.dart';

void main() {
  testWidgets('paints with the theme accent color', (tester) async {
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: AccessRing(diameter: 100)),
        ),
      );
      // A real Scaffold/Material paints with its own CustomPaint nodes too, so
      // find.byType(CustomPaint) is ambiguous here — same fix as
      // indexing_dial_test.dart's `arcFraction` helper: filter by painter
      // type instead of asserting a single CustomPaint in the whole tree.
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<AccessRingPainter>()
          .single;
      final colors = Theme.of(tester.element(find.byType(AccessRing)))
          .extension<AppColors>()!;
      expect(painter.color, colors.accent, reason: name);
    }
  });

  testWidgets('is static — no pending ticker/animation after settling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AccessRing(diameter: 100)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
