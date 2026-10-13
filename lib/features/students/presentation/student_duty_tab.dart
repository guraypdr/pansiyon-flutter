import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_duty_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_duty_report_print.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_roster.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';

/// Öğrenciler sayfasının nöbet modülü.
///
/// Nöbet listesi ay bazında tutulmaz: seçilen başlangıç tarihinden itibaren
/// ikişerli öğrenci yerleştirilir ve liste tüm öğrenciler bitene kadar sürer.
/// Öğrenci arşivlendiğinde listeden düşer ve sonrakiler bir gün öne kayar.
class StudentDutyTab extends StatefulWidget {
  const StudentDutyTab({
    super.key,
    required this.repository,
    required this.students,
    required this.roomOf,
    this.schoolName,
  });

  final StudentDutyRepository repository;

  /// Nöbete girebilecek öğrenciler; arşivlenenler hariç.
  final List<Student> students;

  final BoardingRoom? Function(int studentId) roomOf;

  /// Çıktının başlığında yazılacak okul adı.
  final String? schoolName;

  @override
  State<StudentDutyTab> createState() => _StudentDutyTabState();
}

class _StudentDutyTabState extends State<StudentDutyTab> {
  StudentDutyList? _list;
  Set<String> _blackouts = {};
  bool _isLoading = true;
  bool _isPrinting = false;

  /// Nöbet günlerinin takvim tarihleri; kapalı günler atlanır.
  List<DateTime> _dates = const [];

