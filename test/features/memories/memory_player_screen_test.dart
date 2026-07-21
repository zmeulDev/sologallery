import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/memories_dao.dart'
    show MemorySummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/widgets/photo_page.dart';
import 'package:sologallery/features/memories/memories_providers.dart';
import 'package:sologallery/features/memories/memory_player_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  const memoryId = 5;

  late AppDatabase db;

  // Opening a memory marks it seen, which hits the database — without this
  // override the widget test would spin up a real on-disk connection.
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  List<AssetRef> assets(int n) => [
    for (var i = 0; i < n; i++)
      AssetRef(id: 'a$i', createdAt: DateTime(2025, 6, 1 + i)),
  ];

  /// The player runs on a repeating timer and shows a spinner while loading, so
  /// every pump here is bounded — `pumpAndSettle` would never return.
  Future<void> pump(
    WidgetTester tester, {
    int photos = 3,
    String? cover = 'a0',
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
          memoriesProvider.overrideWithValue(
            AsyncData([
              MemorySummary(
                id: memoryId,
                kind: 'trip',
                title: 'Early June',
                subtitle: '2025',
                coverAssetId: cover,
                assetCount: 3,
              ),
            ]),
          ),
          memoryAssetsProvider(
            memoryId,
          ).overrideWith((ref) async => assets(photos)),
        ],
        // The player reads AppTextStyles off the theme, so the app must carry
        // one — a bare MaterialApp has no theme extensions.
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MemoryPlayerScreen(memoryId: memoryId),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('opens on the title card, over the cover photo', (tester) async {
    await pump(tester);

    expect(find.text('Early June'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
    // The cover carries the frame — a text-only title card reads as a blank
    // screen, which is exactly what it looked like on device.
    expect(find.byType(AssetThumbnail), findsOneWidget);
    // The first photo page is built but the title card is what's shown.
    expect(find.byType(PhotoPage), findsNothing);
  });

  testWidgets('falls back to the first photo when there is no cover', (
    tester,
  ) async {
    await pump(tester, cover: null);

    expect(
      find.byType(AssetThumbnail),
      findsOneWidget,
      reason: 'the title card must never be a bare black frame',
    );
  });

  testWidgets('advances to the first photo on its own', (tester) async {
    await pump(tester);

    await tester.pump(MemoryPlayerScreen.pageDuration);
    await tester.pump(const Duration(milliseconds: 400)); // page transition

    expect(find.byType(PhotoPage), findsOneWidget);
    expect(find.text('Early June'), findsNothing);
  });

  testWidgets('holding pauses the story', (tester) async {
    await pump(tester);

    final gesture = await tester.startGesture(const Offset(200, 400));
    // Past the long-press threshold, then well past a page's dwell time.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(MemoryPlayerScreen.pageDuration * 2);

    expect(
      find.text('Early June'),
      findsOneWidget,
      reason: 'still on the title card while held',
    );

    await gesture.up();
    await tester.pump(MemoryPlayerScreen.pageDuration);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(PhotoPage),
      findsOneWidget,
      reason: 'releasing resumes the timer',
    );
  });

  testWidgets('tapping advances by hand, without waiting for the clock', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Early June'), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 400)); // page transition

    expect(find.byType(PhotoPage), findsOneWidget);
    expect(find.text('Early June'), findsNothing);
  });

  testWidgets('a tapped advance gives the next photo its full turn', (
    tester,
  ) async {
    await pump(tester);

    // Tap late in the title card's dwell, so an un-reset timer would fire
    // almost immediately and double-step.
    await tester.pump(MemoryPlayerScreen.pageDuration ~/ 2);
    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoPage), findsOneWidget);

    // Just short of a full page duration after the tap: still here.
    await tester.pump(MemoryPlayerScreen.pageDuration ~/ 2);
    expect(
      find.byType(PhotoPage),
      findsOneWidget,
      reason: 'the tap restarted the clock rather than inheriting it',
    );
  });

  testWidgets('a tapped advance drives the same page index as the clock', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 400));

    // The progress spine reads its filled-segment count off this index, so a
    // tap path that tracked its own would desync the two.
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller!.page!.round(), 1);
  });

  testWidgets('shows a message when every photo is gone', (tester) async {
    await pump(tester, photos: 0);

    expect(find.text('This memory has no photos left.'), findsOneWidget);
  });

  /// Opens the player on a pushed route, so there is something to pop back to
  /// and leaving the story is observable.
  Future<void> pumpPushed(WidgetTester tester, {int photos = 1}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
          memoriesProvider.overrideWithValue(
            const AsyncData<List<MemorySummary>>([]),
          ),
          memoryAssetsProvider(
            memoryId,
          ).overrideWith((ref) async => assets(photos)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const MemoryPlayerScreen(memoryId: memoryId),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('closes itself after the last photo', (tester) async {
    await pumpPushed(tester);

    // Title card, then the single photo, then the pop. Bounded rather than
    // `pumpAndSettle`: the player always has a timer scheduled, so it would
    // never settle.
    for (
      var i = 0;
      i < 6 && find.byType(MemoryPlayerScreen).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(MemoryPlayerScreen.pageDuration);
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(MemoryPlayerScreen), findsNothing);
  });

  testWidgets('tapping past the last photo closes the player', (tester) async {
    await pumpPushed(tester);

    // Title card → the only photo → out, entirely by hand.
    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoPage), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(MemoryPlayerScreen),
      findsNothing,
      reason: 'a tap on the last photo ends the story, same as the clock',
    );
    expect(find.text('open'), findsOneWidget);
  });
}
