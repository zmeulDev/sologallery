import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/photo_library_service.dart';
import 'package:sologallery/services/watched_assets_notifier.dart';

/// Minimal concrete [WatchedAssetsNotifier]. Each (re)subscription gets its own
/// [StreamController] the test drives directly; [limits] records the window
/// sizes the base asked for.
class _FakeWatched extends WatchedAssetsNotifier {
  final List<int> limits = [];
  final List<StreamController<List<AssetRef>>> _controllers = [];

  @override
  int get pageSize => 3;

  @override
  Stream<List<AssetRef>> watchWindow(int limit) {
    limits.add(limit);
    final controller = StreamController<List<AssetRef>>();
    _controllers.add(controller);
    return controller.stream;
  }

  /// The controller backing the current (latest) subscription.
  StreamController<List<AssetRef>> get current => _controllers.last;

  void disposeControllers() {
    for (final c in _controllers) {
      c.close();
    }
  }
}

AssetRef _ref(String id) => AssetRef(id: id, createdAt: DateTime(2026));

List<AssetRef> _window(String prefix, int n) =>
    [for (var i = 0; i < n; i++) _ref('$prefix$i')];

List<String> _ids(AsyncValue<List<AssetRef>> v) =>
    (v.value ?? const []).map((a) => a.id).toList();

void main() {
  late ProviderContainer container;
  late AsyncNotifierProvider<_FakeWatched, List<AssetRef>> provider;

  setUp(() {
    provider = AsyncNotifierProvider<_FakeWatched, List<AssetRef>>(
      _FakeWatched.new,
    );
    container = ProviderContainer();
  });

  tearDown(() {
    try {
      container.read(provider.notifier).disposeControllers();
    } catch (_) {
      // Container already disposed by the test.
    }
    try {
      container.dispose();
    } catch (_) {
      // Already disposed.
    }
  });

  _FakeWatched notifier() => container.read(provider.notifier);

  test('build subscribes to a page-sized window and completes on first emission',
      () async {
    final n = notifier();
    n.current.add(_window('a', 3));

    final first = await container.read(provider.future);

    expect(first.map((a) => a.id), ['a0', 'a1', 'a2']);
    expect(n.limits, [3]);
    expect(n.hasMore, isTrue);
  });

  test('loadMore grows the window by a page and re-subscribes', () async {
    final n = notifier();
    n.current.add(_window('a', 3));
    await container.read(provider.future);

    final pending = n.loadMore();
    expect(n.limits, [3, 6]);
    n.current.add(_window('a', 6));
    await pending;

    expect(_ids(container.read(provider)), hasLength(6));
    expect(n.hasMore, isTrue);
  });

  test('a window that comes back short ends pagination', () async {
    final n = notifier();
    n.current.add(_window('a', 3));
    await container.read(provider.future);

    final pending = n.loadMore();
    n.current.add(_window('a', 4)); // < requested 6
    await pending;
    expect(n.hasMore, isFalse);

    await n.loadMore(); // no-op: no re-subscription
    expect(n.limits, [3, 6]);
  });

  test('a stream re-emission replaces the window, it does not append', () async {
    final n = notifier();
    n.current.add(_window('a', 3));
    await container.read(provider.future);

    // The underlying window re-emits (metadata sweep, deletion, ML backfill).
    n.current.add([_ref('b0'), _ref('a0'), _ref('a1')]);
    await pumpEventQueue();

    expect(_ids(container.read(provider)), ['b0', 'a0', 'a1']);
  });

  test('an error on the first emission surfaces as AsyncValue.error', () async {
    final n = notifier();
    n.current.addError(StateError('boom'));

    await expectLater(container.read(provider.future), throwsStateError);
    expect(container.read(provider).hasError, isTrue);
  });

  test('a later stream error surfaces as AsyncValue.error', () async {
    final n = notifier();
    n.current.add(_window('a', 3));
    await container.read(provider.future);

    n.current.addError(StateError('later'));
    await pumpEventQueue();

    expect(container.read(provider).hasError, isTrue);
  });

  test('disposal cancels the subscription: no emission after dispose', () async {
    final n = notifier();
    n.current.add(_window('a', 3));
    await container.read(provider.future);

    final emissions = <List<String>>[];
    container.listen(provider, (_, next) => emissions.add(_ids(next)));
    final controller = n.current;
    container.dispose();
    controller.add(_window('z', 3)); // after dispose

    await pumpEventQueue();
    expect(emissions, isEmpty);
  });
}
