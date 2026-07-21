import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// One bottom-nav destination.
class _Destination {
  const _Destination(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _destinations = <_Destination>[
  // Inactive Library/Albums glyphs stay on the default outlined family: the
  // rounded family ships no outlined forms for these, and the filled
  // `_rounded` variant would equal the active glyph.
  _Destination(Icons.photo_library_outlined, Icons.photo_library_rounded,
      'Library'),
  // Material ships no filled counterpart for the magnifier; colour and the dot
  // carry the selected state here, as they do for every destination.
  _Destination(Icons.search_rounded, Icons.search_rounded, 'Search'),
  _Destination(
      Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
  _Destination(Icons.photo_album_outlined, Icons.photo_album_rounded, 'Albums'),
];

/// Custom bottom nav: icon-only destinations with a single dot that slides to
/// sit under the active one — the design-system signature. Labels are omitted
/// so the dot is the only indicator; each destination still carries a semantic
/// label and tooltip.
class DotNavBar extends StatelessWidget {
  const DotNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 58;
  static const double _dotSize = 5;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _destinations.length;
              return Stack(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        Expanded(
                          child: _NavItem(
                            destination: _destinations[i],
                            selected: i == currentIndex,
                            activeColor: scheme.onSurface,
                            inactiveColor: colors.textMuted,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                  AnimatedPositioned(
                    duration: AppMotion.of(context, AppMotion.nav),
                    curve: AppMotion.curve,
                    left: itemWidth * currentIndex + (itemWidth - _dotSize) / 2,
                    bottom: 10,
                    child: Container(
                      width: _dotSize,
                      height: _dotSize,
                      decoration: BoxDecoration(
                        color: colors.pillActiveBg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: SizedBox.expand(
            child: Icon(
              selected ? destination.activeIcon : destination.icon,
              size: 24,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
