import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/circle_icon_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('fires its callback when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        CircleIconButton.overMedia(
          icon: Icons.favorite_rounded,
          tooltip: 'Favorite',
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(CircleIconButton));
    expect(taps, 1);
  });

  testWidgets('is a named button for accessibility', (tester) async {
    await tester.pumpWidget(
      host(
        CircleIconButton.surface(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onPressed: () {},
        ),
      ),
    );
    // Icon-only, so the tooltip is the only name it has — it must reach both
    // the tooltip and the semantics tree.
    expect(find.byTooltip('Settings'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(of: find.byType(Tooltip), matching: find.byType(Semantics))
          .first,
    );
    expect(semantics.properties.label, 'Settings');
    expect(semantics.properties.button, isTrue);
  });

  testWidgets('the over-media variant paints a scrim disc, not a themed one', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CircleIconButton.overMedia(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () {},
        ),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(CircleIconButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, AppOverMedia.scrim);
    expect(material.shape, isA<CircleBorder>());
  });

  testWidgets('the surface variant follows the theme instead', (tester) async {
    await tester.pumpWidget(
      host(
        CircleIconButton.surface(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onPressed: () {},
        ),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(CircleIconButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, AppColors.light.surface2);
  });

  testWidgets('sizes the glyph to the disc', (tester) async {
    await tester.pumpWidget(
      host(
        CircleIconButton.overMedia(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          onPressed: () {},
          size: 60,
        ),
      ),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, 30);
    expect(tester.getSize(find.byType(CircleIconButton)), const Size(60, 60));
  });
}
