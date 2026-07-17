import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/albums_screen.dart';
import 'package:sologallery/features/library/library_screen.dart';
import 'package:sologallery/features/saved/saved_screen.dart';
import 'package:sologallery/features/settings/settings_screen.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('LibraryScreen shows title and an (inert) search action',
      (tester) async {
    await pumpScreen(tester, const LibraryScreen());
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('SavedScreen shows its title', (tester) async {
    await pumpScreen(tester, const SavedScreen());
    expect(find.widgetWithText(AppBar, 'Saved'), findsOneWidget);
  });

  testWidgets('AlbumsScreen shows its title', (tester) async {
    await pumpScreen(tester, const AlbumsScreen());
    expect(find.widgetWithText(AppBar, 'Albums'), findsOneWidget);
  });

  testWidgets('SettingsScreen shows its title', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });
}
