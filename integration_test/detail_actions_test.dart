import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/detail/widgets/detail_action_bar.dart';
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

    // Add to a freshly created album.
    await $.tester.tap(find.byIcon(Icons.add_to_photos_outlined));
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

  patrolTest('share opens the OS share sheet', ($) async {
    await bootAndGrant($);
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();

    await $.tester.tap(find.byIcon(Icons.ios_share_rounded));
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
