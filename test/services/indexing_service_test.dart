import 'dart:async' show Completer;
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/memories/domain/memory_kind.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

import '../support/asset_fixtures.dart';
import '../support/fake_ml_worker.dart';
import '../support/fake_photo_library_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  IndexingService serviceFor(
    FakePhotoLibraryService photos,
    FakeMlWorker worker, {
    Duration debounce = const Duration(seconds: 2),
    int reclusterThreshold = 20,
    int memoryRefreshThreshold = 50,
  }) =>
      IndexingService(
        dao: db.indexDao,
        faces: db.facesDao,
        memories: db.memoriesDao,
        settings: db.settingsDao,
        photos: photos,
        worker: worker,
        resweepDebounce: debounce,
        reclusterThreshold: reclusterThreshold,
        memoryRefreshThreshold: memoryRefreshThreshold,
      );

  /// Grants the on-device analysis consents a test needs. Content search,
  /// memories, and face detection are all opt-in and off until the user enables
  /// them, so a test that exercises any of them has to say so explicitly.
  Future<void> consentTo({
    bool search = false,
    bool faces = false,
    bool memories = false,
  }) async {
    await db.settingsDao.setSearchEnabled(search);
    await db.settingsDao.setFacesEnabled(faces);
    await db.settingsDao.setMemoriesEnabled(memories);
  }

  test('indexes every library asset and persists labels', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 3),
      thumbnailBytes: Uint8List.fromList([1, 2, 3]),
    );
    final worker = FakeMlWorker(
      labels: const [('Dog', 0.9), ('Grass', 0.6)],
      text: 'Hello world',
    );
    await consentTo(search: true);

    await serviceFor(photos, worker).start();

    expect(await db.indexDao.allCachedIds(), hasLength(3));
    expect(worker.calls, hasLength(3));
    final labels = await db.select(db.photoLabels).get();
    expect(labels, hasLength(6)); // 2 per asset
    final texts = await db.select(db.photoTexts).get();
    expect(texts, hasLength(3)); // OCR text stored per asset
    expect(texts.first.content, 'Hello world');
  });

  test('pausing mid-pass halts the ML loop until resume', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 5),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    // Pause the pass exactly when asset 0's worker call begins, and hold that
    // call open. That puts the pass genuinely in flight (sweep done, ML loop
    // started) with `_paused` set, so releasing the call labels asset 0 and
    // the loop's next iteration blocks on its inline `_paused` check.
    final firstCall = Completer<void>();
    late final IndexingService service;
    final worker = FakeMlWorker(
      labels: const [('Dog', 0.9)],
      beforeAnalyze: (i) {
        if (i == 0) {
          service.pause();
          return firstCall.future;
        }
        return Future<void>.value();
      },
    );
    await consentTo(search: true);
    service = serviceFor(photos, worker);
    final done = service.start();

    // Release asset 0's call: it is labelled, then the loop blocks before
    // asset 1. Poll until exactly one label lands.
    firstCall.complete();
    var labelled = 0;
    for (var i = 0; i < 50 && labelled == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      labelled = (await db.select(db.photoLabels).get()).length;
    }
    expect(labelled, 1, reason: 'asset 0 labelled before the pause takes hold');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      (await db.select(db.photoLabels).get()).length,
      1,
      reason: 'no further assets labelled while paused',
    );

    service.resume();
    await done;
    expect(await db.select(db.photoLabels).get(), hasLength(5)); // ML ran
  });

  test('progress emits are throttled, not one per asset', () async {
    // A 60-asset first run with a fast (fake) worker: without throttling the
    // dial would rebuild 60 times mid-pass. With the ~250 ms throttle the
    // whole pass completes inside one throttle window, so only the initial
    // emit + the unconditional final remaining:0 land — far fewer than assets.
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 60),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    final worker = FakeMlWorker(labels: const [('Dog', 0.9)]);
    await consentTo(search: true);
    final service = serviceFor(photos, worker);

    final emits = <IndexingStatus>[];
    final sub = service.watchStatus().listen(emits.add);
    // Let the stream's initial yield (idle) land before starting.
    await Future<void>.delayed(Duration.zero);
    await service.start();
    // The broadcast controller delivers events on microtasks; let the final
    // (post-loop, unconditional) emits drain before reading.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    // The throttle guarantee: strictly fewer emits than assets. (Even on a
    // slow host where the pass spills past one window, a handful of emits
    // is still << 60.)
    expect(emits.length, lessThan(60),
        reason: 'progress should be throttled, not emitted per asset');
    // The unconditional final emit ensures the dial reaches zero rather than
    // lingering on a throttled mid-pass value.
    expect(emits, contains(const IndexingStatus(remaining: 0, total: 60)));
    // The pass ends idle.
    expect(emits.last, const IndexingStatus.idle());
  });

  test('OCR runs on a distinct higher-res image', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 1),
      thumbnailBytes: Uint8List.fromList([1, 2, 3]),
    );
    final worker = FakeMlWorker(text: 'tiny caption text');
    await consentTo(search: true);

    await serviceFor(photos, worker).start();

    expect(worker.calls, hasLength(1));
    // OCR got its own (larger) bytes, separate from the label/face 512 bytes.
    expect(worker.ocrCalls.single, isNotNull);
    expect(worker.ocrCalls.single, isNot(worker.calls.single));
    final texts = await db.select(db.photoTexts).get();
    expect(texts.single.content, 'tiny caption text');
  });

  test('detected faces are stored and clustered into a person', () async {
    final emb = Float32List.fromList(List.filled(192, 0.1));
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 2),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    // Same embedding on both assets → should merge into one person.
    final worker = FakeMlWorker(
      faces: [(left: 0, top: 0, right: 10, bottom: 10, embedding: emb)],
    );
    await consentTo(faces: true);

    await serviceFor(photos, worker).start();

    expect(worker.faceRequests, everyElement(isTrue));
    expect(worker.contentRequests, everyElement(isFalse));
    final faceRows = await db.select(db.faceEmbeddings).get();
    expect(faceRows, hasLength(2)); // one face per asset
    final persons = await db.select(db.persons).get();
    expect(persons, hasLength(1)); // clustered together
    expect(faceRows.every((f) => f.personId == persons.first.id), isTrue);
  });

  test('a second pass skips already-indexed assets', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 2),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    final worker = FakeMlWorker();
    await consentTo(search: true);

    await serviceFor(photos, worker).start();
    expect(worker.calls, hasLength(2));

    // Same service instance, nothing new in the library.
    await serviceFor(photos, worker).start();
    expect(worker.calls, hasLength(2)); // no re-work
  });

  test('records an asset even when it has no thumbnail (no labels)', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 1),
      // thumbnailBytes null → labeling is skipped, asset still marked indexed.
    );
    final worker = FakeMlWorker();
    await consentTo(search: true); // the skip must be the *thumbnail*, not consent

    await serviceFor(photos, worker).start();

    expect(await db.indexDao.allCachedIds(), hasLength(1));
    expect(worker.calls, isEmpty);
    expect(await db.select(db.photoLabels).get(), isEmpty);
  });

  test('empty library does no work and ends idle', () async {
    final photos = FakePhotoLibraryService(thumbnailBytes: Uint8List(0));
    final worker = FakeMlWorker();
    final service = serviceFor(photos, worker);

    await service.start();

    expect(await db.indexDao.allCachedIds(), isEmpty);
    expect(worker.calls, isEmpty);
    expect((await service.watchStatus().first).isIndexing, isFalse);
  });

  test('a foreground library change re-sweeps in the new asset', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 1),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    final worker = FakeMlWorker();
    final service =
        serviceFor(photos, worker, debounce: const Duration(milliseconds: 5));
    addTearDown(service.dispose);

    await service.start();
    expect(await db.indexDao.allCachedIds(), hasLength(1));
    expect(photos.startChangeNotifyCount, 1); // listener registered once

    // A new photo lands while the app is foregrounded.
    photos.assets.add(
      AssetRef(id: 'new-asset', createdAt: DateTime(2026, 8, 15)),
    );
    photos.fireLibraryChange();
    await Future<void>.delayed(const Duration(milliseconds: 60)); // debounce + sweep

    expect(await db.indexDao.allCachedIds(), containsAll(<String>['new-asset']));
  });

  group('memory regeneration', () {
    /// A single-day burst big enough to clear `minTripAssets`, all labelled
    /// "Dog" so it also clears `minThemeAssets`.
    FakePhotoLibraryService burst({int count = 25}) => FakePhotoLibraryService(
          assets: assetsInMonth(2026, 5, count),
          thumbnailBytes: Uint8List.fromList([1, 2, 3]),
        );

    FakeMlWorker dogWorker() => FakeMlWorker(labels: const [('Dog', 0.9)]);

    // Memories are opt-in; this whole group is about what happens once the
    // user has enabled them.
    setUp(() => consentTo(search: true, memories: true));

    test('the first pass generates memories', () async {
      final service = serviceFor(burst(), dogWorker());
      addTearDown(service.dispose);

      await service.start();

      final cards = await db.memoriesDao.watchActive().first;
      expect(cards, isNotEmpty);
      expect(cards.map((c) => c.kind), containsAll(['trip', 'theme']));
    });

    test('a second pass on an unchanged library does not regenerate', () async {
      final photos = burst();
      final service = serviceFor(photos, dogWorker());
      addTearDown(service.dispose);

      await service.start();
      expect(await db.memoriesDao.watchActive().first, isNotEmpty);

      // Wipe them: only a real regeneration can bring them back.
      await db.memoriesDao.clearMemories();
      await service.start();

      expect(await db.memoriesDao.watchActive().first, isEmpty,
          reason: 'same day, too few new assets — nothing to redo');
    });

    test('enough new assets force a regeneration the same day', () async {
      final photos = burst();
      final service = serviceFor(photos, dogWorker(), memoryRefreshThreshold: 5);
      addTearDown(service.dispose);

      await service.start();
      await db.memoriesDao.clearMemories();

      photos.assets.addAll(assetsInMonth(2026, 5, 10, prefix: 'extra'));
      await service.start();

      expect(await db.memoriesDao.watchActive().first, isNotEmpty);
    });

    test('regeneration preserves a dismissed memory', () async {
      final service = serviceFor(burst(), dogWorker(), memoryRefreshThreshold: 1);
      addTearDown(service.dispose);

      await service.start();
      final first = (await db.memoriesDao.watchActive().first).first;
      await db.memoriesDao.hide(first.id);

      await service.start();

      final cards = await db.memoriesDao.watchActive().first;
      expect(cards.map((c) => c.id), isNot(contains(first.id)));
      expect((await db.memoriesDao.memoryById(first.id))!.hidden, isTrue);
    });

    test('rebuild wipes memories and regenerates from scratch', () async {
      final service = serviceFor(burst(), dogWorker());
      addTearDown(service.dispose);

      await service.start();
      final before = await db.memoriesDao.watchActive().first;
      expect(before, isNotEmpty);

      await service.rebuild();

      final after = await db.memoriesDao.watchActive().first;
      expect(after, isNotEmpty, reason: 'regenerated, not left empty');
      expect(after.map((c) => c.id), isNot(contains(before.first.id)),
          reason: 'rows were dropped, not reused');
    });
  });

  group('consent gating', () {
    FakePhotoLibraryService dogPhotos() => FakePhotoLibraryService(
          assets: assetsInMonth(2026, 5, 25),
          thumbnailBytes: Uint8List.fromList([1, 2, 3]),
        );

    FakeMlWorker faceWorker() => FakeMlWorker(
          labels: const [('Dog', 0.9)],
          faces: [
            (
              left: 0,
              top: 0,
              right: 10,
              bottom: 10,
              embedding: Float32List.fromList(List.filled(192, 0.1)),
            ),
          ],
        );

    // Bug: on first run the user granted search + memories + faces, analysis
    // completed, Memories appeared and People stayed empty — faces only showed
    // up after toggling face detection off and on in Settings.
    //
    // The three answers used to be persisted one at a time, each kicking its
    // own pass. The first kick won, and `start()` dropped the later ones
    // because a pass was already running — so the pass that actually ran had
    // read `faces_enabled` before it was written. It labelled everything,
    // stamped `indexed_at` on every asset anyway, and `pendingMlIds` (unstamped
    // rows only) never offered them again.
    test('consent granted mid-pass still derives faces', () async {
      // A pass is already in flight when the user answers the prompt.
      await consentTo(search: true);
      final gate = Completer<void>();
      final firstCall = Completer<void>();
      final worker = FakeMlWorker(
        labels: const [('Dog', 0.9)],
        faces: [
          (
            left: 0.2,
            top: 0.2,
            right: 0.5,
            bottom: 0.5,
            embedding: Float32List.fromList(List.filled(192, 0.1)),
          ),
        ],
        beforeAnalyze: (i) async {
          if (i == 0) {
            firstCall.complete();
            await gate.future;
          }
        },
      );
      final service = serviceFor(dogPhotos(), worker);
      addTearDown(service.dispose);

      final pass = service.start();
      await firstCall.future; // pass is now inside the ML loop, faces off

      await service.applyConsent(
        searchEnabled: true,
        memoriesEnabled: true,
        facesEnabled: true,
      );

      gate.complete();
      await pass;

      // The in-flight pass folded the new answer in and looped again, so the
      // faces the user consented to actually exist.
      expect(await db.select(db.faceEmbeddings).get(), isNotEmpty);
      expect(await db.select(db.persons).get(), isNotEmpty);
      // And nothing is left stranded: no asset is stamped-but-unanalyzed.
      expect(await db.indexDao.pendingMlIds(), isEmpty);
    });

    test('applyConsent persists all three answers and the answered marker',
        () async {
      final service = serviceFor(dogPhotos(), faceWorker());
      addTearDown(service.dispose);

      await service.applyConsent(
        searchEnabled: true,
        memoriesEnabled: false,
        facesEnabled: true,
      );

      expect(await db.settingsDao.readSearchEnabled(), isTrue);
      expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
      expect(await db.settingsDao.readFacesEnabled(), isTrue);
      expect(await db.settingsDao.readConsentRecorded(), isTrue);
    });

    test('applyConsent deletes what an upgrading user declines', () async {
      // Derive everything first, as a pre-consent build would have.
      await consentTo(search: true, faces: true, memories: true);
      final service = serviceFor(dogPhotos(), faceWorker());
      addTearDown(service.dispose);
      await service.start();
      expect(await db.select(db.faceEmbeddings).get(), isNotEmpty);
      expect(await db.select(db.photoLabels).get(), isNotEmpty);

      await service.applyConsent(
        searchEnabled: false,
        memoriesEnabled: false,
        facesEnabled: false,
      );

      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.select(db.photoLabels).get(), isEmpty);
      expect(await db.memoriesDao.watchActive().first, isEmpty);
      // The grid cache itself is not analysis, and must survive.
      expect(await db.indexDao.allCachedIds(), isNotEmpty);
    });

    test('with no consent at all, no ML runs and nothing is derived', () async {
      final worker = faceWorker();
      final service = serviceFor(dogPhotos(), worker);
      addTearDown(service.dispose);

      await service.start();

      // The grid still fills — the metadata sweep is not analysis.
      expect(await db.indexDao.allCachedIds(), isNotEmpty);
      // But the worker is never even asked: no thumbnail is rendered and the
      // isolate never spawns.
      expect(worker.calls, isEmpty);
      expect(await db.select(db.photoLabels).get(), isEmpty);
      expect(await db.select(db.photoTexts).get(), isEmpty);
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.memoriesDao.watchActive().first, isEmpty);
    });

    test('content search alone derives labels but no faces', () async {
      await consentTo(search: true);
      final worker = faceWorker();
      final service = serviceFor(dogPhotos(), worker);
      addTearDown(service.dispose);

      await service.start();

      expect(await db.select(db.photoLabels).get(), isNotEmpty);
      expect(worker.contentRequests, everyElement(isTrue));
      expect(worker.faceRequests, everyElement(isFalse));
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
    });

    test('disabling content search deletes labels and OCR text', () async {
      await consentTo(search: true);
      final service = serviceFor(dogPhotos(), faceWorker());
      addTearDown(service.dispose);

      await service.start();
      expect(await db.select(db.photoLabels).get(), isNotEmpty);

      await service.setSearchEnabled(false);

      expect(await db.select(db.photoLabels).get(), isEmpty);
      expect(await db.select(db.photoTexts).get(), isEmpty);
      // The library cache itself survives — the grid must not go blank.
      expect(await db.indexDao.allCachedIds(), isNotEmpty);
    });

    test('memories on, faces off yields memories but no person memories',
        () async {
      await consentTo(memories: true);
      final service = serviceFor(dogPhotos(), faceWorker());
      addTearDown(service.dispose);

      await service.start();

      final built = await db.memoriesDao.watchActive().first;
      expect(built, isNotEmpty);
      expect(
        built.map((m) => m.kind),
        isNot(contains(MemoryKind.person.name)),
        reason: 'person memories need face clusters the user declined',
      );
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
    });

    test('disabling faces deletes every embedding and person', () async {
      // Search on too, so the "labels survive" assertion below is meaningful.
      await consentTo(search: true, faces: true);
      final service = serviceFor(dogPhotos(), faceWorker());
      addTearDown(service.dispose);

      await service.start();
      expect(await db.select(db.faceEmbeddings).get(), isNotEmpty);
      expect(await db.select(db.persons).get(), isNotEmpty);

      await service.setFacesEnabled(false);

      // Consent withdrawn = data gone, not merely hidden.
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.settingsDao.readFacesEnabled(), isFalse);
      // Labels survive — only the face-derived data goes.
      expect(await db.select(db.photoLabels).get(), isNotEmpty);
    });

    test('disabling memories deletes the curated memories', () async {
      await consentTo(memories: true);
      final service = serviceFor(dogPhotos(), faceWorker());
      addTearDown(service.dispose);

      await service.start();
      expect(await db.memoriesDao.watchActive().first, isNotEmpty);

      await service.setMemoriesEnabled(false);

      expect(await db.memoriesDao.watchActive().first, isEmpty);
      expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
    });

    test('enabling faces backfills assets indexed while it was off', () async {
      // Content search on, faces off: the pass runs and stamps `indexed_at`,
      // which is precisely the state that makes a naive re-enable a no-op.
      await consentTo(search: true);
      final photos = dogPhotos();
      final worker = faceWorker();
      final service = serviceFor(photos, worker);
      addTearDown(service.dispose);

      await service.start();
      expect(await db.select(db.faceEmbeddings).get(), isEmpty);
      expect(await db.indexDao.pendingMlIds(), isEmpty);

      await service.setFacesEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await db.select(db.faceEmbeddings).get(), isNotEmpty);
      expect(worker.faceRequests.last, isTrue);
    });
  });

  test('rebuild clears the index (incl. persons) and re-sweeps', () async {
    final photos = FakePhotoLibraryService(
      assets: assetsInMonth(2026, 8, 2),
      thumbnailBytes: Uint8List.fromList([1]),
    );
    await consentTo(search: true, faces: true);
    final service = serviceFor(photos, FakeMlWorker());
    addTearDown(service.dispose);

    await service.start();
    expect(await db.indexDao.allCachedIds(), hasLength(2));
    // A stale person cluster a rebuild must wipe.
    await db.facesDao.createPerson();
    expect(await db.select(db.persons).get(), hasLength(1));

    final swept = <bool>[];
    final sub = service.watchSwept().listen(swept.add);

    await service.rebuild();
    await Future<void>.delayed(const Duration(milliseconds: 10)); // flush events
    await sub.cancel();

    expect(await db.indexDao.allCachedIds(), hasLength(2)); // re-swept
    expect(await db.select(db.persons).get(), isEmpty); // cluster cleared
    // Cache flips not-ready → ready during the rebuild (drives the spinner).
    expect(swept, containsAllInOrder([false, true]));
  });

  // Seeds two assets already indexed, each with an identical-embedding face
  // assigned to a *separate* person (p1 renamed) — the order-drift a global
  // re-cluster should heal. Returns (p1, p2).
  Future<(int, int)> seedTwoDriftedPersons() async {
    for (final id in const ['a', 'b']) {
      await db.indexDao.upsertIndexed(
        assetId: id,
        createdAt: DateTime(2026, 8, 1),
        isVideo: false,
        width: 1,
        height: 1,
        labels: const [],
        text: '',
      );
      await db.facesDao.insertFaces(id, [
        (left: 0, top: 0, right: 1, bottom: 1, embedding: Float32List.fromList([1, 0])),
      ]);
    }
    final faces = await db.facesDao.allFacesForClustering();
    final p1 = await db.facesDao.createPerson(coverAssetId: 'a');
    final p2 = await db.facesDao.createPerson(coverAssetId: 'b');
    await db.facesDao
        .assignPersonToFace(faces.firstWhere((f) => f.assetId == 'a').id, p1);
    await db.facesDao
        .assignPersonToFace(faces.firstWhere((f) => f.assetId == 'b').id, p2);
    await db.facesDao.renamePerson(p1, 'Alice');
    return (p1, p2);
  }

  FakePhotoLibraryService photosWithAbAnd(String extraId) =>
      FakePhotoLibraryService(assets: [
        AssetRef(id: 'a', createdAt: DateTime(2026, 8, 3)),
        AssetRef(id: 'b', createdAt: DateTime(2026, 8, 2)),
        AssetRef(id: extraId, createdAt: DateTime(2026, 8, 1)),
      ]);

  test('a pass past the threshold globally re-clusters, preserving the rename',
      () async {
    final (p1, _) = await seedTwoDriftedPersons();
    await consentTo(faces: true);
    // This is about clustering, not the pipeline upgrade: stamp the current
    // pipeline so nothing re-analyzes (and so discards) the seeded faces.
    await db.settingsDao.put('face_pipeline_version', '2');
    final service = serviceFor(
      photosWithAbAnd('c'),
      FakeMlWorker(), // no thumbnail bytes → c indexed, adds no faces
      reclusterThreshold: 1,
    );
    addTearDown(service.dispose);

    await service.start();

    final persons = await db.select(db.persons).get();
    expect(persons, hasLength(1)); // the two drifted persons collapsed to one
    expect(persons.single.id, p1); // reused the renamed person
    expect(persons.single.displayName, 'Alice'); // rename preserved
    final faceRows = await db.select(db.faceEmbeddings).get();
    expect(faceRows.every((f) => f.personId == p1), isTrue);
  });

  test('below the threshold the global re-cluster does not run', () async {
    await seedTwoDriftedPersons();
    await consentTo(faces: true);
    final service = serviceFor(
      photosWithAbAnd('c'),
      FakeMlWorker(),
      reclusterThreshold: 100, // 2 faces never reaches it
    );
    addTearDown(service.dispose);

    await service.start();

    expect(await db.select(db.persons).get(), hasLength(2)); // untouched
  });

  test('an install clustered by an older algorithm re-clusters once', () async {
    // Baseline written but no algorithm stamp — what an upgrade from the
    // centroid pass looks like. The stale grouping must be healed on the next
    // pass rather than waiting for another `reclusterThreshold` faces.
    await seedTwoDriftedPersons();
    await db.settingsDao.put('faces_at_last_recluster', '2');
    await db.settingsDao.put('face_pipeline_version', '2');
    await consentTo(faces: true);
    // Library holds only the two already-indexed assets — a fully indexed
    // install is the case that has to heal, and it is the one with no ML work
    // for the re-cluster to hang off.
    final service = serviceFor(
      FakePhotoLibraryService(assets: [
        AssetRef(id: 'a', createdAt: DateTime(2026, 8, 3)),
        AssetRef(id: 'b', createdAt: DateTime(2026, 8, 2)),
      ]),
      FakeMlWorker(),
      reclusterThreshold: 100, // 2 faces never reaches it
    );
    addTearDown(service.dispose);

    await service.start();

    expect(await db.select(db.persons).get(), hasLength(1));
    expect(await db.settingsDao.read('cluster_algo_version'), '2');
  });

  test('a face-pipeline change re-analyzes an already-indexed library',
      () async {
    // Stored embeddings came from the old detector/gate/crop, so they are not
    // comparable with what this build produces — only re-analyzing recovers
    // them, and `pendingMlIds` would otherwise never offer these assets again.
    await seedTwoDriftedPersons();
    await consentTo(faces: true);
    final worker = FakeMlWorker();
    final service = serviceFor(
      FakePhotoLibraryService(
        assets: [
          AssetRef(id: 'a', createdAt: DateTime(2026, 8, 3)),
          AssetRef(id: 'b', createdAt: DateTime(2026, 8, 2)),
        ],
        thumbnailBytes: Uint8List.fromList([1, 2, 3]),
      ),
      worker,
    );
    addTearDown(service.dispose);

    await service.start();

    expect(
      worker.calls,
      hasLength(2),
      reason: 'both already-indexed assets should have been re-analyzed',
    );
    expect(await db.settingsDao.read('face_pipeline_version'), '2');
  });

  test('a fresh install is stamped without a pointless re-analysis', () async {
    await consentTo(faces: true);
    final service = serviceFor(
      FakePhotoLibraryService(thumbnailBytes: Uint8List(0)),
      FakeMlWorker(),
    );
    addTearDown(service.dispose);

    await service.start();

    expect(await db.settingsDao.read('face_pipeline_version'), '2');
  });

  test('dispose stops the change listener', () async {
    final photos = FakePhotoLibraryService(thumbnailBytes: Uint8List(0));
    final service = serviceFor(photos, FakeMlWorker());
    await service.start();
    await service.dispose();
    expect(photos.stopChangeNotifyCount, 1);
  });

  test('dispose tears down the worker', () async {
    final worker = FakeMlWorker();
    final service = serviceFor(
      FakePhotoLibraryService(thumbnailBytes: Uint8List(0)),
      worker,
    );
    await service.dispose();
    expect(worker.disposed, isTrue);
  });
}
