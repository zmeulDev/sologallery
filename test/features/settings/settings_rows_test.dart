import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/settings/widgets/settings_rows.dart';
import 'package:sologallery/widgets/consent_switch.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  group('SettingsGroup', () {
    testWidgets('renders an uppercased label above its child', (tester) async {
      await tester.pumpWidget(
        host(
          const SettingsGroup(
            label: 'Storage',
            child: Text('body'),
          ),
        ),
      );
      expect(find.text('STORAGE'), findsOneWidget);
      expect(find.text('Storage'), findsNothing);
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('SettingsInfoRow', () {
    testWidgets('shows the trailing value when given one', (tester) async {
      await tester.pumpWidget(
        host(const SettingsInfoRow(label: 'Version', value: '26.9.4')),
      );
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('26.9.4'), findsOneWidget);
    });

    testWidgets('omits the value entirely when null', (tester) async {
      await tester.pumpWidget(
        host(const SettingsInfoRow(label: 'Version', value: null)),
      );
      expect(find.text('Version'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('SettingsCaptionRow', () {
    testWidgets('renders its caption text', (tester) async {
      await tester.pumpWidget(
        host(const SettingsCaptionRow('Analysis runs only while charging.')),
      );
      expect(
        find.text('Analysis runs only while charging.'),
        findsOneWidget,
      );
    });
  });

  group('SettingsSwitchRow', () {
    testWidgets('renders the label and caption', (tester) async {
      await tester.pumpWidget(
        host(
          SettingsSwitchRow(
            label: 'Face grouping',
            caption: 'Group photos by the people in them.',
            value: false,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Face grouping'), findsOneWidget);
      expect(
        find.text('Group photos by the people in them.'),
        findsOneWidget,
      );
    });

    testWidgets('reports the toggled value', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        host(
          SettingsSwitchRow(
            label: 'Face grouping',
            caption: 'caption',
            value: false,
            onChanged: (v) => reported = v,
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      expect(reported, isTrue);
    });

    testWidgets('names the switch with the row label for a11y', (tester) async {
      await tester.pumpWidget(
        host(
          SettingsSwitchRow(
            label: 'Face grouping',
            caption: 'caption',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );
      final consentSwitch = tester.widget<ConsentSwitch>(
        find.byType(ConsentSwitch),
      );
      expect(consentSwitch.semanticLabel, 'Face grouping');
    });
  });

  group('SettingsActionRow', () {
    testWidgets('fires onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          SettingsActionRow(
            label: 'Privacy policy',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Privacy policy'));
      expect(taps, 1);
    });

    testWidgets('shows a caption only when given one', (tester) async {
      await tester.pumpWidget(
        host(SettingsActionRow(label: 'Reindex', onTap: () {})),
      );
      expect(find.byType(Text), findsOneWidget);

      await tester.pumpWidget(
        host(
          SettingsActionRow(
            label: 'Reindex',
            caption: 'Rescan the whole library.',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Rescan the whole library.'), findsOneWidget);
    });

    testWidgets('always carries a trailing chevron', (tester) async {
      await tester.pumpWidget(
        host(SettingsActionRow(label: 'Privacy policy', onTap: () {})),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
