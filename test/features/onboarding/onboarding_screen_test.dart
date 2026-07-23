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

  Future<FakePhotoLibraryService> pump(
    WidgetTester tester, {
    required PhotoAccess access,
    PhotoAccess? grantResult,
  }) async {
    final fake = FakePhotoLibraryService(
      access: access,
      grantResult: grantResult,
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

    expect(find.text('Allow photo access'), findsOneWidget);
    expect(find.text('Open Settings'), findsNothing);
    expect(find.text('Your photos\nstay yours.'), findsOneWidget);
  });

  testWidgets('tapping allow requests access', (tester) async {
    final fake = await pump(
      tester,
      access: PhotoAccess.denied,
      grantResult: PhotoAccess.granted,
    );

    await tester.tap(find.text('Allow photo access'));
    await tester.pumpAndSettle();

    expect(fake.requestCount, 1);
  });

  testWidgets('after a refused prompt it offers Settings', (tester) async {
    // Prompt stays denied -> the screen switches to the Settings path.
    final fake = await pump(tester, access: PhotoAccess.denied);

    await tester.tap(find.text('Allow photo access'));
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Allow photo access'), findsNothing);

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
              FakePhotoLibraryService(access: access),
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
      expect(find.text('Allow photo access'), findsNothing);
    });

    /// Pumps with access already granted, so the screen advances to step 2.
    Future<void> pumpConsent(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            photoLibraryServiceProvider.overrideWithValue(
              FakePhotoLibraryService(access: PhotoAccess.granted),
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
  });
}
