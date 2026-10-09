import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Proje genelinde ölçü, boşluk ve ikon kuralları.
///
/// Tüm ekranlar bu değerleri kullanır. Sayılar tek yerde tanımlı olduğu için
/// bir ekranda yapılan değişiklik diğer ekranlarla tutarsızlaşmaz.
class AppTokens {
  AppTokens._();

  // ---------------------------------------------------------------------------
  // Boşluk ölçeği (4'ün katları)
  // ---------------------------------------------------------------------------

  /// Ekran kenar boşluğu; tüm sayfalar bu değerle başlar ve biter.
  static const double pageGutter = 20;

  /// Kart iç boşluğu.
  static const double cardPadding = 16;

  /// Kartlar arası dikey boşluk.
  static const double cardGap = 12;

  /// Form alanları arası dikey boşluk.
  static const double fieldGap = 12;

  /// Etiket ile alan arasındaki boşluk.
  static const double labelGap = 6;

  /// İç içe bileşenler arası küçük boşluk.
  static const double gapXs = 4;

  /// İki öğe arasındaki standart boşluk.
  static const double gapSm = 8;

  /// Filtre çubuğu öğeleri arasındaki boşluk.
  static const double gapMd = 10;

  /// Kutular arasındaki geniş boşluk.
  static const double gapLg = 16;

  // ---------------------------------------------------------------------------
  // Köşe yarıçapı ölçeği
  // ---------------------------------------------------------------------------

  /// Küçük iç içe bileşenler: rozet, küçük etiketler.
  static const double radiusSm = 8;

  /// Butonlar, filtre alanları, ikon butonları.
  static const double radiusMd = 12;

  /// Veri girdi alanları (InputDecoration bu değeri kullanır).
  static const double radiusLg = 14;

  /// Kartlar.
  static const double radiusCard = 16;

  /// Hap biçimindeki bileşenler (çip, sil).
  static const double radiusPill = 999;

  // ---------------------------------------------------------------------------
  // Kontrol yükseklikleri
  // ---------------------------------------------------------------------------

  /// Birincil ve ikincil buton yüksekliği.
  static const double controlHeight = 44;

  /// Filtre çubuğu kontrol yüksekliği (arama, filtre, tarih).
  static const double filterHeight = 42;

  /// Form alanı yüksekliği.
  static const double fieldHeight = 48;

  /// Kart üzerindeki küçük ikon butonu kenarı.
  static const double iconActionCompact = 30;

  /// Araç çubuğundaki ikon butonu kenarı.
  static const double iconActionDefault = 40;

  // ---------------------------------------------------------------------------
  // İkon boyutları
  // ---------------------------------------------------------------------------

  /// Buton içindeki ikon.
  static const double iconSm = 18;

  /// Kart aksiyonlarındaki ikon.
  static const double iconMd = 20;

  /// Chip içindeki ikon.
  static const double iconXs = 14;

  // ---------------------------------------------------------------------------
  // Yazı tipi
  // ---------------------------------------------------------------------------

  /// Sayfa başlığı.
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
  );

  /// Bölüm başlığı.
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: AppColors.darkText,
  );

  /// Buton yazısı.
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.surface,
  );

  /// Filtre ve arama metni.
  static const TextStyle filterLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.darkText,
  );

  /// Yardımcı/ikincil metin.
  static const TextStyle helperTextStyle = TextStyle(
    fontSize: 12,
    height: 1.3,
    color: AppColors.secondaryText,
  );

  // ---------------------------------------------------------------------------
  // Geçişler
  // ---------------------------------------------------------------------------

  /// Standart animasyon süresi.
  static const Duration duration = Duration(milliseconds: 150);

  // ---------------------------------------------------------------------------
  // Duyarlılık
  // ---------------------------------------------------------------------------

  /// Bu genişliğin altındaki ekranlarda filtre çubuğu satıra sarar.
  static const double compactBreakpoint = 1040;

  /// Bu genişliğin altındaki ekranlarda tek sütuna düşülür.
  static const double narrowBreakpoint = 820;
}
