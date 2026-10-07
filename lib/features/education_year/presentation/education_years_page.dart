import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/education_year/data/education_year_repository.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

/// Eğitim öğretim yıllarını yönetir ve sonraki yıla aktarır.
///
/// Yeni yıl boş başlar. Kaynak yıldaki öğrenci ve öğretmenler seçilerek
/// hedef yıla taşınır; taşıma kopyalama değildir, kayıt yılı değişir.
class EducationYearsPage extends StatefulWidget {
  const EducationYearsPage({
    super.key,
    required this.repository,
    required this.studentRepository,
    required this.dutyRepository,
    this.onActiveYearChanged,
  });

  final EducationYearRepository repository;
  final StudentRepository studentRepository;
  final DutyRepository dutyRepository;

  /// Aktarım sonrası çağrılır; uygulama genelinde yıl değişir.
  final ValueChanged<int>? onActiveYearChanged;

  @override
  State<EducationYearsPage> createState() => _EducationYearsPageState();
}

class _EducationYearsPageState extends State<EducationYearsPage> {
  List<EducationYear> _years = const [];
  List<Student> _students = const [];
  List<DutyTeacher> _teachers = const [];
  final Set<int> _selectedStudents = {};
  final Set<int> _selectedTeachers = {};
  int _sourceYear = 0;
  int _targetYear = 0;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final years = await widget.repository.getYears();
      final source = years.isEmpty
          ? currentEducationYearStart()
          : years
                .firstWhere((year) => year.isActive, orElse: () => years.first)
                .startYear;
      final students = await widget.studentRepository.getStudents(
        educationYear: source,
      );
      final teachers = await widget.dutyRepository.getTeachers(
        educationYear: source,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _years = years;
        _sourceYear = source;
        _targetYear = _nextYearAfter(source, years);
        _students = students;
        _teachers = teachers;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Eğitim yılları okunamadı.', AppNotificationTone.error);
    }
  }

  /// Kaynak yıldan sonraki, henüz tanımlı olmayan yıl.
  int _nextYearAfter(int source, List<EducationYear> years) {
    var candidate = source + 1;
    while (years.any((year) => year.startYear == candidate)) {
      candidate++;
    }
    return candidate;
  }

  Future<void> _loadSourceRecords() async {
    try {
      final students = await widget.studentRepository.getStudents(
        educationYear: _sourceYear,
      );
      final teachers = await widget.dutyRepository.getTeachers(
        educationYear: _sourceYear,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _students = students;
        _teachers = teachers;
        _selectedStudents.clear();
        _selectedTeachers.clear();
      });
    } catch (_) {
      _notify('Yıl kayıtları okunamadı.', AppNotificationTone.error);
    }
  }

  Future<void> _createYear() async {
    setState(() => _isBusy = true);
    try {
      await widget.repository.createYear(_targetYear);
      await _load();
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _notify(
        '$_targetYear-${_targetYear + 1} eğitim öğretim yılı oluşturuldu. '
        'Boş başladı.',
        AppNotificationTone.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _notify('Eğitim yılı oluşturulamadı.', AppNotificationTone.error);
    }
  }

  Future<void> _activate(int startYear) async {
    setState(() => _isBusy = true);
    try {
      await widget.repository.setActiveYear(startYear);
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      widget.onActiveYearChanged?.call(startYear);
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _notify('Eğitim yılı etkinleştirilemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _transferSelected() async {
    if (_selectedStudents.isEmpty && _selectedTeachers.isEmpty) {
      _notify('Aktarılacak kayıt seçilmedi.', AppNotificationTone.error);
      return;
    }
    final studentCount = _selectedStudents.length;
    final teacherCount = _selectedTeachers.length;
    final target = _targetYear;
    setState(() => _isBusy = true);
    try {
      await widget.studentRepository.transferStudents(
        studentIds: _selectedStudents.toList(growable: false),
        educationYear: target,
      );
      await widget.dutyRepository.transferTeachers(
        teacherIds: _selectedTeachers.toList(growable: false),
        educationYear: target,
      );
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      await _loadSourceRecords();
      if (!mounted) {
        return;
      }
      _notify(
        '$studentCount öğrenci, $teacherCount öğretmen '
        '$target-${target + 1} yılına aktarıldı.',
        AppNotificationTone.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _notify('Aktarım yapılamadı.', AppNotificationTone.error);
    }
  }

  Future<void> _deleteYear(EducationYear year) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${year.label} yılını sil'),
        content: const Text(
          'Bu yıla ait öğrenci, öğretmen ve nöbet listeleri kalıcı olarak '
          'silinecek.',
        ),
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
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.repository.deleteYear(year.startYear);
      await _load();
    } catch (_) {
      _notify('Yıl silinemedi.', AppNotificationTone.error);
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _SectionCard(
          title: 'Eğitim Öğretim Yılları',
          subtitle:
              'Veriler seçili yıla göre tutulur. Yılı değiştirdiğinizde '
              'öğrenci, öğretmen ve nöbet listeleri o yılın kayıtlarını gösterir.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final year in _years)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _YearRow(
                    key: Key('education_year_row_${year.startYear}'),
                    year: year,
                    isBusy: _isBusy,
                    onActivate: () => _activate(year.startYear),
                    onDelete: () => _deleteYear(year),
                  ),
                ),
              const SizedBox(height: 10),
              _ResponsiveRow(
                children: [
                  _YearSelect(
                    label: 'Yeni yıl',
                    years: _years,
                    value: _targetYear,
                    onChanged: (value) =>
                        setState(() => _targetYear = value ?? _targetYear),
                  ),
                  FilledButton.icon(
                    key: const Key('create_education_year_button'),
                    onPressed: _isBusy ? null : _createYear,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Eğitim Yılı Oluştur'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Sonraki Yıla Aktar',
          subtitle:
              'Kaynak yıldaki kayıtları seçip hedef yıla taşıyın. Taşıma '
              'kopyalama değildir: kayıtlar yalnızca yıl değiştirir.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResponsiveRow(
                children: [
                  _YearSelect(
                    label: 'Kaynak yıl',
                    years: _years,
                    value: _sourceYear,
                    onChanged: (value) {
                      setState(() => _sourceYear = value ?? _sourceYear);
                      unawaited(_loadSourceRecords());
                    },
                  ),
                  _YearSelect(
                    label: 'Hedef yıl',
                    years: _years,
                    value: _targetYear,
                    allowNew: true,
                    onChanged: (value) =>
                        setState(() => _targetYear = value ?? _targetYear),
                  ),
                  FilledButton.icon(
                    key: const Key('transfer_records_button'),
                    onPressed: _isBusy ? null : _transferSelected,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text('Seçilenleri Aktar'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Öğrenciler (${_students.length})',
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (_students.isEmpty)
                const Text(
                  'Bu yılda kayıtlı öğrenci yok.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final student in _students)
                      if (student.id != null)
                        FilterChip(
                          key: Key('transfer_student_${student.id}'),
                          label: Text(student.fullName),
                          selected: _selectedStudents.contains(student.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedStudents.add(student.id!);
                            } else {
                              _selectedStudents.remove(student.id);
                            }
                          }),
                        ),
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                'Öğretmenler (${_teachers.length})',
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (_teachers.isEmpty)
                const Text(
                  'Bu yılda kayıtlı öğretmen yok.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final teacher in _teachers)
                      if (teacher.id != null)
                        FilterChip(
                          key: Key('transfer_teacher_${teacher.id}'),
                          label: Text(teacher.fullName),
                          selected: _selectedTeachers.contains(teacher.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedTeachers.add(teacher.id!);
                            } else {
                              _selectedTeachers.remove(teacher.id);
                            }
                          }),
                        ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    super.key,
    required this.year,
    required this.isBusy,
    required this.onActivate,
    required this.onDelete,
  });

  final EducationYear year;
  final bool isBusy;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: year.isActive
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.inputSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: year.isActive ? AppColors.primary : AppColors.inputBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            year.isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 20,
            color: year.isActive ? AppColors.primary : AppColors.secondaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              year.label,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (year.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Etkin',
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            TextButton(
              key: Key('activate_education_year_${year.startYear}'),
              onPressed: isBusy ? null : onActivate,
              child: const Text('Etkinleştir'),
            ),
          IconButton(
            key: Key('delete_education_year_${year.startYear}'),
            tooltip: 'Yılı sil',
            onPressed: isBusy || year.isActive ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _YearSelect extends StatelessWidget {
  const _YearSelect({
    required this.label,
    required this.years,
    required this.value,
    required this.onChanged,
    this.allowNew = false,
  });

  final String label;
  final List<EducationYear> years;
  final int value;
  final ValueChanged<int?> onChanged;

  /// Tanımlı olmayan yeni bir yıl da seçilebilsin mi.
  final bool allowNew;

  @override
  Widget build(BuildContext context) {
    final options = <int>{
      for (final year in years) year.startYear,
      value,
      if (allowNew) currentEducationYearStart(),
      if (allowNew) currentEducationYearStart() + 1,
    }.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text('$option-${option + 1}'),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
