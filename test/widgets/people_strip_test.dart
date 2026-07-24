import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/faces_dao.dart'
    show PersonSummary;
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/people/widgets/face_avatar.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/widgets/app_card.dart';
import 'package:sologallery/widgets/people_strip.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pump(
    WidgetTester tester,
    List<PersonSummary> people, {
    double textScale = 1,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoLibraryServiceProvider.overrideWithValue(
            FakePhotoLibraryService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: PeopleStrip(people: people)),
          ),
        ),
      ),
    );
  }

  PersonSummary person(int id, String? name) => PersonSummary(
    id: id,
    displayName: name,
    coverAssetId: 'cover-$id',
    faceCount: 3,
  );

  testWidgets('renders an avatar per person under a People header', (
    tester,
  ) async {
    await pump(tester, [person(1, null), person(2, null)]);
    await tester.pump();
    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.byType(FaceAvatar), findsNWidgets(2));
  });

  testWidgets('shows a name when the cluster has one', (tester) async {
    await pump(tester, [person(1, 'Ada')]);
    await tester.pump();
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('an unnamed person gets an avatar and no caption at all', (
    tester,
  ) async {
    // displayName is nullable and nothing names a cluster automatically, so
    // this is the *common* case. It must never fall back to "Unknown", the
    // person id, or an index — the strip simply shows faces.
    await pump(tester, [person(7, null)]);
    await tester.pump();
    expect(find.byType(FaceAvatar), findsOneWidget);
    expect(find.textContaining('Unknown'), findsNothing);
    expect(find.textContaining('Person'), findsNothing);
    expect(find.text('7'), findsNothing);
  });

  testWidgets('a long name is clipped, never overflowing the avatar column', (
    tester,
  ) async {
    await pump(tester, [person(1, 'Bartholomew Fitzgerald-Wellingtonshire')]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.text('Bartholomew Fitzgerald-Wellingtonshire'),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the strip sits in a card, and the faces are circles', (
    tester,
  ) async {
    await pump(tester, [person(1, 'Ada')]);
    await tester.pump();
    expect(find.byType(AppCard), findsOneWidget);
    // FaceAvatar switches between ClipOval and ClipRRect on `borderRadius`, and
    // its placeholder does the same on `shape` — a null radius is the circle.
    // Asserting the input, not the clip, because host tests never get past the
    // placeholder (no decodable thumbnail), so no ClipOval is ever built here.
    expect(tester.widget<FaceAvatar>(find.byType(FaceAvatar)).borderRadius, isNull);
    final placeholder = tester.widget<Container>(
      find.descendant(of: find.byType(FaceAvatar), matching: find.byType(Container)),
    );
    expect(
      (placeholder.decoration! as BoxDecoration).shape,
      BoxShape.circle,
    );
  });

  testWidgets('the photo count stays on the People screen, not in the strip', (
    tester,
  ) async {
    await pump(tester, [person(1, 'Ada')]);
    await tester.pump();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('3 photos'), findsNothing);
  });

  // A horizontal ListView gives its children a *tight* height, so a caption
  // that doesn't fit squashes the circle into an oval instead of overflowing —
  // no red stripe, no exception, it just looks subtly wrong. The circle staying
  // circular at every text scale is therefore the invariant, not the row's
  // overall height (which legitimately grows with the caption).
  for (final scale in const [1.0, 1.15, 1.6, 2.0]) {
    testWidgets('the face stays circular at textScale $scale', (tester) async {
      await pump(tester, [person(1, 'Ada'), person(2, null)], textScale: scale);
      await tester.pump();
      final avatar = tester.getSize(find.byType(FaceAvatar).first);
      expect(avatar.width, avatar.height);
      expect(avatar.width, 64);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the caption band is reserved only when someone is named', (
    tester,
  ) async {
    await pump(tester, [person(1, null), person(2, null)]);
    await tester.pump();
    final bare = tester.getSize(find.byType(ListView)).height;

    await pump(tester, [person(1, 'Ada'), person(2, null)]);
    await tester.pump();
    final named = tester.getSize(find.byType(ListView)).height;

    // The all-unnamed row — the common case — carries no dead space under it.
    expect(bare, 64);
    expect(named, greaterThan(bare));
  });

  testWidgets('every face is its own labelled target', (tester) async {
    final semantics = tester.ensureSemantics();

    await pump(tester, [person(1, 'Ada'), person(2, null)]);
    await tester.pump();

    // Without a label per tile the whole strip collapses into the section
    // header's node, and no individual person can be reached or named.
    expect(
      tester.getSemantics(find.bySemanticsLabel('Ada')),
      matchesSemantics(label: 'Ada', isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Unnamed person')),
      matchesSemantics(
        label: 'Unnamed person',
        isButton: true,
        hasTapAction: true,
      ),
    );

    semantics.dispose();
  });
}
