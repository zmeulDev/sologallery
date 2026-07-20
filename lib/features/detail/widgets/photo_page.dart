import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../detail_providers.dart';

/// One swipeable page in the detail viewer: the full, uncropped photo on the
/// black stage, pinch-to-zoom via [InteractiveViewer]. Bytes come from
/// [detailImageProvider] (screen-capped, never the full original).
class PhotoPage extends ConsumerWidget {
  const PhotoPage({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(detailImageProvider(assetId));
    return image.when(
      data: (bytes) => bytes == null
          ? const _Unavailable()
          : InteractiveViewer(
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
