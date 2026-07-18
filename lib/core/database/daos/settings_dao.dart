import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../app_database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

/// Data-access for [AppSettings] — generic key/value app preferences plus typed
/// helpers for the settings we persist today. Pure data layer; values are
/// encoded to text here so the table stays generic.
@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  static const _themeModeKey = 'theme_mode';

  /// The raw value for [key], reactive; null until it is first set.
  Stream<String?> watch(String key) {
    final q = select(appSettings)..where((s) => s.key.equals(key));
    return q.watchSingleOrNull().map((row) => row?.value);
  }

  /// One-shot read of [key]'s value; null if unset. For non-reactive callers
  /// (e.g. the indexer's re-cluster baseline).
  Future<String?> read(String key) async {
    final row = await (select(appSettings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Upserts [key] = [value].
  Future<void> put(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  // --- Theme override ------------------------------------------------------

  /// The user's theme override, reactive. Defaults to [ThemeMode.system] until
  /// set (or if the stored value is unrecognized).
  Stream<ThemeMode> watchThemeMode() =>
      watch(_themeModeKey).map(_decodeThemeMode);

  /// Persists the theme override.
  Future<void> setThemeMode(ThemeMode mode) => put(_themeModeKey, mode.name);

  static ThemeMode _decodeThemeMode(String? value) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
