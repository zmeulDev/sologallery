import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' show Album, AlbumEntry;
import '../../core/database/daos/albums_dao.dart' show AlbumSummary;
import '../../core/database/database_provider.dart';

/// Albums with cover + count for the list grid, ordered by sort then creation.
final albumSummariesProvider = StreamProvider.autoDispose<List<AlbumSummary>>(
  (ref) => ref.watch(albumsDaoProvider).watchAlbumSummaries(),
);

/// A single album by id — drives the album-detail app-bar title. Null once the
/// album is deleted (the detail screen pops itself in that case).
final albumProvider =
    StreamProvider.autoDispose.family<Album?, int>((ref, id) {
  return ref.watch(albumsDaoProvider).watchAlbum(id);
});

/// The entries of one album, most recently added first.
final albumEntriesProvider =
    StreamProvider.autoDispose.family<List<AlbumEntry>, int>((ref, id) {
  return ref.watch(albumsDaoProvider).watchEntries(id);
});

/// Side-effecting album actions, kept out of widgets (Riverpod conventions).
final albumActionsProvider = Provider<AlbumActions>(AlbumActions.new);

class AlbumActions {
  AlbumActions(this._ref);

  final Ref _ref;

  /// Creates an album; returns its generated id.
  Future<int> create(String name) =>
      _ref.read(albumsDaoProvider).createAlbum(name);

  /// Deletes an album; its entries cascade.
  Future<void> delete(int albumId) =>
      _ref.read(albumsDaoProvider).deleteAlbum(albumId);
}
