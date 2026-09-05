import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/filter_pill.dart';

void main() {
  Widget host({
    required ThemeData theme,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: FilterPill(
            label: 'All',
            selected: selected,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  Material material(WidgetTester tester) => tester.widget<Material>(
    find.descendant(
      of: find.byType(FilterPill),
      matching: find.byType(Material),
    ),
  );

  TextStyle textStyle(WidgetTester tester) =>
      tester.widget<Text>(find.text('All')).style!;

  for (final theme in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    group('in ${theme.key} theme', () {
      final colors = theme.value.extension<AppColors>()!;

      testWidgets(
        'selected shows a transparent fill with an accent border and label',
        (tester) async {
          await tester.pumpWidget(host(theme: theme.value, selected: true));

          final fill = material(tester).color;
          expect(fill, Colors.transparent);

          final shape = material(tester).shape! as StadiumBorder;
          expect(shape.side.color, colors.accent);

          final style = textStyle(tester);
          expect(style.color, colors.accentText);
          expect(style.fontWeight, FontWeight.w700);
        },
      );

      testWidgets(
        'unselected keeps the quiet recessed surface and hairline border',
        (tester) async {
          await tester.pumpWidget(host(theme: theme.value, selected: false));

          expect(material(tester).color, colors.surface2);

          final shape = material(tester).shape! as StadiumBorder;
          expect(shape.side.color, colors.border);

          final style = textStyle(tester);
          expect(style.color, colors.textSecondary);
          expect(style.fontWeight, FontWeight.w400);
        },
      );
    });
  }

  testWidgets('reports a tap on the label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(theme: AppTheme.light, selected: false, onTap: () => taps++),
    );
    await tester.tap(find.text('All'));
    expect(taps, 1);
  });
}
