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
import 'package:sologallery/widgets/people_strip.dart';

import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, List<PersonSummary> people) {
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
          home: Scaffold(body: PeopleStrip(people: people)),
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

  testWidgets('reserves no caption height when nobody is named', (
    tester,
  ) async {
    await pump(tester, [person(1, null), person(2, null)]);
    await tester.pump();
    final unnamedHeight = tester.getSize(find.byType(ListView)).height;

    await pump(tester, [person(1, 'Ada'), person(2, null)]);
    await tester.pump();
    final mixedHeight = tester.getSize(find.byType(ListView)).height;

    // One named person is enough to grow the strip; none leaves it at the bare
    // avatar diameter, so a caption-less row has no dead band under it.
    expect(unnamedHeight, 72);
    expect(mixedHeight, greaterThan(unnamedHeight));
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
}
