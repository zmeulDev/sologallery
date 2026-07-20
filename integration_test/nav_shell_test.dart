import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';

/// On-device shell navigation: the four bottom-nav destinations, the Search tab
/// taking and releasing focus, and Settings reached from the Library app bar
/// (it is no longer a tab). Run with:
///   `patrol test -t integration_test/nav_shell_test.dart -d DEVICE`
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

  patrolTest('bottom nav: Library, Search, Saved, Albums', ($) async {
    await bootAndGrant($);
    for (final label in ['Library', 'Search', 'Saved', 'Albums']) {
      expect(find.byTooltip(label), findsOneWidget,
          reason: '$label should be a bottom-nav destination.');
    }
    expect(find.byTooltip('Settings'), findsOneWidget,
        reason: 'Settings should be the Library app-bar action.');

    // The Search field only takes focus once its tab is selected — a keyboard
    // on the Library tab would mean the branch grabbed focus at boot.
    final field = find.byType(TextField, skipOffstage: false);
    expect(field, findsNothing);

    await $.tester.tap(find.byTooltip('Search'));
    // Bounded pumps from here: a focused TextField's cursor never settles.
    await $.tester.pump();
    await $.tester.pump(const Duration(milliseconds: 500));
    expect($.tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);

    await $.tester.tap(find.byTooltip('Saved'));
    await $.tester.pump();
    await $.tester.pump(const Duration(milliseconds: 500));
    expect($.tester.widget<TextField>(field).focusNode?.hasFocus, isFalse,
        reason: 'Leaving the tab should dismiss the keyboard.');
  });

  patrolTest('Library app bar opens Settings and comes back', ($) async {
    await bootAndGrant($);

    await $.tester.tap(find.byTooltip('Settings'));
    await $.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    // Pushed on the root navigator: full screen, no bottom nav behind it.
    expect(find.byTooltip('Library'), findsNothing);

    await $.tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await $.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Library'), findsOneWidget);
  });
}
