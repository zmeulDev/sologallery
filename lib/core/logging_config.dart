import 'dart:async' show StreamSubscription;
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Configures the hierarchical `SoloGallery` logger. Call once from `main()`
/// before `runApp`.
///
/// Records go two places. `dart:developer.log` feeds the VM-service *Logging*
/// stream, which is what DevTools shows — but nothing else reads it: it is not
/// forwarded by `flutter run` and never reaches Android logcat. So outside
/// release builds every record is also mirrored through [debugPrint], the one
/// sink the engine actually routes to logcat (under the `flutter` tag), which
/// is what makes `adb logcat -s flutter:V SoloGallery:V` work as documented.
/// `dart:io` stdout is *not* an option — Android discards that descriptor.
///
/// This is the one place [debugPrint] is allowed: it is the logger's own sink.
/// Feature code always goes through a [Logger].
///
/// Loggers are created per-area at their point of use, e.g.
/// `Logger('SoloGallery.db')`, `Logger('SoloGallery.ml')`; they inherit this
/// root configuration by name.
StreamSubscription<LogRecord>? _loggingSubscription;

void configureLogging() {
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
  _loggingSubscription?.cancel();
  _loggingSubscription = Logger.root.onRecord.listen((record) {
    developer.log(
      '[${record.loggerName}] ${record.message}',
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
    if (!kReleaseMode) _mirrorToLogcat(record);
  });
}

/// Mirrors [record] to logcat. Kept total — a logging sink that throws would
/// take down whatever it was reporting on.
void _mirrorToLogcat(LogRecord record) {
  try {
    final buffer = StringBuffer()
      ..write(record.level.name)
      ..write(' [')
      ..write(record.loggerName)
      ..write('] ')
      ..write(record.message);
    if (record.error != null) buffer.write('\n  error: ${record.error}');
    if (record.stackTrace != null) buffer.write('\n${record.stackTrace}');
    debugPrint(buffer.toString());
  } catch (_) {
    // Losing the mirror is fine — developer.log already has the record.
  }
}
