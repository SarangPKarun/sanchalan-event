import 'package:flutter/material.dart';

/// Warm festive palette: saffron primary, maroon, gold, cream surfaces.
/// Every text/background pair below is checked against WCAG AA in
/// test/core/theme/contrast_test.dart.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFFB64D08); // deep saffron
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFFFE6D0);
  static const onPrimaryContainer = Color(0xFF4A1F03);

  static const maroon = Color(0xFF7A1F2B);
  static const onMaroon = Color(0xFFFFFFFF);
  static const maroonContainer = Color(0xFFF7DFE2);

  static const gold = Color(0xFFD9A21B); // decorative accents, never text on cream
  static const goldContainer = Color(0xFFFFF1C9);
  static const onGoldContainer = Color(0xFF5C4300);

  // Surfaces
  static const background = Color(0xFFFFF8EF); // cream
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8EEE2); // sand
  static const outline = Color(0xFFE8D9C6);
  static const outlineStrong = Color(0xFFA38D75);

  // Text
  static const ink = Color(0xFF2B1B17);
  static const inkMuted = Color(0xFF6B5B54);

  // Feedback (text color + tinted background pairs)
  static const error = Color(0xFFB3261E);
  static const errorText = Color(0xFFA3201A);
  static const errorBg = Color(0xFFFCE4E1);
  static const successText = Color(0xFF1B6B3C);
  static const successBg = Color(0xFFDDF1E4);
  static const warningText = Color(0xFF7A4E00);
  static const warningBg = Color(0xFFFFF1D0);
  static const infoText = Color(0xFF1F5A9E);
  static const infoBg = Color(0xFFE1ECF9);
  static const neutralText = Color(0xFF4F403A);
  static const neutralBg = Color(0xFFF1E7DB);

  static const scrim = Color(0x66000000);
}

/// Meaning of a status chip. Task and vendor statuses map onto these.
enum StatusTone { neutral, primary, success, warning, error, info }

extension StatusToneColors on StatusTone {
  Color get foreground => switch (this) {
        StatusTone.neutral => AppColors.neutralText,
        StatusTone.primary => AppColors.onPrimaryContainer,
        StatusTone.success => AppColors.successText,
        StatusTone.warning => AppColors.warningText,
        StatusTone.error => AppColors.errorText,
        StatusTone.info => AppColors.infoText,
      };

  Color get background => switch (this) {
        StatusTone.neutral => AppColors.neutralBg,
        StatusTone.primary => AppColors.primaryContainer,
        StatusTone.success => AppColors.successBg,
        StatusTone.warning => AppColors.warningBg,
        StatusTone.error => AppColors.errorBg,
        StatusTone.info => AppColors.infoBg,
      };
}
