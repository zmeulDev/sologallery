import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

/// A rounded surface card with a hairline border — the app's one grouping
/// container. Settings groups, the Search privacy note and the Albums folder
/// rows all sit in one of these, so a "boxed" region reads the same everywhere.
///
/// Two shapes: the default wraps a single [child] (the caller owns its padding,
/// since a note and a row want different insets), while [AppCard.divided] stacks
/// rows separated by hairlines and clips them to the corner radius.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required Widget this.child,
    this.borderRadius = AppRadius.br12,
  }) : children = const [];

  /// A card of stacked rows, hairline-divided. Rows own their own padding; the
  /// card clips them so a row's ink never paints over the rounded corner.
  const AppCard.divided({
    super.key,
    required this.children,
    this.borderRadius = AppRadius.br12,
  }) : child = null;

  final Widget? child;
  final List<Widget> children;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: borderRadius,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: colors.border),
                children[i],
              ],
            ],
          ),
    );
  }
}
