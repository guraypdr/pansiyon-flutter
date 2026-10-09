import 'package:flutter/material.dart';

import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

/// Birincil eylem butonu. Ekrandaki ana aksiyon için kullanılır.
///
/// ```dart
/// AppPrimaryButton(
///   icon: Icons.add,
///   label: 'Kayıt ekle',
///   onPressed: _add,
/// )
/// ```
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = AppTokens.controlHeight,
  });

  final String label;

  /// `null` ise buton devre dışı görünür.
  final VoidCallback? onPressed;

  final IconData? icon;

  /// true iken buton yükleniyor göstergesine döner ve devre dışı olur.
  final bool isLoading;

  /// Buton yüksekliği. Filtre çubuğunda `AppTokens.filterHeight` verilerek
  /// arama alanı ve çiplerle aynı hizaya gelinir.
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: AppTokens.iconSm,
            height: AppTokens.iconSm,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.surface,
            ),
          )
        : null;

    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: child ?? (icon == null ? const SizedBox.shrink() : Icon(icon)),
        label: Text(isLoading ? 'Bekleyin' : label),
        style: FilledButton.styleFrom(
          minimumSize: Size(0, height),
          maximumSize: Size(double.infinity, height),
          // Material 3 dokunma alanı genişletmesi kapatılır; aksi hâlde
          // buton, verilen yüksekliğe ek 8 piksel ekler ve filtre çubuğundaki
          // diğer kontrollerle hizalanmaz.
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.gapLg,
            vertical: AppTokens.gapXs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          textStyle: AppTokens.buttonLabel,
          iconSize: AppTokens.iconSm,
        ),
      ),
    );
  }
}

/// İkincil eylem butonu. Ana eylemin yanındaki seçenekler için kullanılır.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = AppTokens.controlHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Buton yüksekliği; filtre çubuğunda `AppTokens.filterHeight` kullanılır.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: AppTokens.iconSm,
                height: AppTokens.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (icon == null ? const SizedBox.shrink() : Icon(icon)),
        label: Text(isLoading ? 'Bekleyin' : label),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, height),
          maximumSize: Size(double.infinity, height),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.gapLg,
            vertical: AppTokens.gapXs,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          side: const BorderSide(color: AppColors.outline),
          textStyle: AppTokens.buttonLabel.copyWith(color: AppColors.primary),
          iconSize: AppTokens.iconSm,
        ),
      ),
    );
  }
}

/// Tonlu buton: ana eylemin yumuşak varyantı.
///
/// "Blok ekle", "Kat ekle", "Otomatik Yerleştir" gibi ikincil eylemler için
/// kullanılır. Flutter'da tonlu buton için tema karşılığı olmadığı için bu
/// bileşen stili elle taşır.
class AppTonalButton extends StatelessWidget {
  const AppTonalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppTokens.controlHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Küçük varyantlar (ör. form satırı içi "Kat ekle") için 38 verilebilir.
  final double height;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        foregroundColor: AppColors.primaryDark,
        disabledBackgroundColor: AppColors.inputBorder.withValues(alpha: 0.4),
        disabledForegroundColor: AppColors.secondaryText,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.gapMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: AppTokens.buttonLabel.copyWith(color: AppColors.primaryDark),
        iconSize: AppTokens.iconSm,
      ),
    );
  }
}

