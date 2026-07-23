import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/detail/domain/asset_detail_display.dart';
import 'package:sologallery/features/detail/domain/zoom_transform.dart';
import 'package:sologallery/features/detail/widgets/detail_action_bar.dart';
import 'package:sologallery/features/detail/widgets/photo_page.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

/// On-device detail viewer + actions, driving the *real* `photo_manager`,
/// `share_plus`, and Drift paths — the paired counterpart to the host tests that
/// use `FakePhotoLibraryService` (CLAUDE.md "fake-pairing rule").
///
/// Run with: `patrol test -t integration_test/detail_actions_test.dart`.
/// Requires seeded photos on the device (asserts against the real library);
/// see docs/plans/phase2-permissions-gallery.md.
void main() {
  Future<void> bootAndGrant(PatrolIntegrationTester $) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Allow photo access'), findsOneWidget);
    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    // Onboarding step 2 (analysis consent): decline all and continue.
    await $('Continue').tap();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);
  }

  /// Returns the first non-video asset in the library. The very first grid cell
  /// can be a video on some seeded devices, and the double-tap zoom test needs
  /// a still photo.
  Future<String> firstStillAssetId(PatrolIntegrationTester $) async {
    final service = PhotoLibraryService();
    final page = await service.libraryMetadataPage(
      dated: true,
      page: 0,
      pageSize: 60,
    );
    for (final asset in page) {
      if (!await service.isVideoAsset(asset.id)) return asset.id;
    }
    throw Exception('no still assets on device — seed test_assets/');
  }

  patrolTest('open a photo → favorite, view EXIF, add to album', ($) async {
    await bootAndGrant($);

    // Open the first photo into the detail viewer.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    expect($(DetailActionBar), findsOneWidget);

    // Favorite — the heart fills and the flag persists in Drift.
    await $.tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await $.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    // Reveal EXIF metadata, then dismiss the sheet by tapping its barrier.
    await $.tester.tap(find.byIcon(Icons.info_outline_rounded));
    await $.pumpAndSettle();
    expect($('DETAILS'), findsOneWidget);
    await $.tester.tapAt(const Offset(20, 20));
    await $.pumpAndSettle();

    // Add to a freshly created album — the disc in the top bar.
    await $.tester.tap(find.byTooltip('Add to album'));
    await $.pumpAndSettle();
    await $.tester.enterText(find.byType(TextField), 'Patrol Trip');
    await $.tester.tap(find.text('Create'));
    await $.pumpAndSettle();
    expect($('Added to Patrol Trip'), findsOneWidget);

    // Back to the Library grid.
    await $.tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await $.pumpAndSettle();
    expect($('Library'), findsWidgets);
  });

  patrolTest('double tap zooms in on a real photo, and back out', ($) async {
    await bootAndGrant($);
    final stillId = await firstStillAssetId($);
    await $.tester.tap(
      find.byWidgetPredicate(
        (w) => w is AssetThumbnail && w.assetId == stillId,
        description: 'AssetThumbnail($stillId)',
      ),
    );
    await $.pumpAndSettle();

    Matrix4 transform() =>
        $.tester.widget<PhotoPage>(find.byType(PhotoPage)).transformController!
            .value;

    expect(transform(), Matrix4.identity(), reason: 'opens at fit');

    final centre = $.tester.getCenter(find.byType(PhotoPage));
    // Raw down/up pairs with nothing in between: under the live binding a
    // pumpAndSettle here would burn past kDoubleTapTimeout and the two taps
    // would read as two singles.
    Future<void> doubleTap() async {
      for (var i = 0; i < 2; i++) {
        final gesture = await $.tester.startGesture(centre);
        await gesture.up();
      }
      await $.pumpAndSettle();
    }

    // This is the assertion host tests structurally cannot make: on host,
    // detailImageProvider is stubbed to null so no InteractiveViewer ever
    // renders and nothing competes for the gesture. Against a real decoded
    // photo it does — which is exactly how the arena-starvation bug hid.
    await doubleTap();
    expect(transform(), isNot(Matrix4.identity()), reason: 'zoomed in');
    expect(transform().entry(0, 0), closeTo(kDoubleTapZoomScale, 1e-6));

    await doubleTap();
    expect(transform(), Matrix4.identity(), reason: 'back to fit');
  });

  patrolTest('a photo library reports coordinates for at least one asset', (
    $,
  ) async {
    // The Location chip's data path — AssetEntity.latlngAsync — is a platform
    // round-trip that host fakes stub out entirely, and on Android 10+ the
    // *synchronous* getters always return null, so only a device run proves it.
    // Rendering is covered by the host widget test and the exif_sheet golden.
    await bootAndGrant($);
    final service = PhotoLibraryService();
    final page = await service.libraryMetadataPage(
      dated: true,
      page: 0,
      pageSize: 60,
    );
    expect(page, isNotEmpty, reason: 'no assets on device — seed test_assets/');

    String? located;
    for (final asset in page) {
      final detail = await service.assetDetail(asset.id);
      final coords = formatCoordinates(detail?.latitude, detail?.longitude);
      if (coords != null) {
        located = coords;
        break;
      }
    }
    // Fail loudly rather than pass vacuously: "no photo had GPS" and "GPS
    // reading is broken" are indistinguishable from a silent skip.
    if (located == null) {
      fail(
        'No asset in the first 60 reported coordinates. Either GPS reading '
        'regressed, or the device library has no geotagged photo — seed the '
        'GPS JPEG from test_assets/ and re-run.',
      );
    }
    expect(located, matches(RegExp(r'^-?\d+\.\d{4}, -?\d+\.\d{4}$')));
  });

  patrolTest('share opens the OS share sheet', ($) async {
    await bootAndGrant($);
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();

    // Share lives in the top bar now, on its own scrim disc.
    await $.tester.tap(find.byTooltip('Share'));
    await $.pumpAndSettle();
    // The OS share sheet is a system surface; enable per device and assert its
    // labels via the platform automator (labels are device/locale-specific).
  }, skip: true);

  patrolTest('delete a seeded photo removes it and purges rows', ($) async {
    // Destructive — must target a throwaway *seeded* asset, never the device's
    // own photos. Seed first (CLAUDE.md deterministic-assets):
    //   adb push test_assets/ /sdcard/Pictures/SoloGalleryTest/
    // Then open that asset, tap delete, confirm our dialog, drive the OS trash
    // dialog, and assert it leaves the grid. Left skipped until test_assets/ is
    // populated (deferred since Phase 2).
    await bootAndGrant($);
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();

    await $.tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await $.pumpAndSettle();
    expect($('Delete photo?'), findsOneWidget);
    await $('Delete').tap();
    await $.pumpAndSettle();
    // Android renders its own trash confirmation:
    await $.platform.mobile.tap(Selector(text: 'Allow'));
    await $.pumpAndSettle();
    expect($('Photo deleted'), findsOneWidget);
  }, skip: true); // Enable once test_assets/ holds a throwaway asset.
}
