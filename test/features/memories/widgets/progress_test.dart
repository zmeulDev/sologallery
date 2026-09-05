import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/theme/app_theme.dart';
import 'package:sologallery/features/memories/widgets/progress.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required int pages,
    required int index,
    bool paused = false,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: Stack(
            children: [
              Progress(pages: pages, index: index, paused: paused),
            ],
          ),
        ),
      ),
    );
  }

  /// The `pages` segment boxes, in on-screen left-to-right order.
  List<DecoratedBox> segments(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(Progress),
          matching: find.byType(DecoratedBox),
        ),
      )
      .toList();

  Color colorOf(DecoratedBox box) => (box.decoration as BoxDecoration).color!;
  double heightOf(DecoratedBox box) => (box.child! as SizedBox).height!;

  testWidgets('played, current and upcoming segments map to three states',
      (tester) async {
    await pump(tester, pages: 4, index: 2);

    final colors = Theme.of(tester.element(find.byType(Progress)))
        .extension<AppColors>()!;
    final boxes = segments(tester);
    expect(boxes, hasLength(4));

    // i = 0, 1: played.
    expect(colorOf(boxes[0]), AppOverMedia.glyph);
    expect(heightOf(boxes[0]), 2);
    expect(colorOf(boxes[1]), AppOverMedia.glyph);
    expect(heightOf(boxes[1]), 2);

    // i = 2: current — accent colour, taller.
    expect(colorOf(boxes[2]), colors.accent);
    expect(heightOf(boxes[2]), 3);

    // i = 3: upcoming.
    expect(colorOf(boxes[3]), AppOverMedia.segmentOff);
    expect(heightOf(boxes[3]), 2);
  });

  testWidgets('the first page is current with no played segments yet',
      (tester) async {
    await pump(tester, pages: 3, index: 0);

    final colors = Theme.of(tester.element(find.byType(Progress)))
        .extension<AppColors>()!;
    final boxes = segments(tester);

    expect(colorOf(boxes[0]), colors.accent);
    expect(colorOf(boxes[1]), AppOverMedia.segmentOff);
    expect(colorOf(boxes[2]), AppOverMedia.segmentOff);
  });

  testWidgets('the last page is current with no upcoming segments left',
      (tester) async {
    await pump(tester, pages: 3, index: 2);

    final colors = Theme.of(tester.element(find.byType(Progress)))
        .extension<AppColors>()!;
    final boxes = segments(tester);

    expect(colorOf(boxes[0]), AppOverMedia.glyph);
    expect(colorOf(boxes[1]), AppOverMedia.glyph);
    expect(colorOf(boxes[2]), colors.accent);
  });

  testWidgets('the mapping is unaffected by the paused dim', (tester) async {
    // paused only changes the whole bar's Opacity — it must not change
    // which segment is "current" or its colour/height.
    await pump(tester, pages: 3, index: 1, paused: true);

    final colors = Theme.of(tester.element(find.byType(Progress)))
        .extension<AppColors>()!;

    expect(colorOf(segments(tester)[1]), colors.accent);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.35);
  });

  testWidgets('reads in dark theme too', (tester) async {
    await pump(tester, pages: 3, index: 1, theme: AppTheme.dark);

    final colors = Theme.of(tester.element(find.byType(Progress)))
        .extension<AppColors>()!;
    expect(colorOf(segments(tester)[1]), colors.accent);
  });
}
