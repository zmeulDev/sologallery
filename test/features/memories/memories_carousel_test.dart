import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/daos/memories_dao.dart'
    show MemorySummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/memories/memories_providers.dart';
import 'package:sologallery/features/memories/widgets/memories_carousel.dart';
import 'package:sologallery/features/memories/widgets/memory_card.dart';
import 'package:sologallery/services/permission_provider.dart';

import '../../support/fake_photo_library_service.dart';

void main() {
  MemorySummary summary(int id, String title, {int count = 12}) =>
      MemorySummary(
        id: id,
        kind: 'trip',
        title: title,
        subtitle: '2025',
        coverAssetId: 'cover$id',
        assetCount: count,
      );

  /// Renders the carousel alone with the memories provider fixed — the DB-backed
  /// query is covered in memories_dao_test; here we assert what the row shows.
  Future<void> pump(
    WidgetTester tester,
    List<MemorySummary> memories,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: MemoriesCarousel()),
        ),
        GoRoute(
          path: '/memory/:id',
          builder: (_, state) =>
              Scaffold(body: Text('player-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoLibraryServiceProvider
              .overrideWithValue(FakePhotoLibraryService()),
          memoriesProvider.overrideWithValue(AsyncData(memories)),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('renders nothing when there are no memories', (tester) async {
    await pump(tester, const []);

    expect(find.text('MEMORIES'), findsNothing);
    expect(find.byType(MemoryCard), findsNothing);
  });

  testWidgets('renders a header and one card per memory', (tester) async {
    await pump(tester, [summary(1, 'Early June'), summary(2, 'On this day')]);

    expect(find.text('MEMORIES'), findsOneWidget);
    expect(find.byType(MemoryCard), findsNWidgets(2));
    expect(find.text('Early June'), findsOneWidget);
    expect(find.text('On this day'), findsOneWidget);
  });

  testWidgets('tapping a card opens its player', (tester) async {
    await pump(tester, [summary(7, 'Early June')]);

    await tester.tap(find.byType(MemoryCard));
    await tester.pumpAndSettle();

    expect(find.text('player-7'), findsOneWidget);
  });

  testWidgets('long-pressing offers to remove the memory', (tester) async {
    await pump(tester, [summary(3, 'Early June')]);

    await tester.longPress(find.byType(MemoryCard));
    await tester.pumpAndSettle();

    expect(find.text('Remove this memory?'), findsOneWidget);
    // Backing out leaves it alone.
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryCard), findsOneWidget);
  });
}
