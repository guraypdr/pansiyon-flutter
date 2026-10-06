import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';

/// Aylık nöbet listesi: haftalık gruplanmış, her gün 2 veya 3 nöbetçi yuvası.
class DutyRosterTab extends StatelessWidget {
  const DutyRosterTab({
    super.key,
    required this.year,
    required this.month,
    required this.settings,
    required this.assignments,
    required this.teachers,
    required this.onAssignmentChanged,
    required this.onAssignmentRemoved,
  });

  final int year;
  final int month;
  final DutySettings settings;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final void Function(int index, DutyAssignment value) onAssignmentChanged;
  final void Function(int index) onAssignmentRemoved;

  @override
  Widget build(BuildContext context) {
    final byDate = <DateTime, List<int>>{};
    for (var index = 0; index < assignments.length; index++) {
      byDate.putIfAbsent(assignments[index].date, () => []).add(index);
    }
    final slotsPerDay = settings.dailyCount < 2 ? 2 : settings.dailyCount;
    final dates = [
      for (final date in dutyMonthDates(year, month))
        if (!settings.blackouts.contains(dutyDateKey(date))) date,
    ];
    final locations = settings
        .locationsForSlots(settings.dailyCount)
        .where((item) => item.isNotEmpty)
        .join(' • ');

    final weeks = <DateTime, List<DateTime>>{};
    for (final date in dates) {
      weeks.putIfAbsent(_weekStart(date), () => []).add(date);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _RosterSummary(
          dayCount: dates.length,
          dailyCount: settings.dailyCount,
          totalDuty: assignments.length,
          locations: locations,
        ),
        const SizedBox(height: 12),
        for (final week in weeks.entries) ...[
          _WeekHeader(
            label: '${_weekNumber(week.value.first)}. Hafta',
            range:
                '${week.value.first.day} ${dutyMonthName(week.value.first.month)}'
                ' - ${week.value.last.day} ${dutyMonthName(week.value.last.month)}',
            count: '${week.value.length} gün',
          ),
          const SizedBox(height: 6),
          for (final date in week.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DutyDayRow(
                date: date,
                indexes: byDate[date] ?? const [],
                slotsPerDay: slotsPerDay,
                assignments: assignments,
                teachers: teachers,
                settings: settings,
                onChanged: onAssignmentChanged,
                onRemoved: onAssignmentRemoved,
              ),
            ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  static DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  static int _weekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstOfYear = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstOfYear).inDays) / 7).floor() + 1;
  }
}

class _RosterSummary extends StatelessWidget {
  const _RosterSummary({
    required this.dayCount,
    required this.dailyCount,
    required this.totalDuty,
    required this.locations,
  });

