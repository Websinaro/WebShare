import 'package:flutter/animation.dart';

/// Central place for timing/curves so every screen feels like one
/// designed app instead of a pile of ad-hoc durations.
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 480);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeOutBack;
}
