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
  static const _searchEnabledKey = 'search_enabled';
  static const _memoriesEnabledKey = 'memories_enabled';
  static const _facesEnabledKey = 'faces_enabled';
  static const _consentKey = 'ml_consent';

  /// The consent prompt's version. **Bump this when the prompt's scope changes**
  /// — a new analysis feature, or an existing one starting to do materially
  /// more — and every user is asked again, because an answer given to the old
  /// question is not an answer to the new one. The stored value is compared
  /// exactly, so going backwards re-prompts too.
  static const consentVersion = 1;

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

  // --- On-device analysis consent ------------------------------------------
  //
  // Content search, memories, and face detection are opt-in: all three default
  // to *off* until the user says otherwise, so nothing is derived from the
  // library without consent. [_consentKey] records that the question was asked
  // at all — it is deliberately separate from the three flags, because
  // "declined everything" and "never asked" must not look alike (they would
  // re-prompt forever).

  /// Whether content search (ML labels + OCR text) is enabled, reactive. False
  /// until set. This is the flag that decides whether *any* ML runs at all
  /// alongside [watchFacesEnabled].
  Stream<bool> watchSearchEnabled() => watch(_searchEnabledKey).map(_decodeBool);

  Future<bool> readSearchEnabled() async =>
      _decodeBool(await read(_searchEnabledKey));

  Future<void> setSearchEnabled(bool enabled) =>
      put(_searchEnabledKey, enabled.toString());

  /// Whether auto-curated Memories are enabled, reactive. False until set.
  Stream<bool> watchMemoriesEnabled() =>
      watch(_memoriesEnabledKey).map(_decodeBool);

  /// Whether face detection / People is enabled, reactive. False until set.
  Stream<bool> watchFacesEnabled() => watch(_facesEnabledKey).map(_decodeBool);

  /// One-shot reads for the indexer, which gates each pass on these.
  Future<bool> readMemoriesEnabled() async =>
      _decodeBool(await read(_memoriesEnabledKey));

  Future<bool> readFacesEnabled() async =>
      _decodeBool(await read(_facesEnabledKey));

  Future<void> setMemoriesEnabled(bool enabled) =>
      put(_memoriesEnabledKey, enabled.toString());

  Future<void> setFacesEnabled(bool enabled) =>
      put(_facesEnabledKey, enabled.toString());

  /// Whether the user has answered the *current* consent prompt, reactive.
  /// Onboarding holds the user on the consent step until this is true, so a
  /// [consentVersion] bump re-asks even a user who answered before.
  Stream<bool> watchConsentRecorded() => watch(_consentKey).map(_isCurrent);

  Future<bool> readConsentRecorded() async => _isCurrent(await read(_consentKey));

  /// Marks the current consent prompt as answered (whatever the answers were).
  Future<void> recordConsent() => put(_consentKey, consentVersion.toString());

  static bool _isCurrent(String? value) =>
      int.tryParse(value ?? '') == consentVersion;

  static bool _decodeBool(String? value) => value == 'true';
}
