import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/services/indexing_service.dart';
import 'package:sologallery/widgets/indexing_dial.dart';

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
          home: const Scaffold(body: Center(child: IndexingDial())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The fraction the ring was drawn at, or null when no ring is painted.
  double? arcFraction(WidgetTester tester) {
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<IndexingRingPainter>();
    return painters.isEmpty ? null : painters.single.progress;
  }

  testWidgets('says nothing and paints no ring while idle', (tester) async {
    await pump(tester, const AsyncData(IndexingStatus.idle()));

    expect(find.byType(Text), findsNothing);
    expect(arcFraction(tester), isNull);
  });

  testWidgets('says nothing before the first status arrives', (tester) async {
    // The stream is app-wide and unresolved on a cold start; a dial that
    // flashed here would claim work that may not exist.
    await pump(tester, const AsyncLoading());

    expect(find.byType(Text), findsNothing);
    expect(arcFraction(tester), isNull);
  });

  testWidgets('shows how many photos are left while indexing', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 240, total: 1000)),
    );

    expect(find.text('240'), findsOneWidget);
  });

  testWidgets('compacts a count too wide for the disc', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 12345, total: 20000)),
    );

    expect(find.text('12k'), findsOneWidget);
    expect(find.text('12345'), findsNothing);
  });

  testWidgets('the ring fills by the share already done', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 250, total: 1000)),
    );

    expect(arcFraction(tester), closeTo(0.75, 1e-9));
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
    expect(arcFraction(tester), 0.0);
  });

  testWidgets('carries the whole sentence for screen readers', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 42, total: 100)),
    );

    // The bare count is not a sentence — the label the strip used to carry has
    // to survive somewhere.
    expect(
      find.bySemanticsLabel('Analyzing your photos — 42 left'),
      findsOneWidget,
    );
  });

  testWidgets('goes away when the pass finishes', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 3, total: 10)),
    );
    expect(find.text('3'), findsOneWidget);

    await pump(tester, const AsyncData(IndexingStatus.idle()));
    // The dial drops the instant the pass ends — no fade to wait out.
    await tester.pump();

    expect(find.byType(Text), findsNothing);
    expect(arcFraction(tester), isNull);
  });

  testWidgets('reserves its slot whether or not a pass is running',
      (tester) async {
    // The bar's trailing slot must not resize when analysis starts or ends —
    // the capsule's position is measured from the screen edge, not from this.
    await pump(tester, const AsyncData(IndexingStatus.idle()));
    final idle = tester.getSize(find.byType(IndexingDial));

    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 7, total: 8)),
    );

    expect(tester.getSize(find.byType(IndexingDial)), idle);
    expect(idle, const Size.square(IndexingDial.size));
  });

  testWidgets('reads in dark theme too', (tester) async {
    await pump(
      tester,
      const AsyncData(IndexingStatus(remaining: 7, total: 8)),
      theme: AppTheme.dark,
    );

    expect(find.text('7'), findsOneWidget);
  });
}
