import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';

/// The one empty/error message treatment: a centered title with an optional
/// supporting line and call-to-action, or — via [EmptyState.note] — a single
/// centered muted line for full-grid screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required String this.title,
    this.detail,
    this.action,
  }) : note = null;

  /// A single centered `body`/textSecondary line (the former `CenteredNote`).
  const EmptyState.note(String this.note, {super.key})
      : title = null,
        detail = null,
        action = null;

  final String? title;
  final String? detail;
  final Widget? action;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;

    if (note case final text?) {
      return Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: styles.body.copyWith(color: colors.textSecondary),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title!,
              textAlign: TextAlign.center,
              style: styles.body.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (detail case final sub?) ...[
              const SizedBox(height: 6),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: styles.caption.copyWith(color: colors.textSecondary),
              ),
            ],
            if (action case final cta?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s16),
                child: cta,
              ),
          ],
        ),
      ),
    );
  }
}
