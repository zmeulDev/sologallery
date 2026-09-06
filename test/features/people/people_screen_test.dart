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
          // The grid resolves covers in one batch (B2); stub it too so no real
          // database gets touched by this widget test.
          personCoversProvider.overrideWith((ref) async => const {}),
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

  testWidgets(
    'a named person is bold, an unnamed one stays regular weight',
    (tester) async {
      await pump(tester, const [
        PersonSummary(id: 1, displayName: 'Alice', coverAssetId: 'a', faceCount: 4),
        PersonSummary(id: 2, displayName: null, coverAssetId: 'b', faceCount: 1),
      ]);

      expect(
        tester.widget<Text>(find.text('Alice')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        tester.widget<Text>(find.text('Unnamed')).style?.fontWeight,
        FontWeight.w400,
      );
    },
  );

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

    /// Selects both fixtures and confirms the merge, leaving the confirmation
    /// snackbar on screen.
    Future<void> mergeBoth(WidgetTester tester) async {
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
      // The snackbar's entry animation has to finish before its timer starts.
      await tester.pump(const Duration(milliseconds: 750));
    }

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

    // `SnackBar.persist` defaults to `action != null`, and the messenger skips
    // its timeout entirely when it is set — so the Undo banner never dismissed
    // itself, and because it lives on the root messenger (above the Navigator)
    // it followed the user onto every other screen.
    testWidgets('the merge confirmation times out on its own', (tester) async {
      await pump(tester, two);
      await mergeBoth(tester);

      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.persist, isFalse);
      expect(bar.duration, const Duration(seconds: 6));

      // Long enough to reach for Undo, and then gone without being touched.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Merged'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Merged'), findsNothing);
    });

    testWidgets('leaving People takes the confirmation with it', (
      tester,
    ) async {
      await pump(tester, two);
      await mergeBoth(tester);
      expect(find.text('Merged'), findsOneWidget);

      // An Undo for a merge made here has no meaning once the screen is gone.
      await tester.tap(find.text('Zml'));
      await tester.pump();
      // The snackbar's own exit animation runs alongside the push transition,
      // so the banner outlives the 400ms route change by a couple of frames.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('person 1'), findsOneWidget);
      expect(find.text('Merged'), findsNothing);
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

    testWidgets(
      'the selection ring uses accent colour with white check icon',
      (tester) async {
        await pump(tester, two);
        await tester.tap(find.text('Select'));
        await tester.pump();
        await tester.tap(find.text('Zml'));
        await tester.pump();

        final colors = Theme.of(tester.element(find.byType(PeopleScreen)))
            .extension<AppColors>()!;

        // Find the ring's DecoratedBox (the one with a border inside the Opacity).
        // It's in a Positioned.fill, so it's a direct child of the Stack within Opacity.
        final ringBorder = tester.widget<DecoratedBox>(
          find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border != null,
          ).first,
        );
        final ringDecoration = ringBorder.decoration as BoxDecoration;
        expect(ringDecoration.border!.top.color, colors.accent,
            reason: 'Ring border should be accent color');

        // Find the check-disc Container by looking for a circular Container with accent fill.
        final checkDiscFinder = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration as BoxDecoration).color == colors.accent,
        );
        expect(checkDiscFinder, findsWidgets,
            reason: 'Should find check disc Container with accent color');
        final checkDisc = tester.widget<Container>(checkDiscFinder.first);
        final discDecoration = checkDisc.decoration as BoxDecoration;
        expect(discDecoration.color, colors.accent,
            reason: 'Check disc fill should be accent color');

        // Find the check icon within the check disc Container.
        final checkIcon = tester.widget<Icon>(
          find.descendant(
            of: checkDiscFinder.first,
            matching: find.byIcon(Icons.check_rounded),
          ),
        );
        expect(checkIcon.color, Colors.white,
            reason: 'Check icon should be white on accent background');
      },
    );
  });
}
