import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/paged_assets_notifier.dart';
import 'package:sologallery/services/photo_library_service.dart';

/// Minimal concrete [PagedAssetsNotifier] driven by a list of canned pages, with
/// an optional per-fetch hook for interleaving errors / disposal with an
/// in-flight page. Pages past the end of [pages] come back empty.
class _FakePaged extends PagedAssetsNotifier {
  _FakePaged(this.pages, {this.beforeFetch});

  final List<List<AssetRef>> pages;
  final Future<void> Function(int page)? beforeFetch;

  /// Every [fetchPage] the notifier issued, in order — asserts the base stops
  /// paging once a short page arrives.
  final List<int> fetched = [];

  @override
  int get pageSize => 3;

  @override
  Future<List<AssetRef>> fetchPage(int page, int pageSize) async {
    fetched.add(page);
    if (beforeFetch != null) await beforeFetch!(page);
    return page < pages.length ? pages[page] : const [];
  }
}

AssetRef _ref(String id) => AssetRef(id: id, createdAt: DateTime(2026));

List<AssetRef> _page(String prefix, int n) =>
    [for (var i = 0; i < n; i++) _ref('$prefix$i')];

List<String> _ids(AsyncValue<List<AssetRef>> v) =>
    (v.value ?? const []).map((a) => a.id).toList();

void main() {
  AsyncNotifierProvider<_FakePaged, List<AssetRef>> provider(
    List<List<AssetRef>> pages, {
    Future<void> Function(int page)? beforeFetch,
  }) {
    return AsyncNotifierProvider<_FakePaged, List<AssetRef>>(
      () => _FakePaged(pages, beforeFetch: beforeFetch),
    );
  }

  test('build loads the first page; a full page means more may follow', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = provider([_page('a', 3), _page('b', 1)]);

    final first = await c.read(p.future);

    expect(first.map((a) => a.id), ['a0', 'a1', 'a2']);
    expect(c.read(p.notifier).hasMore, isTrue);
  });

  test('a short first page reports no more', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = provider([_page('a', 2)]);

    await c.read(p.future);

    expect(c.read(p.notifier).hasMore, isFalse);
  });

  test('loadMore appends the next page, newest-first order preserved', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = provider([_page('a', 3), _page('b', 2)]);
    await c.read(p.future);
    final n = c.read(p.notifier);

    await n.loadMore();

    expect(_ids(c.read(p)), ['a0', 'a1', 'a2', 'b0', 'b1']);
    expect(n.hasMore, isFalse);
  });

  test('loadMore is a no-op once the data is exhausted', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = provider([_page('a', 3), _page('b', 3)]);
    await c.read(p.future);
    final n = c.read(p.notifier);

    await n.loadMore(); // page 1, full
    await n.loadMore(); // page 2, empty -> exhausted
    expect(n.hasMore, isFalse);
    expect(_ids(c.read(p)), hasLength(6));

    await n.loadMore(); // no-op: no further fetch, no growth
    expect(_ids(c.read(p)), hasLength(6));
    expect(n.fetched, [0, 1, 2]);
  });

  test('concurrent loadMore calls coalesce into one fetch', () async {
    final gate = Completer<void>();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = provider(
      [_page('a', 3), _page('b', 3), _page('c', 3)],
      beforeFetch: (page) => page == 1 ? gate.future : Future.value(),
    );
    await c.read(p.future);
    final n = c.read(p.notifier);

    final first = n.loadMore();
    final second = n.loadMore(); // guarded out while `first` is in flight
    gate.complete();
    await Future.wait([first, second]);

    expect(n.fetched, [0, 1]);
    expect(_ids(c.read(p)), hasLength(6));
  });

  test('a fetch error surfaces as AsyncValue.error', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final p = provider(
      const [],
      beforeFetch: (_) => Future.error(StateError('boom')),
    );

    await expectLater(c.read(p.future), throwsStateError);
    expect(c.read(p).hasError, isTrue);
  });

  test('disposal mid-fetch neither emits nor throws after dispose', () async {
    final gate = Completer<void>();
    final c = ProviderContainer();
    final emissions = <List<String>>[];
    final p = provider(
      [_page('a', 3), _page('b', 3)],
      beforeFetch: (page) => page == 1 ? gate.future : Future.value(),
    );
    c.listen(p, (_, next) => emissions.add(_ids(next)), fireImmediately: true);

    await c.read(p.future);
    final n = c.read(p.notifier);
    final pending = n.loadMore();
    c.dispose();
    gate.complete();
    await expectLater(pending, completes);
    await pumpEventQueue();

    expect(emissions.last, ['a0', 'a1', 'a2']);
  });
}
