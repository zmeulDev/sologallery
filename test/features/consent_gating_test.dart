import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/memories/domain/memory_kind.dart';
import 'package:sologallery/features/memories/domain/planned_memory.dart';
import 'package:sologallery/features/memories/memories_providers.dart';
import 'package:sologallery/features/people/people_providers.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../support/fake_photo_library_service.dart';

/// The consent flags gate the *providers*, not each widget, so every surface
/// that reads them goes quiet together. These tests pin that: with data sitting
/// in the database, the providers must still yield nothing until the user has
/// opted in.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(
          FakePhotoLibraryService(access: PhotoAccess.granted),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  /// One cached asset — memory entries and face rows both reference it.
  Future<void> seedAsset() async {
    await db.indexDao.upsertMetadata([
      (
        id: 'a',
        createdAt: DateTime(2026, 5, 1),
        isVideo: false,
        width: 1,
        height: 1,
        isDated: true,
      ),
    ]);
  }

  Future<void> seedFace() async {
    await seedAsset();
    final person = await db.facesDao.createPerson(coverAssetId: 'a');
    await db.facesDao.insertFaces('a', [
      (
        left: 0,
        top: 0,
        right: 10,
        bottom: 10,
        embedding: Float32List.fromList(List.filled(192, 0.1)),
      ),
    ]);
    final face = await db.select(db.faceEmbeddings).getSingle();
    await db.facesDao.assignPersonToFace(face.id, person);
  }

  test('people stay hidden while face detection is off, then appear', () async {
    await seedFace();
    // Keep the stream alive rather than awaiting `.future` on an autoDispose
    // StreamProvider (CLAUDE.md Riverpod trap #1).
    container.listen(personSummariesProvider, (_, _) {});
    await settle();

    expect(container.read(personSummariesProvider).value, isEmpty);

    await db.settingsDao.setFacesEnabled(true);
    await settle();

    expect(container.read(personSummariesProvider).value, hasLength(1));
  });

  test('memories stay hidden while the feature is off, then appear', () async {
    await seedAsset();
    await db.memoriesDao.applyPlan([
      const PlannedMemory(
        sourceKey: 'onThisDay:2024',
        kind: MemoryKind.onThisDay,
        title: 'On this day',
        subtitle: '2024',
        coverAssetId: 'a',
        assetIds: ['a'],
        score: 1,
      ),
    ]);
    container.listen(memoriesProvider, (_, _) {});
    await settle();

    expect(container.read(memoriesProvider).value, isEmpty);

    await db.settingsDao.setMemoriesEnabled(true);
    await settle();

    expect(container.read(memoriesProvider).value, hasLength(1));
  });
}
