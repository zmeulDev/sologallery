import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart' show AppDatabase;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/app_card.dart';
import 'package:sologallery/widgets/folder_list.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<DeviceFolder> folders) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: FolderList(folders: folders)),
        ),
        GoRoute(
          path: '/folder',
          builder: (_, state) => Scaffold(
            body: Text('folder-detail:${state.uri.queryParameters['id']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders nothing at all for no folders', (tester) async {
    await pump(tester, const []);
    expect(find.byType(AppCard), findsNothing);
    await settle(tester);
  });

  testWidgets('gives each folder its own card, with its count', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 1204),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 318),
      DeviceFolder(id: 'one', name: 'Scans', count: 1),
    ]);
    expect(find.byType(AppCard), findsNWidgets(3));
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('1204 photos'), findsOneWidget);
    expect(find.text('318 photos'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget); // singular, not "1 photos"
    await settle(tester);
  });

  testWidgets('a standalone card row shows it is a destination', (
    tester,
  ) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ]);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await settle(tester);
  });

  testWidgets('tapping a folder opens its detail grid', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ]);
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('folder-detail:cam'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a folder id needing escaping still routes correctly', (
    tester,
  ) async {
    // iOS folder ids are PHAssetCollection local identifiers and contain "/",
    // which is why the route carries them as a query parameter.
    await pump(tester, const [
      DeviceFolder(id: 'ABC123/L0/040', name: 'Recents', count: 5),
    ]);
    await tester.tap(find.text('Recents'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('folder-detail:ABC123/L0/040'), findsOneWidget);
    await settle(tester);
  });
}
