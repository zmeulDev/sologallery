import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/widgets/entrance_fade.dart';

void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );
  }

  Opacity findOpacity() => find
      .ancestor(
        of: find.byType(SizedBox),
        matching: find.byType(Opacity),
      )
      .evaluate()
      .first
      .widget as Opacity;

  testWidgets('index 0 is visible on the first frame, no delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const EntranceFade(
          index: 0,
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );
    expect(findOpacity().opacity, 1);
  });

  testWidgets('a staggered index starts hidden and reveals after its delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const EntranceFade(
          index: 1,
          child: SizedBox(width: 40, height: 40),
        ),
      ),
    );
    // AppMotion.stagger * 1 = 40ms — not yet elapsed.
    expect(findOpacity().opacity, 0);

    await tester.pump(const Duration(milliseconds: 50));
    // Reveal scheduled; still mid-flight through AppMotion.medium (180ms).
    await tester.pump(const Duration(milliseconds: 50));
    final midFlight = findOpacity().opacity;
    expect(midFlight, greaterThan(0));
    expect(midFlight, lessThan(1));

    await tester.pump(const Duration(milliseconds: 200));
    expect(findOpacity().opacity, 1);
  });

  testWidgets('reduced motion renders a staggered index visible immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const EntranceFade(
          index: 5,
          child: SizedBox(width: 40, height: 40),
        ),
        disableAnimations: true,
      ),
    );
    expect(findOpacity().opacity, 1);
  });

  testWidgets('never replays on a rebuild after the reveal', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EntranceFade(
          index: 0,
          child: SizedBox(key: Key('a'), width: 40, height: 40),
        ),
      ),
    );
    expect(findOpacity().opacity, 1);

    // Rebuild with a new child (simulates the section staying mounted while
    // its data changes) — must stay visible, not flash back to 0.
    await tester.pumpWidget(
      wrap(
        const EntranceFade(
          index: 0,
          child: SizedBox(key: Key('b'), width: 40, height: 40),
        ),
      ),
    );
    expect(findOpacity().opacity, 1);
  });
}
