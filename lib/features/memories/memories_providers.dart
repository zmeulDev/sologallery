import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/memories_dao.dart';
import '../../core/database/database_provider.dart';
import '../../services/permission_provider.dart';
import '../../services/photo_library_service.dart' show AssetRef;
import '../settings/consent_provider.dart';

/// Memories eligible for the Library carousel, best first.
///
/// Reactive — re-emits when the background indexer regenerates, when the user
/// dismisses one, and when a deletion empties one out. Idle (empty) unless
/// photo access allows reading the library, matching the Library providers,
/// and unless the user turned Memories on (opt-in; see [ConsentNotifier]).
///
/// Defaults to empty while the flag is still loading — fail-closed is the right
/// bias for a consented feature, and the carousel collapses to nothing anyway.
final memoriesProvider =
    StreamProvider.autoDispose<List<MemorySummary>>((ref) {
  final access = ref.watch(permissionProvider);
  if (!access.canReadLibrary) return Stream.value(const []);
  final enabled = ref.watch(memoriesEnabledProvider).value ?? false;
  if (!enabled) return Stream.value(const []);
  return ref.watch(memoriesDaoProvider).watchActive();
});

/// One memory's photos in playback order. Bounded by the builder's per-memory
/// cap, so this is a plain one-shot fetch — no paging notifier.
final memoryAssetsProvider =
    FutureProvider.autoDispose.family<List<AssetRef>, int>((ref, id) {
  return ref.watch(memoriesDaoProvider).assetsFor(id);
});

/// Side effects on a memory (opened, dismissed). Mirrors `PeopleActions`.
final memoryActionsProvider = Provider<MemoryActions>(MemoryActions.new);

class MemoryActions {
  MemoryActions(this._ref);

  final Ref _ref;

  MemoriesDao get _dao => _ref.read(memoriesDaoProvider);

  /// Stamps the memory as opened; survives regeneration.
  Future<void> markSeen(int id) => _dao.markSeen(id);

  /// Dismisses the memory — it leaves the carousel and regeneration will not
  /// bring it back.
  Future<void> hide(int id) => _dao.hide(id);
}
