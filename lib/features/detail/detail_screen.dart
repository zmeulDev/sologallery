import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'detail_providers.dart';
import 'photo_viewer_args.dart';
import 'widgets/add_to_album_sheet.dart';
import 'widgets/detail_action_bar.dart';
import 'widgets/exif_sheet.dart';
import 'widgets/photo_page.dart';

/// Full-screen photo viewer (`/photo/:id`). Swipes horizontally through the
/// originating sequence; tap toggles the chrome; the action bar favorites,
/// shares, adds to an album, or deletes. The photo is the hero on a black
/// stage — all chrome stays quiet and translucent (Design system).
class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({super.key, required this.args});

  final PhotoViewerArgs args;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late final List<String> _ids = List.of(widget.args.assetIds);
  late int _index =
      widget.args.initialIndex.clamp(0, _ids.isEmpty ? 0 : _ids.length - 1);
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
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    await ref.read(detailActionsProvider).share(_currentId, origin: origin);
  }

  Future<void> _onAddToAlbum() async {
    final name = await showAddToAlbumSheet(context, _currentId);
    if (name != null && mounted) _snack('Added to $name');
  }

  Future<void> _onExif() => showExifSheet(context, _currentId);

  Future<void> _onDelete() async {
    final id = _currentId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
          'This removes it from your device photo library. You can\'t undo '
          'this from SoloGallery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
    final isFavorite =
        ref.watch(isFavoriteProvider(_currentId)).value ?? false;

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
                itemBuilder: (context, i) => PhotoPage(assetId: _ids[i]),
              ),
            ),
          ),
          _Chrome(
            visible: _chromeVisible,
            alignment: Alignment.topCenter,
            child: _TopBar(onExif: _onExif),
          ),
          _Chrome(
            visible: _chromeVisible,
            alignment: Alignment.bottomCenter,
            child: DetailActionBar(
              isFavorite: isFavorite,
              onFavorite: _onFavorite,
              onShare: _onShare,
              onAddToAlbum: _onAddToAlbum,
              onDelete: _onDelete,
            ),
          ),
        ],
      ),
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
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onExif});

  final VoidCallback onExif;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x00000000), Color(0x99000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                tooltip: 'Details',
                onPressed: onExif,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
