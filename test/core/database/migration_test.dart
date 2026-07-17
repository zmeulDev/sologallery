import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sologallery/core/database/app_database.dart';

import 'generated_migrations/schema.dart';

/// Establishes the schema-verification harness. As new schema versions land,
/// add `verifier.migrateAndValidate(db, N)` cases here so every v(N-1)→vN
/// upgrade path is exercised against the committed dumps in `drift_schemas/`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('applies the v1 schema and matches the committed dump', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    // Migrating "to" the current version validates that the live schema built
    // by the generated code equals drift_schemas/drift_schema_v1.json.
    await verifier.migrateAndValidate(db, 1);
  });
}
