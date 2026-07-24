# Plan: Graceful ML worker shutdown

## Problem
`dumpsys dropbox` shows a native `SIGABRT` in `com.zmeul.sologallery`:

```
[FATAL:flutter/lib/ui/window/platform_message_response_dart_port.cc(53)] Check failed: did_send.
```

The top of the Android stack is ML Kit text recognition completing and calling
`MethodChannel.Result.success` → `DartMessenger$Reply.reply`. The reply cannot be
sent because the target Dart isolate/port no longer exists, so the engine aborts
the process.

## Root cause
`lib/services/ml_service.dart:166-176` kills the worker isolate immediately:

```dart
void dispose() {
  _isolate?.kill(priority: Isolate.immediate);
  ...
}
```

`Isolate.immediate` terminates the Dart isolate, but it does **not** cancel the
native ML Kit task that is currently running on another thread. When that task
later finishes on the Android main thread and tries to reply to the dead port,
the engine hits `did_send == false` and deliberately crashes.

The worker **does** call
`BackgroundIsolateBinaryMessenger.ensureInitialized(init.token)` before any ML
Kit call, so the binary messenger itself is bound correctly. The crash is not an
isolate-binding hang; it is a dispose-while-in-flight crash.

## Goal
Make `MlWorkerController.dispose()` shut down gracefully so that the isolate is
never killed while a native ML Kit call may still reply to it.

## Non-goals
- No new user-facing behavior.
- No changes to ML pipeline accuracy, model loading, or consent logic.
- No migration or schema changes.

## Approach

### 1. Add a shutdown protocol between controller and worker
- New private message `_ShutdownJob` sent from controller to worker.
- New private message `_ShutdownAck` sent back when the worker has finished its
  current job and closed its models.

### 2. Worker shutdown sequence (`_workerMain`)
`commands.listen` delivers stream events sequentially, so a `_ShutdownJob` that
arrives while a job is awaiting `processImage` is queued until the current
handler completes. That means no native ML call is in flight when shutdown is
processed.

On `_ShutdownJob`:
1. Close any opened models (`ImageLabeler`, `TextRecognizer`, `FaceDetector`,
   `Interpreter`).
2. Send `_ShutdownAck` to the controller.
3. Close the worker's `ReceivePort`.
4. Let the isolate exit naturally.

### 3. Controller shutdown sequence (`MlWorkerController.dispose`)
Change the interface to `Future<void> dispose()` and return a completer-backed
future so callers can await shutdown.

1. Mark the controller disposed; future `analyze()` calls throw
   `StateError('ML worker disposed')`.
2. Complete every currently pending caller's completer with the same error.
3. Send `_ShutdownJob` to the worker (if the isolate has finished spawning).
4. Spawn the isolate with `onExit: _onExitPort.sendPort` so we can detect natural
   death.
5. Wait for `_ShutdownAck` plus the isolate `onExit` signal, with a generous
   timeout (e.g. 30 s). After ack, no native call can be in flight, so a
   remaining isolate can be force-killed only as a last resort if it fails to
   exit naturally.
6. Close local ports and clear state.

`dispose()` can be called multiple times; subsequent calls return the same
shutdown future.

### 4. Update callers and fakes
- `IndexingService.dispose()` already returns `Future<void>` → `await worker.dispose()`.
- `mlWorkerProvider` `ref.onDispose(worker.dispose)` remains valid because a
  `Future<void> Function()` is assignable to `void Function()`; the async work
  will still run. Change it to `ref.onDispose(() async => await worker.dispose())`
  for clarity.
- `FakeMlWorker.dispose()` → `Future<void>` returning `Future.value()`.
- Integration tests using `addTearDown(worker.dispose)` → `addTearDown(() async => await worker.dispose())`.

### 5. Testing
Because ML Kit cannot run under `flutter test`, add a host unit test that
injects a test worker entrypoint to exercise the shutdown protocol without
touching native code.

- Create `test/services/ml_worker_shutdown_test.dart`.
- Make the worker entrypoint injectable for tests (`@visibleForTesting` constructor
  or factory) and expose the internal init class with `@visibleForTesting`.