/// Buton görünümlü açılır menü.
///
/// Alt seçenekleri olan eylemler için kullanılır (ör. "Çıktı Al" > liste,
/// öğretmen tablosu, istatistik). İkincicil butonla aynı ölçüde ve aynı
/// renk dilindedir; `Chip` gibi görünen menü butonlarının yerini alır.
class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.icon,
    this.isPrimary = false,
    this.isLoading = false,
    this.height = AppTokens.controlHeight,
  });

  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final IconData? icon;

  /// true ise birincil buton gibi görünür; varsayılan ikincil.
  final bool isPrimary;

  /// true iken menü devre dışı olur ve yükleniyor göstergesi görünür.
  final bool isLoading;

  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading;
    final foreground = !enabled
        ? AppColors.secondaryText
        : (isPrimary ? AppColors.surface : AppColors.primary);

    return PopupMenuButton<T>(
      tooltip: label,
      enabled: enabled,
      offset: const Offset(0, 48),
      color: AppColors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: const BorderSide(color: AppColors.inputBorder),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: SizedBox(
        height: height,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.gapLg),
          decoration: BoxDecoration(
            color: isPrimary && enabled ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: enabled && !isPrimary
                  ? AppColors.outline
                  : AppColors.inputBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: AppTokens.iconSm,
                  height: AppTokens.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else if (icon != null) ...[
                Icon(icon, size: AppTokens.iconSm, color: foreground),
                const SizedBox(width: AppTokens.gapXs),
              ],
              Text(
                isLoading ? 'Bekleyin' : label,
                style: AppTokens.buttonLabel.copyWith(color: foreground),
              ),
              const SizedBox(width: AppTokens.gapXs),
              Icon(
                Icons.keyboard_arrow_down,
                size: AppTokens.iconMd,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Düşük ağırlıklı eylem butonu. Vazgeç, Temizle, geri dön gibi işlemler.
class AppGhostButton extends StatelessWidget {
  const AppGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppTokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.gapMd),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: AppTokens.buttonLabel.copyWith(
          color: AppColors.secondaryText,
        ),
        iconSize: AppTokens.iconSm,
      ),
    );
  }
}

/// Yıkıcı eylem butonu. Sil gibi geri alınamaz işlemler için kullanılır.
class AppDangerButton extends StatelessWidget {
  const AppDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.errorFeedback,
        foregroundColor: AppColors.surface,
        minimumSize: const Size(0, AppTokens.controlHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.gapLg,
          vertical: AppTokens.gapMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        textStyle: AppTokens.buttonLabel,
        iconSize: AppTokens.iconSm,
      ),
      icon: icon == null ? const SizedBox.shrink() : Icon(icon),
      label: Text(label),
    );
  }
}

/// Araç çubuğundaki ikon butonu.
///
/// Tüm ikon butonları aynı kenar, ikon boyutu ve ipucu davranışını paylaşır;
/// böylece ekranlar arasında "Sil" düğmesi farklı büyüklükte görünmez.
class AppIconAction extends StatelessWidget {
  const AppIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.isLoading = false,
  });

  final IconData icon;

  /// Erişilebilirlik ve ipucu metni; eylem her zaman açıklamalıdır.
  final String tooltip;

  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppColors.secondaryText;

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
          onTap: isLoading ? null : onPressed,
          child: SizedBox(
            width: AppTokens.iconActionDefault,
            height: AppTokens.iconActionDefault,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: AppTokens.iconSm,
                      height: AppTokens.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Icon(icon, size: AppTokens.iconMd, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kart üzerindeki ikon butonu.
///
/// Kenarlığı yoktur; kartın içinde daha sessiz durur. Yine de tüm kartlar
/// aynı kenarı ve ikon boyutunu kullanır.
class AppCardIconAction extends StatelessWidget {
  const AppCardIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: AppTokens.iconActionCompact,
          height: AppTokens.iconActionCompact,
        ),
        icon: Icon(
          icon,
          size: AppTokens.iconMd,
          color: color ?? AppColors.secondaryText,
        ),
      ),
    );
  }
}

/// Yıkıcı kart aksiyonu. Renk kırmızıdır; diğerlerinden ayrışır.
class AppDangerCardAction extends StatelessWidget {
  const AppDangerCardAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCardIconAction(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppColors.errorFeedback,
    );
  }
}

/// Diyalog alt buton çubuğu.
///
/// Tüm diyaloglarda aynı sıralama ve boşluk kullanılır: iptal solda, onay
/// sağda.
class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Vazgeç',
    this.onCancel,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String cancelLabel;
  final VoidCallback? onCancel;

  /// true ise onay butonu kırmızı olur.
  final bool isDestructive;

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppGhostButton(
          label: cancelLabel,
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: AppTokens.gapSm),
        if (isDestructive)
          AppDangerButton(label: confirmLabel, onPressed: onConfirm)
        else
          AppPrimaryButton(
            label: confirmLabel,
            onPressed: onConfirm,
            isLoading: isLoading,
          ),
      ],
    );
  }
}
