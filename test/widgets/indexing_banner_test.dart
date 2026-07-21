import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/widgets/indexing_banner.dart';

void main() {
  Future<void> pump(WidgetTester tester, AsyncValue<IndexingStatus> status,
      {ThemeData? theme}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // overrideWithValue, not a Stream: an errored/pending StreamProvider
          // never leaves AsyncLoading under fake async (gotcha #5).
          indexingStatusProvider.overrideWithValue(status),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.light,
          home: const Scaffold(body: IndexingBanner()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The strip's own height, which is what the shell's Column gives up to it.
  double height(WidgetTester tester) =>
      tester.getSize(find.byType(IndexingBanner)).height;

  testWidgets('takes no height and says nothing while idle', (tester) async {
    await pump(tester, const AsyncData(IndexingStatus.idle()));

    expect(find.textContaining('Analyzing'), findsNothing);
    expect(height(tester), 0);
  });

  testWidgets('says nothing before the first status arrives', (tester) async {
    // The stream is app-wide and unresolved on a cold start; a banner that
    // flashed here would claim work that may not exist.
    await pump(tester, const AsyncLoading());

    expect(find.textContaining('Analyzing'), findsNothing);
    expect(height(tester), 0);
  });

  testWidgets('names the work and how much is left while indexing',
      (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 240, total: 1000)),
    );

    // Same verb as the Settings row — the app has one word for this.
    expect(find.text('Analyzing your photos — 240 left'), findsOneWidget);
    expect(height(tester), greaterThan(0));
  });

  testWidgets('the progress line fills by the share already done',
      (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 250, total: 1000)),
    );

    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, closeTo(0.75, 1e-9));
  });

  testWidgets('a pass with nothing counted yet does not divide by zero',
      (tester) async {
    // `remaining > 0` with `total == 0` can't be reached by the real service,
    // but the widget must not throw if a pass reports it mid-update.
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 5, total: 0)),
    );

    expect(tester.takeException(), isNull);
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, 0.0);
  });

  testWidgets('collapses back to nothing when the pass finishes',
      (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 3, total: 10)),
    );
    expect(height(tester), greaterThan(0));

    await pump(tester, const AsyncData(IndexingStatus.idle()));
    expect(height(tester), 0);
  });

  testWidgets('reads in dark theme too', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 7, total: 8)),
      theme: AppTheme.dark,
    );
    expect(find.text('Analyzing your photos — 7 left'), findsOneWidget);
  });
}