- Test cases:
  - `dispose()` waits for an in-flight job to finish before completing.
  - `dispose()` completes pending callers with an error immediately.
  - `analyze()` after `dispose()` throws.
  - `dispose()` can be called twice and returns the same future.
  - The worker isolate exits naturally after shutdown (no immediate `kill`).

Keep the on-device integration test `integration_test/ml_indexing_test.dart`
as the real-path counterpart (fake-pairing rule). Update its teardown to await
`worker.dispose()`.

## Files to change
- `lib/services/ml_service.dart` — shutdown protocol, graceful dispose.
- `lib/services/indexing_service.dart` — await `worker.dispose()` in
  `IndexingService.dispose()`; update `mlWorkerProvider` `onDispose`.
- `test/support/fake_ml_worker.dart` — async `dispose()`.
- `test/services/ml_worker_shutdown_test.dart` — new unit tests.
- `integration_test/ml_indexing_test.dart` — await teardown dispose.
- `integration_test/test_fixtures_test.dart` — await teardown dispose.
- `docs/gotchas.md` — add the crash rule if not already covered.

## Risks / follow-ups
- `ref.onDispose` is not awaited by Riverpod; app-kill mid-shutdown is still
  outside our control, but we will no longer be the ones killing the isolate
  while ML is running.
- A stuck worker (native call never returning) would block `dispose()` until the
  timeout. We will log this and fall back to force kill, accepting the small
  crash risk only in that pathological case.

## Implementation status
- [x] `lib/services/ml_service.dart` — added `_ShutdownJob`/`_ShutdownAck` protocol,
      made `dispose()` async and graceful, spawned isolate with `onExit` port,
      added force-kill only after ack (or 60 s stuck timeout).
- [x] `lib/services/indexing_service.dart` — `await worker.dispose()`; updated
      `mlWorkerProvider` `onDispose`.
- [x] `test/support/fake_ml_worker.dart` — async `dispose()`.
- [x] `test/services/ml_worker_shutdown_test.dart` — new host tests with injected
      test worker entrypoint.
- [x] `integration_test/ml_indexing_test.dart`, `test_fixtures_test.dart`,
      `consent_test.dart` — await teardown dispose.
- [x] `pubspec.yaml` — added direct `meta` dependency for `@visibleForTesting`.
- [x] `docs/gotchas.md` — added the "never kill mid-native-ML-call" rule.

## Verification
- `flutter analyze` clean on changed files.
- `flutter test test/services/ml_worker_shutdown_test.dart
   test/services/indexing_service_test.dart
   test/features/settings/consent_provider_test.dart` → all pass.

### 2026-07-24 re-verification
- `flutter analyze` (whole project) → "No issues found!".
- `dart run build_runner build` → 0 outputs written (codegen up to date).
- `flutter test test/services/ml_worker_shutdown_test.dart
   test/services/indexing_service_test.dart` → 42 tests pass, including
  "worker isolate exits naturally after shutdown".
- **On-device (Pixel 9 Pro XL `46121FDAS008AA`):**
  `flutter test integration_test/ml_indexing_test.dart -d 46121FDAS008AA`
  → `+1: All tests passed!` (7 s). The real `MlWorkerController` isolate ran ML
  Kit labeling on device photos and the awaited `worker.dispose()` teardown
  completed without a crash.
  - First attempt failed on the `access.canReadLibrary` precondition — the
    previous run's teardown uninstall wiped the grant (documented in
    `docs/gotchas.md`). Fixed by `adb install -r` + `pm grant` of
    `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_VISUAL_USER_SELECTED`
    before re-running; not a code problem.
  - `adb shell dumpsys dropbox --print` after the run shows **no new**
    `data_app_native_crash`; the newest entry is still 2026-07-21 17:52:28,
    which predates this fix. The `did_send` SIGABRT did not reproduce.

## Remaining work
- Run `tool/check.sh` full suite (some unrelated golden/widget failures and a
  long-running folder-picker test were pre-existing on this branch).
  → in progress 2026-07-24; analyze + build_runner already clean, full
  `flutter test` still running at time of writing.

## Follow-ups
- If the 60 s / 5 s timeouts prove too tight on slow devices, tune them after
  on-device observation.
