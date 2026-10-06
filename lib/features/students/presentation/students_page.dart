import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/user_error_message.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/contact_sheet_pdf.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_completeness.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_form_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_detail_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_import_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.repository,
    this.boardingInfoRepository,
    this.roomRepository,
  });

  final StudentRepository repository;
  final BoardingInfoRepository? boardingInfoRepository;
  final RoomRepository? roomRepository;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<Student> _students = const [];
  List<School> _schools = const [];
  List<String> _classLevels = const [];
  BoardingType? _boardingType;
  String _searchQuery = '';
  String? _classFilter;
  int? _schoolFilter;
  StudentGender? _genderFilter;
  List<BoardingRoom> _rooms = const [];
  List<RoomAssignment> _roomAssignments = const [];
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final boardingInfoFuture =
          widget.boardingInfoRepository?.load() ??
          Future<BoardingInfoDraft?>.value(null);
      final roomsFuture =
          widget.roomRepository?.getRooms() ??
          Future<List<BoardingRoom>>.value(const []);
      final assignmentsFuture =
          widget.roomRepository?.getAssignments() ??
          Future<List<RoomAssignment>>.value(const []);
      // Okul/şube verisi hata verse bile öğrenci listesi boş kalmaz.
      final schoolsFuture = _loadSchoolsSafely();
      final results = await Future.wait<Object?>([
        widget.repository.getStudents(query: _searchQuery),
        schoolsFuture,
        boardingInfoFuture,
        roomsFuture,
        assignmentsFuture,
      ]);
      final students = results[0] as List<Student>;
      final schools = results[1] as List<School>;
      final boardingInfo = results[2] as BoardingInfoDraft?;
      final rooms = results[3] as List<BoardingRoom>;
      final assignments = results[4] as List<RoomAssignment>;
      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        _schools = schools;
        _rooms = rooms;
        _roomAssignments = assignments;
        _classLevels = classLevelsForEducationLevel(
          boardingInfo?.educationLevel,
          hasPreparationGrade: boardingInfo?.hasPreparationGrade ?? true,
        );
        _boardingType = boardingInfo?.boardingType;
        _classFilter = _classLevels.contains(_classFilter)
            ? _classFilter
            : null;
        _schoolFilter = _schools.any((school) => school.id == _schoolFilter)
            ? _schoolFilter
            : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Öğrenci bilgileri yüklenemedi.', AppNotificationTone.error);
    }
  }

  /// Okul ve şube bilgisi hata verirse liste boşalmaz.
  Future<List<School>> _loadSchoolsSafely() async {
    try {
      return await widget.repository.getSchools();
    } catch (_) {
      return const [];
    }
  }

  BoardingRoom? _roomForStudent(int studentId) {
    for (final assignment in _roomAssignments) {
      if (assignment.studentId == studentId) {
        for (final room in _rooms) {
          if (room.id == assignment.roomId) {
            return room;
          }
        }
      }
    }
    return null;
  }

  List<ContactSheetGroup> _buildContactSheetGroups() {
    return buildContactSheetGroups(
      students: _students,
      roomOf: _roomForStudent,
    );
  }

  Future<void> _printContactSheet() async {
    final groups = _buildContactSheetGroups();
    if (groups.isEmpty) {
      _notify('Yazdırılacak öğrenci yok.', AppNotificationTone.error);
      return;
    }
    setState(() => _isPrinting = true);
    try {
      final boardingInfo = await widget.boardingInfoRepository?.load();
      final data = ContactSheetData(
        schoolName: boardingInfo?.schoolName ?? '',
        educationYear: reportEducationYear(DateTime.now()),
        date: DateTime.now(),
        groups: groups,
      );
      final fonts = await ReportFonts.load();
      final bytes = await buildContactSheetPdf(
        pw.Document(),
        data,
        fonts,
      ).save();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Öğrenci İletişim Bilgileri Formu',
      );
    } catch (_) {
      _notify('Yazdırma hazırlanamadı.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _refreshStudents() async {
    setState(() => _isLoading = true);
    await _load();
  }

  Future<void> _openStudentForm([Student? student]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StudentFormDialog(
          repository: widget.repository,
          schools: _schools,
          student: student,
          classLevels: _classLevels,
          boardingType: _boardingType,
          boardingInfoRepository: widget.boardingInfoRepository,
        );
      },
    );
    if (saved == true) {
      await _refreshStudents();
      _notify(
        student == null ? 'Öğrenci eklendi.' : 'Öğrenci güncellendi.',
        AppNotificationTone.success,
      );
    }
  }

  Future<void> _importFromExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    final filePath = result.isEmpty ? null : result.single.path;
    if (filePath == null || !mounted) {
      return;
    }

    try {
      final preview = await const StudentExcelImporter().readFile(filePath);
      if (!mounted) {
        return;
      }
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StudentImportDialog(preview: preview),
      );
      if (shouldImport != true || !mounted) {
        return;
      }

      final schools = [..._schools];
      final students = <Student>[];
      var correctedGenderCount = 0;
      for (final row in preview.rows) {
        if (row.missingFields.contains('Ad Soyad')) {
          continue;
        }
        var schoolId = row.student.schoolId;
        final schoolName = row.schoolName?.trim();
        if (schoolName != null && schoolName.isNotEmpty) {
          School? school;
          for (final item in schools) {
            if (item.name.toLowerCase() == schoolName.toLowerCase()) {
              school = item;
              break;
            }
          }
          school ??= School(
            id: await widget.repository.saveSchool(School(name: schoolName)),
            name: schoolName,
          );
          schools.add(school);
          schoolId = school.id;
        }
        // Tek cinsiyetli pansiyonda cinsiyet kilitlidir, dosyadaki değer
        // pansiyon türüne göre düzeltilir.
        final (constrained, wasCorrected) = applyBoardingGenderConstraint(
          row.student,
          _boardingType,
        );
        if (wasCorrected) {
          correctedGenderCount++;
        }
        students.add(constrained.withSchoolId(schoolId));
      }
      final importedCount = await widget.repository.importStudents(students);
      await _refreshStudents();
      final correctionNote = correctedGenderCount == 0
          ? ''
          : ' $correctedGenderCount öğrencinin cinsiyeti pansiyon türüne '
                'göre düzeltildi.';
      _notify(
        '$importedCount öğrenci Excel dosyasından eklendi.$correctionNote',
        AppNotificationTone.success,
      );
    } on StudentDataIntegrityException catch (error) {
      _notify(error.message, AppNotificationTone.error);
    } on FormatException catch (error) {
      _notify(error.message.toString(), AppNotificationTone.error);
    } catch (error) {
      _notify(
        userErrorMessage(error, fallback: 'Excel dosyası okunamadı.'),
        AppNotificationTone.error,
      );
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = const StudentExcelImporter().createTemplateBytes();
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Excel şablonunu kaydet',
        fileName: 'pansiyon_ogrenci_sablonu.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (!mounted || savedUri == null) {
        return;
      }
      _notify('Excel şablonu kaydedildi.', AppNotificationTone.success);
    } catch (error) {
      _notify(
        userErrorMessage(error, fallback: 'Excel şablonu oluşturulamadı.'),
        AppNotificationTone.error,
      );
    }
  }

  Future<void> _openSchoolSettings() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return SchoolSettingsDialog(
          repository: widget.repository,
          boardingInfoRepository: widget.boardingInfoRepository,
        );
      },
    );
    if (changed == true) {
      await _refreshStudents();
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Öğrenciyi sil'),
          content: Text('${student.fullName} silinsin mi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || student.id == null) {
      return;
    }
    try {
      await widget.repository.deleteStudent(student.id!);
      await _refreshStudents();
      _notify('Öğrenci silindi.', AppNotificationTone.success);
    } catch (_) {
      _notify('Öğrenci silinemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _openStudentDetail(Student student) async {
    if (student.id == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StudentDetailDialog(
        repository: widget.repository,
        studentId: student.id!,
        schools: _schools,
        classLevels: _classLevels,
        boardingType: _boardingType,
        boardingInfoRepository: widget.boardingInfoRepository,
      ),
    );
    await _refreshStudents();
  }

  /// Araç çubuğundaki filtrelere göre süzülmüş öğrenci listesi.
  List<Student> get _visibleStudents {
    return _students
        .where((student) {
          if (_classFilter != null && student.className != _classFilter) {
            return false;
          }
          if (_schoolFilter != null && student.schoolId != _schoolFilter) {
            return false;
          }
          if (_genderFilter != null && student.gender != _genderFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  bool get _hasActiveFilters =>
      _classFilter != null || _schoolFilter != null || _genderFilter != null;

  void _clearFilters() {
    setState(() {
      _classFilter = null;
      _schoolFilter = null;
      _genderFilter = null;
    });
  }

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
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
              Text(
                'Öğrenciler',
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
              const SizedBox(height: 14),
              _buildToolbar(),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  icon: Icons.people_outline,
                  title: _students.isEmpty
                      ? 'Henüz öğrenci eklenmemiş'
                      : 'Filtrelere uyan öğrenci yok',
                  message: _students.isEmpty
                      ? 'İlk öğrenciyi ekleyerek pansiyon kayıtlarını oluşturun.'
                      : 'Filtreleri temizleyerek tüm öğrencileri görebilirsiniz.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = visible[index];
                    return _StudentCard(
                      student: student,
                      onOpenDetail: () => _openStudentDetail(student),
                      onEdit: () => _openStudentForm(student),
                      onDelete: () => _deleteStudent(student),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String get _summaryLine {
    final total = _students.length;
    final visible = _visibleStudents.length;
    if (_hasActiveFilters) {
      return '$visible / $total öğrenci gösteriliyor';
    }
    return total == 0 ? 'Henüz öğrenci yok' : '$total öğrenci kayıtlı';
  }

  Widget _buildToolbar() {
    final searchField = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 340),
      child: TextField(
        key: const Key('student_search_field'),
        onChanged: (value) => _searchQuery = value,
        onSubmitted: (_) => _refreshStudents(),
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Öğrenci ara',
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = <Widget>[
          _FilterButton<String>(
            filterKey: const Key('class_filter_button'),
            label: 'Sınıf',
            value: _classFilter,
            hint: 'Tümü',
            options: _classLevels,
            onSelected: (value) => setState(() => _classFilter = value),
          ),
          _FilterButton<int>(
            filterKey: const Key('school_filter_button'),
            label: 'Okul',
            value: _schoolFilter,
            hint: 'Tümü',
            options: [
              for (final school in _schools)
                if (school.id != null) school.id!,
            ],
            optionLabel: (schoolId) => _schoolLabel(schoolId),
            onSelected: (value) => setState(() => _schoolFilter = value),
          ),
          _FilterButton<StudentGender>(
            filterKey: const Key('gender_filter_button'),
            label: 'Cinsiyet',
            value: _genderFilter,
            hint: 'Tümü',
            options: allowedGendersForBoardingType(_boardingType),
            optionLabel: (gender) => gender.label,
            onSelected: (value) => setState(() => _genderFilter = value),
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              key: const Key('clear_filters_button'),
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Temizle'),
            ),
        ];

        final actions = <Widget>[
          FilledButton.icon(
            key: const Key('add_student_button'),
            onPressed: _openStudentForm,
            icon: const Icon(Icons.person_add_alt_1, size: 20),
            label: const Text('Öğrenci Ekle'),
          ),
          _IconAction(
            actionKey: const Key('import_students_button'),
            tooltip: 'Toplu Yükle (Excel)',
            icon: Icons.upload_file,
            onPressed: _importFromExcel,
          ),
          _IconAction(
            actionKey: const Key('download_template_button'),
            tooltip: 'Şablon İndir',
            icon: Icons.download_outlined,
            onPressed: _downloadTemplate,
          ),
          _IconAction(
            actionKey: const Key('school_settings_button'),
            tooltip: 'Okul Ayarları',
            icon: Icons.school_outlined,
            onPressed: _openSchoolSettings,
          ),
          _IconAction(
            actionKey: const Key('students_print_button'),
            tooltip: 'Yazdır',
            icon: Icons.print_outlined,
            onPressed: _isPrinting
                ? () {}
                : () => unawaited(_printContactSheet()),
          ),
        ];

        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [...filters, searchField],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, runSpacing: 8, children: actions),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in filters) ...[
                      filter,
                      const SizedBox(width: 8),
                    ],
                    searchField,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              actions[index],
            ],
          ],
        );
      },
    );
  }

  String _schoolLabel(int schoolId) {
    for (final school in _schools) {
      if (school.id == schoolId) {
        return school.name;
      }
    }
    return 'Tümü';
  }
}

