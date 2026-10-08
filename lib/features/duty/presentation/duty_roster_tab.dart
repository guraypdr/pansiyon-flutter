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
    final days = dutyMonthDates(
      year,
      month,
    ).where((date) => !settings.blackouts.contains(dutyDateKey(date))).length;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final counts = dutyTeacherDutyCounts(
          assignments: assignments,
          teachers: teachers,
        );

        // Geniş ekranda liste solda, nöbet dağılımı kartı sağda durur.
        // Dar alanda kart listenin altına iner.
        final sideBySide = constraints.maxWidth >= minSidePanelWidth;

        final list = ListView(
          padding: EdgeInsets.fromLTRB(20, 14, sideBySide ? 10 : 20, 20),
          children: _buildContent(
            dates: dates,
            weekDays: weekDays,
            byDate: byDate,
            slotsPerDay: slotsPerDay,
            locations: locations,
          ),
        );

        final panel = _DutyCountPanel(
          counts: counts,
          emptySlotCount: _emptySlotCount,
        );

        if (!sideBySide) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            children: [
              ..._buildContent(
                dates: dates,
                weekDays: weekDays,
                byDate: byDate,
                slotsPerDay: slotsPerDay,
                locations: locations,
              ),
              const SizedBox(height: 8),
              panel,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: list),
            SizedBox(
              width: sidePanelWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 20, 20),
                child: panel,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildContent({
    required List<DateTime> dates,
    required List<List<DateTime>> weekDays,
    required Map<DateTime, List<int>> byDate,
    required int slotsPerDay,
    required String locations,
  }) {
    return [
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
      for (var weekIndex = 0; weekIndex < weekDays.length; weekIndex++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _DutyWeekCard(
            weekNumber: weekIndex + 1,
            dates: weekDays[weekIndex],
            byDate: byDate,
            slotsPerDay: slotsPerDay,
            assignments: assignments,
            teachers: teachers,
            settings: settings,
            onChanged: onAssignmentChanged,
            onRemoved: onAssignmentRemoved,
          ),
        ),
    ];
  }

  /// Haftanın ilk günü (pazartesi).
  static DateTime _weekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  /// Yan panelin genişliği.
  static const double sidePanelWidth = 300;

  /// Yan panelin yan yana görünebileceği en dar liste genişliği.
  static const double minSidePanelWidth = 900;
}

/// Bir öğretmenin nöbet sayısı.
class DutyTeacherCount {
  const DutyTeacherCount({
    required this.teacherId,
    required this.fullName,
    required this.count,
  });

  final int teacherId;
  final String fullName;
  final int count;
}

/// Her öğretmenin nöbet sayısını hesaplar.
///
/// Nöbeti olmayan öğretmenler de sonuca sıfır olarak dahil edilir; liste
/// önce nöbet sayısına, sonra ada göre sıralanır.
List<DutyTeacherCount> dutyTeacherDutyCounts({
  required List<DutyAssignment> assignments,
  required List<DutyTeacher> teachers,
}) {
  final counts = <int, int>{};
  for (final assignment in assignments) {
    final id = assignment.teacherId;
    counts[id] = (counts[id] ?? 0) + 1;
  }

  final result =
      [
        for (final teacher in teachers)
          if (teacher.id case final id?)
            DutyTeacherCount(
              teacherId: id,
              fullName: teacher.fullName,
              count: counts[id] ?? 0,
            ),
      ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.fullName.compareTo(b.fullName);
      });

  return result;
}

/// Ekranın sağında duran "kim kaç nöbet yaptı" kartı.
///
/// Öğretmenler nöbet sayısına göre azalan sırada listelenir; en çok nöbet
/// yapan öğretmen en üstte görünür.
class _DutyCountPanel extends StatelessWidget {
  const _DutyCountPanel({required this.counts, required this.emptySlotCount});

  final List<DutyTeacherCount> counts;

  /// Doldurulmamış yuva sayısı; panelin altında uyarı olarak gösterilir.
  final int emptySlotCount;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.fold<int>(0, (max, item) {
      return item.count > max ? item.count : max;
    });
    final total = counts.fold<int>(0, (sum, item) => sum + item.count);

