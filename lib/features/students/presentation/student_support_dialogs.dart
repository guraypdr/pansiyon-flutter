import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_toggle.dart';

/// Öğrenci formu ve öğrenci listesinin ortak kullandığı okul ayarları diyaloğu.
///
/// Okul ekleme, düzenleme ve silme işlemlerinin yanında lise kademesinde
/// "Hazırlık" sınıfının kullanılıp kullanılmayacağını yönetir.
class SchoolSettingsDialog extends StatefulWidget {
  const SchoolSettingsDialog({
    super.key,
    required this.repository,
    this.boardingInfoRepository,
  });

  final StudentRepository repository;

  /// Verilirse sınıf düzeyi ayarları bölümü gösterilir.
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<SchoolSettingsDialog> createState() => _SchoolSettingsDialogState();
}

class _SchoolSettingsDialogState extends State<SchoolSettingsDialog> {
  final _nameController = TextEditingController();
  final _sectionController = TextEditingController();
  List<School> _schools = const [];
  int? _editingSchoolId;
  int? _sectionsSchoolId;
  String _sectionClassLevel = '';
  List<String> _draftSections = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _changed = false;
  String? _errorMessage;

  EducationLevel? _educationLevel;
  bool _hasPreparationGrade = true;
  List<String> _classLevels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _openSectionEditor(School school) {
    setState(() {
      _sectionsSchoolId = school.id;
      _sectionClassLevel = _classLevels.firstOrNull ?? '';
      _draftSections = List<String>.of(school.sectionsFor(_sectionClassLevel));
      _sectionController.clear();
      _errorMessage = null;
    });
  }

  void _changeSectionClassLevel(String value) {
    setState(() {
      _sectionClassLevel = value;
      final school = _schoolById(_sectionsSchoolId);
      _draftSections = List<String>.of(school?.sectionsFor(value) ?? const []);
      _sectionController.clear();
      _errorMessage = null;
    });
  }

  School? _schoolById(int? schoolId) {
    if (schoolId == null) {
      return null;
    }
    for (final school in _schools) {
      if (school.id == schoolId) {
        return school;
      }
    }
    return null;
  }

  void _closeSectionEditor() {
    setState(() {
      _sectionsSchoolId = null;
      _sectionClassLevel = '';
      _draftSections = const [];
      _sectionController.clear();
    });
  }

  void _addSection() {
    final value = _sectionController.text.trim().toUpperCase();
    if (value.isEmpty) {
      return;
    }
    if (_draftSections.any((section) => section.toUpperCase() == value)) {
      setState(() => _errorMessage = '"$value" şubesi zaten eklenmiş.');
      return;
    }
    setState(() {
      _draftSections = [..._draftSections, value];
      _sectionController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _saveSections(School school) async {
    final schoolId = school.id;
    if (schoolId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.saveSchoolSections(
        schoolId: schoolId,
        className: _sectionClassLevel,
        sections: _draftSections,
      );
      await _loadSchools();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _changed = true;
          _sectionsSchoolId = null;
          _sectionClassLevel = '';
          _draftSections = const [];
          _sectionController.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Şubeler kaydedilemedi.';
        });
      }
    }
  }

  Future<void> _load() async {
    final boardingInfoRepository = widget.boardingInfoRepository;
    final results = await Future.wait<Object?>([
      widget.repository.getSchools(),
      boardingInfoRepository?.load() ?? Future<BoardingInfoDraft?>.value(null),
    ]);
    if (!mounted) {
      return;
    }
    final boardingInfo = results[1] as BoardingInfoDraft?;
    setState(() {
      _schools = results[0] as List<School>;
      _educationLevel = boardingInfo?.educationLevel;
      _hasPreparationGrade = boardingInfo?.hasPreparationGrade ?? true;
      _classLevels = classLevelsForEducationLevel(
        _educationLevel,
        hasPreparationGrade: _hasPreparationGrade,
      );
      _isLoading = false;
    });
  }

