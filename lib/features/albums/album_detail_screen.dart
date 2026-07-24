import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/count_labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/asset_thumbnail.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/empty_state.dart';
import '../detail/photo_viewer_args.dart';
import 'albums_providers.dart';

/// The full grid of one album's photos (`/album/:id`), reached from an album
/// card. Opens with a full-bleed cover hero and title overlay, then a
/// three-column grid whose thumbnails clip to `br12` like every other photo
/// grid in the app.
class AlbumDetailScreen extends ConsumerStatefulWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final int albumId;

  @override
  ConsumerState<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends ConsumerState<AlbumDetailScreen> {
  bool _coverReady = false;
  String? _lastCover;

  @override
  Widget build(BuildContext context) {
    final album = ref.watch(albumProvider(widget.albumId));
    final entries = ref.watch(albumEntriesProvider(widget.albumId));
    // Entries arrive newest-photo-first, so the first one is the album's newest
    // photo — the same cover the Albums grid computes for its card.
    final cover = album.value?.coverAssetId ??
        entries.value?.firstOrNull?.assetId;

    // If the cover id changes (e.g. album metadata streams in after entries),
    // reset the ready flag so the placeholder rides again while the new image
    // decodes.
    if (cover != _lastCover) {
      _lastCover = cover;
      _coverReady = false;
    }

    return Scaffold(
      body: SafeArea(
        top: true,
        child: CustomScrollView(
          slivers: [
            _HeroAppBar(
              name: album.value?.name,
              cover: cover,
              count: entries.value?.length ?? 0,
              coverReady: _coverReady,
              onCoverFrame: cover == null ? null : () {
                if (!_coverReady) {
                  // Defer so the image's first painted frame swaps in, not just
                  // the thumbnail provider completing before decode.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _coverReady = true);
                  });
                }
              },
            ),
            switch (entries) {
              AsyncLoading() => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
              AsyncError() => const SliverFillRemaining(
                  child: EmptyState.note('Couldn\'t load this album.'),
                ),
              AsyncData(value: final items) => items.isEmpty
                  ? const SliverFillRemaining(
                      child: EmptyState.note(
                        'This album is empty.\nAdd photos from any photo\'s menu.',
                      ),
                    )
                  : _Grid(assetIds: [for (final e in items) e.assetId]),
            },
          ],
        ),
      ),
    );
  }
}

/// Collapsible hero header for the album detail screen: the album cover fills
/// the space, a bottom gradient holds the white title and count, and a back
/// button sits in the top-left. The bar collapses to zero height on scroll so
/// the grid can take over.
class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({
    this.name,
    this.cover,
    required this.count,
    required this.coverReady,
    this.onCoverFrame,
  });

  final String? name;
  final String? cover;
  final int count;
  final bool coverReady;
  final VoidCallback? onCoverFrame;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    final topPadding = MediaQuery.paddingOf(context).top;
    final name = this.name ?? 'Album';
    final cover = this.cover;
    final showPlaceholder = cover != null && !coverReady;

    return SliverAppBar(
      pinned: true,
      toolbarHeight: 0,
      expandedHeight: 320,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // explicitChildNodes: without it the app bar's own header annotation
      // merges every descendant into one node — the Back button's node inflates
      // to the whole 320px hero and announces "Back / <album> / <count>", so the
      // title is unreadable and the only target is a screen-sized button.
      flexibleSpace: FlexibleSpaceBar(
        background: Semantics(
          explicitChildNodes: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                AssetThumbnail(
                  assetId: cover,
                  size: 1000,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (!wasSynchronouslyLoaded) onCoverFrame?.call();
                    return child;
                  },
                )
              else
                ColoredBox(color: colors.surface2),
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: showPlaceholder ? 1 : 0,
                  duration: Duration.zero,
                  child: Container(color: colors.surface2),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppOverMedia.scrimHeavy],
                    stops: [0.5, 1],
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 12,
                left: 12,
                child: CircleIconButton.overMedia(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                // Name and count are one thought, so they are one header node
                // rather than two stops reading "Trip" then "1 item".
                child: Semantics(
                  container: true,
                  header: true,
                  label: count > 0 ? '$name, ${itemCountLabel(count)}' : name,
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: text.pageTitle.copyWith(
                          color: AppOverMedia.glyph,
                          height: 1.1,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          itemCountLabel(count),
                          style: text.caption.copyWith(
                            color: AppOverMedia.glyphSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-column square grid of the album's photos. Each cell clips to the
/// app's standard `br12` photo radius and opens the detail viewer swiping
/// across this album.
class _Grid extends StatelessWidget {
  const _Grid({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4 + MediaQuery.paddingOf(context).bottom,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.s4,
          crossAxisSpacing: AppSpace.s4,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => GestureDetector(
            onTap: () => context.push(
              '/photo/${assetIds[i]}',
              extra: PhotoViewerArgs(assetIds, i),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: AssetThumbnail(
                assetId: assetIds[i],
                size: 400,
                showVideoBadge: true,
              ),
            ),
          ),
          childCount: assetIds.length,
        ),
      ),
    );
  }
}
