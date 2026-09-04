import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sologallery/core/database/app_database.dart';
import 'package:sologallery/features/search/domain/search_date.dart';
import 'package:sologallery/services/ml_service.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof of the real ML path: spawns the actual [MlWorkerController]
/// isolate (binds the plugin messenger, runs ML Kit's bundled image-labeling
/// model on a downsized thumbnail), writes `photo_asset`/`photo_label`, and
/// checks content search finds a labeled photo.
///
/// The paired real-path counterpart to the host tests using `FakeMlWorker`
/// (AGENTS.md fake-pairing rule) — the isolate binding hang and the real model
/// can't run under `flutter test`.
///
/// Requires photo access already granted and at least one photo. Run:
///   flutter test integration_test/ml_indexing_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('real worker labels device photos; content search finds them', () async {
    final photos = PhotoLibraryService();
    final access = await photos.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access before running (open the app once and allow).',
    );

    final metaRows = [
      ...await photos.libraryMetadataPage(dated: true, page: 0, pageSize: 20),
      ...await photos.libraryMetadataPage(dated: false, page: 0, pageSize: 20),
    ];
    final ids = [for (final r in metaRows) r.id];
    expect(ids, isNotEmpty, reason: 'Need at least one photo on device.');

    // In-memory DB so the test never touches the real app database.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final worker = MlWorkerController();
    addTearDown(() async => await worker.dispose());

    var anyLabel = <String, double>{};
    var labeledAssetId = '';
    var anyFace = false;

    // Index a bounded handful end-to-end through the *real* isolate. The bytes
    // go straight to the worker over the SendPort — the worker writes its own
    // temps, so this test mirrors the production path (no UI-isolate file I/O).
    for (final id in ids.take(5)) {
      final meta = await photos.assetIndexMeta(id);
      if (meta == null) continue;
      final bytes = await photos.thumbnail(id, 512, 512);
      if (bytes == null) continue;

      // Higher-res OCR image (matches IndexingService): OCR on 1024, labels/
      // faces on the 512 bytes. Exercises the real analyze(ocrBytes:) path.
      final ocrBytes = await photos.thumbnail(id, 1024, 1024);
      final analysis = await worker.analyze(
        bytes: bytes,
        ocrBytes: ocrBytes,
      ); // real ML Kit + higher-res OCR

      await db.indexDao.upsertIndexed(
        assetId: id,
        createdAt: meta.createdAt,
        isVideo: meta.isVideo,
        width: meta.width,
        height: meta.height,
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
      if (analysis.faces.isNotEmpty) anyFace = true;
      if (analysis.labels.isNotEmpty && anyLabel.isEmpty) {
        anyLabel = {analysis.labels.first.$1: analysis.labels.first.$2};
        labeledAssetId = id;
      }
    }

    // The pipeline wrote index rows (the isolate ran and the DB accepted them).
    expect(await db.indexDao.allCachedIds(), isNotEmpty);

    // If any face was detected, the real tflite embedder produced a non-empty
    // vector and it was stored (proves the FFI model runs in the isolate).
    final faceRows = await db.select(db.faceEmbeddings).get();
    if (anyFace) {
      expect(faceRows, isNotEmpty);
      expect(faceRows.first.embedding.length, greaterThan(0));
    }

    // If the model produced any label, content search must surface that asset.
    if (anyLabel.isNotEmpty) {
      final term = anyLabel.keys.first;
      final results = await db.indexDao.searchContent(
        query: term,
        type: MediaTypeFilter.all,
        favoritesOnly: false,
        limit: 50,
        offset: 0,
      );
      expect(
        results.map((r) => r.id),
        contains(labeledAssetId),
        reason: 'Label "$term" was written but content search did not find it.',
      );
    }
  });
}
