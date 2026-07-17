import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'edit_instructions_dao.g.dart';

/// Data-access for [EditInstructions]. Stores non-destructive edit JSON keyed
/// by asset id; originals are never touched. Pure data layer.
@DriftAccessor(tables: [EditInstructions])
class EditInstructionsDao extends DatabaseAccessor<AppDatabase>
    with _$EditInstructionsDaoMixin {
  EditInstructionsDao(super.db);

  /// The edit document for [assetId], or null if none.
  Future<EditInstruction?> getForAsset(String assetId) {
    return (select(editInstructions)..where((e) => e.assetId.equals(assetId)))
        .getSingleOrNull();
  }

  /// Watches the edit document for [assetId].
  Stream<EditInstruction?> watchForAsset(String assetId) {
    return (select(editInstructions)..where((e) => e.assetId.equals(assetId)))
        .watchSingleOrNull();
  }

  /// Inserts or replaces the edit document for [assetId].
  Future<void> upsert(String assetId, String instructionsJson,
      {DateTime? at}) {
    return into(editInstructions).insert(
      EditInstructionsCompanion.insert(
        assetId: assetId,
        instructionsJson: instructionsJson,
        updatedAt: at ?? DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Removes any edit document for [assetId] (reverts to original). Returns
  /// rows deleted.
  Future<int> deleteForAsset(String assetId) {
    return (delete(editInstructions)..where((e) => e.assetId.equals(assetId)))
        .go();
  }
}
