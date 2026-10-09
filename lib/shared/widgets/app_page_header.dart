import 'package:flutter/material.dart';

import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

/// Sayfaların üst kısmındaki ortak başlık bandı.
///
/// Görünüm:
/// ```text
/// ┌───────────────────────────────────────────────┐
/// │▔▔▔▔▔▔ (renkli vurgu çizgisi)                   │
/// │ Başlık                        [ikincil] [ana] │
/// │ Özet yazısı                                     │
/// │ ─────────────────────────────────────────────  │
/// │ (sekme çubuğu / filtreler)                      │
/// └───────────────────────────────────────────────┘
/// ```
///
/// - Bandın üstünde ince renkli vurgu çizgisi vardır.
/// - Altında isteğe bağlı ikinci satır (sekme çubuğu, filtreler) bulunur.
/// - Eylemler sağda sıralanır; ikincil solda, ana eylem en sağda.
/// - Eylemler sığmazsa başlığın altına sarar ve sola yaslanır.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backTooltip = 'Geri',
    this.actions = const [],
    this.bottom,
    this.accent = AppColors.primary,
  });

  final String title;

  /// Başlığın altındaki ikincil açıklama ("12 öğretmen • 3 liste").
  final String? subtitle;

  /// Geri düğmesi gösterilir.
  final VoidCallback? onBack;

  final String backTooltip;

  /// Sağ üstteki eylemler. Sıra korunur; ana eylem en sona yazılır.
  final List<Widget> actions;

  /// Başlık bandının altındaki ikinci satır (sekme çubuğu, filtreler).
  final Widget? bottom;

  /// Üstteki vurgu çizgisinin rengi.
  final Color accent;

  /// Eylemler bu genişliğin altında başlığın altına sarar.
  static const double wrapBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final hasBack = onBack != null;

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
              AppTokens.gapLg,
              AppTokens.gapMd,
              AppTokens.gapMd,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final actionsRow = _ActionRow(actions: actions);
                final heading = _Heading(title: title, subtitle: subtitle);

                final content = constraints.maxWidth < wrapBreakpoint
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          if (actions.isNotEmpty) ...[
                            const SizedBox(height: AppTokens.fieldGap),
                            _ActionRow(actions: actions, alignRight: false),
                          ],
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: heading),
                          if (actions.isNotEmpty) ...[
                            const SizedBox(width: AppTokens.gapMd),
                            Flexible(child: actionsRow),
                          ],
                        ],
                      );

                if (!hasBack) {
                  return content;
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppBackButton(onPressed: onBack, tooltip: backTooltip),
                    const SizedBox(width: AppTokens.fieldGap),
                    Expanded(child: content),
                  ],
                );
              },
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

/// Başlık ve özet yazısı.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}

/// Sağ üstteki eylem sırası. Tüm sayfalarda aynı hizalama ve aralık.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.actions, this.alignRight = true});

  final List<Widget> actions;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
        spacing: AppTokens.gapSm,
        runSpacing: AppTokens.gapSm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      ),
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
