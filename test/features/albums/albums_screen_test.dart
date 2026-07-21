import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/albums_dao.dart'
    show AlbumSummary;
import 'package:sologallery/core/database/daos/faces_dao.dart'
    show PersonSummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/albums/albums_providers.dart';
import 'package:sologallery/features/albums/albums_screen.dart';
import 'package:sologallery/features/albums/widgets/album_card.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/settings/consent_provider.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart'
    show DeviceFolder;

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pump(
    WidgetTester tester, {
    List<DeviceFolder> folders = const [],
    List<PersonSummary> people = const [],
    bool facesEnabled = false,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(folders: folders),
          ),
          facesEnabledProvider.overrideWith(
            (ref) => Stream.value(facesEnabled),
          ),
          personSummariesProvider.overrideWith((ref) => Stream.value(people)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AlbumsScreen()),
      ),
    );
  }

  // A TextField (create dialog) breaks pumpAndSettle; a Drift stream schedules a
  // dispose timer — settle both by disposing the tree and elapsing time.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty state invites creating an album', (tester) async {
    await pump(tester);
    await tester.pump();
    expect(find.text('No albums yet'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('error state shows a message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
          // Inject the error AsyncValue directly (see saved_screen_test).
          albumSummariesProvider.overrideWithValue(
            AsyncError<List<AlbumSummary>>(Exception('boom'), StackTrace.empty),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AlbumsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Couldn\'t load your albums'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('renders a card per album with its count', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip');
    await db.albumsDao.addEntry(id, 'a1');
    await pump(tester);
    await tester.pump();
    expect(find.byType(AlbumCard), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('create-album dialog adds an album', (tester) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump(); // dialog in (TextField now on screen — bounded pumps)
    await tester.enterText(find.byType(TextField), 'Beach');
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pump(); // dialog out, create runs
    await tester.pump(const Duration(milliseconds: 100)); // stream emits

    expect(find.text('Beach'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('long-press then confirm deletes an album', (tester) async {
    await db.albumsDao.createAlbum('Trip');
    await pump(tester);
    await tester.pump();
    expect(find.text('Trip'), findsOneWidget);

    await tester.longPress(find.text('Trip'));
    await tester.pump(); // confirm dialog
    expect(find.text('Delete "Trip"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Trip'), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('folders scroll below the albums grid', (tester) async {
    final id = await db.albumsDao.createAlbum('Trip');
    await db.albumsDao.addEntry(id, 'a1');
    await pump(
      tester,
      folders: const [DeviceFolder(id: 'cam', name: 'Camera', count: 42)],
    );
    await tester.pump();

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('DEVICE FOLDERS'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('People shows when faces are on and a cluster exists', (
    tester,
  ) async {
    await db.albumsDao.createAlbum('Trip');
    await pump(
      tester,
      facesEnabled: true,
      people: const [
        PersonSummary(
          id: 1,
          displayName: null,
          coverAssetId: null,
          faceCount: 8,
        ),
      ],
    );
    await tester.pump();

    expect(find.text('PEOPLE'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('People is hidden when face detection is off', (tester) async {
    await db.albumsDao.createAlbum('Trip');
    // Clusters exist in the provider, but the faces flag gates them out.
    await pump(
      tester,
      facesEnabled: false,
      people: const [
        PersonSummary(
          id: 1,
          displayName: null,
          coverAssetId: null,
          faceCount: 8,
        ),
      ],
    );
    await tester.pump();

    expect(find.text('PEOPLE'), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('a compact note stands in for an empty albums grid', (
    tester,
  ) async {
    // No albums, but a folder carries the screen — the full-screen empty state
    // must yield to the sectioned body with a compact note.
    await pump(
      tester,
      folders: const [DeviceFolder(id: 'cam', name: 'Camera', count: 42)],
    );
    await tester.pump();

    expect(find.text('No albums yet — tap + to make one.'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    // The full-screen empty-state title is not used here.
    expect(find.text('No albums yet'), findsNothing);
    await teardownTree(tester);
  });
}
