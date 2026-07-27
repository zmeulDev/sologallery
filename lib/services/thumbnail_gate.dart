import 'dart:async';
import 'dart:collection';

/// Bounds how many native thumbnail decodes run at once, and drops queued
/// requests whose caller has gone away.
///
/// Both halves matter, and the second is the reason this exists at all. A
/// `FutureProvider.autoDispose` releasing when a grid cell scrolls off screen
/// does **not** cancel an in-flight `thumbnailDataWithSize` — the platform
/// channel call has already been made, so it runs to completion on the native
/// side and the bytes are simply thrown away. A fast fling through a large
/// library therefore piles up decodes for cells nobody is looking at any more,
/// competing for the same native decode threads as the cells that *are* on
/// screen. Capping concurrency alone would only reorder that waste; the
/// [cancelled] re-check after waiting is what discards it.
///
/// The queue is **LIFO**, which is what a scrolling grid wants: the newest
/// request is the one nearest the viewport, while the oldest is most likely to
/// be for a cell that has already scrolled past. Under sustained load a very
/// old request could in principle starve, but in a grid it is cancelled long
/// before that matters — it stops being watched the moment its cell is
/// recycled.
class ThumbnailGate {
  ThumbnailGate({this.maxConcurrent = 6}) : assert(maxConcurrent > 0);

  /// How many decodes may be in flight at once. Six is enough to keep the
  /// native decoders busy without letting a fling queue dozens of them.
  final int maxConcurrent;

  /// Slots currently held (running tasks), not tasks waiting for one.
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  /// Callers parked on [whenQuiet] until this gate next drains fully.
  final List<Completer<void>> _quietWaiters = <Completer<void>>[];

  /// Held slots — running tasks. Exposed for tests.
  int get active => _active;

  /// Requests queued behind [maxConcurrent]. Exposed for tests.
  int get waiting => _waiting.length;

  /// No decode running or queued right now.
  bool get isQuiet => _active == 0 && _waiting.isEmpty;

  /// Completes the next time this gate has nothing running or queued — i.e. a
  /// foreground grid decode burst has fully drained. Resolves immediately if
  /// already quiet.
  ///
  /// Background indexing awaits this before submitting its own decode so it
  /// yields the shared native decode pool (Android: Glide's thread pool) to an
  /// active grid, per CLAUDE.md's "speed and UX come first / move work to
  /// background when idle". A single indexing decode may still overlap the next
  /// grid cell — the burst refills faster than this races — which is harmless;
  /// what it prevents is a whole indexing pass grinding against a "View all"
  /// screenful on the same native decoders (see docs/plans/…-latency.md).
  Future<void> whenQuiet() {
    if (isQuiet) return Future<void>.value();
    final waiter = Completer<void>();
    _quietWaiters.add(waiter);
    return waiter.future;
  }

  /// Runs [task] once a slot is free, returning null instead if [cancelled]
  /// reports the caller has gone away — checked both before queueing and again
  /// after the wait, since that wait is exactly when a cell scrolls off.
  Future<T?> run<T>(
    Future<T?> Function() task, {
    bool Function()? cancelled,
  }) async {
    bool isCancelled() => cancelled?.call() ?? false;
    if (isCancelled()) return null;
    await _acquire();
    try {
      if (isCancelled()) return null;
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// Hands the slot straight to the newest waiter rather than decrementing and
  /// letting it re-acquire — otherwise a task starting between the decrement
  /// and the wake-up could take the slot and push the count over the cap.
  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeLast().complete();
    } else {
      _active--;
    }
    if (isQuiet && _quietWaiters.isNotEmpty) {
      final waiters = List<Completer<void>>.of(_quietWaiters);
      _quietWaiters.clear();
      for (final w in waiters) {
        w.complete();
      }
    }
  }
}
