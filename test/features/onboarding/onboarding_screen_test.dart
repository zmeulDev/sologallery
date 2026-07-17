import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/onboarding/onboarding_screen.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  Future<FakePhotoLibraryService> pump(
    WidgetTester tester, {
    required PhotoAccess access,
    PhotoAccess? grantResult,
  }) async {
    final fake = FakePhotoLibraryService(access: access, grantResult: grantResult);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoLibraryServiceProvider.overrideWithValue(fake)],
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
}
