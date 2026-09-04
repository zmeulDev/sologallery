import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';

/// The query field: a filled, rounded input sitting in the body just below the
/// app bar on every Search state. Owning a real title in the app bar costs no
/// body space and gives the screen the same header anatomy as Library, Saved
/// and Albums.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s4,
        AppSpace.s16,
        AppSpace.s12,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: false,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        style: styles.body.copyWith(color: scheme.onSurface),
        decoration: InputDecoration(
          filled: true,
          // Elevated surface fill + hairline border makes the field read as a
          // real card against the page background, rather than disappearing
          // into it.
          fillColor: scheme.surface,
          border: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.br12,
            borderSide: BorderSide(color: colors.textSecondary),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colors.textMuted,
          ),
          // Tracks the controller directly, so a chip that writes the field
          // reveals the clear button without the screen rebuilding for it.
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Clear',
                    color: colors.textMuted,
                    onPressed: onClear,
                  ),
          ),
          hintText: hintText,
          hintStyle: styles.body.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}