  /// Düzenleme sırasında satır içi düzenleme alanına geçer.
  void _startEditing(School school) {
    setState(() {
      _editingSchoolId = school.id;
      _nameController.text = school.name;
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: school.name.length,
      );
      _errorMessage = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingSchoolId = null;
      _nameController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _saveSchool() async {
    final name = capitalizeWords(_nameController.text.trim());
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Okul adı boş olamaz.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final editingId = _editingSchoolId;
      await widget.repository.saveSchool(School(id: editingId, name: name));
      _nameController.clear();
      await _loadSchools();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _editingSchoolId = null;
          _changed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Bu isimde bir okul zaten kayıtlı.';
        });
      }
    }
  }

  Future<void> _loadSchools() async {
    final schools = await widget.repository.getSchools();
    if (mounted) {
      setState(() => _schools = schools);
    }
  }

  Future<void> _deleteSchool(School school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Okul silinsin mi?'),
        content: Text(
          '"${school.name}" silinecek. Bu okula kayıtlı öğrencilerin okul '
          'bağlantısı boşalır, öğrenci kayıtları korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorFeedback,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.deleteSchool(school.id!);
      await _loadSchools();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _changed = true;
          if (_editingSchoolId == school.id) {
            _editingSchoolId = null;
            _nameController.clear();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Okul silinemedi.';
        });
      }
    }
  }

  Future<void> _togglePreparationGrade(bool value) async {
    final repository = widget.boardingInfoRepository;
    if (repository == null) {
      return;
    }
    final previous = _hasPreparationGrade;
    setState(() {
      _hasPreparationGrade = value;
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await repository.setPreparationGradeEnabled(value);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _changed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasPreparationGrade = previous;
          _isSaving = false;
          _errorMessage = 'Sınıf düzeyi ayarı kaydedilemedi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Okul Ayarları',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('school_settings_close_button'),
                    tooltip: 'Kapat',
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: [
                        if (_educationLevel != null) ...[
                          _sectionTitle('Sınıf Düzeyleri'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.inputBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pansiyon kademesi: ${_educationLevel!.label}',
                                  style: const TextStyle(
                                    color: AppColors.darkText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_educationLevel ==
                                    EducationLevel.highSchool) ...[
                                  const SizedBox(height: 10),
                                  AppToggle(
                                    key: const Key('preparation_grade_toggle'),
                                    label: 'Hazırlık sınıfı var mı?',
                                    description:
                                        'Kapatılırsa sınıf düzeyi listesinden '
                                        '"Hazırlık" çıkarılır.',
                                    icon: Icons.school_outlined,
                                    value: _hasPreparationGrade,
                                    enabled: !_isSaving,
                                    onChanged: _togglePreparationGrade,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        _sectionTitle('Okullar'),
                        const SizedBox(height: 8),
                        _schoolEditor(),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.errorFeedback,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_schools.isEmpty)
                          const _EmptySchools()
                        else
                          for (final school in _schools) ...[
                            _schoolTile(school),
                            if (school != _schools.last)
                              const Divider(height: 1),
                          ],
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const Key('school_settings_done_button'),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, _changed),
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Tamam'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.secondary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _schoolEditor() {
    final isEditing = _editingSchoolId != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: const Key('school_name_field'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [capitalizeWordsFormatter],
            decoration: InputDecoration(
              labelText: isEditing ? 'Okul adını düzenle' : 'Yeni okul adı',
              prefixIcon: const Icon(Icons.school_outlined),
            ),
            onSubmitted: (_) => _saveSchool(),
          ),
        ),
        const SizedBox(width: 10),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: OutlinedButton(
              key: const Key('school_edit_cancel_button'),
              onPressed: _isSaving ? null : _cancelEditing,
              child: const Text('Vazgeç'),
            ),
          )
        else
          const SizedBox(width: 0),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: FilledButton.icon(
            key: const Key('school_submit_button'),
            onPressed: _isSaving ? null : _saveSchool,
            icon: Icon(isEditing ? Icons.save_outlined : Icons.add, size: 20),
            label: Text(isEditing ? 'Güncelle' : 'Ekle'),
          ),
        ),
      ],
    );
  }

  Widget _schoolTile(School school) {
    final isEditing = _editingSchoolId == school.id;
    final showsSections = _sectionsSchoolId == school.id;
    final sectionSummary = school.sectionsByClass.entries.isEmpty
        ? 'Şube tanımlanmamış'
        : school.sectionsByClass.entries
              .map(
                (entry) => entry.key.isEmpty
                    ? entry.value.join(' · ')
                    : '${entry.key}/${entry.value.join(', ')}',
              )
              .join('  |  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: Key('school_tile_${school.id}'),
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          leading: const Icon(Icons.school_outlined),
          title: Text(
            school.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: isEditing
              ? const Text(
                  'Yeni adı yazıp "Ekle" butonuna basın.',
                  style: TextStyle(fontSize: 12),
                )
              : Text(sectionSummary, style: const TextStyle(fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('school_sections_${school.id}'),
                tooltip: 'Şubeleri tanımla',
                onPressed: _isSaving
                    ? null
                    : () => showsSections
                          ? _closeSectionEditor()
                          : _openSectionEditor(school),
                icon: Icon(
                  showsSections ? Icons.expand_less : Icons.grid_view_outlined,
                ),
              ),
              IconButton(
                key: Key('school_edit_${school.id}'),
                tooltip: 'Düzenle',
                onPressed: _isSaving ? null : () => _startEditing(school),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: Key('school_delete_${school.id}'),
                tooltip: 'Sil',
                onPressed: _isSaving ? null : () => _deleteSchool(school),
                color: AppColors.errorFeedback,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        if (showsSections) _sectionEditor(school),
      ],
    );
  }

  Widget _sectionEditor(School school) {
    return Container(
      key: Key('school_sections_editor_${school.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${school.name} şubeleri',
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Şubeler sınıf düzeyine göre tanımlanır; öğrencinin okulu ve sınıf '
            'düzeyi seçilince listeye otomatik gelir.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_classLevels.isNotEmpty)
            DropdownButtonFormField<String>(
              key: Key('school_section_level_${school.id}'),
              initialValue: _sectionClassLevel,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Sınıf düzeyi',
                isDense: true,
              ),
              items: [
                for (final level in _classLevels)
                  DropdownMenuItem<String>(value: level, child: Text(level)),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value != null) {
                        _changeSectionClassLevel(value);
                      }
                    },
            ),
          if (_classLevels.isNotEmpty) const SizedBox(height: 10),
          if (_draftSections.isEmpty)
            Text(
              _sectionClassLevel.isEmpty
                  ? 'Henüz şube eklenmedi.'
                  : '$_sectionClassLevel için henüz şube eklenmedi.',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final section in _draftSections)
                  InputChip(
                    key: Key('school_section_chip_$section'),
                    label: Text(
                      _sectionClassLevel.isEmpty
                          ? section
                          : '$_sectionClassLevel/$section',
                    ),
                    onDeleted: _isSaving
                        ? null
                        : () => setState(() {
                            _draftSections = _draftSections
                                .where((item) => item != section)
                                .toList(growable: false);
                          }),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: Key('school_section_field_${school.id}'),
                  controller: _sectionController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Yeni şube',
                    hintText: 'Örn. B',
                    isDense: true,
                    counterText: '',
                  ),
                  onSubmitted: (_) => _addSection(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: Key('school_section_add_${school.id}'),
                onPressed: _isSaving ? null : _addSection,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: Key('school_section_save_${school.id}'),
              onPressed: _isSaving ? null : () => _saveSections(school),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Şubeleri kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySchools extends StatelessWidget {
  const _EmptySchools();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: const Text(
        'Henüz okul eklenmedi.',
        style: TextStyle(color: AppColors.secondaryText),
      ),
    );
  }
}

class StudentDisciplineDialog extends StatefulWidget {
  const StudentDisciplineDialog({
    super.key,
    required this.student,
    required this.repository,
  });

  final Student student;
  final StudentRepository repository;

  @override
  State<StudentDisciplineDialog> createState() =>
      _StudentDisciplineDialogState();
}

class _StudentDisciplineDialogState extends State<StudentDisciplineDialog> {
  final _descriptionController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showAppDatePicker(
      context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _date = date);
    }
  }

  Future<void> _save() async {
    if (widget.student.id == null) {
      return;
    }
    setState(() => _isSaving = true);
    await widget.repository.saveDisciplineIncident(
      StudentDisciplineIncident(
        studentId: widget.student.id!,
        date: _date,
        description: _descriptionController.text.trim().isEmpty
            ? 'Detayı henüz belirlenmedi.'
            : _descriptionController.text.trim(),
      ),
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.student.fullName} - Disiplin Kaydı'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDateField(
              fieldKey: const Key('discipline_date_field'),
              label: 'Olay tarihi',
              value: _date,
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Olay açıklaması',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Kaydediliyor' : 'Kaydet'),
        ),
      ],
    );
  }
}
