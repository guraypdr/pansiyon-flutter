import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

class StudentFormDialog extends StatefulWidget {
  const StudentFormDialog({
    super.key,
    required this.repository,
    required this.schools,
    this.student,
    this.classLevels = const [],
    this.boardingType,
  });

  final StudentRepository repository;
  final List<School> schools;
  final Student? student;
  final List<String> classLevels;

  /// Pansiyon türü. Tek cinsiyetli pansiyonda cinsiyet alanı kilitlenir.
  final BoardingType? boardingType;

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late int? _schoolId;
  late StudentGender? _gender;
  late final StudentGender? _lockedGender;
  late StudentLivingArrangement _livingArrangement;
  late ParentLivingStatus _parentsLiveTogether;
  late bool _hasChronicDisease;
  late bool _hasAllergy;
  late bool _hasPsychologicalCondition;
  late bool _motherAlive;
  late bool _fatherAlive;
  DateTime? _birthDate;
  DateTime? _boardingRegistrationDate;
  int _currentStep = 0;
  bool _isSaving = false;
  String? _errorMessage;

  static const _steps = [
    'Kimlik ve Okul',
    'İletişim ve Sağlık',
    'Veli ve Yaşam',
  ];

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _schoolId = student?.schoolId;
    _lockedGender = lockedGenderForBoardingType(widget.boardingType);
    _gender = _lockedGender ?? student?.gender;
    _livingArrangement =
        student?.livingArrangement ?? StudentLivingArrangement.withMotherFather;
    _parentsLiveTogether =
        student?.parentsLiveTogether ?? ParentLivingStatus.together;
    _hasChronicDisease = student?.hasChronicDisease ?? false;
    _hasAllergy = student?.hasAllergy ?? false;
    _hasPsychologicalCondition = student?.hasPsychologicalCondition ?? false;
    _motherAlive = student?.motherAlive ?? true;
    _fatherAlive = student?.fatherAlive ?? true;
    _birthDate = student?.birthDate;
    _boardingRegistrationDate = student?.boardingRegistrationDate;
    _controllers = {
      'fullName': _controller(student?.fullName),
      'nationalId': _controller(student?.nationalId),
      'className': _controller(student?.className),
      'sectionName': _controller(student?.sectionName),
      'schoolNumber': _controller(student?.schoolNumber),
      'address': _controller(student?.address),
      'phone': _controller(student?.phone),
      'chronicDiseaseDetails': _controller(student?.chronicDiseaseDetails),
      'allergyDetails': _controller(student?.allergyDetails),
      'regularMedication': _controller(student?.regularMedication),
      'psychologicalConditionDetails': _controller(
        student?.psychologicalConditionDetails,
      ),
      'motherName': _controller(student?.motherName),
      'fatherName': _controller(student?.fatherName),
      'motherPhone': _controller(student?.motherPhone),
      'fatherPhone': _controller(student?.fatherPhone),
      'guardianName': _controller(student?.guardianName),
      'guardianRelation': _controller(student?.guardianRelation),
      'guardianPhone': _controller(student?.guardianPhone),
      'emergencyContactName': _controller(student?.emergencyContactName),
      'emergencyContactPhone': _controller(student?.emergencyContactPhone),
    };
  }

  TextEditingController _controller(String? value) {
    return TextEditingController(text: value ?? '');
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => capitalizeWords(_controllers[key]!.text.trim());

  String _defaultEmergencyName() {
    if (_livingArrangement == StudentLivingArrangement.other &&
        _value('guardianName').isNotEmpty) {
      return _value('guardianName');
    }
    if (_motherAlive && _value('motherName').isNotEmpty) {
      return _value('motherName');
    }
    if (_fatherAlive && _value('fatherName').isNotEmpty) {
      return _value('fatherName');
    }
    return _value('guardianName');
  }

  String _defaultEmergencyPhone() {
    if (_livingArrangement == StudentLivingArrangement.other &&
        _value('guardianPhone').isNotEmpty) {
      return _value('guardianPhone');
    }
    if (_motherAlive && _value('motherPhone').isNotEmpty) {
      return _value('motherPhone');
    }
    if (_fatherAlive && _value('fatherPhone').isNotEmpty) {
      return _value('fatherPhone');
    }
    return _value('guardianPhone');
  }

  Future<void> _pickDate({required bool birthDate}) async {
    final current = birthDate ? _birthDate : _boardingRegistrationDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (birthDate) {
        _birthDate = picked;
      } else {
        _boardingRegistrationDate = picked;
      }
    });
  }

  void _nextStep() {
    if (_currentStep >= _steps.length - 1) {
      _save();
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _selectStep(int step) {
    if (step <= _currentStep) {
      setState(() => _currentStep = step);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final existing = widget.student;
    final student = Student(
      id: existing?.id,
      fullName: _value('fullName'),
      gender: _gender,
      nationalId: _nullIfEmpty(_value('nationalId')),
      schoolId: _schoolId,
      className: _nullIfEmpty(_value('className')),
      sectionName: _nullIfEmpty(_value('sectionName')),
      schoolNumber: _nullIfEmpty(_value('schoolNumber')),
      birthDate: _birthDate,
      address: _nullIfEmpty(_value('address')),
      phone: _nullIfEmpty(_value('phone')),
      hasChronicDisease: _hasChronicDisease,
      chronicDiseaseDetails: _nullIfEmpty(_value('chronicDiseaseDetails')),
      hasAllergy: _hasAllergy,
      allergyDetails: _nullIfEmpty(_value('allergyDetails')),
      regularMedication: _nullIfEmpty(_value('regularMedication')),
      hasPsychologicalCondition: _hasPsychologicalCondition,
      psychologicalConditionDetails: _nullIfEmpty(
        _value('psychologicalConditionDetails'),
      ),
      livingArrangement: _livingArrangement,
      motherName: _nullIfEmpty(_value('motherName')),
      fatherName: _nullIfEmpty(_value('fatherName')),
      motherPhone: _nullIfEmpty(_value('motherPhone')),
      fatherPhone: _nullIfEmpty(_value('fatherPhone')),
      motherAlive: _motherAlive,
      fatherAlive: _fatherAlive,
      parentsLiveTogether: _parentsLiveTogether,
      guardianName: _nullIfEmpty(_value('guardianName')),
      guardianRelation: _nullIfEmpty(_value('guardianRelation')),
      guardianPhone: _nullIfEmpty(_value('guardianPhone')),
      emergencyContactName: _nullIfEmpty(
        _value('emergencyContactName').isEmpty
            ? _defaultEmergencyName()
            : _value('emergencyContactName'),
      ),
      emergencyContactPhone: _nullIfEmpty(
        _value('emergencyContactPhone').isEmpty
            ? _defaultEmergencyPhone()
            : _value('emergencyContactPhone'),
      ),
      boardingRegistrationDate: _boardingRegistrationDate,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );

    try {
      await widget.repository.saveStudent(student);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on StudentDataIntegrityException catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Öğrenci bilgileri kaydedilemedi.';
        });
      }
    }
  }

  String? _nullIfEmpty(String value) {
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 780),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.student == null
                          ? 'Öğrenci Ekle'
                          : 'Öğrenci Düzenle',
                      style: const TextStyle(
                        color: AppColors.sidebar,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
              child: _StudentStepProgress(
                steps: _steps,
                currentStep: _currentStep,
                onSelected: _selectStep,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.errorFeedback,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    _buildCurrentStep(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _isSaving ? null : _previousStep,
                      child: const Text('Geri'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _nextStep,
                    icon: Icon(
                      _currentStep == _steps.length - 1
                          ? Icons.save_outlined
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      _currentStep == _steps.length - 1
                          ? (_isSaving ? 'Kaydediliyor' : 'Kaydet')
                          : 'Devam',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _contactAndHealthStep();
      case 2:
        return _guardianStep();
      default:
        return _identityStep();
    }
  }

  Widget _identityStep() {
    return _StudentFormSection(
      title: 'Kimlik ve Okul Bilgileri',
      subtitle: 'Öğrencinin kimlik ve okul bilgilerini girin.',
      child: _responsive([
        _input(
          'Ad Soyad',
          key: 'fullName',
          validator: (value) => requiredField(value, 'Ad soyad'),
        ),
        _input(
          'T.C. Kimlik No',
          key: 'nationalId',
          keyboardType: TextInputType.number,
          formatters: phoneDigitsFormatters,
          validator: nationalIdValidator,
        ),
        _schoolDropdown(),
        _genderDropdown(),
        _classDropdown(),
        _input('Şube', key: 'sectionName'),
        _input('Okul No', key: 'schoolNumber'),
        _dateField(
          label: 'Doğum Tarihi',
          value: _birthDate,
          onPressed: () => _pickDate(birthDate: true),
        ),
      ]),
    );
  }

  Widget _contactAndHealthStep() {
    return _StudentFormSection(
      title: 'İletişim ve Sağlık Bilgileri',
      subtitle: 'İletişim ve öğrencinin sağlık bilgilerini girin.',
      child: Column(
        children: [
          _responsive([
            _input('Adres', key: 'address', maxLines: 3),
            _input(
              'Telefon',
              key: 'phone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
            _dateField(
              label: 'Pansiyon Kayıt Tarihi',
              value: _boardingRegistrationDate,
              onPressed: () => _pickDate(birthDate: false),
            ),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sürekli hastalığı var mı?'),
            value: _hasChronicDisease,
            onChanged: (value) => setState(() => _hasChronicDisease = value),
          ),
          if (_hasChronicDisease)
            _input(
              'Sürekli Hastalık',
              key: 'chronicDiseaseDetails',
              maxLines: 2,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alerjisi var mı?'),
            value: _hasAllergy,
            onChanged: (value) => setState(() => _hasAllergy = value),
          ),
          if (_hasAllergy)
            _input('Alerji Bilgisi', key: 'allergyDetails', maxLines: 2),
          _input(
            'Sürekli Kullandığı İlaç',
            key: 'regularMedication',
            maxLines: 2,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Psikolojik rahatsızlığı var mı?'),
            value: _hasPsychologicalCondition,
            onChanged: (value) =>
                setState(() => _hasPsychologicalCondition = value),
          ),
          if (_hasPsychologicalCondition)
            _input(
              'Psikolojik Bilgi',
              key: 'psychologicalConditionDetails',
              maxLines: 2,
            ),
        ],
      ),
    );
  }

  Widget _guardianStep() {
    return _StudentFormSection(
      title: 'Veli ve Yaşam Bilgileri',
      subtitle: 'Veli, aile ve acil iletişim bilgilerini girin.',
      child: Column(
        children: [
          _LabelledInput(
            label: 'Öğrenci Kimlerle Yaşıyor?',
            child: DropdownButtonFormField<StudentLivingArrangement>(
              initialValue: _livingArrangement,
              decoration: const InputDecoration(),
              isExpanded: true,
              items: [
                for (final item in StudentLivingArrangement.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _livingArrangement = value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _responsive([
            _input('Anne Adı', key: 'motherName'),
            _input('Baba Adı', key: 'fatherName'),
            _input(
              'Anne Telefonu',
              key: 'motherPhone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
            _input(
              'Baba Telefonu',
              key: 'fatherPhone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
          ]),
          const SizedBox(height: 8),
          _responsive([
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Anne Hayatta mı?'),
              value: _motherAlive,
              onChanged: (value) => setState(() => _motherAlive = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Baba Hayatta mı?'),
              value: _fatherAlive,
              onChanged: (value) => setState(() => _fatherAlive = value),
            ),
          ]),
          const SizedBox(height: 8),
          _LabelledInput(
            label: 'Anne ve Baba Birlikte mi Yaşıyor?',
            child: DropdownButtonFormField<ParentLivingStatus>(
              initialValue: _parentsLiveTogether,
              decoration: const InputDecoration(),
              isExpanded: true,
              items: [
                for (final item in ParentLivingStatus.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _parentsLiveTogether = value);
                }
              },
            ),
          ),
          if (_livingArrangement !=
              StudentLivingArrangement.withMotherFather) ...[
            const SizedBox(height: 12),
            _responsive([
              _input('Birlikte Yaşadığı Kişi', key: 'guardianName'),
              _input('Yakınlık', key: 'guardianRelation'),
              _input(
                'Telefon',
                key: 'guardianPhone',
                keyboardType: TextInputType.phone,
                formatters: phoneDigitsFormatters,
                validator: phoneNumberValidator,
              ),
            ]),
          ],
          const SizedBox(height: 12),
          _responsive([
            _input(
              'Acil Ulaşılacak Kişi',
              key: 'emergencyContactName',
              helperText: 'Boş bırakılırsa veli bilgilerinden seçilir.',
            ),
            _input(
              'Acil Telefon',
              key: 'emergencyContactPhone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _input(
    String label, {
    required String key,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? helperText,
    bool capitalize = true,
  }) {
    return _LabelledInput(
      label: label,
      helperText: helperText,
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: keyboardType,
        textCapitalization: capitalize
            ? TextCapitalization.words
            : TextCapitalization.none,
        inputFormatters: capitalize
            ? [capitalizeWordsFormatter, ...?formatters]
            : formatters,
        maxLines: maxLines,
        style: AppTheme.inputTextStyle,
        decoration: const InputDecoration(),
        validator: validator,
      ),
    );
  }

  Widget _genderDropdown() {
    final locked = _lockedGender;
    if (locked != null) {
      return _LabelledInput(
        label: 'Cinsiyet',
        helperText:
            'Pansiyon türü ${widget.boardingType?.label ?? ''} olduğu için '
            'cinsiyet sabittir.',
        child: Container(
          key: const Key('gender_locked_field'),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.inputSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              Text(locked.label, style: AppTheme.inputTextStyle),
              const Spacer(),
              const Icon(
                Icons.lock_outline,
                size: 16,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      );
    }

    final allowed = allowedGendersForBoardingType(widget.boardingType);
    return _LabelledInput(
      label: 'Cinsiyet',
      child: DropdownButtonFormField<StudentGender?>(
        initialValue: _gender,
        isExpanded: true,
        decoration: const InputDecoration(),
        items: [
          const DropdownMenuItem<StudentGender?>(
            value: null,
            child: Text('Cinsiyet seçilmedi'),
          ),
          for (final gender in allowed)
            DropdownMenuItem<StudentGender?>(
              value: gender,
              child: Text(gender.label),
            ),
        ],
        onChanged: (value) => setState(() => _gender = value),
        validator: (value) => value == null ? 'Cinsiyet seçilmelidir.' : null,
      ),
    );
  }

  Widget _classDropdown() {
    if (widget.classLevels.isEmpty) {
      return _input('Sınıf', key: 'className');
    }

    final currentValue = _controllers['className']!.text.trim();
    final options = <String>{
      ...widget.classLevels,
      if (currentValue.isNotEmpty) currentValue,
    }.toList(growable: false);
    final selectedValue = options.contains(currentValue) ? currentValue : null;

    return _LabelledInput(
      label: 'Sınıf',
      child: DropdownButtonFormField<String?>(
        initialValue: selectedValue,
        isExpanded: true,
        decoration: const InputDecoration(),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Sınıf seçilmedi'),
          ),
          for (final level in options)
            DropdownMenuItem<String?>(value: level, child: Text(level)),
        ],
        onChanged: (value) {
          _controllers['className']!.text = value ?? '';
        },
      ),
    );
  }

  Widget _schoolDropdown() {
    return _LabelledInput(
      label: 'Okul',
      child: DropdownButtonFormField<int?>(
        initialValue: _schoolId,
        isExpanded: true,
        decoration: const InputDecoration(),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Okul seçilmedi'),
          ),
          for (final school in widget.schools)
            DropdownMenuItem<int?>(value: school.id, child: Text(school.name)),
        ],
        onChanged: (value) => setState(() => _schoolId = value),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
  }) {
    return _LabelledInput(
      label: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_month),
        label: Text(value == null ? 'Tarih seç' : _formatDate(value)),
      ),
    );
  }

  Widget _responsive(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var index = 0; index < children.length; index += 2)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index + 2 < children.length ? 12 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[index]),
                    if (index + 1 < children.length) ...[
                      const SizedBox(width: 12),
                      Expanded(child: children[index + 1]),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}.$month.$day';
  }
}

class _StudentStepProgress extends StatelessWidget {
  const _StudentStepProgress({
    required this.steps,
    required this.currentStep,
    required this.onSelected,
  });

  final List<String> steps;
  final int currentStep;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < steps.length; index++) ...[
                _StudentStepItem(
                  index: index,
                  label: steps[index],
                  currentStep: currentStep,
                  onSelected: () => onSelected(index),
                ),
                if (index != steps.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              Expanded(
                child: _StudentStepItem(
                  index: index,
                  label: steps[index],
                  currentStep: currentStep,
                  onSelected: () => onSelected(index),
                ),
              ),
              if (index != steps.length - 1)
                Container(
                  width: 32,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: index < currentStep
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.55),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StudentStepItem extends StatelessWidget {
  const _StudentStepItem({
    required this.index,
    required this.label,
    required this.currentStep,
    required this.onSelected,
  });

  final int index;
  final String label;
  final int currentStep;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final completed = index < currentStep;
    final current = index == currentStep;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: index <= currentStep ? onSelected : null,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: current
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  )
                : null,
            color: current
                ? null
                : completed
                ? AppColors.softMagenta
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: current
                  ? AppColors.transparent
                  : completed
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.border.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current
                      ? AppColors.surface
                      : completed
                      ? AppColors.primary
                      : AppColors.softMagenta,
                  shape: BoxShape.circle,
                ),
                child: completed
                    ? const Icon(
                        Icons.check,
                        color: AppColors.surface,
                        size: 15,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: current
                              ? AppColors.primary
                              : AppColors.darkText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: current
                        ? AppColors.surface
                        : completed
                        ? AppColors.darkText
                        : AppColors.secondaryText,
                    fontSize: 12.5,
                    fontWeight: current || completed
                        ? FontWeight.w700
                        : FontWeight.w600,
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

class _StudentFormSection extends StatelessWidget {
  const _StudentFormSection({
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.cardSurfaceAccent],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeWords(title),
                      style: const TextStyle(
                        color: AppColors.sidebar,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _LabelledInput extends StatelessWidget {
  const _LabelledInput({
    required this.label,
    required this.child,
    this.helperText,
  });

  final String label;
  final Widget child;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capitalizeWords(label.trim()),
          style: const TextStyle(
            color: AppColors.secondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        child,
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
