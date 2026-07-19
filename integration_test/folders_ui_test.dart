import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

/// On-device UI flow for the Search screen's Folders section, driving the real
/// app against the real device library — the end-to-end counterpart to the host
/// widget tests (which render canned `DeviceFolder`s) and to
/// `device_folders_test.dart` (which exercises the service without the UI).
///
/// Run with:
///   `patrol test -t integration_test/folders_ui_test.dart -d DEVICE`
/// Requires seeded photos on the device (see phase2 plan).
void main() {
  /// Bounded pumps, never [PatrolIntegrationTester.pumpAndSettle]: the Search
  /// screen's autofocused TextField blinks a cursor forever, so the tree never
  /// settles once it is on screen (CLAUDE.md gotcha).
  Future<void> settleSearch(PatrolIntegrationTester $) async {
    for (var i = 0; i < 10; i++) {
      await $.tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Bounded pumps until [finder] matches, for the same reason. Fails with
  /// [reason] if it never does.
  Future<void> pumpUntil(
    PatrolIntegrationTester $,
    Finder finder, {
    required String reason,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (finder.evaluate().isNotEmpty) return;
      await $.tester.pump(const Duration(milliseconds: 200));
    }
    fail(reason);
  }

  patrolTest('folders: browse from Search into a folder grid', ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Allow photo access'), findsOneWidget);
    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);

    // Bottom nav → Search.
    await $.tester.tap(find.byTooltip('Search'));
    await settleSearch($);
    expect(find.byType(TextField), findsOneWidget,
        reason: 'The search field should be on screen — navigation failed.');

    // The Folders section lists real device buckets (Camera, Screenshots, …).
    // Polled: deviceFolders() makes two platform round-trips per bucket, so on
    // a library with many folders it resolves well after the first frame.
    await pumpUntil($, find.text('FOLDERS'),
        reason: 'The Folders section never appeared on the Search screen.');
    expect(find.textContaining(' photo'), findsWidgets); // "N photos" counts

    // Open the first folder row. Its name sits directly above the count in the
    // row, so tap the count text's row via the thumbnail beside it.
    final firstFolderThumb = find.descendant(
      of: find.byType(InkWell),
      matching: find.byType(AssetThumbnail),
    );
    expect(firstFolderThumb, findsWidgets,
        reason: 'Folder rows should render a cover thumbnail.');
    await $.tester.tap(firstFolderThumb.first);
    await settleSearch($);

    // The folder grid opened with photos in it (not the empty note).
    expect(find.textContaining('This folder is empty'), findsNothing);
    expect($(AssetThumbnail), findsWidgets);

    // Opening a photo from the folder grid reaches the detail viewer.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await $.pumpAndSettle();

    // Back out of the folder to Search.
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await settleSearch($);
    expect(find.text('FOLDERS'), findsOneWidget);
  });
}
