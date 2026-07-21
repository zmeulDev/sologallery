import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/features/detail/domain/adjacent_ids.dart';

void main() {
  const ids = ['a', 'b', 'c', 'd', 'e'];

  test('returns the next and previous id, next first', () {
    expect(adjacentIds(ids, 2), ['d', 'b']);
  });

  test('drops the missing side at either end rather than clamping', () {
    // Clamping would return the current id and warm a page already on screen.
    expect(adjacentIds(ids, 0), ['b']);
    expect(adjacentIds(ids, 4), ['d']);
  });

  test('orders a wider window nearest-first', () {
    expect(adjacentIds(ids, 2, ahead: 2, behind: 2), ['d', 'b', 'e', 'a']);
  });

  test('runs forward only when nothing is asked for behind', () {
    // The memory player's shape: a story is played, not browsed.
    expect(adjacentIds(ids, 1, ahead: 3, behind: 0), ['c', 'd', 'e']);
  });

  test('keeps the near side of each direction first when they differ', () {
    // Not 'c','d','e','a' — the one page behind is still worth more than the
    // third page ahead, so it goes out before the far end of the run.
    expect(adjacentIds(ids, 1, ahead: 3, behind: 1), ['c', 'a', 'd', 'e']);
  });

  test('never includes the id at index', () {
    for (var i = 0; i < ids.length; i++) {
      expect(
        adjacentIds(ids, i, ahead: ids.length, behind: ids.length),
        isNot(contains(ids[i])),
      );
    }
  });

  test('an index just off either end still warms the id beside it', () {
    // The memory player's title card sits at -1 relative to the photo list.
    expect(adjacentIds(ids, -1), ['a']);
    expect(adjacentIds(ids, 5), ['e']);
  });

  test('the title card warms the opening run of the story', () {
    // What the player asks for on open: the first photos are already being
    // fetched while the title card holds the screen.
    expect(adjacentIds(ids, -1, ahead: 3, behind: 1), ['a', 'b', 'c']);
  });

  test('an index far outside the list warms nothing', () {
    expect(adjacentIds(ids, -9), isEmpty);
    expect(adjacentIds(ids, 99), isEmpty);
  });

  test('an empty list warms nothing', () {
    expect(adjacentIds(const [], 0), isEmpty);
  });

  test('a single-entry list has no neighbour to warm', () {
    expect(adjacentIds(const ['only'], 0), isEmpty);
  });
}
