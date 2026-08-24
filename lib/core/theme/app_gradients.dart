import 'package:flutter/material.dart';

/// Xender-style vivid gradients used across primary CTAs, QR framing,
/// and progress visuals — the thing that makes the app feel "alive"
/// instead of flat Material default colors.
class AppGradients {
  AppGradients._();

  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2F6FED), Color(0xFF7C3AED)],
  );

  static const receive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00B4D8), Color(0xFF2F6FED)],
  );

  static const success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  );

  static const sweepProgress = SweepGradient(
    colors: [Color(0xFF2F6FED), Color(0xFF7C3AED), Color(0xFF00B4D8), Color(0xFF2F6FED)],
    stops: [0.0, 0.4, 0.8, 1.0],
  );
}
