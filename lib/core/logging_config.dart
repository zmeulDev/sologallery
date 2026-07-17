import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Root logger for the app. Children are created per-area, e.g.
/// `Logger('SoloGallery.db')`, `Logger('SoloGallery.ml')`.
final appLogger = Logger('SoloGallery');

/// Configures the hierarchical `SoloGallery` logger. Call once from `main()`
/// before `runApp`. Records go through `dart:developer.log` (never `print`),
/// so on-device they surface under `adb logcat -s flutter:V SoloGallery:V`.
void configureLogging() {
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
}
