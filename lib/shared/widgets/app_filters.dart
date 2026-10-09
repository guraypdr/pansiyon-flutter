import 'package:flutter/material.dart';

import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';

/// Tek seçimli filtre çipi.
///
/// Etkin çip renklenir, pasif çip nötr kalır. Başlık bandının altındaki filtre
/// satırında veya liste içinde kullanılır.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.primaryDark : AppColors.darkText;

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.inputBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppTokens.filterHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gapMd),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppTokens.iconSm,
                    color: isSelected ? AppColors.primaryDark : foreground,
                  ),
                  const SizedBox(width: AppTokens.gapXs),
                ],
                Text(
                  label,
                  style: AppTokens.filterLabel.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Açık/kapalı filtre çipi.
///
/// Seçili olduğunda onay işareti gösterir; "Dolu odaları göster" gibi
/// iki durumlu süzgeçler için kullanılır.
class AppToggleChip extends StatelessWidget {
  const AppToggleChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.surface : AppColors.darkText;

    return Material(
      color: isSelected ? AppColors.secondary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: BorderSide(
          color: isSelected ? AppColors.secondary : AppColors.inputBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppTokens.filterHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.gapMd),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check,
                    size: AppTokens.iconSm,
                    color: AppColors.surface,
                  ),
                  const SizedBox(width: AppTokens.gapXs),
                ] else if (icon != null) ...[
                  Icon(icon, size: AppTokens.iconSm, color: foreground),
                  const SizedBox(width: AppTokens.gapXs),
                ],
                Text(
                  label,
                  style: AppTokens.filterLabel.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
