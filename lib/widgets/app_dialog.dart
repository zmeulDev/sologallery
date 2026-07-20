import 'package:flutter/material.dart';

/// Dialog helpers for the two dialog shapes the app uses. All visuals come
/// from the theme's [DialogThemeData] / [TextButtonThemeData]; these helpers
/// only standardize structure and result handling.

/// A confirm/cancel dialog. Resolves true only when [confirmLabel] is tapped —
/// dismissing by tapping outside (or the back gesture) reads as cancel.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A single-field text-entry dialog. Resolves to the trimmed text, or null on
/// cancel or blank entry. [initial] pre-fills the field (rename flows).
Future<String?> showAppTextInputDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  required String confirmLabel,
  int? maxLength,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      hint: hint,
      initial: initial,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
    ),
  );
  if (result == null) return null;
  final trimmed = result.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// A [StatefulWidget] so its [TextEditingController] is disposed in
/// [State.dispose] — *after* the route fully unmounts. Disposing it eagerly
/// right after `showDialog` returns crashes the exit animation ("a
/// TextEditingController was used after being disposed").
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.confirmLabel,
    required this.maxLength,
  });

  final String title;
  final String? hint;
  final String? initial;
  final String confirmLabel;
  final int? maxLength;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLength: widget.maxLength,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
