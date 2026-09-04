import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

/// The bare brand mark — three offset cards with a sun and ridge — used as
/// the leading element on each onboarding step. Sits on the same row as the
/// `SoloGallery` wordmark, `crossAxisAlignment: center`, with a 12px gap.
///
/// The mark carries two dark back cards (`#4A4A46` / `#8A8A84`) that vanish
/// into the dark theme's near-black background. We wrap the asset in a
/// themed frame using existing tokens — `surface2` fill + `border` hairline
/// at r12 — so the silhouette holds in both themes without inventing new
/// colours or filtering chrome.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  /// Width is intentionally slightly larger than height: the offset cards
  /// stretch horizontally within the 1:1 transparent canvas.
  static const _width = 60.0;
  static const _height = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: AppRadius.br12,
        border: Border.all(color: colors.border, width: 0.5),
      ),
      // Clip the rounded corners on the mark itself — the asset's transparent
      // canvas has hard square edges at the 4096 boundary.
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icon/sologallery_mark_transparent_4096.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
