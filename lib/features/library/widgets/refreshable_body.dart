import 'package:flutter/material.dart';

/// Wraps a scrollable with a pull-to-refresh gesture. The child must itself be
/// a scrollable; the caller supplies `AlwaysScrollableScrollPhysics` on short or
/// empty lists so the gesture still registers.
class RefreshableBody extends StatelessWidget {
  const RefreshableBody({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}
