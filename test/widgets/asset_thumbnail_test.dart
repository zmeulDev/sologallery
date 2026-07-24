import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  // The fake returns null thumbnail bytes → the recessed placeholder; the badge
  // overlay is what's under test. 'v' is a 1:05 video, 'p' a still.
  Future<void> pump(WidgetTester tester, String id, {required bool badge}) {
    final fake = FakePhotoLibraryService(
      videoDurations: {'v': const Duration(minutes: 1, seconds: 5)},
    );
    return tester.pumpWidget(
      ProviderScope(
        overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: AssetThumbnail(assetId: id, showVideoBadge: badge),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bounded pumps, not pumpAndSettle: the thumbnail future resolves on the
  // pump after subscribe, so give it one frame and a little headroom before
  // asserting on the resolved content.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('shows a duration badge for a video', (tester) async {
    await pump(tester, 'v', badge: true);
    await settle(tester);
    expect(find.byType(DurationBadge), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('no badge for a still', (tester) async {
    await pump(tester, 'p', badge: true);
    await settle(tester);
    expect(find.byType(DurationBadge), findsNothing);
  });

  testWidgets('no badge when the flag is off, even for a video', (tester) async {
    await pump(tester, 'v', badge: false);
    await settle(tester);
    expect(find.byType(DurationBadge), findsNothing);
  });
}
