import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/albums_dao.dart';
import 'daos/favorites_dao.dart';

/// App-wide [AppDatabase], kept alive for the whole app lifetime (not
/// autoDispose) — it owns the single SQLite connection. Screen-scoped
/// providers that read it should still be autoDispose themselves.
///
/// Overridden with an in-memory database in tests.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// [FavoritesDao] over the app database (favorite flags keyed by asset id).
final favoritesDaoProvider = Provider<FavoritesDao>(
  (ref) => ref.watch(databaseProvider).favoritesDao,
);

/// [AlbumsDao] over the app database (user albums + membership).
final albumsDaoProvider = Provider<AlbumsDao>(
  (ref) => ref.watch(databaseProvider).albumsDao,
);