class _StudentCard extends StatefulWidget {
  const _StudentCard({
    required this.student,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
  });

  final Student student;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final classLabel = formatClassSectionLabel(
      student.className,
      student.sectionName,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        key: Key('student_card_${student.id}'),
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
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            StudentGenderAvatar(gender: student.gender, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (classLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      classLabel,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    student.schoolName ?? 'Okul seçilmedi',
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
            const SizedBox(width: 6),
            _MissingFieldsBadge(fields: studentMissingFields(student)),
            const SizedBox(width: 6),
            _CardIconAction(
              actionKey: Key('student_detail_${student.id}'),
              tooltip: 'Detay',
              icon: Icons.visibility_outlined,
              onPressed: widget.onOpenDetail,
            ),
            _CardIconAction(
              actionKey: Key('student_edit_${student.id}'),
              tooltip: 'Düzenle',
              icon: Icons.edit_outlined,
              onPressed: widget.onEdit,
            ),
            _CardIconAction(
              actionKey: Key('student_delete_${student.id}'),
              tooltip: 'Sil',
              icon: Icons.delete_outline,
              color: AppColors.errorFeedback,
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kart üzerindeki eksik bilgi uyarısı.
///
/// Eksik alan yoksa hiç görünmez. Varsa turuncu bir rozet gösterir; rozet
/// veya üzerine gelindiğinde eksik alanların adları listelenir.
class _MissingFieldsBadge extends StatelessWidget {
  const _MissingFieldsBadge({required this.fields});

  final List<StudentMissingField> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasCritical = fields.any((field) => field.isCritical);
    final color = hasCritical
        ? AppColors.errorFeedback
        : const Color(0xFFB26A00);
    final summary = studentMissingSummary(fields);

    return Tooltip(
      message: summary,
      waitDuration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.all(10),
      textStyle: const TextStyle(color: AppColors.surface, fontSize: 12),
      decoration: BoxDecoration(
        color: AppColors.darkText,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Semantics(
        label: summary,
        button: true,
        child: Container(
          key: const Key('student_missing_info_badge'),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          // Sabit genişlikte ikon ve sayaç yana sığmaz; sayaç ikonun sağ
          // üst köşesine bindirilir.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 19,
                  color: color,
                ),
              ),
              Positioned(
                right: -5,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${fields.length}',
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: color ?? AppColors.secondaryText),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
      ),
    );
  }
}

class _FilterButton<T> extends StatelessWidget {
  const _FilterButton({
    required this.filterKey,
    required this.label,
    required this.value,
    required this.hint,
    required this.options,
    required this.onSelected,
    this.optionLabel,
  });

  final Key filterKey;
  final String label;
  final T? value;
  final String hint;
  final List<T> options;
  final ValueChanged<T?> onSelected;
  final String Function(T value)? optionLabel;

  String _text(T option) => optionLabel?.call(option) ?? option.toString();

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    // "Tümü" seçeneği null değer döndürdüğü için menüde sıra numarası
    // taşınır; aksi halde PopupMenuButton seçimi iptal sayar.
    return PopupMenuButton<int>(
      key: filterKey,
      tooltip: '$label filtresi',
      onSelected: (index) => onSelected(index == 0 ? null : options[index - 1]),
      offset: const Offset(0, 44),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.inputBorder),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<int>(value: 0, child: Text('$label: $hint')),
        for (var index = 0; index < options.length; index++)
          PopupMenuItem<int>(
            value: index + 1,
            child: Text(_text(options[index])),
          ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == null ? label : '$label: ${_text(value as T)}',
              style: TextStyle(
                color: isActive ? AppColors.primaryDark : AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
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
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
