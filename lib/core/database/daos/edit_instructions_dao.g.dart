// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_instructions_dao.dart';

// ignore_for_file: type=lint
mixin _$EditInstructionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $EditInstructionsTable get editInstructions =>
      attachedDatabase.editInstructions;
  EditInstructionsDaoManager get managers => EditInstructionsDaoManager(this);
}

class EditInstructionsDaoManager {
  final _$EditInstructionsDaoMixin _db;
  EditInstructionsDaoManager(this._db);
  $$EditInstructionsTableTableManager get editInstructions =>
      $$EditInstructionsTableTableManager(
        _db.attachedDatabase,
        _db.editInstructions,
      );
}
