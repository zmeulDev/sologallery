import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    // Grant access *and* answer the analysis-consent prompt so the router
    // redirect lands on the Library, not onboarding. Seeded through the real
    // SettingsDao so these tests exercise the actual ConsentNotifier path.
    await db.settingsDao.recordConsent();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
        ],
        child: const SoloGalleryApp(),
      ),
    );
    // Bounded pumps: the branches show a spinner that animates forever, so
    // pumpAndSettle would hang. Long enough for the shell route's entry
    // transition to finish — mid-slide the nav bar is offset and taps on the
    // right-hand destinations land off-screen.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Dispose the tree + elapse time so the Drift stream store's dispose timer
  // fires before the pending-timer invariant (gotcha #2). Must be in the body.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('boots to the Library tab', (tester) async {
    await pumpApp(tester);
    // App-bar title of the initial (Library) branch.
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('renders the four nav destinations in order', (tester) async {
    await pumpApp(tester);
    for (final label in ['Library', 'Search', 'Saved', 'Albums']) {
      // Each destination exposes a semantic label via Tooltip/Semantics.
      expect(find.byTooltip(label), findsOneWidget);
    }
    await disposeTree(tester);
  });

  testWidgets('tapping a destination switches branches', (tester) async {
    await pumpApp(tester);
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);

    await tester.tap(find.byTooltip('Albums'));
    await tester.pump(); // indexed shell switches branch (no transition anim)
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.widgetWithText(AppBar, 'Albums'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Library'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('search field takes focus with the tab and releases it on leave',
      (tester) async {
    await pumpApp(tester);
    // skipOffstage: false — once another tab is selected the Search branch
    // stays in the tree (indexed shell) but goes offstage.
    final field = find.byType(TextField, skipOffstage: false);

    await tester.tap(find.byTooltip('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);

    // Leaving the tab releases focus so the keyboard doesn't linger.
    await tester.tap(find.byTooltip('Saved'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);

    await disposeTree(tester);
  });
}
