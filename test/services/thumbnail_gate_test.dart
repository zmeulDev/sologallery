import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/thumbnail_gate.dart';

void main() {
  group('ThumbnailGate', () {
    test('runs up to maxConcurrent tasks at once and queues the rest', () async {
      final gate = ThumbnailGate(maxConcurrent: 2);
      final completers = List.generate(4, (_) => Completer<int?>());
      final results = <Future<int?>>[
        for (var i = 0; i < 4; i++) gate.run(() => completers[i].future),
      ];

      await pumpEventQueue();
      expect(gate.active, 2, reason: 'only two slots exist');
      expect(gate.waiting, 2);

      completers[0].complete(0);
      await pumpEventQueue();
      expect(gate.active, 2, reason: 'the freed slot is handed to a waiter');
      expect(gate.waiting, 1);

      for (var i = 1; i < 4; i++) {
        if (!completers[i].isCompleted) completers[i].complete(i);
      }
      expect(await Future.wait(results), [0, 1, 2, 3]);
      expect(gate.active, 0);
      expect(gate.waiting, 0);
    });

    test('never exceeds maxConcurrent under a burst', () async {
      final gate = ThumbnailGate(maxConcurrent: 3);
      var running = 0;
      var peak = 0;
      Future<int?> task() async {
        running++;
        peak = running > peak ? running : peak;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        running--;
        return 1;
      }

      await Future.wait([for (var i = 0; i < 20; i++) gate.run(task)]);
      expect(peak, lessThanOrEqualTo(3));
      expect(gate.active, 0);
    });

    test('skips a queued task whose caller cancelled while it waited', () async {
      // The behaviour the gate exists for: a cell that scrolls away after its
      // request is queued must never reach the native decode at all.
      final gate = ThumbnailGate(maxConcurrent: 1);
      final blocker = Completer<int?>();
      final held = gate.run(() => blocker.future);

      var cancelled = false;
      var ran = false;
      final queued = gate.run(() async {
        ran = true;
        return 7;
      }, cancelled: () => cancelled);

      await pumpEventQueue();
      expect(gate.waiting, 1);

      cancelled = true; // the cell is recycled while the request sits in line
      blocker.complete(0);

      expect(await queued, isNull);
      expect(ran, isFalse, reason: 'the task must never have been invoked');
      await held;
      expect(gate.active, 0);
    });

    test('skips a task cancelled before it was ever queued', () async {
      final gate = ThumbnailGate(maxConcurrent: 4);
      var ran = false;
      final result = await gate.run(() async {
        ran = true;
        return 1;
      }, cancelled: () => true);

      expect(result, isNull);
      expect(ran, isFalse);
      expect(gate.active, 0, reason: 'no slot was ever taken');
    });

    test('releases its slot when the task throws', () async {
      final gate = ThumbnailGate(maxConcurrent: 1);
      await expectLater(
        gate.run<int>(() async => throw StateError('decode failed')),
        throwsStateError,
      );
      expect(gate.active, 0, reason: 'a failed decode must not leak its slot');

      // And the gate still works afterwards.
      expect(await gate.run(() async => 5), 5);
    });

    test('serves the newest waiter first', () async {
      // LIFO: the newest request is the one nearest the viewport.
      final gate = ThumbnailGate(maxConcurrent: 1);
      final blocker = Completer<int?>();
      final held = gate.run(() => blocker.future);
      final order = <int>[];

      final queued = [
        for (var i = 0; i < 3; i++)
          gate.run(() async {
            order.add(i);
            return i;
          }),
      ];

      await pumpEventQueue();
      blocker.complete(0);
      await Future.wait(queued);
      await held;

      expect(order, [2, 1, 0]);
    });
  });
}
