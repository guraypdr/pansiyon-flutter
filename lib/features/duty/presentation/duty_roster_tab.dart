import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

/// Aylık nöbet listesi ayrıntısı: gün başına 2 veya 3 nöbetçi yan yana.
class DutyRosterTab extends StatelessWidget {
  const DutyRosterTab({
    super.key,
    required this.year,
    required this.month,
    required this.sectionLabel,
    required this.settings,
    required this.assignments,
    required this.teachers,
    required this.onAssignmentChanged,
    required this.onAssignmentRemoved,
    required this.onAddAssignment,
  });

  final int year;
  final int month;
  final String sectionLabel;
  final DutySettings settings;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final void Function(int index, DutyAssignment value) onAssignmentChanged;
  final void Function(int index) onAssignmentRemoved;
  final void Function(DateTime date) onAddAssignment;

  @override
  Widget build(BuildContext context) {
    final byDate = <DateTime, List<int>>{};
    for (var index = 0; index < assignments.length; index++) {
      byDate
          .putIfAbsent(assignments[index].date, () => [])
          .add(index);
    }
    final dates = byDate.keys.toList()..sort();
    final blackoutKeys = settings.blackouts;
    final slotsPerDay = settings.dailyCount < 2 ? 2 : settings.dailyCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        Row(
          children: [
            Text(
              'Günlük ${settings.dailyCount} nöbetçi • '
              '${blackoutKeys.where((key) => key.startsWith('$year-')).length} kapalı gün',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (settings.locations.isNotEmpty)
              Text(
                'Nöbet yerleri: ${settings.locations.join(', ')}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (dates.isEmpty)
          const _RosterEmpty()
        else
          for (final date in dates)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:                 _DutyDayRow(
                date: date,
                indexes: byDate[date]!,
                slotsPerDay: slotsPerDay,
                assignments: assignments,
                teachers: teachers,
                onChanged: onAssignmentChanged,
                onRemoved: onAssignmentRemoved,
                onAdd: () => onAddAssignment(date),
              ),
            ),
        const SizedBox(height: 6),
        for (final date in dutyMonthDates(year, month))
          if (!byDate.containsKey(date) && !blackoutKeys.contains(dutyDateKey(date)))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DutyEmptyDayRow(
                date: date,
                onAdd: () => onAddAssignment(date),
              ),
            ),
      ],
    );
  }
}

class _DutyDayRow extends StatelessWidget {
  const _DutyDayRow({
    required this.date,
    required this.indexes,
    required this.slotsPerDay,
    required this.assignments,
    required this.teachers,
    required this.onChanged,
    required this.onRemoved,
    required this.onAdd,
  });

  final DateTime date;
  final List<int> indexes;
  final int slotsPerDay;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final void Function(int index, DutyAssignment value) onChanged;
  final void Function(int index) onRemoved;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dutyWeekdayShortLabel(date.weekday),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  dutyShortDate(date),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: Key('duty_add_for_${date.day}'),
                    onPressed: onAdd,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      'nöbetçi',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var slot = 0; slot < slotsPerDay; slot++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: indexes.length > slot
                          ? _DutyTeacherSlot(
                              assignment: assignments[indexes[slot]],
                              teachers: teachers,
                              onChanged: (value) =>
                                  onChanged(indexes[slot], value),
                              onRemove: () => onRemoved(indexes[slot]),
                            )
                          : const _DutyEmptySlot(),
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

class _DutyTeacherSlot extends StatelessWidget {
  const _DutyTeacherSlot({
    required this.assignment,
    required this.teachers,
    required this.onChanged,
    required this.onRemove,
  });

  final DutyAssignment assignment;
  final List<DutyTeacher> teachers;
  final ValueChanged<DutyAssignment> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: dutyTeacherFill(assignment.teacherId),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dutyTeacherBorder(assignment.teacherId)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int>(
              key: Key(
                'duty_assignment_${assignment.id ?? assignment.date.day}_${assignment.teacherId}',
              ),
              value: teachers.any((item) => item.id == assignment.teacherId)
                  ? assignment.teacherId
                  : null,
              isExpanded: true,
              isDense: true,
              hint: const Text('Seçiniz'),
              underline: const SizedBox.shrink(),
              items: [
                for (final teacher in teachers)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      teacher.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onChanged(
                    DutyAssignment(
                      id: assignment.id,
                      year: assignment.year,
                      month: assignment.month,
                      date: assignment.date,
                      teacherId: value,
                      location: assignment.location,
                    ),
                  );
                }
              },
            ),
          ),
          IconButton(
            key: Key(
              'duty_assignment_remove_${assignment.id ?? assignment.date.day}_${assignment.teacherId}',
            ),
            onPressed: onRemove,
            tooltip: 'Nöbeti kaldır',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 15),
          ),
        ],
      ),
    );
  }
}

class _DutyEmptySlot extends StatelessWidget {
  const _DutyEmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.inputBorder,
        ),
      ),
    );
  }
}

class _DutyEmptyDayRow extends StatelessWidget {
  const _DutyEmptyDayRow({required this.date, required this.onAdd});

  final DateTime date;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('duty_empty_day_${date.day}'),
      onTap: onAdd,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.inputBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '${dutyWeekdayShortLabel(date.weekday)} ${dutyShortDate(date)}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.5,
                ),
              ),
            ),
            const Text(
              'Nöbetçi atanmadı - tıklayarak ekleyin',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterEmpty extends StatelessWidget {
  const _RosterEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(
            Icons.event_note_outlined,
            size: 46,
            color: AppColors.lavender,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu ay için nöbet yazılmadı',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Otomatik Dağıt butonuyla nöbetleri oluşturabilirsiniz.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

void showDutyInfoMessage(BuildContext context, String message) {
  AppNotifier.instance.show(
    context,
    message: message,
    tone: AppNotificationTone.info,
  );
}
