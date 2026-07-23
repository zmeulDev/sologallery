import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/folder_list.dart';

/// On-device UI flow for the Albums tab's Device folders section, driving the
/// real app against the real device library — the end-to-end counterpart to the
/// host widget tests (which render canned `DeviceFolder`s) and to
/// `device_folders_test.dart` (which exercises the service without the UI).
///
/// Folders live on Albums, not Search: they are a place to browse *collections*
/// rather than a way to narrow a query (see `search_screen.dart`'s `_IdleView`).
///
/// Run with:
///   `patrol test -t integration_test/folders_ui_test.dart -d DEVICE`
/// Requires seeded photos on the device (see phase2 plan).
void main() {
  /// Bounded pumps, never [PatrolIntegrationTester.pumpAndSettle]: an
  /// `AsyncValue` loading branch renders a [CircularProgressIndicator], which
  /// schedules a frame forever and so never settles (CLAUDE.md gotcha).
  Future<void> settle(PatrolIntegrationTester $) async {
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

  patrolTest('folders: browse from Albums into a folder grid', ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Allow photo access'), findsOneWidget);
    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    // Onboarding step 2 (analysis consent): decline all and continue.
    await $('Continue').tap();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);

    // Bottom nav → Albums.
    await $.tester.tap(find.byTooltip('Albums'));
    await settle($);

    // The Device folders section lists real buckets (Camera, Screenshots, …).
    // Polled, and polled *first*: deviceFolders() makes two platform
    // round-trips per bucket, and until it resolves a fresh install has no
    // albums, no people and no folders — so the screen is still showing its
    // full-screen empty state and not the sectioned body at all.
    await pumpUntil($, find.text('DEVICE FOLDERS'),
        reason: 'The Device folders section never appeared on Albums.');
    expect(find.text('ALBUMS'), findsOneWidget,
        reason: 'The sectioned body should have replaced the empty state.');
    expect(
      find.descendant(of: find.byType(FolderList), matching: find.byType(Text)),
      findsWidgets,
      reason: 'Each folder tile shows a name and a compact count.',
    );

    // The folder tiles are compact chips: a tappable GestureDetector wrapping a
    // surface2 pill (same StadiumBorder radius as the bottom nav capsule).
    // Scoped to [FolderList] so album cards up the page don't match a looser
    // finder.
    bool isFolderTile(Widget w) {
      if (w is! GestureDetector) return false;
      final child = w.child;
      if (child is! Container) return false;
      final decoration = child.decoration;
      return decoration is ShapeDecoration && decoration.shape is StadiumBorder;
    }

    final firstFolderRow = find.descendant(
      of: find.byType(FolderList),
      matching: find.byWidgetPredicate(isFolderTile),
    );
    expect(firstFolderRow, findsWidgets,
        reason: 'Folder rows should be tappable.');
    await $.scrollUntilVisible(finder: $(firstFolderRow).first);
    await $.tester.tap(firstFolderRow.first);
    await settle($);

    // The folder grid opened with photos in it (not the empty note).
    expect(find.textContaining('This folder is empty'), findsNothing);
    expect($(AssetThumbnail), findsWidgets);

    // Opening a photo from the folder grid reaches the detail viewer.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    await $.tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await $.pumpAndSettle();

    // Back out of the folder to Albums.
    await $.tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle($);
    expect(find.text('DEVICE FOLDERS'), findsOneWidget);
  });
}
