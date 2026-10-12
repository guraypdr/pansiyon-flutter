import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_excel_importer.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';

/// İçe aktarma öncesi önizleme penceresi.
///
/// Kullanıcı ne kadar gün ve yemek okunduğunu, atlanan satırları ve ilk
/// birkaç günün içeriğini burada görür; içe aktarma onayından sonra yapılır.
class MealImportDialog extends StatelessWidget {
  const MealImportDialog({super.key, required this.preview});

  final MealImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final warnings = preview.warnings;
    return AlertDialog(
      title: const Text('Yemek listesi içe aktar'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_menu_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        preview.summaryLine,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final warning in warnings)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  warning,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryText,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Önizleme',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final day in preview.days.take(4)) _DayPreview(day),
                  ],
                ),
              ),
              if (preview.dayCount > 4) ...[
                const SizedBox(height: 8),
                Text(
                  '... ve ${preview.dayCount - 4} gün daha',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Aynı tarihe ait kayıt varsa üzerine yazılır.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('meal_import_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        AppPrimaryButton(
          key: const Key('meal_import_confirm'),
          label: 'İçe Aktar',
          icon: Icons.download_done_outlined,
          onPressed: preview.canImport
              ? () => Navigator.of(context).pop(true)
              : null,
        ),
      ],
    );
  }
}

class _DayPreview extends StatelessWidget {
  const _DayPreview(this.day);

  final MealDay day;

  @override
  Widget build(BuildContext context) {
    final filled = <({String label, List<String> items})>[
      for (final type in MealType.values)
        if (day.mealsOf(type).isNotEmpty)
          (label: type.shortLabel, items: day.mealsOf(type)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.date.day}.${day.date.month.toString().padLeft(2, '0')}.'
            '${day.date.year}  ${mealWeekdayName(day.date)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          if (filled.isEmpty)
            const Text(
              'Bu gün için yemek yok',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final meal in filled)
                  SizedBox(
                    width: 126,
                    child: Text(
                      '${meal.label}: ${meal.items.join(', ')}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
