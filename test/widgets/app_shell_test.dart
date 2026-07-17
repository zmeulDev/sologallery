import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    // Grant access so the router redirect lands on the Library, not onboarding.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: const SoloGalleryApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('boots to the Library tab', (tester) async {
    await pumpApp(tester);
    // App-bar title of the initial (Library) branch.
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
  });

  testWidgets('renders all four nav destinations', (tester) async {
    await pumpApp(tester);
    for (final label in ['Library', 'Saved', 'Albums', 'Settings']) {
      // Each destination exposes a semantic label via Tooltip/Semantics.
      expect(find.byTooltip(label), findsOneWidget);
    }
  });

  testWidgets('tapping a destination switches branches', (tester) async {
    await pumpApp(tester);
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);

    await tester.tap(find.byTooltip('Albums'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Albums'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Library'), findsNothing);
  });
}
