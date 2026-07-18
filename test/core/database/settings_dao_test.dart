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
}
