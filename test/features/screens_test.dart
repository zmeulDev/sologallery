import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/albums_screen.dart';
import 'package:sologallery/features/library/library_screen.dart';
import 'package:sologallery/features/saved/saved_screen.dart';
import 'package:sologallery/features/settings/settings_screen.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
          // Mark the cache ready so LibraryScreen renders its grid branch and
          // never instantiates the real ML worker via the indexing service.
          libraryCacheReadyProvider.overrideWithValue(const AsyncData(true)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    // Bounded pump, not pumpAndSettle: the Saved/Albums loading spinner animates
    // forever, and these tests only assert the app-bar title.
    await tester.pump();
  }

  // Dispose the tree and elapse time so the Drift stream store's zero-duration
  // dispose timer fires before the pending-timer invariant runs (gotcha #2).
  // Must be in the test body: addTearDown runs after that invariant is checked.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('LibraryScreen shows title and an (inert) search action',
      (tester) async {
    await pumpScreen(tester, const LibraryScreen());
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    // LibraryScreen now holds Drift .watch() streams (month counts / older).
    await disposeTree(tester);
  });

  testWidgets('SavedScreen shows its title', (tester) async {
    await pumpScreen(tester, const SavedScreen());
    expect(find.widgetWithText(AppBar, 'Saved'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('AlbumsScreen shows its title', (tester) async {
    await pumpScreen(tester, const AlbumsScreen());
    expect(find.widgetWithText(AppBar, 'Albums'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('SettingsScreen shows its title', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });
}
