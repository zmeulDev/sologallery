import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' show Person;
import '../../core/database/daos/faces_dao.dart' show PersonSummary;
import '../../core/database/database_provider.dart';
import '../../services/photo_library_service.dart' show AssetRef;
import '../settings/consent_provider.dart';

/// A person's cover face: the asset to crop and the box within it, normalized
/// to `[0, 1]` fractions of the image (see the `FaceEmbeddings` table docs).
typedef CoverFace = ({
  String assetId,
  double left,
  double top,
  double right,
  double bottom,
});

/// Clustered people with a face count, most-photographed first. A DB stream so
/// the list grows as indexing/clustering progresses.
///
/// Empty unless the user turned face detection on (opt-in; see
/// [ConsentNotifier]) — disabling deletes the clusters anyway, but gating here
/// means every people surface goes quiet the instant consent is withdrawn,
/// without each one re-checking the flag.
final personSummariesProvider =
    StreamProvider.autoDispose<List<PersonSummary>>((ref) {
  final enabled = ref.watch(facesEnabledProvider).value ?? false;
  if (!enabled) return Stream.value(const []);
  return ref.watch(facesDaoProvider).watchPersonSummaries();
});

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

/// Cover faces for every person in [personSummariesProvider], resolved in one
/// batch so avatar cells don't each hit the DB as they scroll in (B2). Keyed by
/// person id; a person with no face is absent.
final personCoversProvider =
    FutureProvider.autoDispose<Map<int, CoverFace>>((ref) async {
  final summaries = await ref.watch(personSummariesProvider.future);
  if (summaries.isEmpty) return const {};
  return ref
      .watch(facesDaoProvider)
      .coverFacesFor([for (final p in summaries) p.id]);
});

/// The clusters the user merged into this person — empty for almost everyone,
/// so the "separate" action only appears where it means something.
final mergedPeopleProvider =
    FutureProvider.autoDispose.family<List<Person>, int>(
  (ref, id) => ref.watch(facesDaoProvider).mergedPeopleOf(id),
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

  /// Declares [from] to be the same person as [into]. The summaries stream
  /// picks this up on its own; the per-person futures have to be told.
  Future<void> merge({required int into, required int from}) async {
    await _ref.read(facesDaoProvider).mergePersons(into: into, from: from);
    _invalidatePerson(into);
    _invalidatePerson(from);
  }

  /// Undoes a merge, giving [personId] back its own entry.
  Future<void> separate(int personId, {required int from}) async {
    await _ref.read(facesDaoProvider).unmergePerson(personId);
    _invalidatePerson(personId);
    _invalidatePerson(from);
  }

  void _invalidatePerson(int id) {
    _ref.invalidate(personAssetsProvider(id));
    _ref.invalidate(personCoverProvider(id));
    _ref.invalidate(mergedPeopleProvider(id));
  }
}
