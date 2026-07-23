import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/settings/analysis_settings_screen.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/app_card.dart';
import 'package:sologallery/widgets/consent_switch.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    List<DeviceFolder> folders = const [],
    Map<String, List<AssetRef>> folderAssetsById = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(
              folders: folders,
              folderAssetsById: folderAssetsById,
            ),
          ),
          indexingStatusProvider.overrideWithValue(
            const AsyncData(IndexingStatus.idle()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AnalysisSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders all three sections', (tester) async {
    await pump(tester);

    for (final label in const [
      'ON-DEVICE ANALYSIS',
      'INDEX',
      'FOLDERS FOR INDEXING',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Content search'), findsOneWidget);
    expect(find.text('Memories'), findsOneWidget);
    expect(find.text('Face detection'), findsOneWidget);
    expect(find.text('Rebuild index'), findsOneWidget);
    expect(find.text('Folders to analyze'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('each consent toggle gets its own card', (tester) async {
    await pump(tester);

    // Three separate cards, not one divided block: these are independent
    // grants, and a single stack reads as something you accept wholesale.
    final consentCards = find.ancestor(
      of: find.byType(ConsentSwitch),
      matching: find.byType(AppCard),
    );
    expect(consentCards, findsNWidgets(3));

    await disposeTree(tester);
  });

  testWidgets('every toggle starts off', (tester) async {
    await pump(tester);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(3));
    expect(switches.every((s) => s.value == false), isTrue);

    await disposeTree(tester);
  });

  testWidgets('toggling Content search on persists the choice', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 100));

    expect(await db.settingsDao.readSearchEnabled(), isTrue);
    expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
    expect(await db.settingsDao.readFacesEnabled(), isFalse);

    await disposeTree(tester);
  });

  testWidgets('folder row shows summary from excluded set', (tester) async {
    await db.settingsDao.setExcludedFolderIds({'f1'});
    await pump(
      tester,
      folders: [
        const DeviceFolder(id: 'f1', name: 'Camera', count: 10),
        const DeviceFolder(id: 'f2', name: 'Screenshots', count: 5),
      ],
    );

    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('1 of 2 folders'), findsOneWidget);

    await disposeTree(tester);
  });

  testWidgets('folder row shows All folders when nothing is excluded', (
    tester,
  ) async {
    await pump(
      tester,
      folders: [
        const DeviceFolder(id: 'f1', name: 'Camera', count: 10),
      ],
    );

    expect(find.text('All folders'), findsOneWidget);

    await disposeTree(tester);
  });
}
