import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The onboarding poster's decorative ring — a single stroked circle. Purely
/// decorative (see this phase's plan notes for why it uses [AppColors.accent]
/// despite the design system's "accent is state, never decoration" rule);
/// static, no animation. [diameter] is caller-supplied so `AccessStep` can
/// size it as a fraction of screen width rather than a fixed pixel value.
class AccessRing extends StatelessWidget {
  const AccessRing({super.key, required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(painter: AccessRingPainter(color: colors.accent)),
    );
  }
}

/// Public so a widget test can assert the resolved color without pixel
/// matching — same rationale as `IndexingRingPainter`
/// (`lib/widgets/indexing_dial.dart`).
class AccessRingPainter extends CustomPainter {
  const AccessRingPainter({required this.color});

  final Color color;

  static const double _strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_strokeWidth / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(AccessRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
