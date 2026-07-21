import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/detail/detail_providers.dart';
import 'package:sologallery/widgets/precache_adjacent.dart';

void main() {
  // Records which assets actually had their bytes requested, which is the
  // whole observable effect of the widget — it renders nothing.
  late List<String> warmed;

  setUp(() => warmed = []);

  Future<void> pump(
    WidgetTester tester, {
    required List<String> ids,
    required int index,
    int radius = 1,
    Set<String> videos = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isVideoProvider.overrideWith((ref, id) => videos.contains(id)),
          detailImageProvider.overrideWith((ref, id) {
            warmed.add(id);
            return null;
          }),
        ],
        child: MaterialApp(
          home: PrecacheAdjacent(assetIds: ids, index: index, radius: radius),
        ),
      ),
    );
    // isVideoProvider resolves before the bytes are requested, so the warm-up
    // lands on the second build, not the first.
    await tester.pump();
  }

  testWidgets('warms the neighbours and not the visible page', (tester) async {
    await pump(tester, ids: ['a', 'b', 'c'], index: 1);
    expect(warmed, unorderedEquals(['a', 'c']));
    expect(warmed, isNot(contains('b')));
  });

  testWidgets('warms only the one existing neighbour at each end', (
    tester,
  ) async {
    await pump(tester, ids: ['a', 'b', 'c'], index: 0);
    expect(warmed, ['b']);

    warmed.clear();
    await pump(tester, ids: ['a', 'b', 'c'], index: 2);
    expect(warmed, ['b']);
  });

  testWidgets('skips a video neighbour — its page is a player, not bytes', (
    tester,
  ) async {
    await pump(tester, ids: ['a', 'v', 'c'], index: 2, videos: {'v'});
    expect(warmed, isNot(contains('v')));
  });

  testWidgets('warms a wider radius when asked', (tester) async {
    await pump(tester, ids: ['a', 'b', 'c', 'd', 'e'], index: 2, radius: 2);
    expect(warmed, unorderedEquals(['a', 'b', 'd', 'e']));
  });

  testWidgets('renders nothing', (tester) async {
    await pump(tester, ids: ['a', 'b'], index: 0);
    expect(tester.getSize(find.byType(PrecacheAdjacent)), Size.zero);
  });

  testWidgets('a lone asset has nothing to warm', (tester) async {
    await pump(tester, ids: ['a'], index: 0);
    expect(warmed, isEmpty);
  });
}
