import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';

/// On-device drive of the real consent UI — the onboarding step and the
/// Settings toggles, through the actual widget tree and the native permission
/// dialog.
///
/// Host widget tests cover the same screens against an in-memory database;
/// this is the paired real-path run (CLAUDE.md fake-pairing rule). It is also
/// what makes the flow verifiable without screenshots: Flutter is invisible to
/// `uiautomator`, so patrol's Flutter finders are the only reliable way to
/// press these controls on a device.
///
/// `clearPackageData=true` in the JUnit runner resets app data and permissions
/// between cases, so each starts from a fresh install.
///
/// Run with: `patrol test -t integration_test/consent_flow_test.dart`.
void main() {
  /// Boots the app and gets past the photo-access step, landing on consent.
  Future<void> reachConsentStep(PatrolIntegrationTester $) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    expect($('Allow photo access'), findsOneWidget);

    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
  }

  patrolTest('the consent step is owed after access and starts all-off',
      ($) async {
    await reachConsentStep($);

    // `$('text')` is an exact whole-string finder, so match the row labels.
    expect($('CONTENT SEARCH'), findsOneWidget);
    expect($('MEMORIES'), findsOneWidget);
    expect($('FACE DETECTION'), findsOneWidget);
    expect($('Continue'), findsOneWidget);

    // Nothing is pre-accepted — consent is a choice, not an opt-out.
    final switches = $.tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, hasLength(3));
    expect(switches.every((s) => s.value == false), isTrue);
  });

  patrolTest('declining everything still opens the library', ($) async {
    await reachConsentStep($);

    await $('Continue').tap();
    await $.pumpAndSettle();

    // The consent step is gone for good and the app is usable.
    expect($('Continue'), findsNothing);
    expect($('Library'), findsWidgets);
  });

  patrolTest('accepting content search enables it in Settings too', ($) async {
    await reachConsentStep($);

    // Turn on the first row (Content search) and continue.
    await $(Switch).at(0).tap();
    await $('Continue').tap();
    await $.pumpAndSettle();

    // Settings must reflect the onboarding answer — one source of truth.
    await $.tester.tap(find.byTooltip('Settings'));
    await $.pumpAndSettle();

    expect($('ON-DEVICE ANALYSIS'), findsOneWidget);
    expect($('Content search'), findsOneWidget);
    final switches =
        $.tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.first.value, isTrue, reason: 'content search stayed on');
    expect(switches[1].value, isFalse, reason: 'memories were never accepted');
    expect(switches[2].value, isFalse, reason: 'faces were never accepted');
  });

  patrolTest('the People screen explains itself when faces are off', ($) async {
    await reachConsentStep($);
    await $('Continue').tap(); // decline everything
    await $.pumpAndSettle();

    await $.tester.tap(find.byTooltip('Search'));
    await $.pumpAndSettle();

    // With face detection declined the People strip must not be offered at all.
    expect($('People'), findsNothing);
    expect($('See all'), findsNothing);
  });
}