    return Container(
      key: const ValueKey('duty_count_panel'),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(
                  Icons.leaderboard_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'NÖBET DAĞILIMI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  '$total nöbet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: counts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Öğretmen bulunamadı',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    itemCount: counts.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.inputBorder,
                    ),
                    itemBuilder: (context, index) {
                      final item = counts[index];
                      return _DutyCountRow(
                        rank: index + 1,
                        item: item,
                        maxCount: maxCount,
                      );
                    },
                  ),
          ),
          if (emptySlotCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              color: AppColors.lavender.withValues(alpha: 0.14),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$emptySlotCount yuva henüz boş',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

/// Panelde tek bir öğretmenin satırı: sıra, ad, nöbet sayısı ve oransal çubuk.
class _DutyCountRow extends StatelessWidget {
  const _DutyCountRow({
    required this.rank,
    required this.item,
    required this.maxCount,
  });

  final int rank;
  final DutyTeacherCount item;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final hasDuty = item.count > 0;
    final ratio = maxCount == 0 ? 0.0 : item.count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasDuty
                        ? AppColors.darkText
                        : AppColors.secondaryText,
                    fontSize: 12.5,
                    fontWeight: hasDuty ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: hasDuty
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.inputBorder.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.count}',
                  style: TextStyle(
                    color: hasDuty
                        ? AppColors.primaryDark
                        : AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: AppColors.inputBorder.withValues(alpha: 0.35),
                valueColor: AlwaysStoppedAnimation(
                  hasDuty
                      ? AppColors.primary.withValues(alpha: 0.75)
                      : AppColors.transparent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir haftanın tüm nöbetlerini tek kartta toplar.
///
/// Kartın üstünde boydan boya koyu bir başlık çubuğu, altında gün satırları
/// vardır. Her satırda solda tarih etiketi, sağda "N. Kat: Öğretmen" biçiminde
/// nöbetçiler yer alır.
class _DutyWeekCard extends StatelessWidget {
  const _DutyWeekCard({
    required this.weekNumber,
    required this.dates,
    required this.byDate,
    required this.slotsPerDay,
    required this.assignments,
    required this.teachers,
    required this.settings,
    required this.onChanged,
    required this.onRemoved,
  });

  final int weekNumber;
  final List<DateTime> dates;
  final Map<DateTime, List<int>> byDate;
  final int slotsPerDay;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final DutySettings settings;
  final void Function(int index, DutyAssignment value) onChanged;
  final void Function(int index) onRemoved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DutyWeekHeader(weekNumber: weekNumber),
          for (var index = 0; index < dates.length; index++)
            _DutyDayRow(
              date: dates[index],
              indexes: byDate[dates[index]] ?? const [],
              slotsPerDay: slotsPerDay,
              assignments: assignments,
              teachers: teachers,
              settings: settings,
              showDivider: index < dates.length - 1,
              onChanged: onChanged,
              onRemoved: onRemoved,
            ),
        ],
      ),
    );
  }
}

/// Tek günün satırı: solda tarih etiketi, sağda nöbetçi yuvaları.
///
/// Yuvalar "N. Kat: Öğretmen" biçiminde tek satırda yazılır; nöbet yeri
/// öğretmen adının önünde yer alır.
class _DutyDayRow extends StatelessWidget {
  const _DutyDayRow({
    required this.date,
    required this.indexes,
    required this.slotsPerDay,
    required this.assignments,
    required this.teachers,
    required this.settings,
    required this.showDivider,
    required this.onChanged,
    required this.onRemoved,
  });

  final DateTime date;
  final List<int> indexes;
  final int slotsPerDay;
  final List<DutyAssignment> assignments;
  final List<DutyTeacher> teachers;
  final DutySettings settings;

  /// Satırın altına ince ayraç çizgisi çizilir.
  final bool showDivider;
  final void Function(int index, DutyAssignment value) onChanged;
  final void Function(int index) onRemoved;

  static const double _dateColumnWidth = 132;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('duty_day_${date.day}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.inputBorder))
            : null,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _dateColumnWidth,
              child: _DateBadge(date: date),
            ),
            for (var slot = 0; slot < slotsPerDay; slot++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: indexes.length > slot
                      ? _DutyTeacherSlot(
                          key: ValueKey(
                            'duty_slot_${date.day}_${indexes[slot]}',
                          ),
                          assignment: assignments[indexes[slot]],
                          slot: slot,
                          locationLabel: settings.locationForSlot(slot),
                          teachers: teachers,
                          onChanged: (value) => onChanged(indexes[slot], value),
                          onRemove: () => onRemoved(indexes[slot]),
                        )
                      : _DutyEmptySlot(
                          key: ValueKey('duty_slot_empty_${date.day}_$slot'),
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
    );
  }
}

/// Tarih etiketi: "14 Eylül Paz" biçiminde tek satır.
class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.inputBorder.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '${date.day} ${dutyMonthName(date.month)} ${dutyWeekdayShortLabel(date.weekday)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.darkText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Dolu yuva: "N. Kat: Öğretmen" tek satırı.
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

  /// Yuva sırası; anahtar için kullanılır.
  final int slot;

  /// Bu yuvanın nöbet yeri; öğretmen adının önünde yazılır.
  final String locationLabel;
  final List<DutyTeacher> teachers;
  final ValueChanged<DutyAssignment> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final keySuffix = '${assignment.id ?? '${assignment.date.day}_$slot'}';
    final location = assignment.location?.trim().isNotEmpty == true
        ? assignment.location!.trim()
        : locationLabel.trim();

    return Row(
      children: [
        // Etiket dar ekranda küçülebilir; taşmaya yol açmasın.
        Flexible(child: DutyLocationLabel(text: location)),
        Expanded(
          child: AppInlineDropdown<int>(
            key: Key('duty_assignment_$keySuffix'),
            // Açılır liste tüm ekranı kaplamasın.
            maxWidth: 230,
            value: teachers.any((item) => item.id == assignment.teacherId)
                ? assignment.teacherId
                : null,
            fontSize: 13,
            hint: 'Seçiniz',
            textStyle: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.close,
            size: 14,
            color: AppColors.secondaryText.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Boş yuva: "N. Kat: seçiniz" tek satırı.
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

  /// Bu yuvanın nöbet yeri; seçicinin önünde yazılır.
  final String locationLabel;
  final List<DutyTeacher> teachers;
  final DateTime date;
  final void Function(DutyAssignment value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Etiket dar ekranda küçülebilir; taşmaya yol açmasın.
        Flexible(child: DutyLocationLabel(text: locationLabel)),
        Expanded(
          child: AppInlineDropdown<int>(
            key: Key('duty_slot_pick_${date.day}_$slot'),
            // Açılır liste tüm ekranı kaplamasın.
            maxWidth: 230,
            value: null,
            fontSize: 13,
            hint: 'seçiniz',
            textStyle: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
                    location: locationLabel.trim().isEmpty
                        ? null
                        : locationLabel.trim(),
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
