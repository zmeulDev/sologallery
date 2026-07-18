import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/app_database.dart' show Person;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/people/person_detail_screen.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

import '../../support/asset_fixtures.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Person? person,
    List<AssetRef> assets = const [],
  }) async {
    final router = GoRouter(
      initialLocation: '/person/1',
      routes: [
        GoRoute(
          path: '/person/:id',
          builder: (_, _) => const PersonDetailScreen(personId: 1),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService(assets: assets)),
          personProvider.overrideWith((ref, id) => Stream.value(person)),
          personAssetsProvider.overrideWith((ref, id) async => assets),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Person named(String? name) => Person(
        id: 1,
        displayName: name,
        coverAssetId: null,
        createdAt: DateTime(2026, 8, 1),
      );

  testWidgets('shows the person name and their photos', (tester) async {
    await pump(
      tester,
      person: named('Alice'),
      assets: assetsInMonth(2026, 8, 3),
    );
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(AssetThumbnail), findsNWidgets(3));
  });

  testWidgets('falls back to "Person" when unnamed', (tester) async {
    await pump(tester, person: named(null), assets: assetsInMonth(2026, 8, 1));
    expect(find.text('Person'), findsOneWidget);
  });

  testWidgets('empty state when the person has no photos', (tester) async {
    await pump(tester, person: named('Bob'));
    expect(find.textContaining('No photos'), findsOneWidget);
  });
}
