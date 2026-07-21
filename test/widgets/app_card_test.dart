import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/app_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('wraps a single child', (tester) async {
    await tester.pumpWidget(host(const AppCard(child: Text('note'))));
    expect(find.text('note'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('divides stacked rows with one hairline between each', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const AppCard.divided(
          children: [Text('one'), Text('two'), Text('three')],
        ),
      ),
    );
    // Three rows, two dividers — never a leading or trailing rule.
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('a single divided row gets no divider', (tester) async {
    await tester.pumpWidget(
      host(const AppCard.divided(children: [Text('only')])),
    );
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('carries the card radius and clips its children', (tester) async {
    await tester.pumpWidget(host(const AppCard(child: Text('note'))));
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, AppRadius.br12);
    expect(decoration.border, isNotNull);
    expect(container.clipBehavior, Clip.antiAlias);
  });
}
