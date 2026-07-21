import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';

/// The detail viewer's bottom action bar: favorite · details · delete, laid
/// over a bottom scrim so white icons stay legible on any photo.
///
/// The bar carries the actions that act on *this* photo — its state (favorite,
/// delete) and the way into everything else known about it (details). The two
/// outbound actions that send the photo somewhere else, share and add-to-album,
/// live in the top bar instead.
///
/// A pure widget — state (favorite) and behavior come in as inputs, so it is
/// golden-testable in isolation. Favorite reads as a filled vs. outline heart
/// rather than a color, keeping the monochrome chrome (photos supply the color).
class DetailActionBar extends StatelessWidget {
  const DetailActionBar({
    super.key,
    required this.isFavorite,
    required this.onFavorite,
    required this.onInfo,
    required this.onDelete,
  });

  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onInfo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), AppOverMedia.scrimHeavy],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s12,
            AppSpace.s24,
            AppSpace.s12,
            AppSpace.s8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: isFavorite ? 'Favorited' : 'Favorite',
                onTap: onFavorite,
              ),
              _ActionButton(
                icon: Icons.info_outline_rounded,
                label: 'Details',
                onTap: onInfo,
              ),
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppOverMedia.glyph, size: 26),
      tooltip: label,
      onPressed: onTap,
      splashRadius: 24,
    );
  }
}
