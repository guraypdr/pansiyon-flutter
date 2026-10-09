import 'package:flutter/material.dart';

import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

/// Sayfaların üst kısmındaki ortak başlık bandı.
///
/// Her ekranda aynı düzen geçerli olur:
///
/// ```text
/// [Geri]  Başlık                              [ikincil] [ana eylem]
///         Özet yazısı
///         (sekme çubuğu / filtreler)
/// ```
///
/// - Başlık solda, tek satırda ve gerekiyorsa kırpılır.
/// - Özet yazısı başlığın altında ikincil renkte durur.
/// - Eylemler sağda sıralanır; ikincil eylem solda, ana eylem en sağda.
/// - Eylemler sığmazsa başlığın altına sarar ve sola yaslanır.
/// - `bottom` ile sekme çubuğu gibi ikinci satır eklenebilir.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backTooltip = 'Geri',
    this.actions = const [],
    this.bottom,
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

  /// Eylemler bu genişliğin altında başlığın altına sarar.
  static const double wrapBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final hasBack = onBack != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pageGutter,
        AppTokens.gapLg,
        AppTokens.pageGutter,
        AppTokens.gapMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
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
                          actionsRow,
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
                  const SizedBox(width: AppTokens.gapSm),
                  Expanded(child: content),
                ],
              );
            },
          ),
          if (bottom != null) ...[
            const SizedBox(height: AppTokens.gapMd),
            bottom!,
          ],
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
  const _ActionRow({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
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
/// Tüm detay görünümlerinde aynı boyut ve kenarlığa sahiptir; böylece
/// "geri" davranışı ekranlar arasında görsel olarak da tutarlıdır.
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
        color: AppColors.surface,
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
