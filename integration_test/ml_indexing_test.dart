import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/search/domain/search_date.dart';
import 'package:sologallery/services/ml_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

import 'support/fixture_file.dart';

/// On-device proof of the real ML path, over **deterministic seeded fixtures** —
/// never whatever happens to be in the developer's camera roll
/// (ARCHITECTURE.md#deterministic-test-assets). Spawns the actual
/// [MlWorkerController] isolate (binds the plugin messenger, runs ML Kit's
/// bundled image-labeling / text-recognition / face-detection models plus the
/// MobileFaceNet tflite embedder), writes `photo_asset` / `photo_label` /
/// `face_embeddings`, and checks content search finds a labeled photo.
///
/// The paired real-path counterpart to the host tests using `FakeMlWorker`
/// (AGENTS.md fake-pairing rule) — the isolate binding hang, the real models,
/// and the HEIC-thumbnail memory path can't run under `flutter test`.
///
/// **Fixtures.** `synthetic_face.jpg`, `no_exif.jpg` and `large_48mp.heic` are
/// pushed to the app's private storage (not bundled, not the photo library —
/// see `support/fixture_file.dart`). Push once before running:
///
///   iOS:      xcrun devicectl device copy to --device DEVICE_ID
///               --domain-type appDataContainer
///               --domain-identifier com.zmeul.sologallery
///               --source test_assets/synthetic_face.jpg
///               --source test_assets/no_exif.jpg
///               --source test_assets/large_48mp.heic --destination Documents
///   Android:  adb push test_assets/synthetic_face.jpg test_assets/no_exif.jpg
///               test_assets/large_48mp.heic
///               /sdcard/Android/data/com.zmeul.sologallery/files/
///
/// The 48MP HEIC case additionally needs it as a real library asset, so the
/// test copies the pushed file into the photo library once (reusing it on later
/// runs, keyed by its unique 8000×6000 dimensions). It is **not** deleted —
/// iOS/Android both put up a system confirmation a plain `integration_test`
/// cannot tap (see `cache_live_update_test.dart`). Remove the `sg_ml_heic`
/// asset by hand when the remediation backlog is done.
///
/// Requires **full** photo access already granted (open the app once and allow).
/// Run with:
///   flutter test integration_test/ml_indexing_test.dart -d DEVICE_ID --no-uninstall
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real worker derives deterministic content from the seeded fixtures',
    () async {
      final faceBytes =
          await (await fixtureFile('synthetic_face.jpg')).readAsBytes();
      final labelBytes = await (await fixtureFile('no_exif.jpg')).readAsBytes();

      // In-memory DB so the test never touches the real app database.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final worker = MlWorkerController();
      addTearDown(() async => await worker.dispose());

      // --- Task 2.1: face + labels, straight from the fixture bytes ----------
      //
      // No photo library is needed for these — the same path
      // `test_fixtures_test.dart` / `consent_test.dart` already use. The asset
      // ids are synthetic (these bytes never came from `photo_manager`); they
      // just key the in-memory rows.
      Future<void> indexBytes(String id, Uint8List bytes) async {
        final analysis = await worker.analyze(bytes: bytes, ocrBytes: bytes);
        await db.indexDao.upsertIndexed(
          assetId: id,
          createdAt: DateTime(2026),
          isVideo: false,
          width: 0,
          height: 0,
          labels: analysis.labels,
          text: analysis.text,
        );
        await db.facesDao.insertFaces(id, [
          for (final f in analysis.faces)
            (
              left: f.left,
              top: f.top,
              right: f.right,
              bottom: f.bottom,
              embedding: f.embedding,
            ),
        ]);
      }

      const faceId = 'sg-fixture-synthetic-face';
      const labelId = 'sg-fixture-no-exif';
      await indexBytes(faceId, faceBytes);
      await indexBytes(labelId, labelBytes);

      // synthetic_face.jpg → a face embedding with a normalized box. The fixture
      // is a proven positive control (test_fixtures_test.dart); if the real
      // detector + embedder produce nothing here the pipeline is broken.
      final faceRows = await (db.select(
        db.faceEmbeddings,
      )..where((f) => f.assetId.equals(faceId))).get();
      expect(faceRows, isNotEmpty, reason: 'no face for synthetic_face.jpg');
      for (final r in faceRows) {
        for (final edge in [r.left, r.top, r.right, r.bottom]) {
          expect(edge, inInclusiveRange(0.0, 1.0));
        }
        expect(r.right, greaterThan(r.left));
        expect(r.bottom, greaterThan(r.top));
        expect(r.embedding.length, greaterThan(0));
        expect(
          r.embedding.any((b) => b != 0),
          isTrue,
          reason: 'MobileFaceNet returned an all-zero embedding',
        );
      }

      // no_exif.jpg → the XOR-gradient JPEG the labeler tags "Pattern" (~0.90) /
      // "Tile" (~0.74). `small_png.png`, the README's nominal "labeling fast
      // path" fixture, is a 64×64 gradient that produces *no* label above the
      // 0.6 threshold — measured on device — so it can't back a
      // "content was derived" assertion; `no_exif.jpg` can.
      final labelRows = await (db.select(
        db.photoLabels,
      )..where((l) => l.assetId.equals(labelId))).get();
      expect(labelRows, isNotEmpty, reason: 'no label for no_exif.jpg');
      expect(
        labelRows.map((r) => r.label),
        contains('Pattern'),
        reason: 'expected the measured "Pattern" label for no_exif.jpg',
      );
      for (final r in labelRows) {
        expect(r.confidence, greaterThanOrEqualTo(0.6));
      }

      // Content search must surface the labeled asset.
      final results = await db.indexDao.searchContent(
        query: 'Pattern',
        type: MediaTypeFilter.all,
        favoritesOnly: false,
        limit: 50,
        offset: 0,
      );
      expect(
        results.map((r) => r.id),
        contains(labelId),
        reason: 'label "Pattern" was written but content search did not find it',
      );

      // --- Task 2.2: the 48MP HEIC, end to end through photo_manager ---------
      //
      // The point is that the indexer feeds ML a *downsized thumbnail*, never
      // the ~48MP original — the HEIC-OOM regression guard. That needs the HEIC
      // as a real `AssetEntity`, so it goes through the photo library.
      final photos = PhotoLibraryService();
      expect(
        (await photos.currentAccess()).canReadLibrary,
        isTrue,
        reason: 'grant full photo access first (open the app once and allow)',
      );
      final heic = await _seedOrReuseHeic(photos);

      final meta = await photos.assetIndexMeta(heic.id);
      expect(meta, isNotNull, reason: 'seeded HEIC did not resolve');
      expect(meta!.width, greaterThanOrEqualTo(7000));
      expect(meta.height, greaterThanOrEqualTo(5000));

      final thumb = await photos.thumbnail(heic.id, 512, 512, indexing: true);
      expect(thumb, isNotNull, reason: 'no thumbnail for the seeded HEIC');

      // The indexer feeds ML this thumbnail, never the ~48MP original — decoding
      // 8000×6000 to a bitmap is the OOM. Prove it is dimensionally downsized:
      // strictly smaller than the source, and small enough that a Dart-side
      // decode (ml_service crops faces off it) can't blow the heap.
      final decoded = img.decodeImage(thumb!)!;
      expect(decoded.width, lessThan(meta.width));
      expect(decoded.height, lessThan(meta.height));
      expect(
        decoded.width < 2048 && decoded.height < 2048,
        isTrue,
        reason: 'indexing thumbnail is ${decoded.width}×${decoded.height} — '
            'not the downsized image the indexer is supposed to request',
      );
      final heicOcr = await photos.thumbnail(heic.id, 1024, 1024, indexing: true);

      final heicAnalysis = await worker.analyze(bytes: thumb, ocrBytes: heicOcr);
      await db.indexDao.upsertIndexed(
        assetId: heic.id,
        createdAt: meta.createdAt,
        isVideo: meta.isVideo,
        width: meta.width,
        height: meta.height,
        labels: heicAnalysis.labels,
        text: heicAnalysis.text,
      );

      final heicRow = await (db.select(
        db.photoAssets,
      )..where((a) => a.assetId.equals(heic.id))).getSingle();
      expect(
        heicRow.indexedAt,
        isNotNull,
        reason: 'the 48MP HEIC never finished indexing (indexedAt not stamped)',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

/// The seeded `large_48mp.heic` as a photo-library asset. Reuses a copy left by
/// an earlier run (unique 8000×6000 dimensions) so runs don't pile up HEICs;
/// otherwise copies the pushed fixture in once. Never deletes it — the OS
/// deletion prompt can't be driven from a plain `integration_test`.
Future<AssetEntity> _seedOrReuseHeic(PhotoLibraryService photos) async {
  for (var page = 0; page < 10; page++) {
    final rows = await photos.libraryMetadataPage(
      dated: true,
      page: page,
      pageSize: 100,
    );
    if (rows.isEmpty) break;
    for (final r in rows) {
      if (!r.isVideo && r.width == 8000 && r.height == 6000) {
        final entity = await AssetEntity.fromId(r.id);
        if (entity != null) return entity;
      }
    }
  }
  final file = await fixtureFile('large_48mp.heic');
  try {
    return await PhotoManager.editor.saveImageWithPath(
      file.path,
      title: 'sg_ml_heic.heic',
    );
  } catch (e) {
    fail(
      'Could not copy large_48mp.heic into the photo library ($e). Grant '
      'full (not limited) photo access and re-run.',
    );
  }
}
