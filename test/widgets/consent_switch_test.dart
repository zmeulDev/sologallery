import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/consent_switch.dart';

void main() {
  Widget host({
    required ThemeData theme,
  }) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: ConsentSwitch(
            value: true,
            onChanged: (_) {},
            semanticLabel: 'Test consent switch',
          ),
        ),
      ),
    );
  }

  testWidgets('active track color is accent in light theme', (tester) async {
    await tester.pumpWidget(host(theme: AppTheme.light));

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    final colors = AppColors.light;

    expect(switchWidget.activeTrackColor, colors.accent);
  });

  testWidgets('active track color is accent in dark theme', (tester) async {
    await tester.pumpWidget(host(theme: AppTheme.dark));

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    final colors = AppColors.dark;

    expect(switchWidget.activeTrackColor, colors.accent);
  });

  testWidgets('active thumb color is theme-invariant white in light theme', (
    tester,
  ) async {
    await tester.pumpWidget(host(theme: AppTheme.light));

    final switchWidget = tester.widget<Switch>(find.byType(Switch));

    expect(switchWidget.activeThumbColor, Colors.white);
  });

  testWidgets('active thumb color is theme-invariant white in dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(host(theme: AppTheme.dark));

    final switchWidget = tester.widget<Switch>(find.byType(Switch));

    expect(switchWidget.activeThumbColor, Colors.white);
  });
}
