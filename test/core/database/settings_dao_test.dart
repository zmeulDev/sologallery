import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('put then watch round-trips a value', () async {
    expect(await db.settingsDao.watch('k').first, isNull);
    await db.settingsDao.put('k', 'v1');
    expect(await db.settingsDao.watch('k').first, 'v1');
    await db.settingsDao.put('k', 'v2'); // upsert
    expect(await db.settingsDao.watch('k').first, 'v2');
  });

  test('theme mode defaults to system and persists a set value', () async {
    expect(await db.settingsDao.watchThemeMode().first, ThemeMode.system);

    await db.settingsDao.setThemeMode(ThemeMode.dark);
    expect(await db.settingsDao.watchThemeMode().first, ThemeMode.dark);

    await db.settingsDao.setThemeMode(ThemeMode.light);
    expect(await db.settingsDao.watchThemeMode().first, ThemeMode.light);
  });

  test('an unrecognized stored value falls back to system', () async {
    await db.settingsDao.put('theme_mode', 'bogus');
    expect(await db.settingsDao.watchThemeMode().first, ThemeMode.system);
  });

  group('on-device analysis consent', () {
    test('every feature is off until explicitly enabled', () async {
      expect(await db.settingsDao.watchSearchEnabled().first, isFalse);
      expect(await db.settingsDao.readSearchEnabled(), isFalse);
      expect(await db.settingsDao.watchMemoriesEnabled().first, isFalse);
      expect(await db.settingsDao.watchFacesEnabled().first, isFalse);
      expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
      expect(await db.settingsDao.readFacesEnabled(), isFalse);
    });

    test('each flag round-trips independently', () async {
      await db.settingsDao.setFacesEnabled(true);
      expect(await db.settingsDao.readFacesEnabled(), isTrue);
      expect(await db.settingsDao.readMemoriesEnabled(), isFalse);
      expect(await db.settingsDao.readSearchEnabled(), isFalse);

      await db.settingsDao.setMemoriesEnabled(true);
      await db.settingsDao.setFacesEnabled(false);
      expect(await db.settingsDao.readFacesEnabled(), isFalse);
      expect(await db.settingsDao.readMemoriesEnabled(), isTrue);
    });

    test('consent is recorded even when every answer is no', () async {
      expect(await db.settingsDao.readConsentRecorded(), isFalse);

      // Declining both must still count as answered, or onboarding re-prompts
      // forever.
      await db.settingsDao.setSearchEnabled(false);
      await db.settingsDao.setMemoriesEnabled(false);
      await db.settingsDao.setFacesEnabled(false);
      expect(await db.settingsDao.readConsentRecorded(), isFalse);

      await db.settingsDao.recordConsent();
      expect(await db.settingsDao.readConsentRecorded(), isTrue);
      expect(await db.settingsDao.readFacesEnabled(), isFalse);
    });
  });

  group('excluded folders', () {
    test('defaults to empty and round-trips a set', () async {
      expect(await db.settingsDao.readExcludedFolderIds(), isEmpty);
      expect(await db.settingsDao.watchExcludedFolderIds().first, isEmpty);

      await db.settingsDao.setExcludedFolderIds({'f1', 'f2'});
      expect(await db.settingsDao.readExcludedFolderIds(), {'f1', 'f2'});
      expect(await db.settingsDao.watchExcludedFolderIds().first, {'f1', 'f2'});

      await db.settingsDao.setExcludedFolderIds({});
      expect(await db.settingsDao.readExcludedFolderIds(), isEmpty);
    });

    test('malformed stored value defaults to empty', () async {
      await db.settingsDao.put('excluded_folder_ids', 'not-json');
      expect(await db.settingsDao.readExcludedFolderIds(), isEmpty);
    });

    test('non-string entries are ignored', () async {
      await db.settingsDao.put('excluded_folder_ids', '["a", 123, "b"]');
      expect(await db.settingsDao.readExcludedFolderIds(), {'a', 'b'});
    });
  });
}
