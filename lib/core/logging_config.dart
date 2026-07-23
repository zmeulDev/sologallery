import 'dart:async' show StreamSubscription;
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Configures the hierarchical `SoloGallery` logger. Call once from `main()`
/// before `runApp`. Records go through `dart:developer.log` (never `print`),
/// so on-device they surface under `adb logcat -s flutter:V SoloGallery:V`.
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
  });
}
