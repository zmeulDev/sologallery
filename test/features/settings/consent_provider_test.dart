import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/core/database/daos/settings_dao.dart';
import 'package:sologallery/core/database/database_provider.dart';
import 'package:sologallery/features/settings/consent_provider.dart';
import 'package:sologallery/services/permission_provider.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../../support/fake_ml_worker.dart';
import '../../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  /// Recording consent now runs through [IndexingService], which kicks an
  /// indexing pass — so the real photo_manager plugin has to be faked out or it
  /// throws on the host.
  overrides() => [
        databaseProvider.overrideWithValue(db),
        photoLibraryServiceProvider.overrideWithValue(
          // Must contain the seeded asset: enabling a feature kicks a pass, and
          // the metadata sweep prunes cache rows the library no longer has.
          FakePhotoLibraryService(
            assets: [AssetRef(id: 'a', createdAt: DateTime(2026, 5, 1))],
            thumbnailBytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
        // Enabling a feature re-queues the cache and re-analyses it, so a real
        // worker would be spawned here.
        mlWorkerProvider.overrideWithValue(
          FakeMlWorker(labels: const [('Dog', 0.9)], text: 'hello'),
        ),
      ];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(overrides: overrides());
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A real turn, not a microtask — Riverpod batches recomputes on its own
  /// scheduler (CLAUDE.md gotcha).
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  test('starts unresolved, then resolves to needed on a fresh install',
      () async {
    expect(container.read(consentProvider), ConsentState.unresolved);

    await settle();

    expect(container.read(consentProvider), ConsentState.needed);
  });

  test('resolves to recorded when the prompt was already answered', () async {
    await db.settingsDao.recordConsent();

    // A fresh container, as on a cold start with the answer already on disk.
    final fresh = ProviderContainer(overrides: overrides());
    addTearDown(fresh.dispose);

    expect(fresh.read(consentProvider), ConsentState.unresolved);
    await settle();
    expect(fresh.read(consentProvider), ConsentState.recorded);
  });

  test('recording accepts the chosen features and marks the prompt answered',
      () async {
    await settle();

    await container
        .read(consentProvider.notifier)
        .record(search: true, memories: true, faces: false);

    expect(container.read(consentProvider), ConsentState.recorded);
    expect(await db.settingsDao.readSearchEnabled(), isTrue);
    expect(await db.settingsDao.readMemoriesEnabled(), isTrue);
    expect(await db.settingsDao.readFacesEnabled(), isFalse);
  });

  test('declining everything still counts as answered', () async {
    await settle();

    await container
        .read(consentProvider.notifier)
        .record(search: false, memories: false, faces: false);

    // The whole point of the separate consent key: "no to everything" must not
    // re-prompt on the next launch.
    expect(container.read(consentProvider), ConsentState.recorded);
    expect(await db.settingsDao.readConsentRecorded(), isTrue);
  });

  group('upgrading from a build that had no consent step', () {
    /// Data derived before consent existed — what an existing install already
    /// has on disk when it first reaches the prompt.
    Future<void> seedPreExistingDerivedData() async {
      await db.indexDao.upsertIndexed(
        assetId: 'a',
        createdAt: DateTime(2026, 5, 1),
        isVideo: false,
        width: 1,
        height: 1,
        labels: const [('Dog', 0.9)],
        text: 'hello',
      );
      await db.facesDao.createPerson(coverAssetId: 'a');
      await db.facesDao.insertFaces('a', [
        (
          left: 0,
          top: 0,
          right: 9,
          bottom: 9,
          embedding: Float32List.fromList(List.filled(192, 0.1)),
        ),
      ]);
    }

    test('declining everything deletes what was already derived', () async {
      await seedPreExistingDerivedData();
      await settle();

      await container
          .read(consentProvider.notifier)
          .record(search: false, memories: false, faces: false);

      // The whole point of consent: refusing must remove the inferences, not
      // merely stop making new ones.
      expect(await db.select(db.photoLabels).get(), isEmpty);
      expect(await db.select(db.photoTexts).get(), isEmpty);
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
      expect(await db.select(db.persons).get(), isEmpty);
      // The library cache itself survives — the grid must not go blank.
      expect(await db.indexDao.allCachedIds(), isNotEmpty);
    });

    test('accepting a feature keeps (re-derives) its data', () async {
      await seedPreExistingDerivedData();
      await settle();

      await container
          .read(consentProvider.notifier)
          .record(search: true, memories: false, faces: false);

      // Accepting re-queues the library, so the labels are present again —
      // never deleted out from under an accepted feature.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await db.select(db.photoLabels).get(), isNotEmpty);
      // Still declined, so the face data goes.
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
    });
  });

  group('consent versioning', () {
    test('an answer to an older prompt version does not count', () async {
      // What a previous release stored, before the scope changed.
      await db.settingsDao.put('ml_consent', '0');

      final fresh = ProviderContainer(overrides: overrides());
      addTearDown(fresh.dispose);
      // Read once to force construction — providers are lazy, so settling
      // before the first read would resolve nothing.
      expect(fresh.read(consentProvider), ConsentState.unresolved);
      await settle();

      expect(
        fresh.read(consentProvider),
        ConsentState.needed,
        reason: 'a bumped consentVersion must re-ask',
      );
      expect(await db.settingsDao.readConsentRecorded(), isFalse);
    });

    test('recording stores the current version', () async {
      await db.settingsDao.recordConsent();

      expect(
        await db.settingsDao.read('ml_consent'),
        SettingsDao.consentVersion.toString(),
      );
      expect(await db.settingsDao.readConsentRecorded(), isTrue);
    });
  });

  test('the feature flags are false until consent is recorded', () async {
    container.listen(searchEnabledProvider, (_, _) {});
    container.listen(memoriesEnabledProvider, (_, _) {});
    container.listen(facesEnabledProvider, (_, _) {});
    await settle();

    expect(container.read(searchEnabledProvider).value, isFalse);
    expect(container.read(memoriesEnabledProvider).value, isFalse);
    expect(container.read(facesEnabledProvider).value, isFalse);
  });
}
