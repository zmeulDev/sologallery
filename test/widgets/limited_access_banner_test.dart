import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';

void main() {
  Widget host({VoidCallback? onSelectMore, ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(
        body: LimitedAccessBanner(onSelectMore: onSelectMore ?? () {}),
      ),
    );
  }

  testWidgets('shows the explanation and the CTA', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('You\'re showing selected photos only.'), findsOneWidget);
    expect(find.text('Select more'), findsOneWidget);
  });

  testWidgets('tapping the CTA invokes onSelectMore', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(onSelectMore: () => tapped = true));
    await tester.tap(find.text('Select more'));
    expect(tapped, isTrue);
  });

  testWidgets('the CTA label uses the emphasis weight', (tester) async {
    await tester.pumpWidget(host());
    final richText = tester.widget<RichText>(
      find.descendant(
        of: find.text('Select more'),
        matching: find.byType(RichText),
      ),
    );
    expect(richText.text.style?.fontWeight, FontWeight.w700);
  });
}
