import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart' show AppDatabase;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/folder_list.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<DeviceFolder> folders, {
    double textScale = 1,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              // FolderList is a sliver (it builds lazily so a 30-folder device
              // does not build every chip up front), so it hosts in a
              // CustomScrollView, matching how AlbumsScreen mounts it.
              child: CustomScrollView(
                slivers: [FolderList(folders: folders)],
              ),
            ),
          ),
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

  /// A folder chip: a `surface2` pill (StadiumBorder) with a folder icon, name,
  /// and compact count.
  bool isFolderTile(Widget w) {
    if (w is! GestureDetector) return false;
    final child = w.child;
    if (child is! Container) return false;
    final decoration = child.decoration;
    return decoration is ShapeDecoration && decoration.shape is StadiumBorder;
  }

  Finder tileAt(int i) => find.byWidgetPredicate(isFolderTile).at(i);

  testWidgets('renders nothing at all for no folders', (tester) async {
    await pump(tester, const []);
    expect(find.byWidgetPredicate(isFolderTile), findsNothing);
    // A sliver has no box size to measure, so assert the extent it contributes
    // to its viewport instead. It needs `skipOffstage: false` to be found at
    // all: a viewport reports a zero-extent sliver as offstage, which is itself
    // the thing being asserted.
    expect(
      tester
          .renderObject<RenderSliver>(
            find.byType(FolderList, skipOffstage: false),
          )
          .geometry!
          .scrollExtent,
      0,
    );
    await settle(tester);
  });

  testWidgets('gives each folder its own chip, with a compact count', (
    tester,
  ) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 1204),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 318),
      DeviceFolder(id: 'one', name: 'Scans', count: 1),
    ]);
    expect(find.byWidgetPredicate(isFolderTile), findsNWidgets(3));
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    expect(find.text('Scans'), findsOneWidget);
    // compactCount: 1204 -> '1.2k', 318 -> '318', 1 -> '1'.
    expect(find.text('1.2k'), findsOneWidget);
    expect(find.text('318'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('lays folders out two to a row', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 8),
      DeviceFolder(id: 'scans', name: 'Scans', count: 3),
    ]);

    final first = tester.getRect(find.text('Camera'));
    final second = tester.getRect(find.text('Screenshots'));
    final third = tester.getRect(find.text('Scans'));

    // Side by side...
    expect(second.top, first.top);
    expect(second.left, greaterThan(first.left));
    // ...and the third wraps onto the next row, under the first.
    expect(third.top, greaterThan(first.top));
    expect(third.left, first.left);
    await settle(tester);
  });

  testWidgets('folder chip has no cover photo', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12, coverAssetId: 'a1'),
      DeviceFolder(id: 'shots', name: 'Screenshots', count: 8),
    ]);

    // The coverAssetId is deliberately ignored; no image widget appears.
    expect(find.byType(Image), findsNothing);
    await settle(tester);
  });

  testWidgets('folder chip draws a surface2 rounded rectangle', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ]);

    final tile = tester.getRect(tileAt(0));
    final icon = tester.getRect(find.byIcon(Icons.folder_rounded));
    final name = tester.getRect(find.text('Camera'));
    final count = tester.getRect(find.text('12'));

    // Icon on the left, name to its right, count at the end.
    expect(icon.right, lessThanOrEqualTo(name.left));
    expect(count.left, greaterThan(name.left));
    // Everything stays inside the chip.
    for (final r in [icon, name, count]) {
      expect(tile.contains(r.topLeft), isTrue);
      expect(tile.contains(r.bottomRight), isTrue);
    }
    await settle(tester);
  });

  testWidgets('count stays on the same row as the folder name', (tester) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ]);

    final name = tester.getRect(find.text('Camera'));
    final count = tester.getRect(find.text('12'));

    expect(count.top, greaterThanOrEqualTo(name.top - 1));
    expect(count.bottom, lessThanOrEqualTo(name.bottom + 1));
    await settle(tester);
  });

  testWidgets('a large text scale grows the chip instead of squashing it', (
    tester,
  ) async {
    await pump(tester, const [
      DeviceFolder(id: 'cam', name: 'Camera', count: 12),
    ], textScale: 3);

    expect(tester.getSize(tileAt(0)).height, greaterThan(40));
    expect(tester.takeException(), isNull); // no RenderFlex overflow
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
