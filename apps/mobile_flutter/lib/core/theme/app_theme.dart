import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The one ThemeData of the app (light only). Screens take colors, text styles
/// and sizes from here and from the tokens, never hardcode them.
ThemeData buildAppTheme() {
  final textTheme = buildTextTheme();

  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.maroon,
    onSecondary: AppColors.onMaroon,
    secondaryContainer: AppColors.maroonContainer,
    onSecondaryContainer: AppColors.maroon,
    tertiary: AppColors.gold,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.goldContainer,
    onTertiaryContainer: AppColors.onGoldContainer,
    error: AppColors.error,
    onError: AppColors.onPrimary,
    errorContainer: AppColors.errorBg,
    onErrorContainer: AppColors.errorText,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.background,
    surfaceContainer: AppColors.surfaceMuted,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: AppColors.surfaceMuted,
    outline: AppColors.outlineStrong,
    outlineVariant: AppColors.outline,
    scrim: AppColors.scrim,
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.m),
    borderSide: const BorderSide(color: AppColors.outlineStrong),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    fontFamily: AppFonts.body,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.maroon,
      titleTextStyle: textTheme.headlineSmall!.copyWith(color: AppColors.maroon),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kMinTouchTarget, 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        textStyle: textTheme.labelLarge,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.outline,
        disabledForegroundColor: AppColors.inkMuted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(kMinTouchTarget, 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        textStyle: textTheme.labelLarge,
        foregroundColor: AppColors.maroon,
        side: const BorderSide(color: AppColors.maroon, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        textStyle: textTheme.labelLarge,
        foregroundColor: AppColors.primary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.l),
      hintStyle: textTheme.bodyLarge!.copyWith(color: AppColors.inkMuted),
      errorStyle: textTheme.bodySmall!.copyWith(color: AppColors.errorText),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primaryContainer,
      side: const BorderSide(color: AppColors.outlineStrong),
      labelStyle: textTheme.labelMedium,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium!.copyWith(
          color: states.contains(WidgetState.selected)
              ? AppColors.onPrimaryContainer
              : AppColors.inkMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.onPrimaryContainer
              : AppColors.inkMuted,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      titleTextStyle: textTheme.headlineSmall,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: textTheme.bodyMedium!.copyWith(color: AppColors.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      extendedTextStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1, thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.primaryContainer,
      circularTrackColor: AppColors.primaryContainer,
    ),
  );
}
