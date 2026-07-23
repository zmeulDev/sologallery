import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_space.dart';
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
/// originating sequence; swiping down dismisses and swiping up opens the
/// details sheet; tap toggles the chrome and double-tap zooms.
///
/// The chrome splits by direction of travel rather than by category: the top
/// bar carries the outbound actions that send this photo somewhere else (an
/// album, another app), the bottom bar the ones that act on the photo itself
/// (favorite, details, delete). The photo is the hero on a black stage — all
/// chrome stays quiet and translucent (Design system).
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

  String get _currentId => _ids[_index];

  @override
  void dispose() {
    _controller.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (_ids.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // No GestureDetector wrapping the PageView: tap and double-tap are
          // resolved inside DismissiblePhoto, where the zoom transform lives
          // and where the raw-pointer path already avoids the gesture arena.
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: _ids.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _DetailPage(
                assetId: _ids[i],
                onDismissed: () => Navigator.of(context).maybePop(),
                onSwipeUp: _onExif,
                onTap: _toggleChrome,
              ),
            ),
          ),
          // Zero-size; warms the neighbouring pages' bytes. Sits in the Stack
          // so it rebuilds with _index, without the stage rebuilding with it.
          // Three each way: the payload is encoded bytes capped at
          // kDetailImageMaxEdge, not decoded bitmaps, so six neighbours cost
          // ~10-15MB resident and buy a run of spinner-free swipes.
          PrecacheAdjacent(assetIds: _ids, index: _index, ahead: 3, behind: 3),
          _Chrome(
            visible: _chromeVisible,
            alignment: Alignment.topCenter,
            child: _TopBar(
              onAddToAlbum: _onAddToAlbum,
              onShare: _onShare,
            ),
          ),
          // The favorite flag is watched in a Consumer scoped to the action bar
          // alone: a favorite tick then rebuilds only this chrome layer, not the
          // whole PageView/Stage above it.
          _Chrome(
            visible: _chromeVisible,
            alignment: Alignment.bottomCenter,
            child: Consumer(
              builder: (context, ref, _) {
                final isFavorite =
                    ref.watch(isFavoriteProvider(_currentId)).value ?? false;
                return DetailActionBar(
                  isFavorite: isFavorite,
                  onFavorite: _onFavorite,
                  onInfo: _onExif,
                  onDelete: _onDelete,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One page of the viewer: routes to [DismissiblePhoto] (drag-to-dismiss),
/// which itself wraps [DetailStage] branching on [isVideoProvider] into a
/// [VideoPage]/[PhotoPage]. Shows the still while the kind resolves so a
/// video never flashes as a photo page and vice versa.
class _DetailPage extends ConsumerWidget {
  const _DetailPage({
    required this.assetId,
    required this.onDismissed,
    required this.onSwipeUp,
    required this.onTap,
  });

  final String assetId;
  final VoidCallback onDismissed;
  final VoidCallback onSwipeUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = ref.watch(isVideoProvider(assetId)).value ?? false;
    return DismissiblePhoto(
      assetId: assetId,
      isVideo: isVideo,
      onDismissed: onDismissed,
      onSwipeUp: onSwipeUp,
      onTap: onTap,
    );
  }
}

/// Hides and disables a chrome layer pinned to [alignment] when not visible.
/// The opacity is a plain conditional — decorative motion is gone app-wide, so
/// the chrome snaps in and out rather than fading. [IgnorePointer] stays: hidden
/// chrome must not be hit-testable.
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
        child: Opacity(opacity: visible ? 1 : 0, child: child),
      ),
    );
  }
}

/// The viewer's top chrome: back, plus the two outbound actions — send this
/// photo to an album, or to another app. Each glyph sits on its own scrim disc
/// rather than bare over the photo — a white glyph alone disappears against a
/// bright sky, and a full-width scrim would dim the top of every photo to
/// protect three icons.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onAddToAlbum, required this.onShare});

  final VoidCallback onAddToAlbum;
  final VoidCallback onShare;

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
              icon: Icons.ios_share_rounded,
              tooltip: 'Share',
              onPressed: onShare,
            ),
          ],
        ),
      ),
    );
  }
}
