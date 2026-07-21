import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/daos/index_dao.dart' show FavoriteAsset;
import '../../core/database/database_provider.dart';

/// Favorited photos, most recently favorited first — the Saved grid's source.
///
/// A DB stream (not [PagedAssetsNotifier]): favorites are a bounded local set
/// that must react to favorite/unfavorite from the detail viewer. `autoDispose`
/// so the stream closes when the Saved tab is left. Joined to the `photo_asset`
/// cache so a favorite whose asset was deleted (and pruned from the cache) drops
/// out instead of showing a broken thumbnail — and so each row carries the
/// dimensions the masonry grid lays out with.
final savedFavoritesProvider = StreamProvider.autoDispose<List<FavoriteAsset>>(
  (ref) => ref.watch(indexDaoProvider).watchFavoritesInCache(),
);
