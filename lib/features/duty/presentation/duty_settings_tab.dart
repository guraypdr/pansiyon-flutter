import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_labelled_field.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

/// Bölüm bazında ortak nöbet ayarları ve takvim görünümünde kapalı gün seçimi.
class DutySettingsTab extends StatefulWidget {
  const DutySettingsTab({
    super.key,
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
  State<DutySettingsTab> createState() => _DutySettingsTabState();
}

class _DutySettingsTabState extends State<DutySettingsTab> {
  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      children: [
        if (widget.sections.length > 1) ...[
          _SectionTabs(
            sections: widget.sections,
            selectedKey: widget.selectedSectionKey,
            onSelected: widget.onSectionChanged,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SettingsCard(
                title: 'Günlük nöbetçi sayısı',
                subtitle: 'Günlük nöbet tutacak öğretmen sayısını belirleyin',
                child: Row(
                  children: [
                    for (final count in const [2, 3])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SelectTile(
                            tileKey: Key('duty_daily_count_$count'),
                            label: '$count',
                            caption: 'nöbetçi',
                            selected: settings.dailyCount == count,
                            onTap: () => widget.onSaveSettings(
                              settings.copyWith(dailyCount: count),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SettingsCard(
                title: 'Üst üste nöbet sınırı',
                subtitle:
                    'Aynı öğretmene arka arkaya kaç nöbet verilebileceğini belirleyin',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SelectTile(
                            tileKey: const Key('duty_consecutive_0'),
                            label: 'Üst üste nöbet olmasın',
                            caption: '',
                            selected: settings.maxConsecutive == 0,
                            onTap: () => widget.onSaveSettings(
                              settings.copyWith(maxConsecutive: 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final option in const [2, 3, 4])
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: option == 4 ? 0 : 8,
                              ),
                              child: _SelectTile(
                                tileKey: Key('duty_consecutive_$option'),
                                label: 'En fazla $option gün üstte',
                                caption: '',
                                selected: settings.maxConsecutive == option,
                                onTap: () => widget.onSaveSettings(
                                  settings.copyWith(maxConsecutive: option),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          title: 'Nöbet yerleri',
          subtitle:
              'Nöbet yerini kendi ifadenizle yazabilirsiniz. Sağdaki '
              'düğme, okuldaki blok ve katları hazır listeler.',
          child: Column(
            children: [
              for (var slot = 0; slot < settings.dailyCount; slot++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 132,
                        child: Text(
                          '${slot + 1}. nöbetçi yeri',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _EditableLocationField(
                          key: Key('duty_location_slot_$slot'),
                          value: settings.locationForSlot(slot),
                          suggestions: widget.floorOptions,
                          onSubmitted: (value) => widget.onSaveSettings(
                            settings.withLocation(slot, value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
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
                    onPressed: () => widget.onCalendarChanged(
                      widget.calendarYear,
                      widget.calendarMonth == 1 ? 12 : widget.calendarMonth - 1,
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      dutyMonthTitle(widget.calendarYear, widget.calendarMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('duty_calendar_next'),
                    onPressed: () => widget.onCalendarChanged(
                      widget.calendarYear,
                      widget.calendarMonth == 12 ? 1 : widget.calendarMonth + 1,
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _DutyCalendar(
                year: widget.calendarYear,
                month: widget.calendarMonth,
                blackouts: settings.blackouts,
                onToggleDay: (date) {
                  final updated = {...settings.blackouts};
                  final key = dutyDateKey(date);
                  if (!updated.remove(key)) {
                    updated.add(key);
                  }
                  widget.onSaveSettings(settings.copyWith(blackouts: updated));
                },
                onToggleWeekday: (weekday) {
                  final dates = dutyMonthDates(
                    widget.calendarYear,
                    widget.calendarMonth,
                  ).where((date) => date.weekday == weekday).toList();
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
                  widget.onSaveSettings(settings.copyWith(blackouts: updated));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nöbet yeri alanı: serbestçe yazılabilir, öneri de sunar.
///
/// Nöbet yerleri okulun blok/kat listesinden seçilmek zorunda değildir.
/// "Gece Nöbeti", "Nöbet Şefi", "Bahçe" gibi kendi ifadelerini kullanan
/// öğretmenler de olabilir; bu yüzden alan bir metin kutusudur. Yanındaki
/// düğme yalnızca hazır listeyi açar, seçim zorunlu değildir.
class _EditableLocationField extends StatefulWidget {
  const _EditableLocationField({
    super.key,
    required this.value,
    required this.suggestions,
    required this.onSubmitted,
  });

  final String value;
  final List<String> suggestions;
  final ValueChanged<String?> onSubmitted;

  @override
  State<_EditableLocationField> createState() => _EditableLocationFieldState();
}

class _EditableLocationFieldState extends State<_EditableLocationField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _EditableLocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kayıt dışarıdan değişirse (örn. bölüm değişimi) alanı eşitle.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Boş metin `null` olarak kaydedilir; ayarlar boş değeri temizler.
  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed == widget.value) {
      return;
    }
    widget.onSubmitted(trimmed.isEmpty ? null : trimmed);
  }

  void _openSuggestions() {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final origin = box!.localToGlobal(Offset.zero);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy, box.size.width, box.size.height),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(maxHeight: 280, minWidth: 220),
      items: [
        for (final option in widget.suggestions)
          PopupMenuItem<String>(value: option, child: Text(option)),
      ],
    ).then((selected) {
      if (selected == null) {
        return;
      }
      _controller.text = selected;
      _submit(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textInputAction: TextInputAction.done,
      onSubmitted: _submit,
      onTapOutside: (_) => _submit(_controller.text),
      decoration: appInputDecoration(
        helperText: 'Kendi ifadenizi yazabilirsiniz',
        suffixIcon: IconButton(
          onPressed: widget.suggestions.isEmpty ? null : _openSuggestions,
          tooltip: 'Hazır nöbet yerlerinden seç',
          icon: const Icon(Icons.expand_more_rounded, size: 20),
          color: AppColors.secondaryText,
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.sections,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<String?> sections;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: Key('duty_settings_section_${section ?? 'all'}'),
              label: Text(section ?? 'Tüm Bölümler'),
              selected: section == selectedKey,
              onSelected: (_) => onSelected(section),
            ),
          ),
        const Spacer(),
        const Text(
          'Karma pansiyonda her bölümün ayarları ayrı tutulur',
          style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
      ],
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.tileKey,
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final String label;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.inputBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.darkText,
              ),
            ),
            if (caption.isNotEmpty)
              Text(
                caption,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? Colors.white70 : AppColors.secondaryText,
                ),
              ),
          ],
        ),
      ),
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
                style: TextStyle(color: AppColors.errorFeedback, fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
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
