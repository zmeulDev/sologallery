import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/widgets/nav_pill_bar.dart';

void main() {
  /// Wraps the bar the way the shell does — bottom of a Scaffold whose body is
  /// extended under it.
  Widget host(int currentIndex, ValueChanged<int> onTap,
      {bool reduced = false, Widget? trailing}) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: NavPillBar(
            currentIndex: currentIndex,
            onTap: onTap,
            trailing: trailing,
          ),
        ),
      ),
    );
  }

  /// The capsule is the bar's only `ShapeDecoration`.
  Rect capsuleRect(WidgetTester tester) => tester.getRect(
        find.descendant(
          of: find.byType(NavPillBar),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is ShapeDecoration,
          ),
        ),
      );

  /// The knob is the only circular `Container` in the bar.
  Rect knobRect(WidgetTester tester) {
    final knob = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    );
    expect(knob, findsOneWidget);
    return tester.getRect(knob);
  }

  testWidgets('reports the tapped destination index', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(host(0, taps.add));
    await tester.pump(const Duration(milliseconds: 500));

    for (final label in ['Library', 'Search', 'Saved', 'Albums']) {
      await tester.tap(find.byTooltip(label));
      await tester.pump();
    }

    expect(taps, [0, 1, 2, 3]);
  });

  testWidgets('the knob sits over the active destination', (tester) async {
    await tester.pumpWidget(host(0, (_) {}));
    await tester.pump(const Duration(milliseconds: 500));
    final first = knobRect(tester);

    await tester.pumpWidget(host(3, (_) {}));
    await tester.pump(const Duration(milliseconds: 500));
    final last = knobRect(tester);

    expect(last.left, greaterThan(first.left));
    expect(first.width, first.height); // circular, not squashed

    // The capsule hugs its four slots, so the outer knobs clear its ends by the
    // same inset they clear its top and bottom by — no dead ink at the ends.
    final capsule = tester.getRect(
      find.descendant(
        of: find.byType(NavPillBar),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is ShapeDecoration,
        ),
      ),
    );
    final endInset = first.left - capsule.left;
    expect(endInset, closeTo(first.top - capsule.top, 0.01));
    expect(capsule.right - last.right, closeTo(endInset, 0.01));
  });

  // Regression: an expanding `Center` made the bar claim the whole screen, so
  // the capsule floated in the middle of it and the body got a screen-sized
  // bottom inset. The bar must be exactly as tall as it looks.
  testWidgets('the bar sizes to the capsule, above the safe-area inset', (
    tester,
  ) async {
    const systemInset = 24.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: systemInset),
            viewPadding: EdgeInsets.only(bottom: systemInset),
          ),
          child: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: NavPillBar(currentIndex: 0, onTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final bar = tester.getRect(find.byType(NavPillBar));
    final screen = tester.getSize(find.byType(MaterialApp));
    // Capsule (60) + its s12 bottom margin + the system inset — nothing more.
    expect(bar.height, 60 + AppSpace.s12 + systemInset);
    expect(bar.bottom, screen.height);

    // The capsule itself clears the system inset rather than sitting in it.
    final capsule = tester.getRect(
      find.descendant(
        of: find.byType(NavPillBar),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is ShapeDecoration,
        ),
      ),
    );
    expect(screen.height - capsule.bottom, AppSpace.s12 + systemInset);
  });

  // The indexing dial rides here. It must not cost the bar any height (the
  // body's bottom inset is the bar's height), must not move the capsule, and
  // must clear it on the narrowest phone we target.
  testWidgets('a trailing companion sits right of the centred capsule', (
    tester,
  ) async {
    const trailing = SizedBox.square(dimension: 44, key: ValueKey('dial'));
    // 360 logical px — the narrowest of the target devices.
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(0, (_) {}));
    await tester.pump(const Duration(milliseconds: 500));
    final bare = tester.getRect(find.byType(NavPillBar));
    final bareCapsule = capsuleRect(tester);

    await tester.pumpWidget(host(0, (_) {}, trailing: trailing));
    await tester.pump(const Duration(milliseconds: 500));

    // The capsule stays exactly where it was — no destination shifts under the
    // thumb when a pass starts, which is why the dial is beside it, not in it.
    expect(capsuleRect(tester), bareCapsule);
    expect(tester.getRect(find.byType(NavPillBar)), bare);

    final dial = tester.getRect(find.byKey(const ValueKey('dial')));
    expect(dial.left, greaterThan(bareCapsule.right)); // clears the capsule
    expect(dial.right, 360 - AppSpace.s12);
    expect(dial.center.dy, closeTo(bareCapsule.center.dy, 0.01));
  });

  testWidgets('reduced motion lands the knob with no animation', (tester) async {
    await tester.pumpWidget(host(0, (_) {}, reduced: true));
    await tester.pump(const Duration(milliseconds: 500));
    final settled = knobRect(tester);

    // Rebuild at a new index and read the knob on the very next frame: with
    // animations disabled there is no travel to wait out.
    await tester.pumpWidget(host(2, (_) {}, reduced: true));
    await tester.pump();
    final moved = knobRect(tester);

    expect(moved.left, greaterThan(settled.left));
    await tester.pump(const Duration(milliseconds: 500));
    expect(knobRect(tester).left, moved.left);
  });
}
