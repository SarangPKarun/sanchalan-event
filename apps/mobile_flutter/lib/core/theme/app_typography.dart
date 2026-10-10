import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Display face for headings, body face for everything else. Both are variable
/// fonts bundled in assets/fonts, so the weight is set through the `wght` axis.
abstract final class AppFonts {
  static const display = 'PlayfairDisplay';
  static const body = 'NunitoSans';
}

TextStyle _style(
  String family,
  double size,
  double lineHeight,
  FontWeight weight, {
  Color color = AppColors.ink,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      letterSpacing: letterSpacing,
    );

TextTheme buildTextTheme() => TextTheme(
      displayLarge: _style(AppFonts.display, 40, 48, FontWeight.w700),
      displayMedium: _style(AppFonts.display, 34, 42, FontWeight.w700),
      displaySmall: _style(AppFonts.display, 30, 38, FontWeight.w700),
      headlineLarge: _style(AppFonts.display, 28, 36, FontWeight.w700),
      headlineMedium: _style(AppFonts.display, 24, 32, FontWeight.w700),
      headlineSmall: _style(AppFonts.display, 20, 28, FontWeight.w700),
      titleLarge: _style(AppFonts.body, 20, 28, FontWeight.w800),
      titleMedium: _style(AppFonts.body, 16, 24, FontWeight.w700, letterSpacing: 0.1),
      titleSmall: _style(AppFonts.body, 14, 20, FontWeight.w700, letterSpacing: 0.1),
      bodyLarge: _style(AppFonts.body, 17, 26, FontWeight.w400),
      bodyMedium: _style(AppFonts.body, 15, 22, FontWeight.w400),
      bodySmall: _style(AppFonts.body, 13, 18, FontWeight.w400, color: AppColors.inkMuted),
      labelLarge: _style(AppFonts.body, 16, 20, FontWeight.w800, letterSpacing: 0.2),
      labelMedium: _style(AppFonts.body, 13, 16, FontWeight.w700, letterSpacing: 0.3),
      labelSmall: _style(AppFonts.body, 12, 16, FontWeight.w700, letterSpacing: 0.4),
    );
