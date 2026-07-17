import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../services/thumbnail_provider.dart';

/// A single photo thumbnail, resolved by asset id through [thumbnailProvider].
/// Shows a quiet recessed placeholder while loading or if the asset can't be
/// resolved; the photo itself supplies the only color (the chrome is neutral).
///
/// Fills its parent — wrap it in a sized/aspect box.
class AssetThumbnail extends ConsumerWidget {
  const AssetThumbnail({
    super.key,
    required this.assetId,
    this.size = 256,
  });

  final String assetId;

  /// Requested pixel size of the thumbnail (square). Grid cells pass a size
  /// matched to their on-screen dimensions × devicePixelRatio.
  final int size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final async = ref.watch(
      thumbnailProvider(ThumbnailRequest(assetId, width: size, height: size)),
    );
    return async.when(
      data: (bytes) => bytes == null
          ? _Placeholder(colors)
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              width: double.infinity,
              height: double.infinity,
            ),
      loading: () => _Placeholder(colors),
      error: (e, st) => _Placeholder(colors),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.colors);
  final AppColors colors;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: colors.surface2, child: const SizedBox.expand());
}
