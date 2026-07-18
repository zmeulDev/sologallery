import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/saved/saved_providers.dart';
import 'package:sologallery/features/saved/saved_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // Drift's stream store schedules a zero-duration timer on dispose; settle it.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty state invites favoriting', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('No favorites yet'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('renders a grid cell per favorite', (tester) async {
    await db.favoritesDao.add('a1', at: DateTime(2024, 1, 2));
    await db.favoritesDao.add('a2', at: DateTime(2024, 1, 1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(AssetThumbnail), findsNWidgets(2));
    await teardownTree(tester);
  });

  testWidgets('error state shows a message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
          // Inject the error AsyncValue directly — deterministic, and avoids the
          // fake-async stream-delivery quirk in widget tests.
          savedFavoritesProvider.overrideWithValue(
            AsyncError<List<Favorite>>(Exception('boom'), StackTrace.empty),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SavedScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Couldn\'t load your favorites'), findsOneWidget);
    await teardownTree(tester);
  });
}
