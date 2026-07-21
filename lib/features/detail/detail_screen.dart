import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_space.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/circle_icon_button.dart';
import '../../widgets/precache_adjacent.dart';
import 'detail_providers.dart';
import 'photo_viewer_args.dart';
import 'widgets/add_to_album_sheet.dart';
import 'widgets/detail_action_bar.dart';
import 'widgets/dismissible_photo.dart';
import 'widgets/exif_sheet.dart';

/// Full-screen photo viewer (`/photo/:id`). Swipes horizontally through the
/// originating sequence; tap toggles the chrome; swiping up opens the details
/// sheet and swiping down dismisses; the action bar favorites, shares, adds to
/// an album, or deletes. The photo is the hero on a black
/// stage — all chrome stays quiet and translucent (Design system).
class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({super.key, required this.args});

  final PhotoViewerArgs args;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late final List<String> _ids = List.of(widget.args.assetIds);
  late int _index = widget.args.initialIndex.clamp(
    0,
    _ids.isEmpty ? 0 : _ids.length - 1,
  );
  late final PageController _controller = PageController(initialPage: _index);
  bool _chromeVisible = true;

  /// 0 (settled) → 1 (dismissed), mirrored up from whichever page is being
  /// drag-dismissed so the chrome — a sibling of the [PageView], not a
  /// descendant of any one page — fades in lockstep without a full-screen
  /// rebuild on every drag frame.
  final ValueNotifier<double> _dragProgress = ValueNotifier(0);

  String get _currentId => _ids[_index];

  @override
  void dispose() {
    _controller.dispose();
    _dragProgress.dispose();
    super.dispose();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onFavorite() =>
      ref.read(detailActionsProvider).toggleFavorite(_currentId);

  Future<void> _onShare() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await ref.read(detailActionsProvider).share(_currentId, origin: origin);
  }

  Future<void> _onAddToAlbum() async {
    final name = await showAddToAlbumSheet(context, _currentId);
    if (name != null && mounted) _snack('Added to $name');
  }

  Future<void> _onExif() => showExifSheet(context, _currentId);

  Future<void> _onDelete() async {
    final id = _currentId;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete photo?',
      message:
          'This removes it from your device photo library. You can\'t '
          'undo this from SoloGallery.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    final deleted = await ref.read(detailActionsProvider).delete(id);
    if (!deleted || !mounted) return; // OS trash dialog was cancelled

    setState(() {
      _ids.removeAt(_index);
      if (_index > 0 && _index >= _ids.length) _index = _ids.length - 1;
    });
    if (_ids.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
    });
    _snack('Photo deleted');
  }

  /// Multiplies [child]'s opacity by `1 - _dragProgress` and disables its
  /// hit-testing mid-drag, on top of [child]'s own `visible`-driven fade —
  /// the two compose independently, so chrome hides the instant a dismiss
  /// drag starts regardless of whether it was toggled visible.
  Widget _dragFadedChrome({required Widget child}) {
    return ValueListenableBuilder<double>(
      valueListenable: _dragProgress,
      builder: (context, progress, chromeChild) {
        if (progress == 0) return chromeChild!;
        return IgnorePointer(
          child: Opacity(opacity: 1 - progress, child: chromeChild),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ids.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final isFavorite = ref.watch(isFavoriteProvider(_currentId)).value ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleChrome,
              child: PageView.builder(
                controller: _controller,
                itemCount: _ids.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _DetailPage(
                  assetId: _ids[i],
                  onDragProgress: (p) => _dragProgress.value = p,
                  onDismissed: () => Navigator.of(context).maybePop(),
                  onSwipeUp: _onExif,
                ),
              ),
            ),
          ),
          // Zero-size; warms the neighbouring pages' bytes. Sits in the Stack
          // so it rebuilds with _index, without the stage rebuilding with it.
          PrecacheAdjacent(assetIds: _ids, index: _index),
          _dragFadedChrome(
            child: _Chrome(
              visible: _chromeVisible,
              alignment: Alignment.topCenter,
              child: _TopBar(
                isFavorite: isFavorite,
                onFavorite: _onFavorite,
                onAddToAlbum: _onAddToAlbum,
              ),
            ),
          ),
          _dragFadedChrome(
            child: _Chrome(
              visible: _chromeVisible,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SwipeUpHint(),
                  const SizedBox(height: AppSpace.s16),
                  DetailActionBar(
                    isFavorite: isFavorite,
                    onFavorite: _onFavorite,
                    onShare: _onShare,
                    onAddToAlbum: _onAddToAlbum,
                    onDelete: _onDelete,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One page of the viewer: routes to [DismissiblePhoto] (drag-to-dismiss),
/// which itself wraps [DetailStage] (Hero + reveal) branching on
/// [isVideoProvider] into a [VideoPage]/[PhotoPage] once revealed. Shows the
/// still while the kind resolves so a video never flashes as a photo page and
/// vice versa.
class _DetailPage extends ConsumerWidget {
  const _DetailPage({
    required this.assetId,
    required this.onDragProgress,
    required this.onDismissed,
    required this.onSwipeUp,
  });

  final String assetId;
  final ValueChanged<double> onDragProgress;
  final VoidCallback onDismissed;
  final VoidCallback onSwipeUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = ref.watch(isVideoProvider(assetId)).value ?? false;
    return DismissiblePhoto(
      assetId: assetId,
      isVideo: isVideo,
      onProgress: onDragProgress,
      onDismissed: onDismissed,
      onSwipeUp: onSwipeUp,
    );
  }
}

/// Fades and disables a chrome layer pinned to [alignment] when hidden.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppMotion.of(context, AppMotion.medium),
          child: child,
        ),
      ),
    );
  }
}

/// The viewer's top chrome: back, plus the two actions worth reaching without
/// travelling to the bottom bar. Each glyph sits on its own scrim disc rather
/// than bare over the photo — a white glyph alone disappears against a bright
/// sky, and a full-width scrim would dim the top of every photo to protect
/// three icons.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isFavorite,
    required this.onFavorite,
    required this.onAddToAlbum,
  });

  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onAddToAlbum;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        child: Row(
          children: [
            CircleIconButton.overMedia(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const Spacer(),
            CircleIconButton.overMedia(
              icon: Icons.add_rounded,
              tooltip: 'Add to album',
              onPressed: onAddToAlbum,
            ),
            const SizedBox(width: AppSpace.s8),
            CircleIconButton.overMedia(
              icon: isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
              onPressed: onFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

/// The hint that there is more under the photo: a grab handle over a tracked
/// caption, centered above the action bar.
///
/// Swipe-up-for-details is otherwise undiscoverable — there is nothing on a
/// full-bleed photo to suggest it — and it is the gesture that reveals EXIF, so
/// it earns one quiet line. Purely decorative: the gesture itself is owned by
/// [DismissiblePhoto], and this never intercepts a touch.
class _SwipeUpHint extends StatelessWidget {
  const _SwipeUpHint();

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: const BoxDecoration(
              color: AppOverMedia.glyphFaint,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.r2)),
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Swipe up for details'.toUpperCase(),
            style: styles.sectionLabel.copyWith(color: AppOverMedia.glyphSoft),
          ),
        ],
      ),
    );
  }
}
