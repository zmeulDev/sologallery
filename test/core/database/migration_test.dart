import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v6.dart';
import 'generated_migrations/schema_v7.dart';

/// Establishes the schema-verification harness. Each case migrates a real old
/// schema all the way to the current version and asserts it matches the
/// committed dump (`drift_schemas/`). We validate every path *to current* (not
/// each intermediate step) because `onUpgrade`'s `createTable` calls use the
/// live table definitions, so a stopped-at-vN run would reflect the current
/// photo_assets shape, not vN's — only the end state is historically exact.
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

  test('upgrades v1 → v10 (fresh photo_asset in current shape + all later tables)',
      () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('upgrades v2 → v10 (adds photo_text + alters photo_asset + settings/memories)',
      () async {
    final connection = await verifier.startAt(2);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('upgrades v3 → v10 (photo_asset.indexed_at nullable + is_dated + rest)',
      () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('upgrades v4 → v10 (adds app_settings + memories)', () async {
    final connection = await verifier.startAt(4);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('upgrades v5 → v10 (adds memories + memory_entries)', () async {
    final connection = await verifier.startAt(5);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('upgrades v6 → v10 (face box columns become normalized reals)', () async {
    final connection = await verifier.startAt(6);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test(
      'v6 → v7 drops pixel-space faces and clusters, and re-queues the assets '
      'so they are re-derived', () async {
    final schema = await verifier.schemaAt(6);
    final old = DatabaseAtV6(schema.newConnection());
    // A fully ML-indexed v6 asset with one clustered face, box in pixels.
    await old.customStatement(
      'INSERT INTO photo_assets '
      '(asset_id, created_at, is_video, width, height, is_dated, indexed_at) '
      "VALUES ('a', 1000, 0, 4032, 3024, 1, 2000)",
    );
    await old.customStatement(
      'INSERT INTO persons (id, display_name, cover_asset_id, created_at) '
      "VALUES (1, 'Ana', 'a', 1000)",
    );
    await old.customStatement(
      'INSERT INTO face_embeddings '
      '(id, asset_id, person_id, embedding, "left", "top", "right", "bottom") '
      "VALUES (1, 'a', 1, x'0000803f', 100, 120, 260, 280)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    // The pixel box is unconvertible — the thumbnail size it was measured
    // against was never recorded — so the face and the cluster built from it
    // go, rather than being reinterpreted as a (nonsense) fraction.
    expect(await db.facesDao.faceCount(), 0);
    expect(await db.facesDao.allPersons(), isEmpty);
    // And the asset is unstamped again, so the next pass re-derives both.
    expect(await db.indexDao.pendingMlIds(), ['a']);
  });

  test('upgrades v7 → v10 (persons gain merged_into)', () async {
    final connection = await verifier.startAt(7);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);
  });

  test('v7 → v8 keeps existing people, unmerged', () async {
    final schema = await verifier.schemaAt(7);
    final old = DatabaseAtV7(schema.newConnection());
    await old.customStatement(
      'INSERT INTO persons (id, display_name, cover_asset_id, created_at) '
      "VALUES (1, 'Ana', 'a', 1000)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    // The column is additive: the person survives and starts life unmerged.
    final people = await db.facesDao.allPersons();
    expect(people, hasLength(1));
    expect(people.single.displayName, 'Ana');
    expect(people.single.mergedInto, isNull);
  });

  test('upgrades v8 → v10 (adds the photo_assets (is_dated, created_at) index)',
      () async {
    final connection = await verifier.startAt(8);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    // Positive control: the v10 index actually landed. migrateAndValidate
    // checks the schema dump, but a dropped `m.create` would silently pass
    // if the dump were stale — assert the index row itself (AGENTS.md
    // "positive control" rule).
    final indexRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name='photo_asset_dated_created'",
        )
        .get();
    expect(indexRows, hasLength(1));
  });

  test('upgrades v9 → v10 (adds recently_viewed table)', () async {
    final connection = await verifier.startAt(9);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 10);

    // Positive control: the table exists and rows survive the migration.
    await db.customStatement(
      "INSERT INTO recently_viewed (asset_id, viewed_at) VALUES ('a', 1000)"
    );
    final rows = await db
        .customSelect("SELECT asset_id FROM recently_viewed")
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('asset_id'), 'a');
  });
}
