import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// On-device proof that the **real** `photo_manager` change notification
/// reaches [PhotoLibraryService.startLibraryChangeNotify] — the path the host
/// `FakePhotoLibraryService` stands in for (AGENTS.md "fake-pairing rule").
/// The host `indexing_service_test` fires the callback synthetically; only a
/// device can prove the native MediaStore/PhotoKit observer actually fires it.
///
/// Adds one app-owned image to the library, waits for the observer, then
/// removes it.
///
/// **This is a `patrol` test, not a plain `integration_test`, purely because of
/// the cleanup.** On Android 11+ `PhotoManager.editor.deleteWithIds` goes
/// through `MediaStore.createDeleteRequest`, which puts up a *system*
/// confirmation dialog. A plain `integration_test` has no way to tap it, so the
/// teardown hangs until the run times out — the assertion itself passes long
/// before that. Patrol can drive the dialog, so the probe is really deleted
/// rather than left to disappear with the app's uninstall.
///
/// Run with:
///   patrol test -t integration_test/cache_live_update_test.dart -d DEVICE_ID
void main() {
  patrolTest('a real library change fires the registered listener', ($) async {
    final service = PhotoLibraryService();

    // No UI is pumped here, so nothing has raised the permission dialog yet —
    // `grantPermissionWhenInUse` on its own would 404 with nothing to tap.
    // Kick the request first, then tap the dialog it puts up.
    if (!(await service.currentAccess()).canReadLibrary) {
      final request = PhotoManager.requestPermissionExtend();
      await $.platform.mobile.grantPermissionWhenInUse();
      await request;
    }
    final access = await service.currentAccess();
    expect(
      access.canReadLibrary,
      isTrue,
      reason: 'The photo permission dialog was not granted.',
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

    // Cleanup, inline rather than in a tearDown: the delete only completes once
    // the system dialog is confirmed, and both halves have to run in order.
    //
    // The selector targets the dialog's **resource id**, not its text.
    // `MediaStore.createDeleteRequest`'s confirmation is a stock
    // `android:id/button1`/`button2` AlertDialog (positive/negative,
    // `com.google.android.providers.media.module`) — those two framework ids
    // are the one thing guaranteed stable across device locale and OEM skin.
    // A text selector isn't: on a device set to Romanian this dialog reads
    // "Permiți ca SoloGallery să șteargă această fotografie?" over
    // `Refuz`/`Permite`, not `Deny`/`Allow` — confirmed via
    // `NativeAutomator2.getNativeViews` on the Samsung SM-S938B test device
    // (docs/gotchas.md). `textContains: 'Allow'` would also match the dialog
    // *title* first — a non-clickable TextView — reporting the tap a success
    // while the dialog stays up and the delete never returns.
    final deletion = PhotoManager.editor.deleteWithIds([saved.id]);
    await $.platform.mobile.tap(
      Selector(resourceId: 'android:id/button1'),
      timeout: const Duration(seconds: 20),
    );
    final deleted = await deletion;
    expect(
      deleted,
      contains(saved.id),
      reason: 'The probe image was not removed from the library.',
    );
  });
}
