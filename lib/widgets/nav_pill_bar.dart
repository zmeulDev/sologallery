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
  // Material ships no filled counterpart for the magnifier; colour and the knob
  // carry the selected state here, as they do for every destination.
  _Destination(Icons.search_rounded, Icons.search_rounded, 'Search'),
  _Destination(
      Icons.favorite_border_rounded, Icons.favorite_rounded, 'Saved'),
  _Destination(Icons.photo_album_outlined, Icons.photo_album_rounded, 'Albums'),
];

/// Custom bottom nav: a floating inverted-ink capsule of icon-only
/// destinations, with a filled circular knob that sits under the active one —
/// the design-system signature. Labels are omitted so the knob is the only
/// indicator; each destination still carries a semantic label and tooltip.
/// The knob and the active glyph swap instantly on tap (no travel).
///
/// The capsule floats over the page ([Scaffold.extendBody]), so every scroller
/// in a shell branch pads its bottom by `MediaQuery.paddingOf(context).bottom`.
class NavPillBar extends StatelessWidget {
  const NavPillBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.trailing,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Optional companion pinned to the right of the capsule, on its baseline —
  /// the indexing dial. It rides beside the capsule rather than inside it so
  /// the destinations never shift; the capsule stays centred either way, and
  /// the bar's height is the capsule's whatever this is.
  final Widget? trailing;

  /// Capsule height, and — because each destination's slot is square — the
  /// width of one slot too. The knob is [_knobSize], so it clears the capsule
  /// by [_knobInset] on every side, including the two ends: a slot any wider
  /// would strand dead ink between the capsule's edge and the outer glyphs.
  static const double _pillHeight = 60;
  static const double _slotWidth = _pillHeight;
  static const double _knobSize = 52;
  static const double _knobInset = (_pillHeight - _knobSize) / 2;
  static const double _iconSize = 22;

  /// The capsule hugs its slots and centres, rather than stretching to the
  /// screen.
  static double get _pillWidth => _slotWidth * _destinations.length;

  /// Inactive glyphs sit back from the active one without introducing a second
  /// ink colour.
  static const double _inactiveOpacity = 0.7;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final capsule = Container(
      width: _pillWidth,
      height: _pillHeight,
      decoration: ShapeDecoration(
        color: colors.pillActiveBg,
        shape: const StadiumBorder(),
      ),
      child: Stack(
        children: [
          // Beneath the icons, so the active glyph reads on top of it.
          Positioned(
            left: _slotWidth * currentIndex + _knobInset,
            top: _knobInset,
            child: Container(
              width: _knobSize,
              height: _knobSize,
              decoration: BoxDecoration(
                color: colors.pillActiveText,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                SizedBox(
                  width: _slotWidth,
                  child: _NavItem(
                    destination: _destinations[i],
                    selected: i == currentIndex,
                    activeColor: colors.pillActiveBg,
                    inactiveColor: colors.pillActiveText
                        .withValues(alpha: _inactiveOpacity),
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s12),
        // `heightFactor: 1` is load-bearing: a plain `Center` takes the
        // *largest* size its loose constraints allow, so the bar would claim
        // the whole screen and float the capsule in the middle of it (and hand
        // the body a screen-sized bottom inset). Sizing to the child keeps the
        // bar exactly as tall as the capsule, above the safe-area inset.
        child: Align(
          heightFactor: 1,
          // Full width so [trailing] can sit at the screen's right edge while
          // the capsule stays centred. The band is still exactly the capsule's
          // height, so the body's bottom inset doesn't move.
          child: SizedBox(
            width: double.infinity,
            height: _pillHeight,
            child: Stack(
              children: [
                Align(child: capsule),
                if (trailing != null)
                  Positioned(
                    right: AppSpace.s12,
                    top: 0,
                    bottom: 0,
                    child: Center(child: trailing),
                  ),
              ],
            ),
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
        // The knob is the press feedback; an ink splash would fight it and
        // would have to be clipped to the capsule besides.
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Icon(
              selected ? destination.activeIcon : destination.icon,
              size: NavPillBar._iconSize,
              color: selected ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
