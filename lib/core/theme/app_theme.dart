import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFFDF48A1);
  static const primaryDark = Color(0xFF3E0C28);
  static const appBackground = warmBackground;
  static const secondary = Color(0xFF960A5C);
  static const softPurple = Color(0xFFFFFBF3);
  static const softMagenta = Color(0xFFFFD968);
  static const lavender = Color(0xFFFFB219);
  static const warmBackground = Color(0xFFFFFBF3);
  static const surface = Color(0xFFFFFBF3);
  static const darkText = Color(0xFF3E0C28);
  static const secondaryText = Color(0xFF960A5C);
  static const border = Color(0xFFFFD968);
  static const outline = Color(0xFFFFB219);
  static const sidebar = primaryDark;
  static const sidebarActive = primary;
  static const sidebarHover = softMagenta;
  static const error = secondary;
  static const onErrorContainer = darkText;
  static const surfaceContainer = Color(0xFFFFFBF3);
  static const surfaceContainerHigh = Color(0xFFFFFBF3);
  static const surfaceContainerHighest = Color(0xFFFFD968);
  static const inputSurface = surface;
  static const cardSurface = Color(0xFFFFF9ED);
  static const cardSurfaceAccent = Color(0xFFFFF0C7);
  static const inputBorder = Color(0xFFE5C5D5);
  static const shadow = darkText;
  static const transparent = Color(0x00000000);
  static const successFeedback = Color(0xFF1B5E20);
  static const errorFeedback = Color(0xFFB71C1C);
}

class AppTheme {
  AppTheme._();

  static const inputTextStyle = TextStyle(
    color: AppColors.darkText,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.softPurple,
      onPrimaryContainer: AppColors.darkText,
      secondary: AppColors.secondary,
      onSecondary: AppColors.surface,
      secondaryContainer: AppColors.softMagenta,
      onSecondaryContainer: AppColors.darkText,
      tertiary: AppColors.primaryDark,
      onTertiary: AppColors.surface,
      tertiaryContainer: AppColors.lavender,
      onTertiaryContainer: AppColors.darkText,
      error: AppColors.error,
      onError: AppColors.surface,
      errorContainer: AppColors.softMagenta,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.secondaryText,
      outline: AppColors.outline,
      outlineVariant: AppColors.border,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.warmBackground,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      surfaceTint: AppColors.primary,
      inversePrimary: AppColors.lavender,
      onInverseSurface: AppColors.darkText,
      inverseSurface: AppColors.darkText,
      scrim: AppColors.darkText,
      shadow: AppColors.shadow,
    );
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.warmBackground,
    );
    final baseTextTheme = baseTheme.textTheme.apply(
      bodyColor: AppColors.darkText,
      displayColor: AppColors.darkText,
    );
    final textTheme = baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.lavender;
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return AppColors.primaryDark;
            }
            return AppColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(AppColors.surface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.secondary,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: TextStyle(
          color: AppColors.secondaryText.withValues(alpha: 0.68),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.errorFeedback),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.errorFeedback,
            width: 2,
          ),
        ),
      ),
    );
  }
}
