import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/detail/widgets/video_page.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/section_header.dart';
import 'package:video_player/video_player.dart';

/// On-device video playback, driving the *real* `photo_manager` video query and
/// `video_player` controller — the paired counterpart to the host tests that
/// stub `FakePhotoLibraryService.videoFile` (CLAUDE.md "fake-pairing rule").
/// This is the path that would hide a native controller-init or codec failure
/// from `flutter test`.
///
/// Run with: `patrol test -t integration_test/video_playback_test.dart`.
/// Requires **at least one video** in the device library (grid cells with a
/// [DurationBadge]). Populate `test_assets/` with the seed video to make this
/// deterministic (deferred since Phase 2).
void main() {
  patrolTest('open a video → it renders a real player', ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Continue'), findsOneWidget);
    await $('Continue').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    // Onboarding step 2 (analysis consent): decline all and continue.
    await $('Continue').tap();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);

    // Videos aren't always among a month's six previews, so open the newest
    // month's full grid, then scroll to the first video (marked by a
    // [DurationBadge]) and open it. The whole section header row is the
    // destination — there is no separate "view all" control.
    await $(SectionHeader).first.tap();
    await $.pumpAndSettle();
    await $.scrollUntilVisible(finder: $(DurationBadge).first);
    await $(DurationBadge).first.tap();
    await $.pumpAndSettle();

    // The video branch is chosen and the real controller initializes on device
    // (VideoPlayer only mounts once initialize() completes — reaching it means
    // the local file resolved and the platform decoder came up).
    expect($(VideoPage), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget);

    // Tap toggles play/pause without crashing.
    await $.tester.tap(find.byType(VideoPage));
    await $.pump(const Duration(milliseconds: 300));
    await $.tester.tap(find.byType(VideoPage));
    await $.pumpAndSettle();
  });
}
