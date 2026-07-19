import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/daos/faces_dao.dart' show PersonSummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/people/people_screen.dart';
import 'package:sologallery/features/settings/consent_provider.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<PersonSummary> people, {
    bool facesEnabled = true,
  }) async {
    final router = GoRouter(
      initialLocation: '/people',
      routes: [
        GoRoute(path: '/people', builder: (_, _) => const PeopleScreen()),
        GoRoute(
          path: '/person/:id',
          builder: (_, s) => Scaffold(
            body: Text('person ${s.pathParameters['id']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Face detection is opt-in; these cases are about the screen once the
          // user has turned it on.
          facesEnabledProvider.overrideWith((ref) => Stream.value(facesEnabled)),
          personSummariesProvider.overrideWith((ref) => Stream.value(people)),
          // Avatars resolve to the placeholder — no DB/thumbnail needed here.
          personCoverProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('empty state when there are no people', (tester) async {
    await pump(tester, const []);
    expect(find.textContaining('No people yet'), findsOneWidget);
  });

  testWidgets('with face detection off, says so instead of "no people yet"',
      (tester) async {
    await pump(tester, const [], facesEnabled: false);

    expect(find.textContaining('Face detection is off'), findsOneWidget);
    // The indexing note would imply people are still coming. They aren't.
    expect(find.textContaining('No people yet'), findsNothing);
  });

  testWidgets('renders a named and an unnamed person with counts',
      (tester) async {
    await pump(tester, const [
      PersonSummary(id: 1, displayName: 'Alice', coverAssetId: 'a', faceCount: 4),
      PersonSummary(id: 2, displayName: null, coverAssetId: 'b', faceCount: 1),
    ]);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('4 photos'), findsOneWidget);
    expect(find.text('Unnamed'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
  });

  testWidgets('tapping a person opens their detail route', (tester) async {
    await pump(tester, const [
      PersonSummary(id: 7, displayName: 'Bob', coverAssetId: 'a', faceCount: 2),
    ]);

    await tester.tap(find.text('Bob'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('person 7'), findsOneWidget);
  });
}
