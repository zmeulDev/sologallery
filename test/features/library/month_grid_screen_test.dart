import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/library/month_grid_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    String monthKey, {
    List<AssetRef> assets = const [],
  }) async {
    final fake = FakePhotoLibraryService(
      access: PhotoAccess.granted,
      assets: assets,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MonthGridScreen(monthKey: monthKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the month title and a grid of assets', (tester) async {
    await pump(tester, '2026-08', assets: assetsInMonth(2026, 8, 10));
    expect(find.widgetWithText(AppBar, 'August 2026'), findsOneWidget);
    // GridView is lazy — assert the visible rows built (not all 10).
    expect(find.byType(AssetThumbnail), findsAtLeastNWidgets(6));
  });

  testWidgets('empty month shows a note', (tester) async {
    await pump(tester, '2026-08');
    expect(find.text('No photos in this month.'), findsOneWidget);
  });

  testWidgets('invalid key shows a not-found note', (tester) async {
    await pump(tester, 'not-a-month');
    expect(find.text('That month couldn\'t be found.'), findsOneWidget);
  });
}