  final int dayCount;
  final int dailyCount;
  final int totalDuty;
  final String locations;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, String value, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          item('Nöbet günü', '$dayCount'),
          item('Günlük nöbetçi', '$dailyCount'),
          item('Toplam nöbet', '$totalDuty'),
          item(
            'Nöbet yerleri',
            locations.isEmpty ? 'Seçilmedi' : locations,
            flex: 3,
          ),
        ],
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.label,
    required this.range,
    required this.count,
  });

  final String label;
  final String range;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            range,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            count,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
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
    required this.settings,
    required this.onChanged,
    required this.onRemoved,
  });

  final DateTime date;
  final List<int> indexes;
  final int slotsPerDay;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final DutySettings settings;
  final void Function(int index, DutyAssignment value) onChanged;
  final void Function(int index) onRemoved;

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday >= DateTime.saturday;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWeekend
            ? AppColors.surfaceContainerHighest.withValues(alpha: 0.35)
            : AppColors.cardSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWeekend
              ? AppColors.errorFeedback.withValues(alpha: 0.25)
              : AppColors.inputBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dutyWeekdayShortLabel(date.weekday),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isWeekend
                        ? AppColors.errorFeedback
                        : AppColors.primaryDark,
                  ),
                ),
                Text(
                  '${date.day} ${dutyMonthName(date.month)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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
                      padding: EdgeInsets.only(
                        right: slot == slotsPerDay - 1 ? 0 : 8,
                      ),
                      child: indexes.length > slot
                          ? _DutyTeacherSlot(
                              key: ValueKey(
                                'duty_slot_${date.day}_${indexes[slot]}',
                              ),
                              assignment: assignments[indexes[slot]],
                              slot: slot,
                              locationLabel: settings.locationForSlot(slot),
                              teachers: teachers,
                              onChanged: (value) =>
                                  onChanged(indexes[slot], value),
                              onRemove: () => onRemoved(indexes[slot]),
                            )
                          : _DutyEmptySlot(
                              key: ValueKey(
                                'duty_slot_empty_${date.day}_$slot',
                              ),
                              slot: slot,
                              locationLabel: settings.locationForSlot(slot),
                              teachers: teachers,
                              date: date,
                              onChanged: (value) => onChanged(-1, value),
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

class _DutyTeacherSlot extends StatelessWidget {
  const _DutyTeacherSlot({
    super.key,
    required this.assignment,
    required this.slot,
    required this.locationLabel,
    required this.teachers,
    required this.onChanged,
    required this.onRemove,
  });

  final DutyAssignment assignment;
  final int slot;
  final String locationLabel;
  final List<DutyTeacher> teachers;
  final ValueChanged<DutyAssignment> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final location = assignment.location?.isNotEmpty == true
        ? assignment.location!
        : locationLabel;
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
      decoration: BoxDecoration(
        color: dutyTeacherFill(assignment.teacherId),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dutyTeacherBorder(assignment.teacherId)),
      ),
      child: Row(
        children: [
          _LocationLabel(text: location),
          const SizedBox(width: 6),
          Expanded(
            child: AppInlineDropdown<int>(
              key: Key(
                'duty_assignment_${assignment.id ?? '${assignment.date.day}_$slot'}',
              ),
              value: teachers.any((item) => item.id == assignment.teacherId)
                  ? assignment.teacherId
                  : null,
              fontSize: 12,
              hint: 'Seçiniz',
              textStyle: const TextStyle(
                color: AppColors.darkText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final teacher in teachers)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      teacher.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 12,
                      ),
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
              'duty_assignment_remove_${assignment.id ?? '${assignment.date.day}_$slot'}',
            ),
            onPressed: onRemove,
            tooltip: 'Nöbeti kaldır',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.close,
              size: 14,
              color: AppColors.secondaryText.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _DutyEmptySlot extends StatelessWidget {
  const _DutyEmptySlot({
    super.key,
    required this.slot,
    required this.locationLabel,
    required this.teachers,
    required this.date,
    required this.onChanged,
  });

  final int slot;
  final String locationLabel;
  final List<DutyTeacher> teachers;
  final DateTime date;
  final void Function(DutyAssignment value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          _LocationLabel(text: locationLabel),
          const SizedBox(width: 6),
          Expanded(
            child: AppInlineDropdown<int>(
              key: Key('duty_slot_pick_${date.day}_$slot'),
              value: null,
              fontSize: 12,
              hint: '${slot + 1}. nöbetçi seçin',
              items: [
                for (final teacher in teachers)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      teacher.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onChanged(
                    DutyAssignment(
                      year: date.year,
                      month: date.month,
                      date: date,
                      teacherId: value,
                      location: locationLabel.isEmpty ? null : locationLabel,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    return Tooltip(
      message: hasText ? text : 'Nöbet yeri seçilmedi',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasText ? Icons.place : Icons.place_outlined,
            size: 12,
            color: hasText ? AppColors.primary : AppColors.secondaryText,
          ),
          const SizedBox(width: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Text(
              hasText ? text : 'yer yok',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.1,
                color: hasText
                    ? AppColors.primaryDark
                    : AppColors.secondaryText,
                fontWeight: hasText ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
