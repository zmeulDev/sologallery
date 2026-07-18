import 'dart:io' show File;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
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
/// (CLAUDE.md fake-pairing rule) — the isolate binding hang and the real model
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

    final ids = await photos.allAssetIds(page: 0, pageSize: 20);
    expect(ids, isNotEmpty, reason: 'Need at least one photo on device.');

    // In-memory DB so the test never touches the real app database.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final worker = MlWorkerController();
    addTearDown(worker.dispose);
    final tempDir = await getTemporaryDirectory();

    var anyLabel = <String, double>{};
    var labeledAssetId = '';

    // Index a bounded handful end-to-end through the *real* isolate.
    for (final id in ids.take(5)) {
      final meta = await photos.assetIndexMeta(id);
      if (meta == null) continue;
      final bytes = await photos.thumbnail(id, 512, 512);
      if (bytes == null) continue;

      final file = File('${tempDir.path}/ml_test_${id.hashCode}.jpg');
      await file.writeAsBytes(bytes, flush: true);
      final analysis = await worker.analyzeFile(file.path); // real ML Kit + OCR
      if (await file.exists()) await file.delete();

      await db.indexDao.upsertIndexed(
        assetId: id,
        createdAt: meta.createdAt,
        isVideo: meta.isVideo,
        width: meta.width,
        height: meta.height,
        labels: analysis.labels,
        text: analysis.text,
      );
      if (analysis.labels.isNotEmpty && anyLabel.isEmpty) {
        anyLabel = {analysis.labels.first.$1: analysis.labels.first.$2};
        labeledAssetId = id;
      }
    }

    // The pipeline wrote index rows (the isolate ran and the DB accepted them).
    expect(await db.indexDao.indexedAssetIds(), isNotEmpty);

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
