import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_space.dart';
import '../core/theme/app_text_styles.dart';

/// Opens a modal bottom sheet built by [builder]. Surface, top-r20 shape, and
/// clipping all come from the theme's [BottomSheetThemeData] — builders return
/// content (usually an [AppSheet]) and never paint their own background.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  bool isScrollControlled = false,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: builder,
  );
}

/// The one bottom-sheet body: grab handle, optional tracked-uppercase header,
/// then [child], lifted above the keyboard and inset for the bottom safe area.
///
/// Deliberately paints nothing — the modal's surface and shape come from
/// [BottomSheetThemeData], so the sheet look is themed once, not per call site.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, this.label, required this.child});

  /// Optional header, rendered as the design system's tracked-uppercase
  /// section label.
  final String? label;

  /// Sheet content. Laid out with a loose bounded height, so a child needing
  /// to scroll can use `Flexible` around its own list.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      // Lift above the keyboard when a field inside the sheet is focused.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.r2)),
                ),
              ),
            ),
            if (label case final text?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s20,
                  18,
                  AppSpace.s20,
                  10,
                ),
                child: Text(
                  text,
                  style:
                      styles.sectionLabel.copyWith(color: colors.textSecondary),
                ),
              ),
            // Loose flex: under the modal's bounded height the child may take
            // what remains (its own Flexible list scrolls); in an unbounded
            // context (goldens) it simply shrink-wraps.
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// A left-aligned supporting note inside a sheet (loading/error/empty copy).
class AppSheetNote extends StatelessWidget {
  const AppSheetNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        AppSpace.s24,
        AppSpace.s20,
        28,
      ),
      child: Text(
        text,
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
