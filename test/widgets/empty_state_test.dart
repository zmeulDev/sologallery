import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/empty_state.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders the title', (tester) async {
    await tester.pumpWidget(host(const EmptyState(title: 'Nothing here')));
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('the title uses the emphasis weight', (tester) async {
    await tester.pumpWidget(host(const EmptyState(title: 'Nothing here')));
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.text('Nothing here'),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.text.style?.fontWeight, FontWeight.w700);
  });
}
