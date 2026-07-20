import 'package:flutter/widgets.dart';

/// Motion tokens. Every animated widget routes its duration through
/// [AppMotion.of] so the system "remove animations" setting disables motion
/// app-wide in one place.
abstract final class AppMotion {
  /// Pressed-state feedback (card scale).
  static const Duration pressed = Duration(milliseconds: 110);

  /// Selection changes (filter pills).
  static const Duration short = Duration(milliseconds: 150);

  /// Content reveals (thumbnail fade-in).
  static const Duration medium = Duration(milliseconds: 180);

  /// Nav indicator travel (dot nav bar).
  static const Duration nav = Duration(milliseconds: 260);

  static const Curve curve = Curves.easeOutCubic;

  /// [d], or [Duration.zero] when the platform asks for reduced motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : d;
}
