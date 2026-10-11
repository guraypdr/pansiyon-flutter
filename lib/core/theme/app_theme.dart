import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Uygulamanın renk paleti.
///
/// Tüm ekranlar yalnızca bu değerleri kullanır; bir rengi değiştirmek için
/// buradaki tek satırı düzenlemek yeterlidir.
///
/// Palet açık gri zemin + beyaz kart + kral mavisi vurgu düzenine dayanır.
class AppColors {
  AppColors._();

  // --- Marka renkleri ---------------------------------------------------------

  /// Ana vurgu rengi: butonlar, seçili menüler, ikonlar.
  static const primary = Color(0xFF2563EB);

  /// Koyu marka rengi: koyu başlık bantları ve başlık metinleri.
  static const primaryDark = Color(0xFF0F172A);

  /// İkincil vurgu: gradyanların ve ikincil butonların koyu ucu.
  static const secondary = Color(0xFF1D4ED8);

  /// Buton kenarlığı.
  static const outline = Color(0xFF3B82F6);

  // --- Yüzeyler ---------------------------------------------------------------

  /// Sayfa zemini (açık gri).
  static const appBackground = Color(0xFFF1F5F9);

  /// Kart ve içerik zemini (beyaz).
  static const surface = Color(0xFFFFFFFF);
  static const cardSurface = Color(0xFFFFFFFF);

  /// Kart içi ikincil dolgu.
  static const cardSurfaceAccent = Color(0xFFF8FAFC);

  /// Form alanı zemini.
  static const inputSurface = Color(0xFFFFFFFF);

  static const surfaceContainer = Color(0xFFFFFFFF);
  static const surfaceContainerHigh = Color(0xFFF8FAFC);
  static const surfaceContainerHighest = Color(0xFFDBEAFE);

  // --- Yazı renkleri ----------------------------------------------------------

  /// Ana metin (koyu lacivert).
  static const darkText = Color(0xFF0F172A);

  /// İkincil metin (slate gri).
  static const secondaryText = Color(0xFF64748B);

  // --- Çizgiler ---------------------------------------------------------------

  /// Kart ve alan kenarlığı (açık gri).
  static const inputBorder = Color(0xFFE2E8F0);

  /// Daha belirgin kenarlık.
  static const border = Color(0xFFCBD5E1);

  // --- Vurgu tonları ----------------------------------------------------------

  /// En açık mavi ton; seçili olmayan zeminlerde kullanılır.
  static const softPurple = Color(0xFFEFF6FF);

  /// Açık mavi; dolgu ve vurgu zemini.
  static const softMagenta = Color(0xFFDBEAFE);

  /// Orta mavi; devre dışı durumlar.
  static const lavender = Color(0xFFBFDBFE);

  static const warmBackground = appBackground;

  // --- Kabuk ------------------------------------------------------------------

  /// Koyu mürekkep rengi; metin ve simgelerde kullanılır.
  static const sidebar = primaryDark;

  /// Uygulama çerçevesi rengi (açık gri).
  static const frame = Color(0xFFE2E8F0);

  static const sidebarActive = primary;
  static const sidebarHover = softMagenta;

  // --- Durum renkleri ----------------------------------------------------------

  static const error = secondary;
  static const onErrorContainer = darkText;
  static const shadow = darkText;
  static const transparent = Color(0x00000000);
  static const successFeedback = Color(0xFF16A34A);
  static const errorFeedback = Color(0xFFDC2626);
}

/// Yazı tipi tanımları.
///
/// Tüm başlık ve metin stilleri bu değerlerden gelir; punto ve kalınlık
/// değiştirmek için buradaki tek satırı düzenlemek yeterlidir.
class AppTypography {
  AppTypography._();

  /// Uygulamanın genel yazı tipi ailesi. Windows'ta Segoe UI, diğer
  /// sistemlerde Roboto'ya düşer.
  static const List<String> fontFamily = <String>['Segoe UI', 'Roboto'];

  static const List<String> fontFamilyFallback = <String>[
    'Segoe UI',
    'Roboto',
    'Arial',
  ];

  /// Büyük sayfa başlığı.
  static const TextStyle display = TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.darkText,
  );

  /// Kart başlığı.
  static const TextStyle title = TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.darkText,
  );

  /// Gövde metni.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.darkText,
  );

  /// İkincil açıklama.
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.secondaryText,
  );

  /// Buton yazısı.
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.surface,
  );
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
      // Yazı tipi ailesi tema üzerinden tek yerden yönetilir.
      fontFamily: 'Segoe UI',
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.appBackground,
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
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppTokens.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          // Tüm butonlarda aynı ikon boyutu ve yazı tipi; çağrı yerinde
          // verilen değerler artık sapma yaratmaz.
          iconSize: const WidgetStatePropertyAll(AppTokens.iconSm),
          textStyle: const WidgetStatePropertyAll(AppTokens.buttonLabel),
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
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          iconSize: AppTokens.iconSm,
          textStyle: AppTokens.buttonLabel.copyWith(color: AppColors.primary),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      // Tüm ikon butonları aynı kenar ve ikon boyutunda başlar; tekil
      // ekranlarda `AppIconAction` / `AppCardIconAction` bileşenleri
      // bilinçli olarak daha küçük ölçü tanımlar.
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppTokens.iconActionDefault, AppTokens.iconActionDefault),
          ),
          iconSize: const WidgetStatePropertyAll(AppTokens.iconMd),
          visualDensity: VisualDensity.compact,
          foregroundColor: const WidgetStatePropertyAll(
            AppColors.secondaryText,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
        ),
      ),
      // Düşük ağırlıklı buton: "Vazgeç", "Temizle", geri dön.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          iconSize: AppTokens.iconSm,
          textStyle: AppTokens.buttonLabel.copyWith(
            color: AppColors.secondaryText,
          ),
          foregroundColor: AppColors.secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
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
