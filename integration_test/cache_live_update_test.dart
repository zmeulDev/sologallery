import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof that the **real** `photo_manager` change notification
/// reaches [PhotoLibraryService.startLibraryChangeNotify] — the path the host
/// `FakePhotoLibraryService` stands in for (CLAUDE.md "fake-pairing rule").
/// The host `indexing_service_test` fires the callback synthetically; only a
/// device can prove the native MediaStore/PhotoKit observer actually fires it.
///
/// Adds one app-owned image to the library (deletable without a system dialog
/// since the app contributed it), waits for the observer, then removes it.
///
/// Requires photo access already granted. Run with:
///   flutter test integration_test/cache_live_update_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('a real library change fires the registered listener', () async {
    final service = PhotoLibraryService();
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'Grant photo access before running (open the app once and allow).',
    );

    var fired = 0;
    await service.startLibraryChangeNotify(() => fired++);
    addTearDown(service.stopLibraryChangeNotify);

    // A tiny app-owned PNG dropped into the library should trip the observer.
    final bytes = img.encodePng(img.Image(width: 2, height: 2));
    final saved = await PhotoManager.editor.saveImage(
      bytes,
      filename: 'sg_live_update_probe.png',
    );
    addTearDown(() => PhotoManager.editor.deleteWithIds([saved.id]));

    // Poll for the native callback (observer latency varies by platform).
    for (var i = 0; i < 50 && fired == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    expect(
      fired,
      greaterThan(0),
      reason: 'startLibraryChangeNotify callback never fired after a real '
          'library insert — foreground re-sweep would not trigger.',
    );
  });
}
