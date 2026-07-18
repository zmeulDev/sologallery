import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';

/// The app's theme override (Light / Dark / System), persisted in Drift via
/// [SettingsDao]. App-wide and kept alive — `app.dart` reads it to drive
/// `MaterialApp.themeMode`, and the Settings screen writes it. Falls back to
/// [ThemeMode.system] until the stream first emits.
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref.watch(settingsDaoProvider).watchThemeMode();
});
