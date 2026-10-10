import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const huge = 48.0;

  /// Side gutter of every screen.
  static const gutter = 16.0;
}

abstract final class AppRadius {
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

abstract final class AppShadows {
  /// Soft, warm shadow for raised cards.
  static const soft = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A7A1F2B), blurRadius: 4, offset: Offset(0, 1)),
  ];
}

/// Smallest tappable size (Material and WCAG guidance).
const kMinTouchTarget = 48.0;

/// Motion durations.
abstract final class AppMotion {
  static const quick = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
}

/// Convenience for a hairline card border.
Border appBorder([Color color = AppColors.outline]) => Border.all(color: color);
