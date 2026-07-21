import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:sologallery/app.dart';
import 'package:sologallery/features/library/widgets/year_header.dart';
import 'package:sologallery/widgets/asset_thumbnail.dart';
import 'package:sologallery/widgets/indexing_dial.dart';
import 'package:sologallery/widgets/section_header.dart';
import 'package:sologallery/widgets/nav_pill_bar.dart';

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

  /// The active branch's vertical scroller. The Library's filter bar is a
  /// horizontal scrollable in the same subtree, so type alone isn't enough.
  ScrollableState verticalScrollable(PatrolIntegrationTester $) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state as ScrollableState;
      if (state.position.axis == Axis.vertical) return state;
    }
    fail('No vertical scrollable on screen — nothing to scroll to the end of.');
  }

  /// Scrolls [tab] to its end and asserts the lowest thing it renders — any of
  /// [content] — sits fully above the floating nav capsule.
  ///
  /// [content] is a set rather than one type because the bottom of the
  /// timeline is not always a photo: the oldest section can have an empty
  /// preview grid, leaving its header as the last thing on screen. Whatever
  /// ends up lowest is what must clear the capsule.
  ///
  /// The scroller *must* have somewhere to scroll: on a short library every
  /// row already clears the capsule and the assertion would pass without
  /// exercising the padding at all, so a zero extent fails loudly instead.
  Future<void> lastRowClearsPill(
    PatrolIntegrationTester $,
    String tab,
    List<Type> content,
  ) async {
    await $.tester.tap(find.byTooltip(tab));
    await $.tester.pump();
    await $.tester.pump(const Duration(milliseconds: 500));

    final position = verticalScrollable($).position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: '$tab must have more rows than fit on screen, or "the last row '
          'clears the capsule" proves nothing.',
    );
    // A lazy `ListView.builder` extrapolates `maxScrollExtent` from the
    // children built so far, and the guess overshoots: jumping straight to it
    // lands past the last row, in blank space, where nothing renders at all.
    // Step toward the end a screenful at a time instead — each step builds the
    // next children and corrects the estimate — until the position stops
    // moving, which is the real end.
    for (var i = 0; i < 200; i++) {
      final before = position.pixels;
      position.jumpTo(before + 1000);
      await $.tester.pump();
      await $.tester.pump(const Duration(milliseconds: 100));
      if (position.pixels <= before + 0.5) break;
    }
    // Thumbnails at the end start undecoded (patrol reinstalls, so the cache is
    // cold); give them a bounded moment to land.
    final finders = [for (final type in content) find.byType(type)];
    int rendered() => finders.fold(0, (sum, f) => sum + f.evaluate().length);
    for (var i = 0; i < 20 && rendered() == 0; i++) {
      await $.tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      rendered(),
      greaterThan(0),
      reason: '$tab reached its end (${position.pixels} of '
          '${position.maxScrollExtent}) with none of $content rendered.',
    );

    var lowest = 0.0;
    var lowestType = content.first;
    for (var f = 0; f < finders.length; f++) {
      for (var i = 0; i < finders[f].evaluate().length; i++) {
        final bottom = $.tester.getRect(finders[f].at(i)).bottom;
        if (bottom > lowest) {
          lowest = bottom;
          lowestType = content[f];
        }
      }
    }

    final pillTop = $.tester.getRect(find.byType(NavPillBar)).top;
    expect(
      lowest,
      lessThanOrEqualTo(pillTop),
      reason: '$tab: the lowest content ($lowestType) ends at $lowest, under '
          'the nav capsule that starts at $pillTop — its scroller is missing '
          'the bottom inset.',
    );
  }

  // Library only: it is the one tab guaranteed to hold more photos than fit on
  // screen, so the assertion can't go vacuous. The other three depend on what
  // the device happens to carry — Saved is empty until something is favorited,
  // and Albums is a handful of rows — so their scrollers are pinned by
  // `test/widgets/nav_bottom_inset_test.dart` instead.
  patrolTest('scrolled to the end, Library clears the nav capsule', ($) async {
    await bootAndGrant($);
    await lastRowClearsPill(
      $,
      'Library',
      const [AssetThumbnail, SectionHeader, YearHeader],
    );
  });

  /// The count inside the dial — the only thing it renders while a pass runs.
  Finder dialCount() => find.descendant(
        of: find.byType(IndexingDial),
        matching: find.byType(Text),
      );

  // The dial's geometry only exists on a real screen: host tests can't prove it
  // clears the capsule at the device's actual width, inside its safe area.
  // Paired with the negative case below — "no dial" means nothing unless a
  // same-file run shows the dial does appear when there is work (CLAUDE.md:
  // a device-only assertion needs a positive control).
  patrolTest('the indexing dial rides right of the capsule while analysing',
      ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: SoloGalleryApp()));
    await $('Allow photo access').tap();
    await $.platform.mobile.grantPermissionWhenInUse();
    await $.pumpAndSettle();
    // Accept content search, so the pass has real work and the dial has a
    // reason to show.
    await $(Switch).at(0).tap();
    await $('Continue').tap();
    await $.pumpAndSettle();

    // The pass sweeps the whole library before it knows what is pending, so
    // poll to a deadline rather than assuming the dial is up on frame one.
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (dialCount().evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await $.tester.pump(const Duration(milliseconds: 250));
    }
    expect(dialCount(), findsOneWidget,
        reason: 'With content search accepted, analysis should be running and '
            'the dial showing how many photos are left.');

    final dial = $.tester.getRect(find.byType(IndexingDial));
    final capsule = $.tester.getRect(
      find.descendant(
        of: find.byType(NavPillBar),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is ShapeDecoration,
        ),
      ),
    );
    final screen = $.tester.getSize(find.byType(MaterialApp));

    expect(dial.left, greaterThan(capsule.right),
        reason: 'The dial overlaps the capsule at this screen width.');
    expect(dial.right, lessThan(screen.width),
        reason: 'The dial runs off the right edge.');
    expect(dial.center.dy, closeTo(capsule.center.dy, 1),
        reason: 'The dial should share the capsule\'s baseline.');
    // Bottom chrome, not a band at the top of the screen.
    expect(dial.top, greaterThan(screen.height / 2));
  });

  patrolTest('with analysis declined the dial never shows', ($) async {
    await bootAndGrant($); // declines every consent at the onboarding step

    expect(find.byType(IndexingDial), findsOneWidget,
        reason: 'The dial is always mounted; it just shows nothing when idle.');
    expect(dialCount(), findsNothing);
    // Give a pass that might be starting a moment to prove itself, so this is
    // not just "we looked too early".
    for (var i = 0; i < 20; i++) {
      await $.tester.pump(const Duration(milliseconds: 250));
    }
    expect(dialCount(), findsNothing,
        reason: 'Nothing was consented to, so there is no analysis to report.');
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
