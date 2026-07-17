import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/limited_access_banner.dart';

/// On-device permission matrix + real-path grid smoke.
///
/// These drive the *real* `photo_manager` permission flow and grid — the paired
/// on-device counterpart to the host tests that use `FakePhotoLibraryService`
/// (CLAUDE.md "fake-pairing rule"). `clearPackageData=true` in the JUnit runner
/// resets app data and permissions between cases, so each starts fresh.
///
/// Run with: `patrol test -t integration_test/permission_matrix_test.dart`.
/// Requires seeded photos on the device (Library asserts against the real
/// library); see docs/plans/phase2-permissions-gallery.md.
void main() {
  Future<void> bootOnboarding(PatrolIntegrationTester $) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    // Fresh install → no access → onboarding gate.
    expect($('Allow photo access'), findsOneWidget);
  }

  patrolTest('granting full access reveals the month grid', ($) async {
    await bootOnboarding($);

    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse(); // "Allow all" on Android 14+
    await $.pumpAndSettle();

    // Redirected off onboarding into the Library.
    expect($('Allow photo access'), findsNothing);
    expect($('Library'), findsWidgets);
    // A device with photos shows sections (thumbnails), not the empty state.
    expect($('No photos yet'), findsNothing);
    expect($(AssetThumbnail), findsWidgets);
  });

  patrolTest('denying access keeps the user on onboarding', ($) async {
    await bootOnboarding($);

    await $('Allow photo access').tap();
    await $.platform.mobile.denyPermission();
    await $.pumpAndSettle();

    // Still gated, now offering the Settings path.
    expect($('Open Settings'), findsOneWidget);
  });

  patrolTest('limited access shows the selected-photos banner', ($) async {
    await bootOnboarding($);

    await $('Allow photo access').tap();
    // Android 14 photo dialog: choose "Allow limited access", then the picker.
    await $.platform.mobile.tap(Selector(text: 'Allow limited access'));
    // Confirm the (empty or default) selection in the system photo picker.
    await $.platform.mobile.tap(Selector(text: 'Allow'));
    await $.pumpAndSettle();

    expect($(LimitedAccessBanner), findsOneWidget);
  }, skip: true); // Picker flow is device-specific; enable per-device.
}
