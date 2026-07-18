import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' show Favorite;
import '../../core/database/database_provider.dart';

/// Favorited photos, most recently favorited first — the Saved grid's source.
///
/// A DB stream (not [PagedAssetsNotifier]): favorites are a bounded local set
/// that must react to favorite/unfavorite from the detail viewer. `autoDispose`
/// so the stream closes when the Saved tab is left. Joined to the `photo_asset`
/// cache so a favorite whose asset was deleted (and pruned from the cache) drops
/// out instead of showing a broken thumbnail.
final savedFavoritesProvider = StreamProvider.autoDispose<List<Favorite>>(
  (ref) => ref.watch(indexDaoProvider).watchFavoritesInCache(),
);
