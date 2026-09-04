import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/app_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );

  InkWell inkWell(WidgetTester tester) => tester.widget<InkWell>(
    find.descendant(of: find.byType(AppButton), matching: find.byType(InkWell)),
  );

  group('AppButton.primary', () {
    testWidgets('fires its callback when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton.primary(label: 'Continue', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed disables the tap target', (tester) async {
      await tester.pumpWidget(
        host(const AppButton.primary(label: 'Continue', onPressed: null)),
      );
      expect(inkWell(tester).onTap, isNull);
    });

    testWidgets('busy swaps the label for a spinner', (tester) async {
      await tester.pumpWidget(
        host(
          const AppButton.primary(
            label: 'Continue',
            onPressed: null,
            busy: true,
          ),
        ),
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('compact drops the height to the 40 app-bar metric', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AppButton.primary(label: 'Done', onPressed: () {}, compact: true)),
      );
      expect(tester.getSize(find.byType(SizedBox).first).height, 40);
    });

    testWidgets('the default height is 52', (tester) async {
      await tester.pumpWidget(
        host(AppButton.primary(label: 'Done', onPressed: () {})),
      );
      expect(tester.getSize(find.byType(SizedBox).first).height, 52);
    });

    testWidgets('expand stretches the pill to the available width', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 300,
            child: AppButton.primary(
              label: 'Done',
              onPressed: () {},
              expand: true,
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppButton)).width, 300);
    });

    testWidgets('renders a leading icon when given one', (tester) async {
      await tester.pumpWidget(
        host(
          AppButton.primary(
            label: 'Add',
            onPressed: () {},
            icon: Icons.add_rounded,
          ),
        ),
      );
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('AppButton.secondary', () {
    testWidgets('fires its callback when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton.secondary(label: 'New album', onPressed: () => taps++)),
      );
      await tester.tap(find.text('New album'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed disables the tap target', (tester) async {
      await tester.pumpWidget(
        host(const AppButton.secondary(label: 'New album', onPressed: null)),
      );
      expect(inkWell(tester).onTap, isNull);
    });

    testWidgets('renders a leading icon when given one', (tester) async {
      await tester.pumpWidget(
        host(
          AppButton.secondary(
            label: 'New album',
            onPressed: () {},
            icon: Icons.add_rounded,
          ),
        ),
      );
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('sits at the 40 quiet-surface metric', (tester) async {
      await tester.pumpWidget(
        host(AppButton.secondary(label: 'New album', onPressed: () {})),
      );
      expect(tester.getSize(find.byType(SizedBox).first).height, 40);
    });
  });

  group('AppButton.quiet', () {
    testWidgets('fires its callback when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton.quiet(label: 'View all 12', onPressed: () => taps++)),
      );
      await tester.tap(find.text('View all 12'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed disables the tap target', (tester) async {
      await tester.pumpWidget(
        host(const AppButton.quiet(label: 'View all 12', onPressed: null)),
      );
      expect(inkWell(tester).onTap, isNull);
    });

    testWidgets('shows a trailing chevron only when asked', (tester) async {
      await tester.pumpWidget(
        host(AppButton.quiet(label: 'See all', onPressed: () {})),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await tester.pumpWidget(
        host(
          AppButton.quiet(label: 'See all', onPressed: () {}, chevron: true),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
