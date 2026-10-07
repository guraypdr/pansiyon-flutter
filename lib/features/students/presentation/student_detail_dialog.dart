import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_form_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';

/// Öğrenci detay ekranı.
///
/// İzin, rapor ve disiplin işlemleri bu ekrandan yürütülür; liste kartlarında
/// yalnızca detay, düzenleme ve silme kısayolları bulunur.
class StudentDetailDialog extends StatefulWidget {
  const StudentDetailDialog({
    super.key,
    required this.repository,
    required this.studentId,
    required this.schools,
    this.classLevels = const [],
    this.boardingType,
    this.boardingInfoRepository,
  });

  final StudentRepository repository;
  final int studentId;
  final List<School> schools;
  final List<String> classLevels;
  final BoardingType? boardingType;

  /// Düzenleme formundaki okul ayarları için kullanılır.
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<StudentDetailDialog> createState() => _StudentDetailDialogState();
}

class _StudentDetailDialogState extends State<StudentDetailDialog> {
  Student? _student;
  List<StudentAttendance> _attendance = const [];
  List<StudentDisciplineIncident> _incidents = const [];
  bool _isLoading = true;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.repository.getStudent(widget.studentId),
        widget.repository.getAttendance(studentId: widget.studentId),
        widget.repository.getDisciplineIncidents(widget.studentId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _student = results[0] as Student?;
        _attendance = results[1] as List<StudentAttendance>;
        _incidents = results[2] as List<StudentDisciplineIncident>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Öğrenci bilgileri okunamadı.');
    }
  }

  Future<void> _addAttendance(StudentAttendanceStatus status) async {
    final student = _student;
    if (student == null || _isWorking) {
      return;
    }
    final date = await showAppDatePicker(
      context,
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
    setState(() => _isWorking = true);
    try {
      await widget.repository.saveAttendance(
        StudentAttendance(studentId: student.id!, date: date, status: status),
      );
      await _load();
      _notify('Kayıt eklendi.', AppNotificationTone.success);
    } catch (_) {
      _notify('Kayıt eklenemedi.');
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _openDiscipline() async {
    final student = _student;
    if (student == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StudentDisciplineDialog(
        student: student,
        repository: widget.repository,
      ),
    );
    await _load();
  }

  Future<void> _openEditForm() async {
    final student = _student;
    if (student == null) {
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StudentFormDialog(
        repository: widget.repository,
        schools: widget.schools,
        student: student,
        classLevels: widget.classLevels,
        boardingType: widget.boardingType,
        boardingInfoRepository: widget.boardingInfoRepository,
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  void _notify(
    String message, [
    AppNotificationTone tone = AppNotificationTone.error,
  ]) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Öğrenci Detayı',
                      style: const TextStyle(
                        color: AppColors.sidebar,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('detail_close_button'),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final student = _student;
    if (student == null) {
      return const Center(child: Text('Öğrenci bulunamadı.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 20 : 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailHeader(
                    student: student,
                    isWorking: _isWorking,
                    onEdit: _openEditForm,
                    onLeave: () =>
                        _addAttendance(StudentAttendanceStatus.homeLeave),
                    onReport: () =>
                        _addAttendance(StudentAttendanceStatus.medicalReport),
                    onDiscipline: _openDiscipline,
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Kimlik ve İletişim',
                    rows: [
                      _DetailRow(
                        label: 'Okul',
                        value: student.schoolName ?? 'Okul seçilmedi',
                      ),
                      _DetailRow(
                        label: 'Sınıf / Şube',
                        value: formatClassSectionLabel(
                          student.className,
                          student.sectionName,
                        ),
                      ),
                      _DetailRow(label: 'Okul No', value: student.schoolNumber),
                      _DetailRow(
                        label: 'T.C. Kimlik No',
                        value: student.nationalId,
                      ),
                      _DetailRow(
                        label: 'Doğum Tarihi',
                        value: _formatDate(student.birthDate),
                      ),
                      _DetailRow(label: 'Telefon', value: student.phone),
                      _DetailRow(label: 'Adres', value: student.address),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Sağlık',
                    rows: [
                      _DetailRow(
                        label: 'Kronik Hastalık',
                        value: student.hasChronicDisease
                            ? (student.chronicDiseaseDetails ?? 'Var')
                            : 'Yok',
                      ),
                      _DetailRow(
                        label: 'Alerji',
                        value: student.hasAllergy
                            ? (student.allergyDetails ?? 'Var')
                            : 'Yok',
                      ),
                      _DetailRow(
                        label: 'Düzlü İlaç',
                        value: student.regularMedication,
                      ),
                      _DetailRow(label: 'Kan Grubu', value: student.bloodType),
                      _DetailRow(
                        label: 'Psikolojik Durum',
                        value: student.hasPsychologicalCondition
                            ? (student.psychologicalConditionDetails ?? 'Var')
                            : 'Yok',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Veli Bilgileri',
                    rows: [
                      _DetailRow(
                        label: 'Veli',
                        value: [
                          student.guardianName,
                          student.guardianRelation,
                          student.guardianPhone,
                        ].whereType<String>().join(' · '),
                      ),
                      _DetailRow(
                        label: 'Veli Adresi',
                        value: student.guardianAddress ?? '',
                      ),
                      _DetailRow(
                        label: 'Diğer Veli',
                        value: [
                          student.guardian2Name,
                          student.guardian2Relation,
                          student.guardian2Phone,
                        ].whereType<String>().join(' · '),
                      ),
                      _DetailRow(
                        label: 'Diğer Veli Adresi',
                        value: student.guardian2Address ?? '',
                      ),
                      _DetailRow(
                        label: 'Acil Durum',
                        value: [
                          student.emergencyContactName,
                          student.emergencyContactPhone,
                        ].whereType<String>().join(' · '),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Yoklama Kayıtları',
                    rows: [
                      for (final record in _attendance)
                        _DetailRow(
                          label: _formatDate(record.date),
                          value: record.status.label,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Disiplin Kayıtları',
                    rows: [
                      for (final incident in _incidents)
                        _DetailRow(
                          label: _formatDate(incident.date),
                          value: incident.description,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.student,
    required this.isWorking,
    required this.onEdit,
    required this.onLeave,
    required this.onReport,
    required this.onDiscipline,
  });

  final Student student;
  final bool isWorking;
  final VoidCallback onEdit;
  final VoidCallback onLeave;
  final VoidCallback onReport;
  final VoidCallback onDiscipline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.cardSurfaceAccent],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentGenderAvatar(gender: student.gender, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (student.className != null)
                          'Sınıf ${student.className}',
                        if (student.schoolName != null) student.schoolName!,
                        if (student.gender != null) student.gender!.label,
                      ].join(' • '),
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('detail_leave_button'),
                onPressed: isWorking ? null : onLeave,
                icon: const Icon(Icons.beach_access_outlined),
                label: const Text('İzin Ekle'),
              ),
              FilledButton.tonalIcon(
                key: const Key('detail_report_button'),
                onPressed: isWorking ? null : onReport,
                icon: const Icon(Icons.medical_information_outlined),
                label: const Text('Rapor Ekle'),
              ),
              OutlinedButton.icon(
                key: const Key('detail_discipline_button'),
                onPressed: isWorking ? null : onDiscipline,
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('Disiplin Kaydı'),
              ),
              OutlinedButton.icon(
                key: const Key('detail_edit_button'),
                onPressed: isWorking ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Düzenle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final hasRows = rows.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasRows)
            const Text(
              'Kayıt yok.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            )
          else
            for (final row in rows) ...[row, const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim() ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text.isEmpty ? '-' : text,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cinsiyete göre renklenen avatar ikonu.
class StudentGenderAvatar extends StatelessWidget {
  const StudentGenderAvatar({super.key, required this.gender, this.size = 44});

  final StudentGender? gender;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isFemale = gender == StudentGender.female;
    final isMale = gender == StudentGender.male;
    final background = isFemale
        ? const Color(0xFFFCE4F0)
        : isMale
        ? const Color(0xFFDCE9FB)
        : AppColors.softMagenta;
    final foreground = isFemale
        ? const Color(0xFFB3156B)
        : isMale
        ? const Color(0xFF1B4F9C)
        : AppColors.secondaryText;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Icon(
        isFemale
            ? Icons.face_3
            : isMale
            ? Icons.face_6
            : Icons.person_outline,
        color: foreground,
        size: size * 0.55,
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}
