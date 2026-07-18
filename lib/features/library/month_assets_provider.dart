import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../services/photo_library_service.dart';
import '../../services/watched_assets_notifier.dart';
import 'domain/year_month.dart';

/// Reactive paged assets for a single month, backing the full-month grid — a
/// live growing window over the `photo_asset` cache. Keyed by [YearMonth]; the
/// family passes the month to the notifier constructor. Re-emits as photos are
/// added/removed while the grid is on screen.
class MonthAssetsNotifier extends WatchedAssetsNotifier {
  MonthAssetsNotifier(this.month);

  final YearMonth month;

  @override
  Stream<List<AssetRef>> watchWindow(int limit) {
    return ref.read(indexDaoProvider).watchMonthAssets(month, limit: limit);
  }
}

final monthAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<MonthAssetsNotifier, List<AssetRef>, YearMonth>(
  MonthAssetsNotifier.new,
);

/// Reactive paged undated assets, backing the "Older" full grid — a live
/// growing window over the cache.
class OlderAssetsNotifier extends WatchedAssetsNotifier {
  @override
  Stream<List<AssetRef>> watchWindow(int limit) {
    return ref.read(indexDaoProvider).watchOlderAssets(limit: limit);
  }
}

final olderAssetsProvider =
    AsyncNotifierProvider.autoDispose<OlderAssetsNotifier, List<AssetRef>>(
  OlderAssetsNotifier.new,
);
