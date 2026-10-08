import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';

/// Aylık nöbet listesi: haftalık gruplanmış, her gün 2 veya 3 nöbetçi yuvası.
///
/// Görünüm İstatistikler sekmesiyle aynı dili kullanır: özet kutuları, hafta
/// başlığı ve iç içe kenarlıklı tablo satırları. Her hücre sabit yükseklikte
/// ve esner; nöbet yeri etiketi kırılır, bu yüzden dar pencerede taşma olmaz.
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

  /// Boş bırakılmış yuva sayısı; başlıkta uyarı olarak gösterilir.
  int get _emptySlotCount {
    final days = dutyMonthDates(year, month).where(
      (date) => !settings.blackouts.contains(dutyDateKey(date)),
    ).length;
    final slotsPerDay = settings.dailyCount < 2 ? 2 : settings.dailyCount;
    final total = days * slotsPerDay;
    final remaining = total - assignments.length;
    return remaining < 0 ? 0 : remaining;
  }

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

    // Haftalar aya göre gruplanır; numaralandırma ayın 1. gününe göre
    // 1'den başlar, takvimdeki ISO hafta numarası kullanılmaz.
    final weekDays = <List<DateTime>>[];
    DateTime? lastWeekStart;
    for (final date in dates) {
      final weekStart = _weekStart(date);
      if (lastWeekStart == null || weekStart != lastWeekStart) {
        weekDays.add([date]);
        lastWeekStart = weekStart;
      } else {
        weekDays.last.add(date);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        DutyStatTileWrap(
          tiles: [
            DutyStatTile(
              label: 'Nöbet günü',
              value: '${dates.length}',
              detail: 'kapalı günler hariç',
              color: AppColors.primary,
              icon: Icons.calendar_month_outlined,
            ),
            DutyStatTile(
              label: 'Günlük nöbetçi',
              value: '$slotsPerDay',
              detail: 'gün başına yuva',
              color: AppColors.secondary,
              icon: Icons.groups_outlined,
            ),
            DutyStatTile(
              label: 'Toplam nöbet',
              value: '${assignments.length}',
              detail: _emptySlotCount == 0
                  ? 'tüm yuvalar dolu'
                  : '$_emptySlotCount yuva boş',
              color: _emptySlotCount == 0
                  ? AppColors.successFeedback
                  : AppColors.lavender,
              icon: Icons.event_available_outlined,
            ),
            DutyStatTile(
              label: 'Nöbet yerleri',
              value: '${settings.locationsForSlots(settings.dailyCount).length}',
              detail: locations.isEmpty ? 'Seçilmedi' : locations,
              color: AppColors.lavender,
              icon: Icons.place_outlined,
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var weekIndex = 0; weekIndex < weekDays.length; weekIndex++) ...[
          // Hafta numarası ay içinde 1'den başlar.
          DutyWeekHeader(weekNumber: weekIndex + 1),
          for (var index = 0; index < weekDays[weekIndex].length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DutyDayRow(
                date: weekDays[weekIndex][index],
                indexes: byDate[weekDays[weekIndex][index]] ?? const [],
                slotsPerDay: slotsPerDay,
                assignments: assignments,
                teachers: teachers,
                settings: settings,
                striped: index.isOdd,
                onChanged: onAssignmentChanged,
                onRemoved: onAssignmentRemoved,
              ),
            ),
        ],
      ],
    );
  }

  /// Haftanın ilk günü (pazartesi). Ayın 1'i pazartesiden başlıyorsa
  /// bu hafta 1. haftadır; değilse ayın 1'inden itibaren yeni hafta başlar.
  static DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));
}

/// Tek günün satırı: tarih hücresi + nöbetçi yuvaları.
///
/// Tüm hücreler aynı yükseklikte ve ortak kenarlıklarla çizilir; böylece
/// günler arasında hizalama kayması olmaz. İç içe kart yerine düz bir
/// tablo satırı kullanılır.
class _DutyDayRow extends StatelessWidget {
  const _DutyDayRow({
    required this.date,
    required this.indexes,
    required this.slotsPerDay,
    required this.assignments,
    required this.teachers,
    required this.settings,
    required this.striped,
    required this.onChanged,
    required this.onRemoved,
  });

