import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/detail/widgets/detail_action_bar.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

/// On-device Saved + Albums flows, driving the *real* `photo_manager` + Drift
/// paths — the paired counterpart to the host widget tests (CLAUDE.md
/// "fake-pairing rule"). Run with:
///   `patrol test -t integration_test/saved_albums_test.dart -d DEVICE`
/// Requires seeded photos on the device (see phase2 plan).
void main() {
  Future<void> bootAndGrant(PatrolIntegrationTester $) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Allow photo access'), findsOneWidget);
    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);
  }

  patrolTest('favorite round-trip: detail → Saved tab → unfavorite', ($) async {
    await bootAndGrant($);

    // Open the first library photo and normalize it to favorited.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    expect($(DetailActionBar), findsOneWidget);
    if (find.byIcon(Icons.favorite_border).evaluate().isEmpty) {
      await $.tester.tap(find.byIcon(Icons.favorite)); // was already favorited
      await $.pumpAndSettle();
    }
    await $.tester.tap(find.byIcon(Icons.favorite_border));
    await $.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    // Back to Library, then over to the Saved tab — the favorite shows there.
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await $.pumpAndSettle();
    await $.tester.tap(find.byTooltip('Saved'));
    await $.pumpAndSettle();
    expect($(AssetThumbnail), findsWidgets);

    // Open it from Saved and unfavorite — the round-trip persists in Drift.
    await $(AssetThumbnail).first.tap();
    await $.pumpAndSettle();
    await $.tester.tap(find.byIcon(Icons.favorite));
    await $.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await $.pumpAndSettle();
  });

  patrolTest('albums: create, open, then delete', ($) async {
    await bootAndGrant($);

    await $.tester.tap(find.byTooltip('Albums'));
    await $.pumpAndSettle();

    // Create an album with a run-unique name.
    final name = 'Patrol ${DateTime.now().millisecondsSinceEpoch}';
    await $.tester.tap(find.byIcon(Icons.add).first);
    await $.pumpAndSettle();
    await $.tester.enterText(find.byType(TextField), name);
    await $.tester.tap(find.text('Create'));
    await $.pumpAndSettle();
    expect($(name), findsOneWidget);

    // Open its (empty) detail grid.
    await $(name).tap();
    await $.pumpAndSettle();
    // The empty-album note is a longer multi-line string; match a substring
    // ($('..') is an exact-text finder).
    expect(find.textContaining('This album is empty'), findsOneWidget);
    await $.tester.tap(find.byIcon(Icons.arrow_back));
    await $.pumpAndSettle();

    // Long-press the card → confirm delete → it's gone.
    await $.tester.longPress($(name));
    await $.pumpAndSettle();
    expect($('Delete "$name"?'), findsOneWidget);
    await $('Delete').tap();
    await $.pumpAndSettle();
    expect($(name), findsNothing);
  });
}
