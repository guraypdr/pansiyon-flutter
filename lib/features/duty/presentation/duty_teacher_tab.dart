import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';

class DutyTeacherTab extends StatelessWidget {
  const DutyTeacherTab({
    super.key,
    required this.teachers,
    required this.monthOffTeacherIds,
    required this.canToggleMonth,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleMonth,
  });

  final List<DutyTeacher> teachers;
  final Set<int> monthOffTeacherIds;
  final bool canToggleMonth;
  final ValueChanged<DutyTeacher> onEdit;
  final ValueChanged<DutyTeacher> onDelete;
  final ValueChanged<DutyTeacher> onToggleMonth;

  @override
  Widget build(BuildContext context) {
    if (teachers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 46, color: AppColors.lavender),
            SizedBox(height: 12),
            Text(
              'Öğretmen kayıtlı değil',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Öğretmen Ekle ya da Excel ile toplu yükleme yapın.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: teachers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final teacher = teachers[index];
        final isOff = monthOffTeacherIds.contains(teacher.id);
        return _DutyTeacherCard(
          teacher: teacher,
          isInactiveForMonth: isOff,
          canToggleMonth: canToggleMonth,
          onEdit: () => onEdit(teacher),
          onDelete: () => onDelete(teacher),
          onToggleMonth: () => onToggleMonth(teacher),
        );
      },
    );
  }
}

class _DutyTeacherCard extends StatelessWidget {
  const _DutyTeacherCard({
    required this.teacher,
    required this.isInactiveForMonth,
    required this.canToggleMonth,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleMonth,
  });

  final DutyTeacher teacher;
  final bool isInactiveForMonth;
  final bool canToggleMonth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('duty_teacher_card_${teacher.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: dutyTeacherFill(teacher.id),
            child: Text(
              dutyTeacherInitials(teacher.fullName),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        teacher.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!teacher.hasDutyTraining) ...[
                      const SizedBox(width: 8),
                      const _DutyChip(
                        label: 'Eğitim yok',
                        color: AppColors.errorFeedback,
                      ),
                    ],
                    if (isInactiveForMonth) ...[
                      const SizedBox(width: 8),
                      const _DutyChip(
                        label: 'Bu ay pasif',
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    teacher.school,
                    teacher.branch,
                    'Tel: ${teacher.phone ?? '-'}',
                    teacher.nationalId == null ? null : 'TC: ${teacher.nationalId}',
                    'Nöbet: ${teacher.dutyPreference.label}',
                    teacher.availableWeekdayLabel,
                  ].whereType<String>().join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (canToggleMonth)
            Tooltip(
              message: isInactiveForMonth
                  ? 'Bu ay için görevlendir'
                  : 'Bu ay için pasif yap',
              child: IconButton(
                key: Key('duty_teacher_month_toggle_${teacher.id}'),
                onPressed: onToggleMonth,
                icon: Icon(
                  isInactiveForMonth
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  size: 20,
                ),
              ),
            ),
          IconButton(
            key: Key('duty_teacher_edit_${teacher.id}'),
            onPressed: onEdit,
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            key: Key('duty_teacher_delete_${teacher.id}'),
            onPressed: onDelete,
            tooltip: 'Sil',
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.errorFeedback,
            ),
          ),
        ],
      ),
    );
  }
}

class _DutyChip extends StatelessWidget {
  const _DutyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
