import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/services/ml_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String testTempDir() {
    return Directory.systemTemp.createTempSync('sg_ml_test_').path;
  }

  group('MlWorkerController graceful shutdown', () {
    test('dispose waits for in-flight native work before completing', () async {
      final worker = MlWorkerController.withWorkerMain(
        testWorkerMain(jobDelay: const Duration(milliseconds: 200)),
        tempDirectory: testTempDir(),
      );

      final job = worker.analyze(bytes: Uint8List.fromList([1, 2, 3]));
      // Give the job time to start but not finish.
      await Future.delayed(const Duration(milliseconds: 50));

      // Attach the error listener before dispose() completes the job future.
      final jobError = expectLater(job, throwsA(isA<StateError>()));

      final dispose = worker.dispose();
      // dispose should not complete instantly because the worker still has a
      // job in progress and must finish it (without killing the isolate) before
      // it can acknowledge shutdown and exit.
      var disposeCompletedEarly = false;
      unawaited(dispose.then((_) => disposeCompletedEarly = true));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(disposeCompletedEarly, isFalse);

      await jobError;
      await dispose;
    });

    test('dispose completes pending callers with an error immediately', () async {
      final worker = MlWorkerController.withWorkerMain(
        testWorkerMain(jobDelay: const Duration(seconds: 10)),
        tempDirectory: testTempDir(),
      );

      final job = worker.analyze(bytes: Uint8List.fromList([1, 2, 3]));
      await Future.delayed(const Duration(milliseconds: 50));

      // Attach the error listener before dispose() so the async error is caught
      // rather than reported as unhandled.
      final jobError = expectLater(job, throwsA(isA<StateError>()));

      // dispose() should complete the pending job future with an error, not
      // leave it dangling while it waits for the worker to exit.
      await worker.dispose();
      await jobError;
    });

    test('analyze after dispose throws', () async {
      final worker = MlWorkerController.withWorkerMain(
        testWorkerMain(),
        tempDirectory: testTempDir(),
      );
      await worker.dispose();
      expect(
        () => worker.analyze(bytes: Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });

    test('dispose returns the same future on repeated calls', () async {
      final worker = MlWorkerController.withWorkerMain(
        testWorkerMain(),
        tempDirectory: testTempDir(),
      );
      final first = worker.dispose();
      final second = worker.dispose();
      expect(identical(first, second), isTrue);
      await first;
      await second;
    });

    test('worker isolate exits naturally after shutdown', () async {
      final worker = MlWorkerController.withWorkerMain(
        testWorkerMain(jobDelay: const Duration(milliseconds: 200)),
        tempDirectory: testTempDir(),
      );
      // Start a job and dispose while it is running.
      final job = worker.analyze(bytes: Uint8List.fromList([1, 2, 3]));
      await Future.delayed(const Duration(milliseconds: 50));

      final jobError = expectLater(job, throwsA(isA<StateError>()));
      await worker.dispose();
      await jobError;
      // dispose() only completes after the isolate onExit signal, so reaching
      // here proves the worker exited naturally without an immediate kill
      // mid-job.
    });
  });
}
