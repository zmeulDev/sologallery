import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/widgets/precache_adjacent.dart';

void main() {
  // Records which assets actually had their bytes requested, and which were
  // let go again — the whole observable effect of the widget, since it renders
  // nothing.
  late List<String> warmed;
  late List<String> dropped;

  setUp(() {
    warmed = [];
    dropped = [];
  });

  /// Pumps one frame only. Nothing here waits on `isVideoProvider`: the point
  /// of the widget is that the bytes are already in flight by the first frame.
  Future<void> pump(
    WidgetTester tester, {
    required List<String> ids,
    required int index,
    int ahead = 1,
    int behind = 1,
    Set<String> videos = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Async on purpose: on device this is a platform round-trip that
          // is still in flight on the first frame, which is the case that
          // matters. A sync override would answer before the widget builds
          // and hide the very behaviour under test.
          isVideoProvider.overrideWith((ref, id) async => videos.contains(id)),
          detailImageProvider.overrideWith((ref, id) {
            warmed.add(id);
            ref.onDispose(() => dropped.add(id));
            return null;
          }),
        ],
        child: MaterialApp(
          home: Center(
            child: PrecacheAdjacent(
              assetIds: ids,
              index: index,
              ahead: ahead,
              behind: behind,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('warms the neighbours and not the visible page', (tester) async {
    await pump(tester, ids: ['a', 'b', 'c'], index: 1);
    expect(warmed, unorderedEquals(['a', 'c']));
    expect(warmed, isNot(contains('b')));
  });

  testWidgets('warms without waiting on the video check', (tester) async {
    // The fetch that matters starts on the first frame. Gating it on
    // isVideoProvider first would serialize two platform round-trips on the
    // one path that has to be fast.
    await pump(tester, ids: ['a', 'b'], index: 0);
    expect(warmed, ['b']);
  });

  testWidgets('at the front, warms only the neighbour that exists', (
    tester,
  ) async {
    await pump(tester, ids: ['a', 'b', 'c'], index: 0);
    expect(warmed, ['b']);
  });

  testWidgets('at the back, warms only the neighbour that exists', (
    tester,
  ) async {
    await pump(tester, ids: ['a', 'b', 'c'], index: 2);
    expect(warmed, ['b']);
  });

  testWidgets('lets a video neighbour go once it is known to be one', (
    tester,
  ) async {
    await pump(tester, ids: ['a', 'v', 'c'], index: 2, videos: {'v'});
    // Warmed optimistically on the first frame...
    expect(warmed, contains('v'));

    await tester.pump(const Duration(milliseconds: 10));
    // ...and released as soon as the answer lands, so nothing holds a poster
    // frame no page will ever display.
    expect(dropped, contains('v'));
    expect(dropped, isNot(contains('a')));
  });

  testWidgets('runs the window forward when asked', (tester) async {
    // The memory player's shape: a story is played, not browsed.
    await pump(
      tester,
      ids: ['a', 'b', 'c', 'd', 'e'],
      index: 1,
      ahead: 3,
      behind: 1,
    );
    expect(warmed, unorderedEquals(['a', 'c', 'd', 'e']));
  });

  testWidgets('warms three each way — the detail viewer\'s window', (
    tester,
  ) async {
    // A free swipe can outrun a one-deep window in a second, so the viewer
    // asks for three; the payload is encoded bytes, not decoded bitmaps.
    await pump(
      tester,
      ids: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
      index: 4, // 'e'
      ahead: 3,
      behind: 3,
    );
    expect(warmed, unorderedEquals(['b', 'c', 'd', 'f', 'g', 'h']));
    expect(warmed, isNot(contains('e'))); // the visible page
    expect(warmed, isNot(contains('a'))); // outside the window
    expect(warmed, isNot(contains('i')));
  });

  testWidgets('a three-each-way window clamps at the front edge', (
    tester,
  ) async {
    await pump(
      tester,
      ids: ['a', 'b', 'c', 'd', 'e'],
      index: 1, // 'b' — only one page behind it exists
      ahead: 3,
      behind: 3,
    );
    expect(warmed, unorderedEquals(['a', 'c', 'd', 'e']));
  });

  testWidgets('renders nothing', (tester) async {
    await pump(tester, ids: ['a', 'b'], index: 0);
    // Given a choice it takes no space at all — which is exactly why it has to
    // be a positioned child of any Stack it lives in, or the Stack sizes
    // itself to this and clips everything else away.
    expect(tester.getSize(find.byType(PrecacheAdjacent)), Size.zero);
  });

  testWidgets('a lone asset has nothing to warm', (tester) async {
    await pump(tester, ids: ['a'], index: 0);
    expect(warmed, isEmpty);
  });
}
