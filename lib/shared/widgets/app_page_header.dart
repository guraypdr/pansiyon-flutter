import 'package:flutter/material.dart';

import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

/// Sayfaların üst kısmındaki ortak başlık bandı.
///
/// Görünüm:
/// ```text
/// ┌───────────────────────────────────────────────┐
/// │▔▔▔▔▔ (renkli vurgu çizgisi)                   │
/// │ Başlık + özet          (bölüm seçici / sekme)  │
/// │                               [ikincil] [ana]  │
/// └───────────────────────────────────────────────┘
/// ```
///
/// - Bandın üstünde ince renkli vurgu çizgisi vardır.
/// - `section` başlık satırının **sağ ucunda**, başlıkla aynı hizada durur.
/// - Eylemler (`actions`) başlığın bir altına, sağa yaslanmış olarak gelir;
///   böylece başlık satırı yalnızca isim ve bölüm seçiciye kalır.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backTooltip = 'Geri',
    this.actions = const [],
    this.section,
    this.bottom,
    this.accent = AppColors.primary,
  });

  final String title;

  /// Başlığın altındaki ikincil açıklama ("12 öğretmen • 3 liste").
  final String? subtitle;

  /// Geri düğmesi gösterilir.
  final VoidCallback? onBack;

  final String backTooltip;

  /// Başlığın altında, sağa yaslanmış eylemler.
  final List<Widget> actions;

  /// Başlık satırının sağ ucunda duran bölüm seçici (sekme çubuğu gibi).
  final Widget? section;

  /// Başlık bandının altındaki ikinci satır (filtreler).
  final Widget? bottom;

  /// Üstteki vurgu çizgisinin rengi.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTokens.pageGutter,
        AppTokens.gapMd,
        AppTokens.pageGutter,
        0,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard + 2),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: AppTokens.shadowRaised,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üstte ince vurgu çizgisi; bandı sayfadan ayırır.
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, AppColors.secondary, AppColors.lavender],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.gapLg,
              AppTokens.fieldGap,
              AppTokens.gapMd,
              AppTokens.fieldGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleRow(
                  title: title,
                  subtitle: subtitle,
                  section: section,
                  leading: onBack == null
                      ? null
                      : AppBackButton(onPressed: onBack, tooltip: backTooltip),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: AppTokens.gapSm,
                      runSpacing: AppTokens.gapSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (bottom != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.inputBorder)),
              ),
              // Alt şerit yalnızca ince bir ayraç ve çubuk yüksekliği kadar
              // yer kaplar; başlık bandı gereksiz boşluk bırakmaz.
              padding: const EdgeInsets.fromLTRB(
                AppTokens.gapMd,
                6,
                AppTokens.gapMd,
                6,
              ),
              child: bottom!,
            ),
        ],
      ),
    );
  }
}

/// Başlık satırı: geri düğmesi, başlık + özet ve sağdaki bölüm seçici.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    this.subtitle,
    this.section,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? section;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTokens.pageTitle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTokens.gapXs),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.helperTextStyle,
          ),
        ],
      ],
    );

    final text = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: heading),
        if (section != null) ...[
          const SizedBox(width: AppTokens.gapMd),
          Flexible(child: section!),
        ],
      ],
    );

    if (leading == null) {
      return text;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading!,
        const SizedBox(width: AppTokens.fieldGap),
        Expanded(child: text),
      ],
    );
  }
}

/// Standart geri düğmesi.
///
/// Tüm detay görünümlerinde aynı boyut ve kenarlığa sahiptir.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Geri',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: AppTokens.iconActionDefault,
            height: AppTokens.iconActionDefault,
            child: Center(
              child: Icon(
                Icons.arrow_back,
                size: AppTokens.iconMd,
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
