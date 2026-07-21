import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/segmented_control.dart';

void main() {
  Widget host({
    required ThemeMode value,
    required ValueChanged<ThemeMode> onChanged,
    List<ThemeMode>? options,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SegmentedControl<ThemeMode>(
            options: options ?? ThemeMode.values,
            value: value,
            labelBuilder: (m) => m.name,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('renders one label per option', (tester) async {
    await tester.pumpWidget(host(value: ThemeMode.system, onChanged: (_) {}));
    expect(find.text('system'), findsOneWidget);
    expect(find.text('light'), findsOneWidget);
    expect(find.text('dark'), findsOneWidget);
  });

  testWidgets('reports the tapped option', (tester) async {
    ThemeMode? picked;
    await tester.pumpWidget(
      host(value: ThemeMode.system, onChanged: (m) => picked = m),
    );
    await tester.tap(find.text('dark'));
    expect(picked, ThemeMode.dark);
  });

  testWidgets('a tap anywhere in a segment counts, not just on the glyphs', (
    tester,
  ) async {
    ThemeMode? picked;
    await tester.pumpWidget(
      host(value: ThemeMode.system, onChanged: (m) => picked = m),
    );
    // The far edge of the last segment — inside its box, well clear of the
    // centered label.
    final box = tester.getRect(find.byType(SegmentedControl<ThemeMode>));
    await tester.tapAt(Offset(box.right - 6, box.center.dy));
    expect(picked, ThemeMode.dark);
  });

  testWidgets('marks only the selected segment as selected for a11y', (
    tester,
  ) async {
    await tester.pumpWidget(host(value: ThemeMode.light, onChanged: (_) {}));
    final selected = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.selected == true);
    expect(selected.length, 1);
  });

  testWidgets(
    'a value outside the options renders without a thumb, not a crash',
    (tester) async {
      // Guards the transient mismatch a settings screen can hit mid-load.
      await tester.pumpWidget(
        host(
          value: ThemeMode.dark,
          onChanged: (_) {},
          options: const [ThemeMode.system, ThemeMode.light],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('system'), findsOneWidget);
    },
  );
}
