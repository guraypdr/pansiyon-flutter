import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_date_field.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_labelled_field.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_toggle.dart';

class StudentFormDialog extends StatefulWidget {
  const StudentFormDialog({
    super.key,
    required this.repository,
    required this.schools,
    this.student,
    this.classLevels = const [],
    this.boardingType,
    this.boardingInfoRepository,
  });

  final StudentRepository repository;
  final List<School> schools;
  final Student? student;
  final List<String> classLevels;

  /// Pansiyon türü. Tek cinsiyetli pansiyonda cinsiyet alanı kilitlenir.
  final BoardingType? boardingType;

  /// Verilirse okul ayarları diyaloğunda sınıf düzeyi seçenekleri yönetilir.
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late int? _schoolId;
  late StudentGender? _gender;
  late final StudentGender? _lockedGender;
  late bool _hasChronicDisease;
  late bool _hasAllergy;
  late bool _hasPsychologicalCondition;
  late bool _hasRegularMedication;
  DateTime? _birthDate;
  DateTime? _boardingRegistrationDate;
  int _currentStep = 0;
  bool _isSaving = false;
  String? _errorMessage;

  /// Diyalog içinde eklenen okulların anında görünmesi için yerel kopya.
  late List<School> _schools;

  static const _steps = ['Kimlik ve İletişim', 'Veli'];

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _schools = widget.schools;
    _schoolId = student?.schoolId;
    _lockedGender = lockedGenderForBoardingType(widget.boardingType);
    _gender = _lockedGender ?? student?.gender;
    _hasChronicDisease = student?.hasChronicDisease ?? false;
    _hasAllergy = student?.hasAllergy ?? false;
    _hasPsychologicalCondition = student?.hasPsychologicalCondition ?? false;
    _hasRegularMedication = (student?.regularMedication ?? '')
        .trim()
        .isNotEmpty;
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
      'bloodType': _controller(student?.bloodType),
      'psychologicalConditionDetails': _controller(
        student?.psychologicalConditionDetails,
      ),
      'guardianName': _controller(student?.guardianName),
      'guardianRelation': _controller(student?.guardianRelation),
      'guardianPhone': _controller(student?.guardianPhone),
      'guardianAddress': _controller(student?.guardianAddress),
      'guardian2Name': _controller(student?.guardian2Name),
      'guardian2Relation': _controller(student?.guardian2Relation),
      'guardian2Phone': _controller(student?.guardian2Phone),
      'guardian2Address': _controller(student?.guardian2Address),
      'emergencyContactName': _controller(student?.emergencyContactName),
      'emergencyContactPhone': _controller(student?.emergencyContactPhone),
    };
    // Kayıtlı şube, okulun tanımlı şubeleriyle uyumlu değilse boşaltılır.
    _syncSectionWithSchool();
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

  /// Formda acil iletişim alanı yoktur; birincil veliden türetilir.
  String _defaultEmergencyName() => _value('guardianName');

  /// Birincil veli yoksa ikincil veliye düşer.
  String _defaultEmergencyPhone() {
    final primary = _value('guardianPhone');
    return primary.isNotEmpty ? primary : _value('guardian2Phone');
  }

  Future<void> _pickDate({required bool birthDate}) async {
    final current = birthDate ? _birthDate : _boardingRegistrationDate;
    final picked = await showAppDatePicker(
      context,
      initialDate: current ?? DateTime.now(),
      firstDate: birthDate ? DateTime(1940) : DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: birthDate ? 'Doğum tarihini seçin' : 'Kayıt tarihini seçin',
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

  /// Okul ayarları diyaloğunu açar ve okul listesini tazeler.
  Future<void> _openSchoolSettings() async {
    final repository = widget.repository;
    final boardingInfoRepository = widget.boardingInfoRepository;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SchoolSettingsDialog(
        repository: repository,
        boardingInfoRepository: boardingInfoRepository,
      ),
    );
    final schools = await repository.getSchools();
    if (!mounted) {
      return;
    }
    setState(() {
      _schools = schools;
      if (_schoolId != null &&
          !schools.any((school) => school.id == _schoolId)) {
        _schoolId = null;
      }
      // Okul kaldırıldıysa şube ataması da düşer.
      _syncSectionWithSchool();
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
      sectionName: _validSectionName(),
      schoolNumber: _nullIfEmpty(_value('schoolNumber')),
      birthDate: _birthDate,
      address: _nullIfEmpty(_value('address')),
      phone: _nullIfEmpty(_value('phone')),
      hasChronicDisease: _hasChronicDisease,
      chronicDiseaseDetails: _nullIfEmpty(_value('chronicDiseaseDetails')),
      hasAllergy: _hasAllergy,
      allergyDetails: _nullIfEmpty(_value('allergyDetails')),
      regularMedication: _nullIfEmpty(_value('regularMedication')),
      bloodType: _nullIfEmpty(_value('bloodType')),
      hasPsychologicalCondition: _hasPsychologicalCondition,
      psychologicalConditionDetails: _nullIfEmpty(
        _value('psychologicalConditionDetails'),
      ),
      guardianName: _nullIfEmpty(_value('guardianName')),
      guardianRelation: _nullIfEmpty(_value('guardianRelation')),
      guardianPhone: _nullIfEmpty(_value('guardianPhone')),
      guardianAddress: _nullIfEmpty(_value('guardianAddress')),
      guardian2Name: _nullIfEmpty(_value('guardian2Name')),
      guardian2Relation: _nullIfEmpty(_value('guardian2Relation')),
      guardian2Phone: _nullIfEmpty(_value('guardian2Phone')),
      guardian2Address: _nullIfEmpty(_value('guardian2Address')),
      // Formda acil iletişim alanı yok; kayıtlı değer korunur, yoksa veli
      // bilgisinden türetilir.
      emergencyContactName:
          _storedOrDefault(existing?.emergencyContactName) ??
          _defaultEmergencyName(),
      emergencyContactPhone:
          _storedOrDefault(existing?.emergencyContactPhone) ??
          _defaultEmergencyPhone(),
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

  /// Kayıtlı metni kırpar; boşsa `null` döner.
  ///
  /// Formda giriş alanı bulunmayan değerler için kullanılır: kayıtlı metin
  /// korunur, yoksa çağıran taraf varsayılanı sağlar.
  String? _storedOrDefault(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
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
    if (_currentStep == 1) {
      return _guardianStep();
    }
    return _identityStep();
  }

  Widget _identityStep() {
    return _StudentFormSection(
      title: 'Kimlik ve İletişim Bilgileri',
      subtitle: 'Kimlik, okul, iletişim ve sağlık bilgilerini girin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _responsive([
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
            _sectionDropdown(),
            _input('Okul No', key: 'schoolNumber'),
            _input('Adres', key: 'address', maxLines: 2),
            _dateField(
              fieldKey: const Key('student_birth_date_field'),
              label: 'Doğum Tarihi',
              value: _birthDate,
              onPressed: () => _pickDate(birthDate: true),
            ),
            _dateField(
              fieldKey: const Key('student_registration_date_field'),
              label: 'Pansiyon Kayıt Tarihi',
              value: _boardingRegistrationDate,
              onPressed: () => _pickDate(birthDate: false),
            ),
            _input(
              'Telefon',
              key: 'phone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
          ]),
          const SizedBox(height: 20),
          _healthToggles(),
        ],
      ),
    );
  }

  /// Sağlıkla ilgili dört soru ve kan grubu.
  Widget _healthToggles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sağlık',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _responsive([
          AppToggle(
            key: const Key('chronic_disease_toggle'),
            label: 'Sürekli hastalığı var mı?',
            icon: Icons.medical_information_outlined,
            value: _hasChronicDisease,
            enabled: !_isSaving,
            onChanged: (value) => setState(() => _hasChronicDisease = value),
          ),
          AppToggle(
            key: const Key('regular_medication_toggle'),
            label: 'Düzenli kullandığı ilaç var mı?',
            icon: Icons.medication_outlined,
            value: _hasRegularMedication,
            enabled: !_isSaving,
            onChanged: (value) => setState(() {
              _hasRegularMedication = value;
              if (!value) {
                _controllers['regularMedication']!.clear();
              }
            }),
          ),
          AppToggle(
            key: const Key('allergy_toggle'),
            label: 'Herhangi bir alerjisi var mı?',
            icon: Icons.healing_outlined,
            value: _hasAllergy,
            enabled: !_isSaving,
            onChanged: (value) => setState(() => _hasAllergy = value),
          ),
          AppToggle(
            key: const Key('psychological_toggle'),
            label: 'Psikolojik rahatsızlığı var mı?',
            icon: Icons.psychology_outlined,
            value: _hasPsychologicalCondition,
            enabled: !_isSaving,
            onChanged: (value) =>
                setState(() => _hasPsychologicalCondition = value),
          ),
        ]),
        if (_hasChronicDisease) ...[
          const SizedBox(height: 10),
          _input('Sürekli Hastalık', key: 'chronicDiseaseDetails', maxLines: 2),
        ],
        if (_hasRegularMedication) ...[
          const SizedBox(height: 10),
          _input('İlaç Bilgisi', key: 'regularMedication', maxLines: 2),
        ],
        if (_hasAllergy) ...[
          const SizedBox(height: 10),
          _input('Alerji Bilgisi', key: 'allergyDetails', maxLines: 2),
        ],
        if (_hasPsychologicalCondition) ...[
          const SizedBox(height: 10),
          _input(
            'Psikolojik Bilgi',
            key: 'psychologicalConditionDetails',
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 12),
        _bloodGroupDropdown(),
      ],
    );
  }

  Widget _bloodGroupDropdown() {
    final controller = _controllers['bloodType']!;
    final currentValue = controller.text.trim();
    final options = <String>{
      ...bloodGroupOptions,
      if (currentValue.isNotEmpty) currentValue,
    }.toList(growable: false);
    final selectedValue = options.contains(currentValue) ? currentValue : null;

    return AppDropdown<String>(
      key: const Key('student_blood_group_dropdown'),
      label: 'Kan Grubu',
      value: selectedValue,
      placeholder: 'Kan grubu seçilmedi',
      items: [
        for (final option in options)
          DropdownMenuItem<String>(value: option, child: Text(option)),
      ],
      onChanged: (value) => controller.text = value ?? '',
    );
  }

  Widget _guardianStep() {
    return _StudentFormSection(
      title: 'Veli Bilgileri',
      subtitle: 'Acil durumlarda ulaşılacak veli bilgilerini girin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Birincil Veli',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _responsive([
            _input('Ad Soyad', key: 'guardianName'),
            _input('Öğrenciye Yakınlığı', key: 'guardianRelation'),
            _input(
              'Telefon Numarası',
              key: 'guardianPhone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
            _input('Adresi', key: 'guardianAddress', maxLines: 2),
          ]),
          const SizedBox(height: 22),
          const Text(
            'İkincil Veli',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _responsive([
            _input('Ad Soyad', key: 'guardian2Name'),
            _input('Öğrenciye Yakınlığı', key: 'guardian2Relation'),
            _input(
              'Telefon Numarası',
              key: 'guardian2Phone',
              keyboardType: TextInputType.phone,
              formatters: phoneDigitsFormatters,
              validator: phoneNumberValidator,
            ),
            _input('Adresi', key: 'guardian2Address', maxLines: 2),
          ]),
        ],
      ),
    );
  }

  Widget _input(
    String label, {
    required String key,
    Key? fieldKey,
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
        key: fieldKey ?? Key('${key}_field'),
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
    return AppDropdown<StudentGender>(
      label: 'Cinsiyet',
      value: _gender,
      placeholder: 'Cinsiyet seçilmedi',
      items: [
        for (final gender in allowed)
          DropdownMenuItem<StudentGender>(
            value: gender,
            child: Text(gender.label),
          ),
      ],
      onChanged: (value) => setState(() => _gender = value),
      validator: (value) => value == null ? 'Cinsiyet seçilmelidir.' : null,
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

    return AppDropdown<String>(
      key: const Key('student_class_dropdown'),
      label: 'Sınıf',
      value: selectedValue,
      placeholder: 'Sınıf seçilmedi',
      items: [
        for (final level in options)
          DropdownMenuItem<String>(value: level, child: Text(level)),
      ],
      onChanged: (value) => setState(() {
        _controllers['className']!.text = value ?? '';
        // Sınıf düzeyi değişince şube listesi ve ataması yenilenir.
        _syncSectionWithSchool();
      }),
    );
  }

  /// Şubeyi yalnızca seçili okulun, seçili sınıf düzeyine ait tanımlı
  /// şubelerinden seçtirir. Okul seçili değilse veya o düzeyde şube
  /// tanımlanmamışsa "Şube eklenmedi" yazar ve atama yapılamaz.
  Widget _sectionDropdown() {
    final controller = _controllers['sectionName']!;
    final school = _selectedSchool;
    final classLevel = _controllers['className']!.text.trim();
    final sections =
        school?.sectionsFor(classLevel.isEmpty ? null : classLevel) ??
        const <String>[];

    if (school == null || sections.isEmpty) {
      // Okul ya da şube tanımı yoksa atama yapılamaz. Build sırasında
      // controller değiştirilmez; atamanın boşaltılması [_syncSectionWithSchool]
      // (okul/sınıf değişiminde) ve kayıt sırasındaki [_validSectionName] ile
      // güvence altındadır.
      return _LabelledInput(
        label: 'Şube',
        child: InputDecorator(
          key: const Key('student_section_empty'),
          decoration: const InputDecoration(isDense: true),
          child: Text(
            'Şube eklenmedi',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 16),
          ),
        ),
      );
    }

    final currentValue = controller.text.trim().toUpperCase();
    final selectedValue = sections.contains(currentValue) ? currentValue : null;
    String display(String section) =>
        classLevel.isEmpty ? section : '$classLevel/$section';

    return AppDropdown<String>(
      key: const Key('student_section_dropdown'),
      label: 'Şube',
      value: selectedValue,
      placeholder: 'Şube eklenmedi',
      items: [
        for (final section in sections)
          DropdownMenuItem<String>(
            value: section,
            child: Text(display(section)),
          ),
      ],
      onChanged: (value) => controller.text = value ?? '',
    );
  }

  School? get _selectedSchool {
    if (_schoolId == null) {
      return null;
    }
    for (final school in _schools) {
      if (school.id == _schoolId) {
        return school;
      }
    }
    return null;
  }

  /// Şube atamasını seçili okulun tanımlı şubeleriyle uyumlu hale getirir.
  /// Okul seçili değilse veya o sınıf düzeyinde şube tanımlanmamışsa atama
  /// boşaltılır; kullanıcı yeni okulun listesinden seçmeden şube atanamaz.
  void _syncSectionWithSchool() {
    final controller = _controllers['sectionName']!;
    final level = _controllers['className']!.text.trim();
    final sections =
        _selectedSchool?.sectionsFor(level.isEmpty ? null : level) ??
        const <String>[];
    final current = controller.text.trim().toUpperCase();
    if (current.isEmpty || !sections.contains(current)) {
      controller.clear();
    } else {
      controller.text = current;
    }
  }

  /// Geçerli şube atamasını döndürür.
  ///
  /// Okul seçili değilse veya o sınıf düzeyinde şube tanımlanmamışsa `null`
  /// döner. Böylece controller'da geçersiz bir atama kalmış olsa bile geçersiz
  /// şube kaydedilemez; bu, render sırasında controller mutasyonu yapmadan
  /// veri bütünlüğünü korur.
  String? _validSectionName() {
    final level = _controllers['className']!.text.trim();
    final sections =
        _selectedSchool?.sectionsFor(level.isEmpty ? null : level) ??
        const <String>[];
    final current = _controllers['sectionName']!.text.trim().toUpperCase();
    if (current.isEmpty || !sections.contains(current)) {
      return null;
    }
    return current;
  }

  Widget _schoolDropdown() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppDropdown<int>(
            key: const Key('student_school_dropdown'),
            label: 'Okul',
            value: _schoolId,
            placeholder: 'Okul seçilmedi',
            items: [
              for (final school in _schools)
                DropdownMenuItem<int>(
                  value: school.id,
                  child: Text(
                    school.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _schoolId = value;
              // Okul değişti: şube, yeni okulun tanımlı şubeleriyle
              // eşleşmiyorsa atama düşer.
              _syncSectionWithSchool();
            }),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: OutlinedButton.icon(
            key: const Key('student_school_settings_button'),
            onPressed: _isSaving ? null : _openSchoolSettings,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Okul Ayarları'),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
    Key? fieldKey,
  }) {
    return AppDateField(
      fieldKey: fieldKey,
      label: label,
      value: value,
      onTap: onPressed,
      enabled: !_isSaving,
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

/// Etiket biçimi [AppLabelledField]'den gelir; yalnızca etiket metninin
/// her kelimesi büyük harfle başlatılır.
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
    return AppLabelledField(
      label: capitalizeWords(label.trim()),
      helperText: helperText,
      child: child,
    );
  }
}
