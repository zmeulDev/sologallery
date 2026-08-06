import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/onboarding/onboarding_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final folders = [
    DeviceFolder(id: 'camera-folder', name: 'Camera', count: 120),
    DeviceFolder(id: 'screenshots-folder', name: 'Screenshots', count: 30),
  ];

  Future<FakePhotoLibraryService> pump(
    WidgetTester tester, {
    required PhotoAccess access,
    PhotoAccess? grantResult,
  }) async {
    final fake = FakePhotoLibraryService(
      access: access,
      grantResult: grantResult,
      folders: folders,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Granting access advances the screen to the consent step, which
          // reads the database — keep that in memory, never the real one.
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('first run invites the native prompt', (tester) async {
    // Android reports denied even when never asked; before a prompt we still
    // show the allow CTA, not the settings path.
    await pump(tester, access: PhotoAccess.denied);

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Open Settings'), findsNothing);
    expect(find.text('Your photos\nstay yours.'), findsOneWidget);
  });

  testWidgets('access step leads with the brand mark + wordmark', (
    tester,
  ) async {
    await pump(tester, access: PhotoAccess.denied);

    // The bare mark asset is listed in pubspec.yaml under flutter.assets:,
    // so flutter test bundles it into the test catalog. One widget on this
    // step — the brand anchor.
    expect(
      find.byType(Image).evaluate().any(
        (e) =>
            (e.widget as Image).image is AssetImage &&
            (e.widget as Image).image
                .toString()
                .contains('sologallery_mark_transparent_4096.png'),
      ),
      isTrue,
      reason: 'bare brand mark should be the leading element on step 1',
    );
    expect(find.text('SoloGallery'), findsOneWidget);
  });

  testWidgets('tapping allow requests access', (tester) async {
    final fake = await pump(
      tester,
      access: PhotoAccess.denied,
      grantResult: PhotoAccess.granted,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(fake.requestCount, 1);
  });

  testWidgets('after a refused prompt it offers Settings', (tester) async {
    // Prompt stays denied -> the screen switches to the Settings path.
    final fake = await pump(tester, access: PhotoAccess.denied);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(fake.openSettingsCount, 1);
  });

  group('consent step', () {
    /// Pumps with [access] already sufficient to read, so the screen advances
    /// to step 2. `pumpAndSettle` — the consent step has no perpetually
    /// scheduling widget (no spinner, no focused TextField), so it's safe
    /// here and reliably lets the step's providers resolve before asserting.
    Future<void> pumpConsentWith(
      WidgetTester tester,
      PhotoAccess access,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            photoLibraryServiceProvider.overrideWithValue(
              FakePhotoLibraryService(
                access: access,
                folders: folders,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('limited access still owes the consent step', (tester) async {
      // `limited` counts as canReadLibrary, so the user passes step 1 — but a
      // partial library is still a library to analyze, so consent is owed.
      await pumpConsentWith(tester, PhotoAccess.limited);

      expect(find.text('What should stay\non the shelf?'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
      expect(find.text('Your photos\nstay yours.'), findsNothing);
    });

    /// Pumps with access already granted, so the screen advances to step 2.
    Future<void> pumpConsent(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            photoLibraryServiceProvider.overrideWithValue(
              FakePhotoLibraryService(
                access: PhotoAccess.granted,
                folders: folders,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const OnboardingScreen(),
          ),
        ),
      );
      // pumpAndSettle, not a short bounded pump — see pumpConsentWith's note.
      await tester.pumpAndSettle();
    }

    testWidgets('asks once access is granted, with every feature off', (
      tester,
    ) async {
      await pumpConsent(tester);

      expect(find.text('What should stay\non the shelf?'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(3));
      expect(
        switches.every((s) => s.value == false),
        isTrue,
        reason: 'consent is opt-in — nothing starts on',
      );
    });

    testWidgets('consent step leads with the same brand mark + wordmark', (
      tester,
    ) async {
      await pumpConsent(tester);

      // Same asset, same row, same identity — brand anchor doesn't change
      // between steps.
      expect(
        find.byType(Image).evaluate().any(
          (e) =>
              (e.widget as Image).image is AssetImage &&
              (e.widget as Image).image
                  .toString()
                  .contains('sologallery_mark_transparent_4096.png'),
        ),
        isTrue,
        reason: 'bare brand mark should be the leading element on step 2',
      );
      expect(find.text('SoloGallery'), findsOneWidget);
    });

    testWidgets('Continue persists exactly what was switched on', (
      tester,
    ) async {
      await pumpConsent(tester);

      // Turn Content search on (first row), leave Memories and Faces off.
      await tester.tap(find.byType(Switch).first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Continue'));
      // pumpAndSettle: recording consent flips the screen back to step 1
      // (canReadLibrary stays true, consent no longer "needed"), which
      // remounts the access step under a fresh KeyedSubtree.
      await tester.pumpAndSettle();

      expect(await db.settingsDao.readSearchEnabled(), isTrue);
      expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
      expect(await db.settingsDao.readFacesEnabled(), isFalse);
      expect(await db.settingsDao.readConsentRecorded(), isTrue);
    });

    testWidgets('Continue with nothing on still records the answer', (
      tester,
    ) async {
      await pumpConsent(tester);

      await tester.tap(find.text('Continue'));
      // pumpAndSettle — see the note in the previous test.
      await tester.pumpAndSettle();

      expect(await db.settingsDao.readConsentRecorded(), isTrue);
      expect(await db.settingsDao.readSearchEnabled(), isFalse);
      expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
      expect(await db.settingsDao.readFacesEnabled(), isFalse);
    });

    testWidgets('shows folder summary and selected photo count', (tester) async {
      await pumpConsent(tester);

      expect(find.text('Folders to analyze'), findsOneWidget);
      expect(
        find.text('All folders · 150 photos. This may take a while.'),
        findsNothing,
      );
      // By default no ML features are on, so the caption says so.
      expect(
        find.text('All folders · No on-device analysis is turned on.'),
        findsOneWidget,
      );
    });

    testWidgets('caption switches to time estimate when analysis is enabled', (
      tester,
    ) async {
      await pumpConsent(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(
        find.text('All folders · 150 photos. This may take a while.'),
        findsOneWidget,
      );
    });

    testWidgets('a small selection drops the "a while" warning', (tester) async {
      await pumpConsent(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // The brand-mark row + three switch rows push the folder card below
      // the test viewport. Scroll the consent step until the card is on
      // screen, then proceed.
      await tester.scrollUntilVisible(
        find.text('Folders to analyze'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Exclude the 120-photo Camera folder, leaving 30 — well under the
      // threshold where the warning is honest.
      await tester.tap(find.text('Folders to analyze'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 folders · 30 photos.'), findsOneWidget);
      expect(find.textContaining('This may take a while'), findsNothing);
    });

    testWidgets('folder picker updates summary and persisted scope', (
      tester,
    ) async {
      await pumpConsent(tester);

      // The card starts with every folder included and no analysis enabled.
      expect(
        find.text('All folders · No on-device analysis is turned on.'),
        findsOneWidget,
      );

      // Scroll the consent step until the folder card is on screen (the
      // brand-mark row + three switch rows push it past the default
      // 800×600 test viewport).
      await tester.scrollUntilVisible(
        find.text('Folders to analyze'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Folders to analyze'));
      await tester.pumpAndSettle();

      // The folder picker sheet is open.
      expect(find.text('FOLDERS TO ANALYZE'), findsOneWidget);

      // Toggle the Screenshots folder off. The sheet shows All folders, Camera,
      // Screenshots — tap the last checkbox.
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes, hasLength(3));
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();

      // Tap Done in the sheet.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Summary now reflects one excluded folder; still no analysis on.
      expect(
        find.text('1 of 2 folders · No on-device analysis is turned on.'),
        findsOneWidget,
      );

      // Turn content search on so analysis is enabled and Continue persists.
      await tester.tap(find.byType(Switch).first);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        await db.settingsDao.readExcludedFolderIds(),
        const {'screenshots-folder'},
      );
    });
  });
}
