import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/widgets/dismissible_photo.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../../../support/fake_photo_library_service.dart';

void main() {
  // Default 800x600 test surface — 30% dismiss threshold is 180px down.
  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<double>? onProgress,
    VoidCallback? onDismissed,
    bool disableAnimations = false,
  }) {
    final fake = FakePhotoLibraryService();
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider.overrideWithValue(fake),
          detailImageProvider.overrideWith((ref, id) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          // Applied *inside* MaterialApp's own MediaQuery (via builder), not
          // wrapped around it — an ancestor MediaQuery here would be the one
          // the app tree resolves, and MediaQueryData's default `size` is
          // Size.zero, breaking the drag's screen-height-relative math.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: DismissiblePhoto(
              assetId: 'a1',
              isVideo: false,
              onProgress: onProgress ?? (_) {},
              onDismissed: onDismissed ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a small drag reports progress then springs back', (
    tester,
  ) async {
    var dismissed = false;
    var lastProgress = 0.0;
    await pump(
      tester,
      onProgress: (p) => lastProgress = p,
      onDismissed: () => dismissed = true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 60)); // well under the 180px/30% mark
    await tester.pump();
    expect(lastProgress, greaterThan(0));
    expect(lastProgress, lessThan(0.3));
    expect(dismissed, isFalse);

    await gesture.up();
    // Spring-back animates over AppMotion.long (450ms) — bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(lastProgress, 0);
    expect(dismissed, isFalse);
  });

  testWidgets(
    'a drag past the threshold dismisses immediately, with no exit '
    'animation to wait out',
    (tester) async {
      var dismissed = false;
      await pump(tester, onDismissed: () => dismissed = true);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(DismissiblePhoto)),
      );
      await gesture.moveBy(const Offset(0, 250)); // past the 180px/30% mark
      await gesture.up();

      // No pump at all: onDismissed fires synchronously from the pointer-up
      // handler — it hands off to the route's own Hero return-flight rather
      // than finishing a separate shrink-to-nothing animation and popping
      // only once *that* completes (the two-stage version of this read as
      // a black flash followed by a second, disconnected animation).
      expect(dismissed, isTrue);
    },
  );

  testWidgets('reduced motion springs back instantly, without animating', (
    tester,
  ) async {
    var lastProgress = 0.0;
    await pump(
      tester,
      onProgress: (p) => lastProgress = p,
      disableAnimations: true,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DismissiblePhoto)),
    );
    await gesture.moveBy(const Offset(0, 60)); // under the dismiss threshold
    await tester.pump();
    expect(lastProgress, greaterThan(0));

    await gesture.up();
    // A single pump is enough — the spring-back duration resolved to zero.
    await tester.pump();
    expect(lastProgress, 0);
  });
}
