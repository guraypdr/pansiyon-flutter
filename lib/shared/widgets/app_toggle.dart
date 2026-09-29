import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';

/// Tema uyumlu anahtar butonu.
///
/// Açık/kapalı durumları kart görünümünde bir anahtar ile sunar; açıklaması
/// Durum metni her zaman görünür: kapalıyken "Hayır", açıkken "Evet" yazılır.
/// Böylece bütün anahtar butonları aynı görünür ve alanın açık olup olmadığı
/// yazıyla da anlaşılır.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.icon,
    this.enabled = true,
    this.offLabel,
    this.onLabel,
    this.showValueLabel = true,
  });

  final String label;
  final String? description;
  final IconData? icon;
  final bool value;
  final bool enabled;

  /// Kapalıyken ve açıkken anahtarın yanında gösterilecek metin.
  ///
  /// Verilmezse sırasıyla "Hayır" ve "Evet" kullanılır. "Var/Yok" gibi farklı
  /// bir karşılık gereken alanlarda bu değerlerle değiştirilebilir.
  final String? offLabel;
  final String? onLabel;

  /// Durum metnini gizlemek için false yapılabilir.
  final bool showValueLabel;

  final ValueChanged<bool> onChanged;

  /// Kapalı durum için varsayılan metin.
  static const defaultOffLabel = 'Hayır';

  /// Açık durum için varsayılan metin.
  static const defaultOnLabel = 'Evet';

  @override
  Widget build(BuildContext context) {
    final active = value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.inputBorder,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: active ? AppColors.primary : AppColors.secondaryText,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: enabled
                        ? AppColors.darkText
                        : AppColors.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (showValueLabel) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                active
                    ? (onLabel ?? defaultOnLabel)
                    : (offLabel ?? defaultOffLabel),
                key: ValueKey<bool>(active),
                style: TextStyle(
                  color: active ? AppColors.primary : AppColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Switch.adaptive(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
