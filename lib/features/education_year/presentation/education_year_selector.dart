import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';

/// Sidebar'daki eğitim öğretim yılı seçici.
///
/// Seçilen yıl uygulama genelinde geçerli olur; öğrenci, öğretmen ve nöbet
/// listesi ekranları bu yılın verisini gösterir.
class EducationYearSelector extends StatelessWidget {
  const EducationYearSelector({
    super.key,
    required this.years,
    required this.activeYear,
    required this.onSelected,
  });

  final List<EducationYear> years;
  final int activeYear;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final active = years.firstWhere(
      (year) => year.startYear == activeYear,
      orElse: () => EducationYear(startYear: activeYear),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: PopupMenuButton<int>(
        key: const Key('education_year_selector'),
        tooltip: 'Eğitim Öğretim Yılı',
        color: AppColors.surface,
        position: PopupMenuPosition.under,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final year in years)
            PopupMenuItem<int>(
              key: Key('education_year_option_${year.startYear}'),
              value: year.startYear,
              child: Row(
                children: [
                  Icon(
                    year.startYear == activeYear
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: year.startYear == activeYear
                        ? AppColors.primary
                        : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    year.label,
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontWeight: year.startYear == activeYear
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.sidebarHover.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.softMagenta.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.school_outlined,
                size: 18,
                color: AppColors.softMagenta,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Eğitim Öğretim Yılı',
                      style: TextStyle(
                        color: AppColors.softMagenta.withValues(alpha: 0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      active.label,
                      style: const TextStyle(
                        color: AppColors.surface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
