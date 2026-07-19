import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'favorites_dao.g.dart';

/// Data-access for [Favorites]. Pure data layer — no UI, no business rules.
@DriftAccessor(tables: [Favorites])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  /// Whether [assetId] is currently favorited.
  Stream<bool> watchIsFavorite(String assetId) {
    final query = select(favorites)..where((f) => f.assetId.equals(assetId));
    return query.watch().map((rows) => rows.isNotEmpty);
  }

  Future<bool> isFavorite(String assetId) async {
    final query = select(favorites)..where((f) => f.assetId.equals(assetId));
    return (await query.get()).isNotEmpty;
  }

  /// Marks [assetId] as favorite (idempotent).
  Future<void> add(String assetId, {DateTime? at}) {
    return into(favorites).insert(
      FavoritesCompanion.insert(
        assetId: assetId,
        favoritedAt: at ?? DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Removes [assetId] from favorites (idempotent). Returns rows deleted.
  Future<int> remove(String assetId) {
    return (delete(favorites)..where((f) => f.assetId.equals(assetId))).go();
  }
}
