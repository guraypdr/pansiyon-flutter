import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';

/// Nöbet istatistikleri: eklenen öğretmenler ve aylık nöbet dağılımı.
class DutyStatsTab extends StatelessWidget {
  const DutyStatsTab({
    super.key,
    required this.teachers,
    required this.lists,
    required this.assignments,
    required this.year,
    required this.perTeacherMonth,
  });

  final List<DutyTeacher> teachers;
  final List<DutyMonthList> lists;
  final List<DutyAssignment> assignments;
  final int year;

  /// Öğretmen id -> ay -> nöbet sayısı
  final Map<int, Map<int, int>> perTeacherMonth;

  @override
  Widget build(BuildContext context) {
    final yearLists = lists.where((item) => item.year == year).toList();
    final yearTotal = yearLists.fold<int>(
      0,
      (sum, item) => sum + item.assignmentCount,
    );
    final activeTeachers = teachers.where((teacher) => teacher.isActive).length;
    final monthlyAverage = yearLists.isEmpty
        ? 0
        : yearTotal ~/ yearLists.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Eklenen öğretmen',
                value: '${teachers.length}',
                detail: '$activeTeachers aktif',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: '$year yılı nöbet',
                value: '$yearTotal',
                detail: '${yearLists.length} liste',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Liste başına ortalama',
                value: '$monthlyAverage',
                detail: 'nöbet',
                color: AppColors.lavender,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Bu ayki nöbet',
                value: '${assignments.length}',
                detail: 'seçili liste',
                color: AppColors.successFeedback,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StatsSection(
          title: 'Aylık nöbet dağılımı',
          subtitle: '$year yılında oluşturulan listeler',
          child: _MonthlyChart(lists: yearLists),
        ),
        const SizedBox(height: 12),
        _StatsSection(
          title: 'Öğretmen bazında aylık nöbetler',
          subtitle: 'Liste oluşturulan aylar ve toplam nöbet',
          child: _TeacherChart(
            teachers: teachers,
            perTeacherMonth: perTeacherMonth,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.lists});

  final List<DutyMonthList> lists;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return const _StatsEmpty();
    }
    final counts = <int, int>{};
    for (final list in lists) {
      counts[list.month] = (counts[list.month] ?? 0) + list.assignmentCount;
    }
    final maxValue = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final months = counts.keys.toList()..sort();

    return Column(
      children: [
        for (final month in months)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    dutyMonthName(month),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: maxValue == 0 ? 0 : counts[month]! / maxValue,
                      minHeight: 16,
                      backgroundColor: AppColors.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.primary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${counts[month]}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TeacherChart extends StatelessWidget {
  const _TeacherChart({required this.teachers, required this.perTeacherMonth});

  final List<DutyTeacher> teachers;

  /// Öğretmen id -> ay -> nöbet sayısı
  final Map<int, Map<int, int>> perTeacherMonth;

  @override
  Widget build(BuildContext context) {
    if (teachers.isEmpty) {
      return const _StatsEmpty();
    }
    final months = <int>{
      for (final counts in perTeacherMonth.values) ...counts.keys,
    }.toList()..sort();
    var maxValue = 1;
    for (final counts in perTeacherMonth.values) {
      for (final value in counts.values) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              children: [
                const SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      'Öğretmen',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
                for (final teacher in teachers)
                  SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: dutyTeacherFill(teacher.id),
                          child: Text(
                            dutyTeacherInitials(teacher.fullName),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            teacher.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          for (final month in months) ...[
            SizedBox(
              width: 66,
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Center(
                    child: Text(
                      dutyMonthName(month).substring(0, 3),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                  for (final teacher in teachers)
                    SizedBox(
                      height: 46,
                      child: Center(
                        child: Text(
                          '${(perTeacherMonth[teacher.id] ?? const {})[month] ?? 0}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: 78,
            child: Column(
              children: [
                const SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      'Toplam',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
                for (final teacher in teachers)
                  SizedBox(
                    height: 46,
                    child: Center(
                      child: Text(
                        '${(perTeacherMonth[teacher.id] ?? const {}).values.fold<int>(0, (a, b) => a + b)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsEmpty extends StatelessWidget {
  const _StatsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          'Gösterilecek veri yok',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
        ),
      ),
    );
  }
}
