import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/widgets/photo_page.dart';
import 'package:sologallery/features/memories/widgets/ken_burns_photo.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String assetId,
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Skip the real image decode — same pattern as detail_screen_test.
          detailImageProvider.overrideWith((ref, id) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: KenBurnsPhoto(
              assetId: assetId,
              duration: const Duration(seconds: 3),
            ),
          ),
        ),
      ),
    );
  }

  // Scoped to KenBurnsPhoto's own subtree — Scaffold/Material internals also
  // use Transform widgets elsewhere in the tree.
  Finder ownTransform() =>
      find.descendant(of: find.byType(KenBurnsPhoto), matching: find.byType(Transform));

  testWidgets('drifts the scale up over its duration', (tester) async {
    await pump(tester, assetId: 'a1');
    await tester.pump();
    final atStart =
        tester.widgetList<Transform>(ownTransform()).first.transform.getMaxScaleOnAxis();
    expect(atStart, closeTo(1, 0.001));

    await tester.pump(const Duration(seconds: 3));
    final atEnd =
        tester.widgetList<Transform>(ownTransform()).first.transform.getMaxScaleOnAxis();
    expect(atEnd, closeTo(1.08, 0.001));

    expect(find.byType(PhotoPage), findsOneWidget);
  });

  testWidgets('reduced motion renders the photo statically, no Transform', (
    tester,
  ) async {
    await pump(tester, assetId: 'a1', disableAnimations: true);
    await tester.pump();

    expect(find.byType(PhotoPage), findsOneWidget);
    expect(ownTransform(), findsNothing);
    // Waiting out the (never-started) duration must not throw, and the
    // teardown dispose must not either — the whole point of this test.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('restarts the drift when reused for a different asset', (
    tester,
  ) async {
    await pump(tester, assetId: 'a1');
    await tester.pump(const Duration(seconds: 3));
    final beforeSwap =
        tester.widgetList<Transform>(ownTransform()).first.transform.getMaxScaleOnAxis();
    expect(beforeSwap, closeTo(1.08, 0.001));

    await pump(tester, assetId: 'a2');
    await tester.pump();
    final afterSwap =
        tester.widgetList<Transform>(ownTransform()).first.transform.getMaxScaleOnAxis();
    expect(afterSwap, closeTo(1, 0.001));
  });
}
