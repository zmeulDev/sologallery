import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/filter_pill.dart';
import '../domain/search_date.dart' show MediaTypeFilter;
import '../search_providers.dart';

/// The facet row: media type (single-select) plus a favorites toggle. Visible
/// on both the idle and results states so the user knows these narrowing
/// controls exist before committing a query.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, required this.type, required this.favoritesOnly});

  final MediaTypeFilter type;
  final bool favoritesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setType(MediaTypeFilter t) =>
        ref.read(searchTypeProvider.notifier).set(t);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          FilterPill(
            label: 'All',
            selected: type == MediaTypeFilter.all,
            onTap: () => setType(MediaTypeFilter.all),
          ),
          const SizedBox(width: 8),
          FilterPill(
            label: 'Photos',
            selected: type == MediaTypeFilter.photos,
            onTap: () => setType(MediaTypeFilter.photos),
          ),
          const SizedBox(width: 8),
          FilterPill(
            label: 'Videos',
            selected: type == MediaTypeFilter.videos,
            onTap: () => setType(MediaTypeFilter.videos),
          ),
          const SizedBox(width: 16),
          FilterPill(
            label: 'Favorites',
            selected: favoritesOnly,
            onTap: () =>
                ref.read(searchFavoritesOnlyProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}
