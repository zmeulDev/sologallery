import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../services/photo_library_service.dart';
import '../../services/watched_assets_notifier.dart';

/// Reactive paged assets for a single calendar year, backing the full-year grid
/// — a live growing window over the `photo_asset` cache. Keyed by year; the
/// family passes the year to the notifier constructor. Re-emits as photos are
/// added/removed while the grid is on screen.
class YearAssetsNotifier extends WatchedAssetsNotifier {
  YearAssetsNotifier(this.year);

  final int year;

  @override
  Stream<List<AssetRef>> watchWindow(int limit) {
    return ref.read(indexDaoProvider).watchYearAssets(year, limit: limit);
  }
}

final yearAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<YearAssetsNotifier, List<AssetRef>, int>(
  YearAssetsNotifier.new,
);
