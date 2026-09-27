import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/attendance/data/absence_sheet_pdf.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_detail_dialog.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.studentRepository,
    required this.roomRepository,
    this.boardingInfoRepository,
  });

  final StudentRepository studentRepository;
  final RoomRepository roomRepository;
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Student> _students = const [];
  List<BoardingRoom> _rooms = const [];
  List<RoomAssignment> _assignments = const [];
  Map<int, StudentAttendance> _attendanceByStudent = const {};
  BoardingSection? _sectionFilter;
  String? _blockFilter;
  String? _floorFilter;
  String _searchQuery = '';
  DateTime _date = DateTime.now();
  String _schoolName = '';
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.studentRepository.getStudents(query: _searchQuery),
        widget.roomRepository.getRooms(),
        widget.roomRepository.getAssignments(),
        widget.studentRepository.getAttendance(date: _date),
        widget.boardingInfoRepository?.load() ??
            Future<BoardingInfoDraft?>.value(null),
      ]);
      if (!mounted) {
        return;
      }
      final rooms = results[1] as List<BoardingRoom>;
      final assignments = results[2] as List<RoomAssignment>;
      final attendance = results[3] as List<StudentAttendance>;
      final boardingInfo = results[4] as BoardingInfoDraft?;
      setState(() {
        _students = results[0] as List<Student>;
        _rooms = rooms;
        _assignments = assignments;
        _attendanceByStudent = {
          for (final record in attendance) record.studentId: record,
        };
        _schoolName = boardingInfo?.schoolName ?? '';
        if (_sectionFilter == null && rooms.isNotEmpty) {
          _sectionFilter = rooms.first.section;
          _blockFilter = rooms.first.blockName;
          _floorFilter = rooms.first.floorLabel;
        }
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Yoklama bilgileri yüklenemedi.', AppNotificationTone.error);
    }
  }

  List<BoardingSection> get _sections =>
      {for (final room in _rooms) room.section}.toList(growable: false);

  List<String> get _blocks => _rooms
      .where((room) => _sectionFilter == null || room.section == _sectionFilter)
      .map((room) => room.blockName)
      .toSet()
      .toList(growable: false);

  List<String> get _floors => _rooms
      .where(
        (room) =>
            (_sectionFilter == null || room.section == _sectionFilter) &&
            (_blockFilter == null || room.blockName == _blockFilter),
      )
      .map((room) => room.floorLabel)
      .toSet()
      .toList(growable: false);

  String get _locationLabel {
    final parts = [
      if (_sectionFilter != null) _sectionFilter!.label,
      if (_blockFilter != null && _blockFilter!.isNotEmpty) _blockFilter!,
      if (_floorFilter != null && _floorFilter!.isNotEmpty) _floorFilter!,
    ];
    return parts.isEmpty ? 'Tüm Bölümler' : parts.join(' - ');
  }

  BoardingRoom? _roomForStudent(int studentId) {
    final assignment = _assignments.firstWhere(
      (item) => item.studentId == studentId,
      orElse: () => const RoomAssignment(roomId: -1, studentId: -1),
    );
    if (assignment.roomId < 0) {
      return null;
    }
    for (final room in _rooms) {
      if (room.id == assignment.roomId) {
        return room;
      }
    }
    return null;
  }

  bool _matchesLocation(Student student) {
    final room = _roomForStudent(student.id!);
    if (_sectionFilter == null && _blockFilter == null && _floorFilter == null) {
      return true;
    }
    if (room == null) {
      return false;
    }
    if (_sectionFilter != null && room.section != _sectionFilter) {
      return false;
    }
    if (_blockFilter != null && room.blockName != _blockFilter) {
      return false;
    }
    if (_floorFilter != null && room.floorLabel != _floorFilter) {
      return false;
    }
    return true;
  }

  String _roomLabel(Student student) {
    final room = _roomForStudent(student.id!);
    if (room == null) {
      return 'Odasız';
    }
    return '${room.roomNumber}';
  }

  List<Student> get _visibleStudents {
    final list = _students.where(_matchesLocation).toList();
    list.sort((a, b) {
      final roomCompare = _roomSortKey(a).compareTo(_roomSortKey(b));
      if (roomCompare != 0) {
        return roomCompare;
      }
      return a.fullName.compareTo(b.fullName);
    });
    return list;
  }

  String _roomSortKey(Student student) {
    final room = _roomForStudent(student.id!);
    if (room == null) {
      return '9999';
    }
    return room.roomNumber.toString().padLeft(4, '0');
  }

  /// Sayaçlar yalnızca seçili bölum/blok/kat öğrencileri üzerinden hesaplanır.
  int _countVisible(StudentAttendanceStatus status) {
    return _visibleStudents
        .where((student) => _attendanceByStudent[student.id!]?.status == status)
        .length;
  }

  int get _leaveCount => _countVisible(StudentAttendanceStatus.homeLeave);

  int get _reportCount => _countVisible(StudentAttendanceStatus.medicalReport);

  int get _presentCount => _countVisible(StudentAttendanceStatus.present);

  String get _summaryLine {
    final total = _students.length;
    final visible = _visibleStudents.length;
    final dateText = AppDateField.formatDate(_date);
    final counts = <String>[
      'evci izinli: $_leaveCount',
      'raporlu: $_reportCount',
    ].join(' • ');
    if (visible == total) {
      return '$total öğrenci • $dateText • $counts';
    }
    return '$visible / $total öğrenci • $dateText • $counts';
  }

  Future<void> _changeDate() async {
    final date = await showAppDatePicker(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Yoklama tarihini seçin',
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() => _date = date);
    await _load();
  }

  Future<void> _saveLeave(Student student, StudentAttendanceStatus status) async {
    final result = await showDialog<_AttendanceEntryInput>(
      context: context,
      builder: (dialogContext) => _AttendanceEntryDialog(
        studentName: student.fullName,
        status: status,
        initialDate: _date,
      ),
    );
    if (result == null) {
      return;
    }
    try {
      var cursor = result.start;
      var count = 0;
      while (!cursor.isAfter(result.end)) {
        await widget.studentRepository.saveAttendance(
          StudentAttendance(
            studentId: student.id!,
            date: cursor,
            status: status,
            note: result.note,
          ),
        );
        count++;
        cursor = cursor.add(const Duration(days: 1));
      }
      _notify(
        '$count günlük kayıt eklendi.',
        AppNotificationTone.success,
      );
      await _load();
    } catch (_) {
      _notify('Kayıt eklenemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _clearEntry(Student student) async {
    final record = _attendanceByStudent[student.id!];
    if (record == null) {
      _notify('Bu öğrenci için kayıtlı izin/rapor yok.', AppNotificationTone.info);
      return;
    }
    try {
      await widget.studentRepository.saveAttendance(
        StudentAttendance(
          studentId: student.id!,
          date: record.date,
          status: StudentAttendanceStatus.present,
          note: null,
        ),
      );
      _notify('Kayıt temizlendi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Kayıt temizlenemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _openHistory(Student student) async {
    final records = await widget.studentRepository.getAttendanceHistory(student.id!);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AttendanceHistoryDialog(
        studentName: student.fullName,
        records: records,
      ),
    );
  }

  Future<void> _printSheet() async {
    final students = _visibleStudents;
    if (students.isEmpty) {
      _notify(
        'Yazdırılacak öğrenci yok. Bölüm, blok ve kat seçimini gözden geçirin.',
        AppNotificationTone.error,
      );
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final entries = students.map((student) {
        final record = _attendanceByStudent[student.id!];
        final status = record?.status;
        return AbsenceSheetEntry(
          studentName: student.fullName,
          className: student.className,
          schoolNumber: student.schoolNumber,
          roomLabel: _roomLabel(student),
          attendanceMark: switch (status) {
            StudentAttendanceStatus.homeLeave => 'İ',
            StudentAttendanceStatus.medicalReport => 'R',
            _ => '',
          },
          note: record?.note,
        );
      }).toList(growable: false);

      final data = AbsenceSheetData(
        schoolName: _schoolName.trim().isEmpty
            ? 'Okul Adı Girilmemiş'
            : _schoolName.trim(),
        educationYear: absenceSheetEducationYear(_date),
        date: _date,
        locationLabel: _locationLabel,
        entries: entries,
        summary: AbsenceSheetSummary(
          presentCount: _presentCount,
          leaveCount: _leaveCount,
          reportCount: _reportCount,
          absentCount: 0,
          totalCount: students.length,
        ),
      );

      final fonts = await ReportFonts.load();
      final bytes = await buildAbsenceSheetPdf(pw.Document(), data, fonts).save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Pansiyon Yoklama Çizelgesi',
      );
    } catch (_) {
      _notify('Yazdırma hazırlanamadı.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final visible = _visibleStudents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yoklama',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _summaryLine,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('attendance_print_button'),
                    onPressed: _isPrinting ? null : _printSheet,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: const Text('Yazdır'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildToolbar(),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const _AttendanceEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = visible[index];
                    return _AttendanceStudentCard(
                      student: student,
                      roomLabel: _roomLabel(student),
                      record: _attendanceByStudent[student.id!],
                      onAddLeave: () => _saveLeave(
                        student,
                        StudentAttendanceStatus.homeLeave,
                      ),
                      onAddReport: () => _saveLeave(
                        student,
                        StudentAttendanceStatus.medicalReport,
                      ),
                      onOpenHistory: () => _openHistory(student),
                      onClear: () => _clearEntry(student),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 40,
          child: TextField(
            key: const Key('attendance_search_field'),
            onSubmitted: (value) {
              setState(() => _searchQuery = value.trim());
              _load();
            },
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Öğrenci ara',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        DropdownButton<BoardingSection>(
          key: const Key('attendance_section_filter'),
          value: _sectionFilter,
          underline: const SizedBox.shrink(),
          items: [
            for (final section in _sections)
              DropdownMenuItem(
                value: section,
                child: Text(section.label),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _sectionFilter = value;
              _blockFilter = null;
              _floorFilter = null;
            });
          },
        ),
        DropdownButton<String>(
          key: const Key('attendance_block_filter'),
          value: _blockFilter,
          underline: const SizedBox.shrink(),
          items: [
            for (final block in _blocks)
              DropdownMenuItem(value: block, child: Text(block)),
          ],
          onChanged: (value) {
            setState(() {
              _blockFilter = value;
              _floorFilter = null;
            });
          },
        ),
        DropdownButton<String>(
          key: const Key('attendance_floor_filter'),
          value: _floorFilter,
          underline: const SizedBox.shrink(),
          items: [
            for (final floor in _floors)
              DropdownMenuItem(value: floor, child: Text(floor)),
          ],
          onChanged: (value) => setState(() => _floorFilter = value),
        ),
        OutlinedButton.icon(
          key: const Key('attendance_date_button'),
          onPressed: _changeDate,
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text(AppDateField.formatDate(_date)),
        ),
      ],
    );
  }
}

class _AttendanceStudentCard extends StatefulWidget {
  const _AttendanceStudentCard({
    required this.student,
    required this.roomLabel,
    required this.record,
    required this.onAddLeave,
    required this.onAddReport,
    required this.onOpenHistory,
    required this.onClear,
  });

  final Student student;
  final String roomLabel;
  final StudentAttendance? record;
  final VoidCallback onAddLeave;
  final VoidCallback onAddReport;
  final VoidCallback onOpenHistory;
  final VoidCallback onClear;

  @override
  State<_AttendanceStudentCard> createState() => _AttendanceStudentCardState();
}

class _AttendanceStudentCardState extends State<_AttendanceStudentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final record = widget.record;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        key: Key('attendance_card_${student.id}'),
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _isHovered
              ? AppColors.surface
              : AppColors.cardSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          children: [
            StudentGenderAvatar(gender: student.gender, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (record != null) ...[
                        const SizedBox(width: 8),
                        _RecordChip(status: record.status),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      'Oda ${widget.roomLabel}',
                      if (student.className != null) 'Sınıf ${student.className}',
                      student.schoolName ?? 'Okul seçilmedi',
                      if (record != null &&
                          record.note != null &&
                          record.note!.isNotEmpty)
                        record.note!,
                    ].join(' • '),
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
            const SizedBox(width: 8),
            _CardIconAction(
              actionKey: Key('attendance_leave_${student.id}'),
              tooltip: 'Evci izni ekle',
              icon: Icons.home_work_outlined,
              color: const Color(0xFF8A5A00),
              onPressed: widget.onAddLeave,
            ),
            _CardIconAction(
              actionKey: Key('attendance_report_${student.id}'),
              tooltip: 'Rapor ekle',
              icon: Icons.medical_information_outlined,
              color: const Color(0xFFB3156B),
              onPressed: widget.onAddReport,
            ),
            _CardIconAction(
              actionKey: Key('attendance_history_${student.id}'),
              tooltip: 'Devamsızlık detayları',
              icon: Icons.history_toggle_off,
              onPressed: widget.onOpenHistory,
            ),
            if (record != null)
              _CardIconAction(
                actionKey: Key('attendance_clear_${student.id}'),
                tooltip: 'Kaydı temizle',
                icon: Icons.restart_alt,
                color: AppColors.errorFeedback,
                onPressed: widget.onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({required this.status});

  final StudentAttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final isLeave = status == StudentAttendanceStatus.homeLeave;
    final background = isLeave
        ? const Color(0xFFFFF1D6)
        : const Color(0xFFFFE1EC);
    final foreground = isLeave
        ? const Color(0xFF8A5A00)
        : const Color(0xFFB3156B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CardIconAction extends StatelessWidget {
  const _CardIconAction({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        key: actionKey,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: color,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _AttendanceEntryInput {
  const _AttendanceEntryInput({
    required this.start,
    required this.end,
    required this.note,
  });

  final DateTime start;
  final DateTime end;
  final String? note;
}

class _AttendanceEntryDialog extends StatefulWidget {
  const _AttendanceEntryDialog({
    required this.studentName,
    required this.status,
    required this.initialDate,
  });

  final String studentName;
  final StudentAttendanceStatus status;
  final DateTime initialDate;

  @override
  State<_AttendanceEntryDialog> createState() => _AttendanceEntryDialogState();
}

class _AttendanceEntryDialogState extends State<_AttendanceEntryDialog> {
  late DateTime _start = widget.initialDate;
  late DateTime _end = widget.initialDate;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _isLeave => widget.status == StudentAttendanceStatus.homeLeave;

  String get _title => _isLeave ? 'Evci izni ekle' : 'Rapor ekle';

  Future<void> _pickDate({required bool start}) async {
    final date = await showAppDatePicker(
      context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: start ? 'Başlangıç tarihi' : 'Bitiş tarihi',
    );
    if (date == null) {
      return;
    }
    setState(() {
      if (start) {
        _start = date;
        if (_end.isBefore(date)) {
          _end = date;
        }
      } else {
        _end = date.isBefore(_start) ? _start : date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _end.difference(_start).inDays + 1;
    return AlertDialog(
      title: Text('$_title • ${widget.studentName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: true),
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      'Başlangıç: ${AppDateField.formatDate(_start)}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(start: false),
                    icon: const Icon(Icons.event_available, size: 18),
                    label: Text('Bitiş: ${AppDateField.formatDate(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Açıklama (yoklama çizelgesinde görünür)',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$days gün için kayıt eklenecek.',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _AttendanceEntryInput(
              start: _start,
              end: _end,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ),
          ),
          child: Text(_isLeave ? 'İzni ekle' : 'Raporu ekle'),
        ),
      ],
    );
  }
}

class _AttendanceHistoryDialog extends StatelessWidget {
  const _AttendanceHistoryDialog({
    required this.studentName,
    required this.records,
  });

  final String studentName;
  final List<StudentAttendance> records;

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    final leaves = records
        .where((record) => record.status == StudentAttendanceStatus.homeLeave)
        .length;
    final reports = records
        .where((record) => record.status == StudentAttendanceStatus.medicalReport)
        .length;
    return AlertDialog(
      title: Text('Devamsızlık detayları • $studentName'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toplam $total kayıt • evci izinli $leaves • raporlu $reports',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text('Kayıtlı izin veya rapor bulunmuyor.'),
                    )
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            record.status ==
                                    StudentAttendanceStatus.homeLeave
                                ? Icons.home_work_outlined
                                : Icons.medical_information_outlined,
                            size: 20,
                          ),
                          title: Text(
                            '${AppDateField.formatDate(record.date)} • ${record.status.label}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          subtitle: record.note == null || record.note!.isEmpty
                              ? null
                              : Text(record.note!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _AttendanceEmptyState extends StatelessWidget {
  const _AttendanceEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 46, color: AppColors.lavender),
          SizedBox(height: 12),
          Text(
            'Bu bölüm, blok ve katta öğrenci yok',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6),
          Text(
            'Oda ataması yapılmış öğrenciler listede görünür.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
