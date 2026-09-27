import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

/// Bölüm bazında ortak nöbet ayarları ve takvim görünümünde kapalı gün seçimi.
class DutySettingsTab extends StatelessWidget {
  const DutySettingsTab({
    super.key,
    required this.state,
    required this.settings,
    required this.sections,
    required this.selectedSectionKey,
    required this.floorOptions,
    required this.calendarYear,
    required this.calendarMonth,
    required this.onSectionChanged,
    required this.onCalendarChanged,
    required this.onSaveSettings,
  });

  final dynamic state;
  final DutySettings settings;
  final List<String?> sections;
  final String? selectedSectionKey;
  final List<String> floorOptions;
  final int calendarYear;
  final int calendarMonth;
  final ValueChanged<String?> onSectionChanged;
  final void Function(int year, int month) onCalendarChanged;
  final Future<void> Function(DutySettings settings) onSaveSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        if (sections.length > 1)
          _Card(
            title: 'Bölüm',
            subtitle: 'Karma pansiyonda her bölümün ayarları ayrı tutulur.',
            child: DropdownButton<String?>(
              key: const Key('duty_settings_section'),
              value: selectedSectionKey,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final section in sections)
                  DropdownMenuItem(
                    value: section,
                    child: Text(section ?? 'Tüm Bölümler'),
                  ),
              ],
              onChanged: onSectionChanged,
            ),
          )
        else
          const _Card(
            title: 'Bölüm',
            subtitle: 'Pansiyon tek bölüm olduğu için ayarlar tüm pansiyon için geçerlidir.',
            child: Text('Tüm Bölümler'),
          ),
        const SizedBox(height: 12),
        _Card(
          title: 'Günlük nöbetçi sayısı',
          child: Row(
            children: [
              for (final count in const [2, 3])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('duty_daily_count_$count'),
                    label: Text('$count nöbetçi'),
                    selected: settings.dailyCount == count,
                    onSelected: (_) =>
                        onSaveSettings(settings.copyWith(dailyCount: count)),
                  ),
                ),
              const Spacer(),
              const Text('Üst üste nöbet sınırı:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const Key('duty_max_consecutive_dropdown'),
                value: settings.maxConsecutive,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Üst üste yok')),
                  DropdownMenuItem(value: 1, child: Text('1 gün')),
                  DropdownMenuItem(value: 2, child: Text('2 gün')),
                  DropdownMenuItem(value: 3, child: Text('3 gün')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onSaveSettings(settings.copyWith(maxConsecutive: value));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Nöbet yerleri',
          subtitle: 'Bina katlarından seçiniz',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in floorOptions)
                FilterChip(
                  key: Key('duty_location_$option'),
                  label: Text(option),
                  selected: settings.locations.contains(option),
                  onSelected: (selected) {
                    final updated = [...settings.locations];
                    if (selected) {
                      updated.add(option);
                    } else {
                      updated.remove(option);
                    }
                    onSaveSettings(settings.copyWith(locations: updated));
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Nöbete kapalı günler',
          subtitle:
              'Gün başlığına (örn. Cuma) tıklayarak ayın tüm o günlerini '
              'kapatabilir ya da açabilirsiniz. Kapalı günler dağıtımdan düşülür.',
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    key: const Key('duty_calendar_previous'),
                    onPressed: () => onCalendarChanged(
                      calendarYear,
                      calendarMonth == 1 ? 12 : calendarMonth - 1,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      dutyMonthTitle(calendarYear, calendarMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('duty_calendar_next'),
                    onPressed: () => onCalendarChanged(
                      calendarYear,
                      calendarMonth == 12 ? 1 : calendarMonth + 1,
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _DutyCalendar(
                year: calendarYear,
                month: calendarMonth,
                blackouts: settings.blackouts,
                onToggleDay: (date) {
                  final updated = {...settings.blackouts};
                  final key = dutyDateKey(date);
                  if (!updated.remove(key)) {
                    updated.add(key);
                  }
                  onSaveSettings(settings.copyWith(blackouts: updated));
                },
                onToggleWeekday: (weekday) {
                  final dates = dutyMonthDates(calendarYear, calendarMonth)
                      .where((date) => date.weekday == weekday)
                      .toList();
                  final allClosed = dates.every(
                    (date) => settings.blackouts.contains(dutyDateKey(date)),
                  );
                  final updated = {...settings.blackouts};
                  for (final date in dates) {
                    if (allClosed) {
                      updated.remove(dutyDateKey(date));
                    } else {
                      updated.add(dutyDateKey(date));
                    }
                  }
                  onSaveSettings(settings.copyWith(blackouts: updated));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DutyCalendar extends StatelessWidget {
  const _DutyCalendar({
    required this.year,
    required this.month,
    required this.blackouts,
    required this.onToggleDay,
    required this.onToggleWeekday,
  });

  final int year;
  final int month;
  final Set<String> blackouts;
  final void Function(DateTime date) onToggleDay;
  final void Function(int weekday) onToggleWeekday;

  @override
  Widget build(BuildContext context) {
    final weeks = dutyMonthCalendar(year, month);
    return Column(
      children: [
        Row(
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              Expanded(
                child: InkWell(
                  key: Key('duty_calendar_weekday_$weekday'),
                  onTap: () => onToggleWeekday(weekday),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: weekday >= DateTime.saturday
                          ? AppColors.errorFeedback.withValues(alpha: 0.08)
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dutyWeekdayShortLabel(weekday),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final week in weeks)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (final date in week)
                  Expanded(
                    child: date == null
                        ? const SizedBox(height: 40)
                        : _DutyCalendarDay(
                            date: date,
                            isClosed: blackouts.contains(dutyDateKey(date)),
                            onTap: () => onToggleDay(date),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DutyCalendarDay extends StatelessWidget {
  const _DutyCalendarDay({
    required this.date,
    required this.isClosed,
    required this.onTap,
  });

  final DateTime date;
  final bool isClosed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday >= DateTime.saturday;
    return InkWell(
      key: Key('duty_calendar_day_${date.day}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        margin: const EdgeInsets.only(right: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isClosed
              ? AppColors.errorFeedback.withValues(alpha: 0.10)
              : isWeekend
              ? AppColors.surfaceContainerHighest.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isClosed ? AppColors.errorFeedback : AppColors.inputBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isClosed ? FontWeight.w700 : FontWeight.w500,
                color: isClosed ? AppColors.errorFeedback : null,
                decoration: isClosed ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isClosed)
              const Text(
                'kapalı',
                style: TextStyle(
                  color: AppColors.errorFeedback,
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
