import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';

import 'generated_migrations/schema.dart';

/// Establishes the schema-verification harness. Each case migrates a real old
/// schema all the way to the current version and asserts it matches the
/// committed dump (`drift_schemas/`). We validate every path *to current* (not
/// each intermediate step) because `onUpgrade`'s `createTable` calls use the
/// live table definitions, so a stopped-at-vN run would reflect the current
/// photo_assets shape, not vN's — only the end state (v4) is historically exact.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('applies the v1 schema and matches the committed dump', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
  });

  test('upgrades v1 → v4 (fresh photo_asset in current shape)', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);
  });

  test('upgrades v2 → v4 (adds photo_text + alters photo_asset)', () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);
  });

  test('upgrades v3 → v4 (photo_asset.indexed_at nullable + is_dated)',
      () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 4);
  });
}
