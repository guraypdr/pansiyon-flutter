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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: AppColors.surface,
        headerHelpStyle: const TextStyle(
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
        ),
        headerHeadlineStyle: const TextStyle(
          color: AppColors.surface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        weekdayStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        dayStyle: const TextStyle(fontWeight: FontWeight.w700),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surface;
          }
          return AppColors.darkText;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.transparent;
        }),
        dayShape: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const CircleBorder();
          }
          return RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          );
        }),
        dayOverlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDark;
          }
          return AppColors.primary.withValues(alpha: 0.12);
        }),
        todayBorder: const BorderSide(color: AppColors.primary, width: 1.4),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.primary),
        todayBackgroundColor: const WidgetStatePropertyAll(
          AppColors.softPurple,
        ),
        yearStyle: const TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w800,
        ),
        yearForegroundColor: const WidgetStatePropertyAll(AppColors.darkText),
        yearBackgroundColor: const WidgetStatePropertyAll(AppColors.softPurple),
        yearOverlayColor: const WidgetStatePropertyAll(AppColors.softMagenta),
        yearShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dividerColor: AppColors.inputBorder,
        subHeaderForegroundColor: AppColors.secondaryText,
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        confirmButtonStyle: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
        ),
        toggleButtonTextStyle: const TextStyle(
          color: AppColors.secondaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        hourMinuteColor: AppColors.inputSurface.withValues(alpha: 0.9),
        dayPeriodColor: AppColors.primary.withValues(alpha: 0.12),
        dialBackgroundColor: AppColors.inputSurface,
        dialHandColor: AppColors.primary,
        dialTextColor: AppColors.darkText,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.surface),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.inputBorder),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
          ),
        ),
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
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Düşük ağırlıklı buton: "Vazgeç", "Temizle", geri dön.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: AppColors.secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
        isDense: false,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 6,
        textStyle: const TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.darkText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.darkText,
          fontSize: 14,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surface;
          }
          return AppColors.secondaryText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.inputBorder;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.transparent),
      ),
    );
  }
}
