import 'package:flutter/foundation.dart';
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
///
/// `watchFavoritesInCache()` is an unbounded join that Drift re-runs — and
/// re-emits — on every `photo_asset` write during ML/metadata backfill, even
/// when the favorites result is byte-for-byte unchanged. [FavoriteAsset] is a
/// Dart record, so it has structural `==`; `distinct(listEquals)` drops those
/// no-op re-emissions before they reach the Saved grid, while a genuine change
/// (a favorite added/removed, or its cached dimensions resolving from 0 to
/// real) still differs structurally and propagates.
final savedFavoritesProvider = StreamProvider.autoDispose<List<FavoriteAsset>>(
  (ref) =>
      ref.watch(indexDaoProvider).watchFavoritesInCache().distinct(listEquals),
);
