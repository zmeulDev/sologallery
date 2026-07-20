import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../detail_providers.dart';

/// One swipeable page in the detail viewer: the full, uncropped photo on the
/// black stage, pinch-to-zoom via [InteractiveViewer]. Bytes come from
/// [detailImageProvider] (screen-capped, never the full original).
///
/// [transformController], when supplied, lets an ancestor (the drag-dismiss
/// gesture) read the live zoom/pan matrix to gate itself off while the photo
/// is pinch-zoomed, and read it back to identity when the user is done.
/// Unsupplied (the default), [PhotoPage] manages its own — every existing
/// caller that doesn't care about zoom state is unaffected.
///
/// [panEnabled] defaults to true (unchanged behavior for existing callers).
/// The drag-dismiss gesture passes `false` while not zoomed: at scale 1
/// there's nothing to pan to anyway, and leaving [InteractiveViewer]'s own
/// one-finger pan recognizer enabled makes it compete with — and can win
/// outright against — the dismiss drag's recognizer in the gesture arena,
/// silently swallowing the whole gesture. `scaleEnabled` (pinch, two
/// fingers) is untouched, so zooming in still works either way.
class PhotoPage extends ConsumerWidget {
  const PhotoPage({
    super.key,
    required this.assetId,
    this.transformController,
    this.panEnabled = true,
  });

  final String assetId;
  final TransformationController? transformController;
  final bool panEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(detailImageProvider(assetId));
    return image.when(
      data: (bytes) => bytes == null
          ? const _Unavailable()
          : InteractiveViewer(
              transformationController: transformController,
              panEnabled: panEnabled,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
      loading: () => const _Loading(),
      error: (_, _) => const _Unavailable(),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(AppOverMedia.glyphDim),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: AppOverMedia.glyphDim,
        size: 44,
      ),
    );
  }
}
