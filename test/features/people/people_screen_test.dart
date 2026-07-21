import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sologallery/core/database/daos/faces_dao.dart' show PersonSummary;
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/features/people/people_screen.dart';
import 'package:sologallery/features/settings/consent_provider.dart';

/// Records what the screen asked the data layer to do, so the merge flow can be
/// tested without a database. Implemented rather than extended so it needs no
/// `Ref`, which lets each test own an instance from the start — the provider is
/// created lazily, so a test whose path never reads it would otherwise still be
/// holding the previous test's recorder.
class _RecordingActions implements PeopleActions {
  final List<(int into, int from)> merges = [];
  final List<(int id, int from)> separations = [];

  @override
  Future<void> merge({required int into, required int from}) async =>
      merges.add((into, from));

  @override
  Future<void> separate(int personId, {required int from}) async =>
      separations.add((personId, from));

  @override
  Future<void> rename(int personId, String? name) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingActions actions;

  setUp(() => actions = _RecordingActions());

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
          peopleActionsProvider.overrideWithValue(actions),
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

  group('merging', () {
    const two = [
      PersonSummary(id: 1, displayName: 'Zml', coverAssetId: 'a', faceCount: 47),
      PersonSummary(id: 2, displayName: 'ZmlG', coverAssetId: 'b', faceCount: 10),
    ];

    testWidgets('offers no Select with only one person to merge',
        (tester) async {
      await pump(tester, const [
        PersonSummary(id: 1, displayName: 'Zml', coverAssetId: 'a', faceCount: 4),
      ]);
      expect(find.text('Select'), findsNothing);
    });

    testWidgets('offers Select once there are two people', (tester) async {
      await pump(tester, two);
      expect(find.text('Select'), findsOneWidget);
    });

    testWidgets('selection mode counts the selection and cancels back out',
        (tester) async {
      await pump(tester, two);
      await tester.tap(find.text('Select'));
      await tester.pump();

      expect(find.text('0 selected'), findsOneWidget);
      await tester.tap(find.text('Zml'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('People'), findsOneWidget);
      expect(find.text('Merge people'), findsNothing);
    });

    testWidgets('the merge button only enables at two selections',
        (tester) async {
      await pump(tester, two);
      await tester.tap(find.text('Select'));
      await tester.pump();

      // Present but inert with nothing (and then one thing) selected.
      expect(find.text('Merge people'), findsOneWidget);
      await tester.tap(find.text('Zml'));
      await tester.pump();
      expect(find.text('Merge people'), findsOneWidget);

      await tester.tap(find.text('ZmlG'));
      await tester.pump();
      expect(find.text('Merge 2 people'), findsOneWidget);
    });

    testWidgets('merges into the most-photographed person and names it',
        (tester) async {
      await pump(tester, two);
      await tester.tap(find.text('Select'));
      await tester.pump();
      // Select the smaller one first: the survivor is decided by photo count,
      // not by tap order.
      await tester.tap(find.text('ZmlG'));
      await tester.pump();
      await tester.tap(find.text('Zml'));
      await tester.pump();
      await tester.tap(find.text('Merge 2 people'));
      await tester.pump();

      expect(find.text('Merge people?'), findsOneWidget);
      expect(
        find.textContaining('ZmlG and Zml become one person, named Zml'),
        findsOneWidget,
      );

      await tester.tap(find.text('Merge'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(actions.merges, [(1, 2)]);
      expect(find.text('Merged'), findsOneWidget);
      // Selection mode ends once the merge lands.
      expect(find.text('People'), findsOneWidget);
    });

    testWidgets('cancelling the dialog merges nothing', (tester) async {
      await pump(tester, two);
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.tap(find.text('Zml'));
      await tester.pump();
      await tester.tap(find.text('ZmlG'));
      await tester.pump();
      await tester.tap(find.text('Merge 2 people'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await tester.pump();

      expect(actions.merges, isEmpty);
      // Still selecting, so the choice is not silently thrown away either.
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('Undo separates the people again', (tester) async {
      await pump(tester, two);
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.tap(find.text('Zml'));
      await tester.pump();
      await tester.tap(find.text('ZmlG'));
      await tester.pump();
      await tester.tap(find.text('Merge 2 people'));
      await tester.pump();
      await tester.tap(find.text('Merge'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pump(const Duration(milliseconds: 750));
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actions.separations, [(2, 1)]);
    });

    testWidgets('tapping a person while selecting does not open them',
        (tester) async {
      await pump(tester, two);
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.tap(find.text('Zml'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('person 1'), findsNothing);
      expect(find.text('1 selected'), findsOneWidget);
    });
  });
}
