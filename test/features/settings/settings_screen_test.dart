import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/settings/settings_providers.dart';
import 'package:sologallery/features/settings/settings_screen.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedCache() async {
    await db.indexDao.upsertMetadata([
      for (var i = 0; i < 4; i++)
        (
          id: 'p$i',
          createdAt: DateTime(2026, 8, i + 1),
          isVideo: i == 0, // one video
          width: 1,
          height: 1,
          isDated: true,
        ),
    ]);
  }

  Future<void> pump(
    WidgetTester tester, {
    PhotoAccess access = PhotoAccess.granted,
  }) async {
    // Tall surface so every section of the scrolling list is laid out (the
    // ListView builds lazily; About sits below an 800px fold otherwise).
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(access: access),
          ),
          indexingStatusProvider.overrideWithValue(
            const AsyncData(IndexingStatus.idle()),
          ),
          appVersionProvider.overrideWith((ref) async => '1.0.0 (1)'),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    // Live Drift streams + async permission refresh — bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders every section', (tester) async {
    await seedCache();
    await pump(tester);

    for (final label in const [
      'PHOTO ACCESS',
      'LIBRARY',
      'ANALYSIS',
      'APPEARANCE',
      'ABOUT',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 4 assets − 1 video
    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('1.0.0 (1)'), findsOneWidget);
    // Theme picker segments.
    for (final t in const ['System', 'Light', 'Dark']) {
      expect(find.text(t), findsOneWidget);
    }

    await disposeTree(tester);
  });

  testWidgets('tapping a theme segment persists the choice', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final row = await db.select(db.appSettings).getSingleOrNull();
    expect(row?.value, 'dark');

    await disposeTree(tester);
  });

  testWidgets('limited-access actions show only when access is limited', (
    tester,
  ) async {
    await pump(tester, access: PhotoAccess.limited);
    expect(find.text('Limited access'), findsOneWidget);
    expect(find.text('Select more photos'), findsOneWidget);
    expect(find.text('Open system settings'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('full access hides the manage actions', (tester) async {
    await pump(tester, access: PhotoAccess.granted);
    expect(find.text('Full access'), findsOneWidget);
    expect(find.text('Select more photos'), findsNothing);
    expect(find.text('Open system settings'), findsNothing);
    await disposeTree(tester);
  });
}