  final DateTime date;
  final List<int> indexes;
  final int slotsPerDay;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final DutySettings settings;
  final bool striped;
  final void Function(int index, DutyAssignment value) onChanged;
  final void Function(int index) onRemoved;

  static const double _rowHeight = 56;
  static const double _dateWidth = 66;

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday >= DateTime.saturday;
    final isToday = _isSameDay(date, DateTime.now());
    final background = isWeekend
        ? AppColors.softMagenta.withValues(alpha: 0.16)
        : striped
        ? AppColors.cardSurface.withValues(alpha: 0.5)
        : Colors.transparent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border.all(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.55)
                : AppColors.inputBorder,
            width: isToday ? 1.5 : 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowHeight),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              _cell(
                width: _dateWidth,
                background: isToday
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dutyWeekdayShortLabel(date.weekday),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isWeekend
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              for (var slot = 0; slot < slotsPerDay; slot++)
                Expanded(
                  child: _cell(
                    borderLeft: true,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ortak kenarlıklı hücre.
  Widget _cell({
    required Widget child,
    double? width,
    Color? background,
    bool borderLeft = false,
  }) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: _rowHeight),
      decoration: BoxDecoration(
        color: background,
        border: borderLeft
            ? const Border(left: BorderSide(color: AppColors.inputBorder))
            : null,
      ),
      child: child,
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Dolu yuva: öğretmen açılır listesi ve nöbet yeri.
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
    final keySuffix =
        '${assignment.id ?? '${assignment.date.day}_$slot'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Nöbet yeri açılır listenin dışında, sabit bir başlık olarak durur.
        _LocationLabel(text: location),
        const SizedBox(height: 3),
        // Açılır liste kutusu: yalnızca yumuşak zemin, çevresinde çizgi yok.
        Container(
          padding: const EdgeInsets.fromLTRB(8, 0, 2, 0),
          decoration: BoxDecoration(
            color: dutyTeacherFill(assignment.teacherId),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: AppInlineDropdown<int>(
                  key: Key('duty_assignment_$keySuffix'),
                  value: teachers.any(
                    (item) => item.id == assignment.teacherId,
                  )
                      ? assignment.teacherId
                      : null,
                  fontSize: 12,
                  hint: 'Seçiniz',
                  textStyle: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                key: Key('duty_assignment_remove_$keySuffix'),
                onPressed: onRemove,
                tooltip: 'Nöbeti kaldır',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.secondaryText.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Boş yuva: öğretmen seçilebilir.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Boş yuvada da nöbet yeri açılır listenin dışında sabit başlıktır.
        _LocationLabel(text: locationLabel, muted: true),
        const SizedBox(height: 3),
        // Açılır listenin çevresinde çizgi yok; yalnızca soluk zemin.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AppInlineDropdown<int>(
            key: Key('duty_slot_pick_${date.day}_$slot'),
            value: null,
            fontSize: 12,
            hint: '${slot + 1}. nöbetçi seçin',
            textStyle: const TextStyle(
              color: AppColors.secondaryText,
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
    );
  }
}

/// Nöbet yeri etiketi.
///
/// Açılır listenin dışında sabit başlık olarak durur. Genişliği sınırlı
/// değildir; `Expanded` içinde kırpılır. Önceden sabit 76px genişlikteydi
/// ve dar pencerede yuvayı taşırıyordu.
class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.text, this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    final color = !hasText
        ? AppColors.secondaryText
        : muted
        ? AppColors.secondaryText
        : AppColors.primaryDark;
    final icon = !hasText
        ? Icons.place_outlined
        : muted
        ? Icons.place_outlined
        : Icons.place;

    return Tooltip(
      message: hasText ? text : 'Nöbet yeri seçilmedi',
      child: Row(
        children: [
          Icon(icon, size: 11, color: muted ? color : AppColors.primary),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              hasText ? text : 'yer yok',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.1,
                color: color,
                fontWeight: hasText && !muted
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}