  /// Nöbet sorumlusunun adı; çıktıda ikinci imza satırında basılır.
  late final TextEditingController _officerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _officerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repository.getCurrentList();
      final blackouts = await widget.repository.getBlackouts();
      if (!mounted) return;
      setState(() {
        _list = list;
        _blackouts = blackouts;
        _recomputeDates();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Nöbet günlerini takvim tarihlerine çevirir.
  ///
  /// Liste gün sırasıyla ilerler ve aradaki kapalı günler atlanır.
  void _recomputeDates() {
    final list = _list;
    if (list == null) {
      _dates = const [];
      return;
    }
    var cursor = list.startDate;
    final dates = <DateTime>[];
    for (var day = 1; day <= list.dayCount; day++) {
      while (_blackouts.contains(studentDutyDateKey(cursor))) {
        cursor = cursor.add(const Duration(days: 1));
      }
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    _dates = dates;
  }

  /// Yeni tur oluşturur: oda sırasına göre öğrenciler ikişer yerleştirilir.
  Future<void> _createList() async {
    final startDate = await showAppDatePicker(
      context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Nöbet listesinin başlangıç tarihi',
    );
    if (startDate == null || !mounted) {
      return;
    }

    final sorted = sortStudentsByRoom(
      widget.students.where((s) => !s.isArchived).toList(),
      (student) =>
          student.id == null ? null : widget.roomOf(student.id!)?.roomNumber,
    );
    final ids = [
      for (final student in sorted)
        if (student.id != null) student.id!,
    ];

    final list = await widget.repository.createList(startDate: startDate);
    final days = buildStudentDutyDays(
      studentIds: ids,
      startDate: startDate,
      blackouts: _blackouts,
    );
    await widget.repository.replaceEntries(listId: list.id!, days: days);
    await _load();
  }

  /// Nöbet listesini yazdırma penceresini açar.
  Future<void> _print() async {
    final list = _list;
    if (list == null || list.isEmpty) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      await printStudentDutyReport(
        context: context,
        report: StudentDutyReportData(
          schoolName: widget.schoolName ?? '',
          list: list,
          students: widget.students,
          dates: _dates,
          dutyOfficerName: _officerController.text.trim(),
          roomNumberOf: (studentId) => widget.roomOf(studentId)?.roomNumber,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  /// Kapalı günleri yöneten takvimi açar.
  Future<void> _openBlackouts() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => _StudentDutyBlackoutDialog(
        initialKeys: _blackouts,
        startDate: _list?.startDate ?? DateTime.now(),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _blackouts = result);
    await widget.repository.saveBlackouts(result);
    _recomputeDates();
    // Kapalı gün eklendiğinde tur içindeki öğrenci sayısı değişmez; yalnızca
    // gün tarihleri kayar, bu yüzden girişler yeniden yazılmaz.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = _list;
    if (list == null || list.isEmpty) {
      return _buildEmptyState();
    }

    final byId = {for (final student in widget.students) student.id: student};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(list),
        Expanded(
          child: ListView.separated(
            key: const Key('student_duty_list'),
            padding: const EdgeInsets.fromLTRB(
              AppTokens.pageGutter,
              0,
              AppTokens.pageGutter,
              20,
            ),
            itemCount: list.days.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final day = list.days[index];
              final date = index < _dates.length ? _dates[index] : null;
              return _buildDayRow(day, date, byId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final hasStudents = widget.students.any((s) => !s.isArchived);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Henüz nöbet listesi yok',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasStudents
                  ? 'Oda numarası sırasına göre öğrenciler ikişerli nöbet '
                        'dağıtılarak liste oluşturulur.'
                  : 'Nöbete girecek öğrenci yok. Önce öğrenci ekleyin.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              key: const Key('student_duty_create_button'),
              label: 'Nöbet Listesi Oluştur',
              icon: Icons.add_rounded,
              onPressed: hasStudents ? _createList : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(StudentDutyList list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.pageGutter,
        0,
        AppTokens.pageGutter,
        12,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A3E0C28),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${list.studentCount} öğrenci • ${list.dayCount} nöbet günü',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Başlangıç: ${_formatDate(list.startDate)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSecondaryButton(
                  key: const Key('student_duty_print_button'),
                  label: 'Yazdır',
                  icon: Icons.print_outlined,
                  isLoading: _isPrinting,
                  onPressed: _isPrinting ? null : _print,
                ),
                const SizedBox(width: 8),
                AppSecondaryButton(
                  key: const Key('student_duty_blackouts_button'),
                  label: 'Kapalı Günler',
                  icon: Icons.event_busy_outlined,
                  onPressed: _openBlackouts,
                ),
                const SizedBox(width: 8),
                AppSecondaryButton(
                  key: const Key('student_duty_new_list_button'),
                  label: 'Yeni Tur',
                  icon: Icons.refresh_rounded,
                  onPressed: _createList,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextField(
                key: const Key('student_duty_officer_field'),
                controller: _officerController,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Nöbet Sorumlusu',
                  hintText: 'Ad soyad',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(
    StudentDutyDay day,
    DateTime? date,
    Map<int?, Student> byId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${day.sequence}. Gün',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final studentId in day.studentIds)
                  _buildStudentChip(byId[studentId], studentId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentChip(Student? student, int studentId) {
    // Öğrenci arşivlendiyse nöbetten düşmüş olmalıdır; yine de liste
    // tutarsızsa kayıt kimliğiyle gösterilir.
    final name = student?.fullName ?? 'Öğrenci #$studentId';
    final room = student?.id == null
        ? null
        : widget.roomOf(student!.id!)?.roomNumber.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceAccent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          if (room != null) ...[
            const SizedBox(width: 6),
            Text(
              'Oda $room',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}

/// Nöbeti kapalı günlerin seçildiği takvim.
///
/// Öğretmen nöbet ayarlarındaki takvimle aynı düzeni kullanır: gün başlığına
/// (örn. Cuma) tıklayarak ayın tüm o günleri topluca kapatılır veya açılır.
class _StudentDutyBlackoutDialog extends StatefulWidget {
  const _StudentDutyBlackoutDialog({
    required this.initialKeys,
    required this.startDate,
  });

  final Set<String> initialKeys;
  final DateTime startDate;

  @override
  State<_StudentDutyBlackoutDialog> createState() =>
      _StudentDutyBlackoutDialogState();
}

class _StudentDutyBlackoutDialogState
    extends State<_StudentDutyBlackoutDialog> {
  late final Set<String> _keys = {...widget.initialKeys};
  late int _year = widget.startDate.year;
  late int _month = widget.startDate.month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nöbete kapalı günler'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gün başlığına (örn. Cuma) tıklayarak ayın tüm o günlerini '
                'kapatabilir ya da açabilirsiniz. Kapalı günler nöbet '
                'dağıtımından düşülür.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    key: const Key('student_duty_blackout_previous'),
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      _monthTitle(_year, _month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('student_duty_blackout_next'),
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _StudentDutyCalendar(
                year: _year,
                month: _month,
                blackouts: _keys,
                onToggleDay: _toggleDay,
                onToggleWeekday: _toggleWeekday,
              ),
              const SizedBox(height: 10),
              Text(
                '${_keys.length} gün kapalı',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('student_duty_blackout_save'),
          onPressed: () => Navigator.of(context).pop(_keys),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  void _toggleDay(DateTime date) {
    setState(() {
      final key = studentDutyDateKey(date);
      if (!_keys.remove(key)) {
        _keys.add(key);
      }
    });
  }

  /// Haftanın tüm günlerini topluca açar veya kapatır.
  void _toggleWeekday(int weekday) {
    setState(() {
      final dates = _monthDates(_year, _month)
          .where((date) => date.weekday == weekday)
          .toList();
      final allClosed = dates.every(
        (date) => _keys.contains(studentDutyDateKey(date)),
      );
      for (final date in dates) {
        final key = studentDutyDateKey(date);
        if (allClosed) {
          _keys.remove(key);
        } else {
          _keys.add(key);
        }
      }
    });
  }

  void _shift(int delta) {
    setState(() {
      var month = _month + delta;
      var year = _year;
      if (month < 1) {
        month = 12;
        year -= 1;
      } else if (month > 12) {
        month = 1;
        year += 1;
      }
      _month = month;
      _year = year;
    });
  }
}

/// Ayın günleri; 31 günlük aylar Aralık'ta sığar.
List<DateTime> _monthDates(int year, int month) => [
      for (var day = 1; day <= DateTime(year, month + 1, 0).day; day++)
        DateTime(year, month, day),
    ];

/// Pazartesi başlayan haftalara ayrılmış takvim ızgarası.
List<List<DateTime?>> _monthCalendar(int year, int month) {
  final days = _monthDates(year, month);
  final leading = days.first.weekday - 1;
  final cells = <DateTime?>[...List<DateTime?>.filled(leading, null), ...days];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [
    for (var index = 0; index < cells.length; index += 7)
      cells.sublist(index, index + 7),
  ];
}

/// Kapalı gün seçme takvimi.
class _StudentDutyCalendar extends StatelessWidget {
  const _StudentDutyCalendar({
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
    final weeks = _monthCalendar(year, month);
    return Column(
      children: [
        Row(
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              Expanded(
                child: InkWell(
                  key: Key('student_duty_blackout_weekday_$weekday'),
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
                      _weekdayShortLabel(weekday),
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
                        : _StudentDutyCalendarDay(
                            date: date,
                            isClosed: blackouts.contains(
                              studentDutyDateKey(date),
                            ),
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

/// 1 = Pazartesi ... 7 = Pazar.
String _weekdayShortLabel(int weekday) {
  const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  return labels[weekday - 1];
}

const _monthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String _monthName(int month) => _monthNames[month - 1];

String _monthTitle(int year, int month) => '${_monthName(month)} $year';

class _StudentDutyCalendarDay extends StatelessWidget {
  const _StudentDutyCalendarDay({
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
      key: Key('student_duty_blackout_day_${date.day}'),
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