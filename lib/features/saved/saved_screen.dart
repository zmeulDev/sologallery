import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_thumbnail.dart';
import '../detail/photo_viewer_args.dart';
import 'saved_providers.dart';

/// Saved: every favorited photo in one grid, newest-favorited first. Tapping a
/// cell opens the detail viewer swiping across the favorites sequence, so an
/// unfavorite there flows straight back into this grid.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(savedFavoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const _SavedMessage(
          title: 'Couldn\'t load your favorites',
          detail: 'Something went wrong. Come back in a moment.',
        ),
        data: (rows) => rows.isEmpty
            ? const _SavedMessage(
                title: 'No favorites yet',
                detail: 'Tap the heart on a photo and it will be collected here.',
              )
            : _SavedGrid(assetIds: [for (final f in rows) f.assetId]),
      ),
    );
  }
}

class _SavedGrid extends StatelessWidget {
  const _SavedGrid({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: assetIds.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => context.push(
          '/photo/${assetIds[i]}',
          extra: PhotoViewerArgs(assetIds, i),
        ),
        child: AssetThumbnail(
          assetId: assetIds[i],
          size: 400,
          showVideoBadge: true,
        ),
      ),
    );
  }
}

/// Centered title + supporting line for the empty and error states — mirrors the
/// Library screen's message treatment.
class _SavedMessage extends StatelessWidget {
  const _SavedMessage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.body.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
