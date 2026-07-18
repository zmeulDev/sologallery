import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' show Person;
import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../core/database/database_provider.dart';
import '../../services/photo_library_service.dart' show AssetRef;

/// A person's cover face: the asset to crop and the box within its 512-thumb.
typedef CoverFace = ({
  String assetId,
  int left,
  int top,
  int right,
  int bottom,
});

/// Clustered people with a face count, most-photographed first. A DB stream so
/// the list grows as indexing/clustering progresses.
final personSummariesProvider =
    StreamProvider.autoDispose<List<PersonSummary>>(
  (ref) => ref.watch(facesDaoProvider).watchPersonSummaries(),
);

/// A single person by id — drives the detail app-bar title/rename.
final personProvider = StreamProvider.autoDispose.family<Person?, int>(
  (ref, id) => ref.watch(facesDaoProvider).watchPerson(id),
);

/// The photos a person appears in, newest first.
final personAssetsProvider =
    FutureProvider.autoDispose.family<List<AssetRef>, int>(
  (ref, id) => ref.watch(facesDaoProvider).assetsForPerson(id),
);

/// The representative face box for a person's avatar (null if none).
final personCoverProvider =
    FutureProvider.autoDispose.family<CoverFace?, int>(
  (ref, id) => ref.watch(facesDaoProvider).coverFace(id),
);

/// Side-effecting people actions, kept out of widgets (Riverpod conventions).
final peopleActionsProvider = Provider<PeopleActions>(PeopleActions.new);

class PeopleActions {
  PeopleActions(this._ref);
  final Ref _ref;

  /// Renames a person (null/empty clears the name back to "unnamed").
  Future<void> rename(int personId, String? name) {
    final trimmed = name?.trim();
    return _ref
        .read(facesDaoProvider)
        .renamePerson(personId, (trimmed == null || trimmed.isEmpty) ? null : trimmed);
  }
}
