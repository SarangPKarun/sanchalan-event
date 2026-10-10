import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/theme/app_colors.dart';

double _channel(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('contrast helper matches known values', () {
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)), closeTo(4.48, 0.05));
  });

  // Text colors and the backgrounds they appear on. All need 4.5:1 (AA, normal text).
  final pairs = <String, (Color, Color)>{
    'ink on background': (AppColors.ink, AppColors.background),
    'ink on surface': (AppColors.ink, AppColors.surface),
    'ink on sand': (AppColors.ink, AppColors.surfaceMuted),
    'inkMuted on background': (AppColors.inkMuted, AppColors.background),
    'inkMuted on surface': (AppColors.inkMuted, AppColors.surface),
    'inkMuted on sand': (AppColors.inkMuted, AppColors.surfaceMuted),
    'onPrimary on primary (buttons)': (AppColors.onPrimary, AppColors.primary),
    'primary on background (links)': (AppColors.primary, AppColors.background),
    'primary on surface': (AppColors.primary, AppColors.surface),
    'onPrimaryContainer on primaryContainer': (
      AppColors.onPrimaryContainer,
      AppColors.primaryContainer
    ),
    'inkMuted on primaryContainer (unselected nav on indicator)': (
      AppColors.inkMuted,
      AppColors.primaryContainer
    ),
    'maroon on background': (AppColors.maroon, AppColors.background),
    'maroon on surface': (AppColors.maroon, AppColors.surface),
    'maroon on maroonContainer': (AppColors.maroon, AppColors.maroonContainer),
    'onMaroon on maroon': (AppColors.onMaroon, AppColors.maroon),
    'onGoldContainer on goldContainer': (AppColors.onGoldContainer, AppColors.goldContainer),
    'errorText on surface': (AppColors.errorText, AppColors.surface),
    'errorText on background': (AppColors.errorText, AppColors.background),
    'ink on snackbar': (AppColors.surface, AppColors.ink),
  };

  for (final e in pairs.entries) {
    test('${e.key} >= 4.5:1', () {
      final ratio = contrast(e.value.$1, e.value.$2);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '${e.key} is ${ratio.toStringAsFixed(2)}:1');
    });
  }

  for (final tone in StatusTone.values) {
    test('status chip ${tone.name} >= 4.5:1', () {
      final ratio = contrast(tone.foreground, tone.background);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '${tone.name} is ${ratio.toStringAsFixed(2)}:1');
    });
  }

  test('error icon color is at least 3:1 on surface (non-text)', () {
    expect(contrast(AppColors.error, AppColors.surface), greaterThanOrEqualTo(3));
  });

  test('input border is at least 3:1 on surface (non-text)', () {
    expect(contrast(AppColors.outlineStrong, AppColors.surface), greaterThanOrEqualTo(3));
  });
}
