import 'package:flutter/material.dart';

/// Scoped access from [FolderScopeCard] to the enclosing onboarding state
/// without passing four fields through every constructor.
class InheritedConsentScope extends InheritedWidget {
  const InheritedConsentScope({
    super.key,
    required super.child,
    required this.search,
    required this.memories,
    required this.faces,
    required this.excludedFolderIds,
    required this.onOpenFolderPicker,
  });

  final bool search;
  final bool memories;
  final bool faces;
  final Set<String> excludedFolderIds;
  final VoidCallback onOpenFolderPicker;

  @override
  bool updateShouldNotify(InheritedConsentScope old) =>
      search != old.search ||
      memories != old.memories ||
      faces != old.faces ||
      excludedFolderIds != old.excludedFolderIds ||
      onOpenFolderPicker != old.onOpenFolderPicker;

  static InheritedConsentScope of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<InheritedConsentScope>();
    assert(result != null, 'InheritedConsentScope not found');
    return result!;
  }
}
