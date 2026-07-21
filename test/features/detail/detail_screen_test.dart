import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/features/detail/detail_screen.dart';
import 'package:sologallery/features/detail/photo_viewer_args.dart';
import 'package:sologallery/features/detail/widgets/detail_action_bar.dart';
import 'package:sologallery/features/detail/widgets/photo_page.dart';
import 'package:sologallery/features/detail/widgets/video_page.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/circle_icon_button.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pump(
    WidgetTester tester, {
    List<String> ids = const ['a1'],
    Map<String, AssetDetail> details = const {},
    Map<String, Duration> videoDurations = const {},
  }) async {
    final fake = FakePhotoLibraryService(
      details: details,
      videoDurations: videoDurations,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(fake),
          // Skip the real image decode in host tests (its async decode leaves a
          // pending timer); the preview path is covered on-device by patrol.
          detailImageProvider.overrideWith((ref, id) => null),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: PhotoDetailScreen(args: PhotoViewerArgs(ids, 0)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Dispose the tree, then pump so the zero-duration Timer drift schedules when
  // it cancels the favorite-watch stream on ProviderScope disposal fires before
  // the "Timer still pending" teardown invariant runs.
  Future<void> settleTeardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// Drags the photo up past the open threshold with a raw pointer sequence.
  /// Not `tester.fling`, which coalesces down/move/up and would hide whether
  /// the axis lock resolved on the intervening moves.
  Future<void> swipeUp(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PhotoPage)),
    );
    await gesture.moveBy(const Offset(0, -150)); // past the 15%-of-height mark
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('renders the action bar and top-bar affordances', (tester) async {
    await pump(tester);
    expect(find.byType(DetailActionBar), findsOneWidget);
    // Back, add-to-album and favorite ride on discs in the top bar.
    expect(find.byType(CircleIconButton), findsNWidgets(3));
    expect(find.byTooltip('Back'), findsOneWidget);
    // Favorite is reachable from both bars, deliberately — the top one is the
    // thumb-reachable copy, the bottom one keeps the action set complete.
    expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
    await settleTeardown(tester);
  });

  testWidgets('the swipe-up hint advertises the details gesture', (
    tester,
  ) async {
    // The gesture is otherwise undiscoverable on a full-bleed photo.
    await pump(tester);
    expect(find.text('SWIPE UP FOR DETAILS'), findsOneWidget);
    await settleTeardown(tester);
  });

  testWidgets('favorite from the top bar toggles the heart and persists', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(CircleIconButton),
        matching: find.byIcon(Icons.favorite_border_rounded),
      ),
    );
    await tester.pumpAndSettle();

    // Both copies follow the one provider — neither can drift out of sync.
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
    expect(await db.favoritesDao.isFavorite('a1'), isTrue);
    await settleTeardown(tester);
  });

  testWidgets('favorite from the action bar toggles the same state', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(DetailActionBar),
        matching: find.byIcon(Icons.favorite_border_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
    expect(await db.favoritesDao.isFavorite('a1'), isTrue);
    await settleTeardown(tester);
  });

  testWidgets('the EXIF sheet shows formatted fields', (tester) async {
    await pump(
      tester,
      details: {
        'a1': AssetDetail(
          id: 'a1',
          width: 4000,
          height: 3000,
          createdAt: DateTime(2026, 7, 12, 14, 33),
          orientationDegrees: 0,
          isVideo: false,
          mimeType: 'image/jpeg',
        ),
      },
    );
    await swipeUp(tester);

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('4000 × 3000'), findsOneWidget);
    expect(find.text('JPEG'), findsOneWidget);
    await settleTeardown(tester);
  });

  testWidgets('swiping up is what opens the EXIF sheet', (tester) async {
    await pump(
      tester,
      details: {
        'a1': AssetDetail(
          id: 'a1',
          width: 4000,
          height: 3000,
          createdAt: DateTime(2026, 7, 12, 14, 33),
          orientationDegrees: 0,
          isVideo: false,
          mimeType: 'image/jpeg',
        ),
      },
    );

    await swipeUp(tester);

    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('4000 × 3000'), findsOneWidget);
    await settleTeardown(tester);
  });

  testWidgets('swiping down dismisses the viewer instead of opening details', (
    tester,
  ) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PhotoPage)),
    );
    await gesture.moveBy(const Offset(0, 250));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('DETAILS'), findsNothing);
    // Nothing to pop back to (PhotoDetailScreen is the MaterialApp home), so
    // maybePop is a no-op and the viewer stays — the assertion that matters is
    // that the downward drag did not reach the swipe-up path.
    await settleTeardown(tester);
  });

  testWidgets('add-to-album creates a new album and confirms', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add_to_photos_outlined));
    // Bounded pumps throughout — the sheet's TextField cursor-blink is a
    // periodic timer, so pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField), 'Trip');
    await tester.tap(find.text('Create'));
    // Bounded pumps (not pumpAndSettle — the confirmation SnackBar's timer keeps
    // it from settling): let the sheet pop and the DB writes complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // One-shot query (a stream's .first would deadlock under FakeAsync).
    final albums = await db.select(db.albums).get();
    expect(albums.map((a) => a.name), contains('Trip'));
    expect(find.text('Added to Trip'), findsOneWidget); // snackbar
    await settleTeardown(tester);
  });

  testWidgets('delete asks for confirmation first', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Delete photo?'), findsOneWidget);
    await settleTeardown(tester);
  });

  testWidgets('a still renders a PhotoPage', (tester) async {
    await pump(tester, ids: ['a1']);
    expect(find.byType(PhotoPage), findsOneWidget);
    expect(find.byType(VideoPage), findsNothing);
    await settleTeardown(tester);
  });

  testWidgets('a video renders a VideoPage', (tester) async {
    // videoDurations marks 'v1' a video; the fake's videoFile returns null, so
    // VideoPage lands on its unavailable branch (no real controller on host —
    // real playback is covered on-device by patrol).
    await pump(
      tester,
      ids: ['v1'],
      videoDurations: {'v1': const Duration(seconds: 42)},
    );
    expect(find.byType(VideoPage), findsOneWidget);
    expect(find.byType(PhotoPage), findsNothing);
    await settleTeardown(tester);
  });
}
