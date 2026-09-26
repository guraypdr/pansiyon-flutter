import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_form_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_import_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    required this.repository,
    this.boardingInfoRepository,
  });

  final StudentRepository repository;
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<Student> _students = const [];
  List<School> _schools = const [];
  List<String> _classLevels = const [];
  BoardingType? _boardingType;
  Map<int, StudentAttendanceStatus> _attendanceByStudent = const {};
  DateTime _attendanceDate = DateTime.now();
  String _searchQuery = '';
  bool _isLoading = true;

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
      final results = await Future.wait<Object?>([
        widget.repository.getStudents(query: _searchQuery),
        widget.repository.getSchools(),
        widget.repository.getAttendance(date: _attendanceDate),
        boardingInfoFuture,
      ]);
      final students = results[0] as List<Student>;
      final schools = results[1] as List<School>;
      final attendance = results[2] as List<StudentAttendance>;
      final boardingInfo = results[3] as BoardingInfoDraft?;
      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        _schools = schools;
        _classLevels = classLevelsForEducationLevel(
          boardingInfo?.educationLevel,
        );
        _boardingType = boardingInfo?.boardingType;
        _attendanceByStudent = {
          for (final record in attendance) record.studentId: record.status,
        };
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
      _notify('Excel dosyası okunamadı: $error', AppNotificationTone.error);
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
        'Excel şablonu oluşturulamadı: $error',
        AppNotificationTone.error,
      );
    }
  }

  Future<void> _openSchoolSettings() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return SchoolSettingsDialog(repository: widget.repository);
      },
    );
    if (changed == true) {
      await _refreshStudents();
    }
  }

  Future<void> _addAttendance(
    Student student,
    StudentAttendanceStatus status,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: status == StudentAttendanceStatus.homeLeave
          ? 'İzin tarihini seçin'
          : 'Rapor tarihini seçin',
    );
    if (date == null || !mounted) {
      return;
    }
    try {
      await widget.repository.saveAttendance(
        StudentAttendance(studentId: student.id!, date: date, status: status),
      );
      await _load();
      _notify(
        status == StudentAttendanceStatus.homeLeave
            ? 'Evci izin kaydı eklendi.'
            : 'Rapor kaydı eklendi.',
        AppNotificationTone.success,
      );
    } catch (_) {
      _notify('Yoklama kaydı kaydedilemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _setAttendanceStatus(
    Student student,
    StudentAttendanceStatus status,
  ) async {
    try {
      await widget.repository.saveAttendance(
        StudentAttendance(
          studentId: student.id!,
          date: _attendanceDate,
          status: status,
        ),
      );
      setState(() {
        _attendanceByStudent = {..._attendanceByStudent, student.id!: status};
      });
    } catch (_) {
      _notify('Yoklama durumu kaydedilemedi.', AppNotificationTone.error);
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

  Future<void> _changeAttendanceDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _attendanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() => _attendanceDate = date);
    await _load();
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

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                  },
                  onSubmitted: (_) => _refreshStudents(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Öğrenci ara',
                  ),
                );
                final actions = <Widget>[
                  FilledButton.icon(
                    onPressed: _openStudentForm,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Öğrenci Ekle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSchoolSettings,
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Okul Ayarları'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Şablon'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _importFromExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Excel'),
                  ),
                ];

                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: actions,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 10),
                    for (var index = 0; index < actions.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      actions[index],
                    ],
                  ],
                );
              },
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Öğrenci Listesi'),
              Tab(text: 'Yoklama Çizelgesi'),
              Tab(text: 'Disiplin Kayıtları'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStudentList(),
                _buildAttendanceView(),
                _buildDisciplinePlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        title: 'Henüz öğrenci eklenmemiş',
        message: 'İlk öğrenciyi ekleyerek pansiyon kayıtlarını oluşturun.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: _students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final student = _students[index];
        return _StudentCard(
          student: student,
          onEdit: () => _openStudentForm(student),
          onLeave: () =>
              _addAttendance(student, StudentAttendanceStatus.homeLeave),
          onReport: () =>
              _addAttendance(student, StudentAttendanceStatus.medicalReport),
          onDiscipline: () => _openDisciplineDialog(student),
          onDelete: () => _deleteStudent(student),
        );
      },
    );
  }

  Widget _buildAttendanceView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Row(
            children: [
              Text(
                'Yoklama tarihi: ${_dateOnly(_attendanceDate)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _changeAttendanceDate,
                icon: const Icon(Icons.calendar_month),
                label: const Text('Tarih seç'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _students.isEmpty
              ? const _EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Yoklama için öğrenci yok',
                  message:
                      'Öğrenci ekledikten sonra günlük yoklama yapabilirsiniz.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  itemCount: _students.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final status =
                        _attendanceByStudent[student.id] ??
                        StudentAttendanceStatus.present;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(student.fullName),
                      subtitle: Text(student.schoolName ?? 'Okul seçilmedi'),
                      trailing: DropdownButton<StudentAttendanceStatus>(
                        value: status,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final item in StudentAttendanceStatus.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _setAttendanceStatus(student, value);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDisciplinePlaceholder() {
    return const _EmptyState(
      icon: Icons.gavel_outlined,
      title: 'Disiplin kayıtları',
      message:
          'Disiplin olay kayıtları burada tutulacak. Kayıt içeriği ve detayları '
          'sonraki aşamada belirlenecek.',
    );
  }

  Future<void> _openDisciplineDialog(Student student) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StudentDisciplineDialog(
        student: student,
        repository: widget.repository,
      ),
    );
    if (result == true) {
      _notify('Disiplin kaydı eklendi.', AppNotificationTone.success);
    }
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onLeave,
    required this.onReport,
    required this.onDiscipline,
    required this.onDelete,
  });

  final Student student;
  final VoidCallback onEdit;
  final VoidCallback onLeave;
  final VoidCallback onReport;
  final VoidCallback onDiscipline;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = student.fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.surface,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    student.schoolName ?? 'Okul seçilmedi',
                    if (student.gender != null) student.gender!.label,
                    if (student.className != null) 'Sınıf ${student.className}',
                    if (student.sectionName != null)
                      'Şube ${student.sectionName}',
                    if (student.phone != null) student.phone!,
                  ].join(' • '),
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: onLeave,
                child: const Text('İzin Ekle'),
              ),
              OutlinedButton(
                onPressed: onReport,
                child: const Text('Rapor Ekle'),
              ),
              OutlinedButton(
                onPressed: onDiscipline,
                child: const Text('Disiplin'),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
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
            Icon(icon, size: 58, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
