import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../services/photo_library_service.dart';
import '../../services/watched_assets_notifier.dart';

/// Reactive paged assets for a single calendar day, backing the full-day grid —
/// a live growing window over the `photo_asset` cache. Keyed by calendar day;
/// the family passes the day to the notifier constructor. Re-emits as photos
/// are added/removed while the grid is on screen.
class DayAssetsNotifier extends WatchedAssetsNotifier {
  DayAssetsNotifier(this.day);

  final DateTime day;

  @override
  Stream<List<AssetRef>> watchWindow(int limit) {
    return ref.read(indexDaoProvider).watchDayAssets(day, limit: limit);
  }
}

final dayAssetsProvider = AsyncNotifierProvider.autoDispose
    .family<DayAssetsNotifier, List<AssetRef>, DateTime>(
  DayAssetsNotifier.new,
);
