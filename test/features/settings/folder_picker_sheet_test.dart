import 'dart:async' show Completer;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/settings/widgets/folder_picker_sheet.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Set<String> initialExcluded,
    List<DeviceFolder> folders = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(folders: folders),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await FolderPickerSheet.show(
                  context,
                  initialExcluded: initialExcluded,
                );
                // Capture the result in the navigator key for assertions.
                Navigator.of(context).pop(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists folders and initial exclusions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSheet(
      tester,
      initialExcluded: {'f2'},
      folders: [
        const DeviceFolder(id: 'f1', name: 'Camera', count: 10),
        const DeviceFolder(id: 'f2', name: 'Screenshots', count: 5),
      ],
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('FOLDERS TO ANALYZE'), findsOneWidget);
    expect(find.text('All folders'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Dismiss so tear-down is clean.
    await tester.tap(find.text('Done'));
    await tester.pump();
  });

  testWidgets('tapping All folders clears exclusions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSheet(
      tester,
      initialExcluded: {'f1'},
      folders: [
        const DeviceFolder(id: 'f1', name: 'Camera', count: 10),
      ],
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('All folders'));
    await tester.pump();

    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).every((c) => c.value == true),
      isTrue,
    );

    await tester.tap(find.text('Done'));
    await tester.pump();
  });

  testWidgets('returns the selected exclusion set', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final completer = Completer<Set<String>?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(
              folders: [
                const DeviceFolder(id: 'f1', name: 'Camera', count: 10),
                const DeviceFolder(id: 'f2', name: 'Screenshots', count: 5),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                completer.complete(
                  await FolderPickerSheet.show(
                    context,
                    initialExcluded: const {},
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Uncheck Screenshots to exclude it.
    await tester.tap(find.text('Screenshots'));
    await tester.pump();

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(await completer.future, {'f2'});
  });

}
