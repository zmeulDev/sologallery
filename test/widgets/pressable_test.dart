import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/widgets/pressable.dart';

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

  testWidgets('forwards tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        Pressable(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    await tester.tap(find.byType(Pressable));
    // Bounded pumps: let the pressed scale spring back (110ms token).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
  });

  testWidgets('forwards long-press', (tester) async {
    var longPresses = 0;
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        Pressable(
          onTap: () => taps++,
          onLongPress: () => longPresses++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    await tester.longPress(find.byType(Pressable));
    await tester.pump(const Duration(milliseconds: 200));
    expect(longPresses, 1);
    expect(taps, 0);
  });

  testWidgets('scales down while the pointer is held', (tester) async {
    await tester.pumpWidget(
      wrap(
        Pressable(onTap: () {}, child: const SizedBox(width: 100, height: 100)),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.97,
    );
    await gesture.up();
    await tester.pump();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.0,
    );
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('reduced motion zeroes the duration and still forwards tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        Pressable(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 100),
        ),
        disableAnimations: true,
      ),
    );
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
      Duration.zero,
    );
    await tester.tap(find.byType(Pressable));
    await tester.pump();
    expect(taps, 1);
  });
}
