import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

part 'boarding_info_form_models.dart';
part 'boarding_info_widgets.dart';

final _phoneNumberFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final formatted = _formatPhoneNumber(newValue.text);
  final cursorOffset = _phoneCursorOffset(
    formatted,
    newValue.text,
    newValue.selection.baseOffset,
  );
  return newValue.copyWith(
    text: formatted,
    selection: TextSelection.collapsed(offset: cursorOffset),
  );
});

final _phoneInputFormatters = <TextInputFormatter>[_phoneNumberFormatter];

final _capitalizeWordsFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final text = _capitalizeWords(newValue.text);
  final baseOffset = _clampTextOffset(newValue.selection.baseOffset, text);
  final extentOffset = _clampTextOffset(
    newValue.selection.extentOffset,
    text,
    fallback: baseOffset,
  );
  return newValue.copyWith(
    text: text,
    selection: TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
    ),
  );
});

String _capitalizeWords(String value) {
  final result = StringBuffer();
  var capitalizeNext = true;

  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (_isWordSeparator(character)) {
      result.write(character);
      capitalizeNext = true;
    } else if (capitalizeNext) {
      result.write(character.toUpperCase());
      capitalizeNext = false;
    } else {
      result.write(character);
    }
  }

  return result.toString();
}

bool _isWordSeparator(String value) {
  return value.trim().isEmpty || value == '-' || value == "'" || value == '’';
}

int _clampTextOffset(int? offset, String text, {int? fallback}) {
  if (offset == null || offset < 0) {
    return fallback ?? text.length;
  }
  return offset.clamp(0, text.length);
}

String _normalizePhoneNumber(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String _formatPhoneNumber(String value) {
  final digits = _normalizePhoneNumber(value);
  final truncated = digits.length > 11 ? digits.substring(0, 11) : digits;
  final result = StringBuffer();

  for (var index = 0; index < truncated.length; index++) {
    result.write(truncated[index]);
    if ((index == 3 || index == 6 || index == 8) &&
        index < truncated.length - 1) {
      result.write(' ');
    }
  }

  return result.toString();
}

int _phoneCursorOffset(String formatted, String rawValue, int? rawOffset) {
  final safeOffset = rawOffset == null || rawOffset < 0
      ? rawValue.length
      : rawOffset.clamp(0, rawValue.length);
  final digitsBeforeCursor = _normalizePhoneNumber(
    rawValue.substring(0, safeOffset),
  );
  if (digitsBeforeCursor.isEmpty) {
    return 0;
  }

  var digitCount = 0;
  for (var index = 0; index < formatted.length; index++) {
    if (_isPhoneDigit(formatted[index])) {
      digitCount++;
      if (digitCount == digitsBeforeCursor.length) {
        return index + 1;
      }
    }
  }
  return formatted.length;
}

bool _isPhoneDigit(String value) {
  final codeUnit = value.codeUnitAt(0);
  return codeUnit >= 48 && codeUnit <= 57;
}

class PansiyonBilgileriPage extends StatefulWidget {
  const PansiyonBilgileriPage({
    super.key,
    required this.repository,
    this.onDirtyChanged,
  });

  final BoardingInfoRepository repository;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<PansiyonBilgileriPage> createState() => _PansiyonBilgileriPageState();
}

class _PansiyonBilgileriPageState extends State<PansiyonBilgileriPage> {
  final _generalFormKey = GlobalKey<FormState>();
  final _buildingFormKey = GlobalKey<FormState>();
  late final TextEditingController _schoolNameController;
  late final TextEditingController _principalNameController;
  late final TextEditingController _principalPhoneController;
  late final TextEditingController _deputyNameController;
  late final TextEditingController _deputyPhoneController;

  final Map<BoardingSection, List<_BlockForm>> _blocks = {
    BoardingSection.common: [],
    BoardingSection.girls: [],
    BoardingSection.boys: [],
  };

  BoardingType? _boardingType;
  EducationLevel? _educationLevel;
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _selectionError;
  bool _isDirty = false;
  bool _isApplyingDraft = false;

  @override
  void initState() {
    super.initState();
    _schoolNameController = TextEditingController();
    _principalNameController = TextEditingController();
    _principalPhoneController = TextEditingController();
    _deputyNameController = TextEditingController();
    _deputyPhoneController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _principalNameController.dispose();
    _principalPhoneController.dispose();
    _deputyNameController.dispose();
    _deputyPhoneController.dispose();
    for (final sectionBlocks in _blocks.values) {
      for (final block in sectionBlocks) {
        block.dispose();
      }
    }
    super.dispose();
  }

  void _setDirty(bool value) {
    if (_isApplyingDraft || _isDirty == value) {
      return;
    }
    _isDirty = value;
    widget.onDirtyChanged?.call(value);
  }

  Future<void> _load() async {
    try {
      final draft = await widget.repository.load();
      if (!mounted) {
        return;
      }
      if (draft != null) {
        _isApplyingDraft = true;
        try {
          _schoolNameController.text = _capitalizeWords(draft.schoolName);
          _principalNameController.text = _capitalizeWords(draft.principalName);
          _principalPhoneController.text = _formatPhoneNumber(
            draft.principalPhone,
          );
          _deputyNameController.text = _capitalizeWords(draft.deputyName);
          _deputyPhoneController.text = _formatPhoneNumber(draft.deputyPhone);
          _boardingType = draft.boardingType;
          _educationLevel = draft.educationLevel;
          _setBlocksFromDraft(draft.blocks);
        } finally {
          _isApplyingDraft = false;
        }
      }
      _setDirty(false);
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _setDirty(false);
      setState(() {
        _isLoading = false;
        _loadError = 'Kayıtlı pansiyon bilgileri okunamadı.';
      });
    }
  }

  void _setBlocksFromDraft(List<BoardingBlockDraft> blocks) {
    for (final sectionBlocks in _blocks.values) {
      for (final block in sectionBlocks) {
        block.dispose();
      }
      sectionBlocks.clear();
    }
    for (final block in blocks) {
      _blocks[block.section]!.add(
        _BlockForm.fromDraft(block, _blocks[block.section]!.length),
      );
    }
    for (final section in _activeSections) {
      _ensureSection(section);
    }
  }

  List<BoardingSection> get _activeSections {
    switch (_boardingType) {
      case BoardingType.girls:
        return [BoardingSection.girls];
      case BoardingType.boys:
        return [BoardingSection.boys];
      case BoardingType.mixed:
        return [BoardingSection.girls, BoardingSection.boys];
      case null:
        return [];
    }
  }

  // Keep loaded sections in the snapshot so changing the boarding type
  // cannot silently delete blocks that are not currently visible.
  List<BoardingSection> get _sectionsToSave {
    final sections = <BoardingSection>[..._activeSections];
    for (final section in BoardingSection.values) {
      if (!sections.contains(section) && _blocks[section]!.isNotEmpty) {
        sections.add(section);
      }
    }
    return sections;
  }

  void _setBoardingType(BoardingType? value) {
    setState(() {
      _boardingType = value;
      _selectionError = null;
      if (value != null) {
        for (final section in _activeSections) {
          _ensureSection(section);
        }
      }
    });
    _setDirty(true);
  }

  void _setEducationLevel(EducationLevel? value) {
    setState(() {
      _educationLevel = value;
      _selectionError = null;
    });
    _setDirty(true);
  }

  void _ensureSection(BoardingSection section) {
    if (_blocks[section]!.isEmpty) {
      _blocks[section]!.add(
        _BlockForm.newBlock(section, _blocks[section]!.length),
      );
    }
  }

  void _addBlock(BoardingSection section) {
    setState(() {
      _blocks[section]!.add(
        _BlockForm.newBlock(section, _blocks[section]!.length),
      );
    });
    _setDirty(true);
  }

  void _removeBlock(BoardingSection section, int index) {
    final block = _blocks[section]!.removeAt(index);
    block.dispose();
    setState(() {});
    _setDirty(true);
  }

  void _addFloor(_BlockForm block) {
    setState(() {
      block.floors.add(
        _FloorForm(
          floorNumber: block.floors.length + 1,
          hasStudentRooms: false,
          studentRoomCount: '',
          roomStartNumber: '',
          hasStudyRoom: false,
          studyRoomCount: '',
        ),
      );
    });
    _setDirty(true);
  }

  void _removeFloor(_BlockForm block, int index) {
    if (block.floors.length <= 1) {
      return;
    }
    final floor = block.floors.removeAt(index);
    floor.dispose();
    for (var floorIndex = 0; floorIndex < block.floors.length; floorIndex++) {
      block.floors[floorIndex].floorNumber = floorIndex + 1;
    }
    setState(() {});
    _setDirty(true);
  }

  void _nextStep() {
    switch (_currentStep) {
      case 0:
        if ((_generalFormKey.currentState?.validate() ?? false) &&
            _validateGeneralValues()) {
          setState(() => _currentStep = 1);
        }
      case 1:
        if (_validateSelections()) {
          setState(() => _currentStep = 2);
        }
      case 2:
        if (_validateBuildings(showFormErrors: true)) {
          setState(() => _currentStep = 3);
        }
      case 3:
        _save();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildTypeStep();
      case 2:
        return _buildBuildingsStep();
      case 3:
        return _buildReviewStep();
      default:
        return _buildGeneralStep();
    }
  }

  bool _validateGeneralValues() {
    final fields = [
      _schoolNameController.text,
      _principalNameController.text,
      _principalPhoneController.text,
      _deputyNameController.text,
      _deputyPhoneController.text,
    ];
    final hasEmptyField = fields.any((value) => value.trim().isEmpty);
    final phonesValid =
        _phoneValidator(_principalPhoneController.text) == null &&
        _phoneValidator(_deputyPhoneController.text) == null;
    if (hasEmptyField || !phonesValid) {
      _notify('Genel bilgiler ve telefon numaraları eksiksiz girilmelidir.');
      return false;
    }
    return true;
  }

  bool _validateSelections() {
    if (_boardingType == null || _educationLevel == null) {
      setState(() {
        _selectionError = 'Pansiyon türü ve kademe seçilmelidir.';
      });
      return false;
    }
    return true;
  }

  bool _validateBuildings({bool showFormErrors = false}) {
    if (showFormErrors && _buildingFormKey.currentState?.validate() == false) {
      return false;
    }

    for (final section in _activeSections) {
      final blocks = _blocks[section]!;
      if (blocks.isEmpty) {
        _notify('En az bir blok bilgisi girilmelidir.');
        return false;
      }
      for (final block in blocks) {
        if (block.nameController.text.trim().isEmpty ||
            !_isPositiveNumber(block.capacityController.text) ||
            block.floors.isEmpty ||
            block.floors.any(
              (floor) =>
                  (floor.hasStudentRooms &&
                      (!_isPositiveNumber(
                            floor.roomStartNumberController.text,
                          ) ||
                          !_isPositiveNumber(
                            floor.roomCountController.text,
                          ))) ||
                  (floor.hasStudyRoom &&
                      !_isPositiveNumber(floor.studyRoomCountController.text)),
            )) {
          _notify('Blok, kat ve oda sayıları eksiksiz girilmelidir.');
          return false;
        }
      }
    }
    return true;
  }

  bool _isPositiveNumber(String value) {
    final number = int.tryParse(value.trim());
    return number != null && number > 0;
  }

  Future<void> _save() async {
    if (!_validateGeneralValues() ||
        !_validateSelections() ||
        !_validateBuildings()) {
      return;
    }

    final draft = _buildDraft();
    setState(() => _isSaving = true);
    try {
      await widget.repository.save(draft);
      if (mounted) {
        _setDirty(false);
        _notify('Pansiyon bilgileri kaydedildi.', AppNotificationTone.success);
      }
    } catch (_) {
      if (mounted) {
        _notify('Bilgiler kaydedilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  BoardingInfoDraft _buildDraft() {
    final blocks = <BoardingBlockDraft>[];
    for (final section in _sectionsToSave) {
      for (final block in _blocks[section]!) {
        blocks.add(
          BoardingBlockDraft(
            section: section,
            name: block.nameController.text.trim(),
            standardRoomCapacity: int.parse(block.capacityController.text),
            hasBasement: block.hasBasement,
            floors: [
              for (var index = 0; index < block.floors.length; index++)
                BoardingFloorDraft(
                  floorNumber: index + 1,
                  hasStudentRooms: block.floors[index].hasStudentRooms,
                  studentRoomCount: block.floors[index].hasStudentRooms
                      ? int.parse(block.floors[index].roomCountController.text)
                      : null,
                  roomStartNumber: block.floors[index].hasStudentRooms
                      ? int.parse(
                          block.floors[index].roomStartNumberController.text,
                        )
                      : null,
                  hasStudyRoom: block.floors[index].hasStudyRoom,
                  studyRoomCount: block.floors[index].hasStudyRoom
                      ? int.parse(
                          block.floors[index].studyRoomCountController.text,
                        )
                      : null,
                ),
            ],
          ),
        );
      }
    }

    return BoardingInfoDraft(
      schoolName: _schoolNameController.text,
      principalName: _principalNameController.text,
      principalPhone: _normalizePhoneNumber(_principalPhoneController.text),
      deputyName: _deputyNameController.text,
      deputyPhone: _normalizePhoneNumber(_deputyPhoneController.text),
      boardingType: _boardingType!,
      educationLevel: _educationLevel!,
      blocks: blocks,
    );
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 820;
        return Padding(
          padding: EdgeInsets.all(horizontal ? 28 : 16),
          child: SizedBox(
            width: double.infinity,
            height: constraints.maxHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  children: [
                    _StepProgress(
                      key: const Key('boarding_step_progress'),
                      steps: const [
                        'Genel Bilgiler',
                        'Tür ve Kademe',
                        'Bina Bilgileri',
                        'Kontrol ve Kayıt',
                      ],
                      currentStep: _currentStep,
                      compact: !horizontal,
                      onStepSelected: (step) {
                        if (step <= _currentStep) {
                          setState(() => _currentStep = step);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(child: _buildCurrentStep()),
                    ),
                    const SizedBox(height: 16),
                    _StepControls(
                      currentStep: _currentStep,
                      isSaving: _isSaving,
                      onBack: _previousStep,
                      onNext: _nextStep,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneralStep() {
    return Form(
      key: _generalFormKey,
      onChanged: () => _setDirty(true),
      child: _FormSection(
        title: 'Okul ve yönetim bilgileri',
        subtitle: 'Pansiyonun temel kimlik ve iletişim bilgileri.',
        child: Column(
          children: [
            _LabelledField(
              label: 'Okul / Pansiyon adı',
              child: TextFormField(
                controller: _schoolNameController,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_capitalizeWordsFormatter],
                style: AppTheme.inputTextStyle,
                decoration: const InputDecoration(),
                validator: (value) => _required(value, 'Okul / pansiyon adı'),
              ),
            ),
            const SizedBox(height: 14),
            _ResponsiveFields(
              children: [
                _LabelledField(
                  label: 'Okul müdürü adı',
                  child: TextFormField(
                    controller: _principalNameController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [_capitalizeWordsFormatter],
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: (value) => _required(value, 'Müdür adı'),
                  ),
                ),
                _LabelledField(
                  label: 'Müdür telefonu',
                  child: TextFormField(
                    controller: _principalPhoneController,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: _phoneInputFormatters,
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: _phoneValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ResponsiveFields(
              children: [
                _LabelledField(
                  label: 'Müdür yardımcısı adı',
                  child: TextFormField(
                    controller: _deputyNameController,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [_capitalizeWordsFormatter],
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: (value) =>
                        _required(value, 'Müdür yardımcısı adı'),
                  ),
                ),
                _LabelledField(
                  label: 'Müdür yardımcısı telefonu',
                  child: TextFormField(
                    controller: _deputyPhoneController,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: _phoneInputFormatters,
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: _phoneValidator,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeStep() {
    return _FormSection(
      title: 'Pansiyon türü ve kademesi',
      subtitle:
          'Karma seçilirse bina bilgileri kız ve erkek tarafı için ayrı alınır.',
      child: Column(
        children: [
          _TypeDropdown(
            value: _boardingType,
            errorText: _selectionError,
            onChanged: _setBoardingType,
          ),
          const SizedBox(height: 14),
          _LevelDropdown(value: _educationLevel, onChanged: _setEducationLevel),
        ],
      ),
    );
  }

  Widget _buildBuildingsStep() {
    if (_boardingType == null) {
      return _FormSection(
        title: 'Bina bilgileri',
        subtitle: 'Önce pansiyon türünü seçmelisiniz.',
        child: const Text('Pansiyon türü seçilmedi.'),
      );
    }

    return Form(
      key: _buildingFormKey,
      onChanged: () => _setDirty(true),
      child: Column(
        children: [
          for (final section in _activeSections) ...[
            _BuildingSectionEditor(
              section: section,
              blocks: _blocks[section]!,
              onAddBlock: () => _addBlock(section),
              onRemoveBlock: (index) => _removeBlock(section, index),
              onAddFloor: _addFloor,
              onRemoveFloor: _removeFloor,
              onBasementChanged: (block, value) {
                setState(() => block.hasBasement = value);
                _setDirty(true);
              },
              onStudentRoomsChanged: (block, floorIndex, value) {
                setState(
                  () => block.floors[floorIndex].hasStudentRooms = value,
                );
                _setDirty(true);
              },
              onStudyRoomChanged: (block, floorIndex, value) {
                setState(() => block.floors[floorIndex].hasStudyRoom = value);
                _setDirty(true);
              },
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final sections = _activeSections;
    return _FormSection(
      title: 'Bilgileri kontrol et',
      subtitle: 'Kaydetmeden önce girilen bilgileri kontrol edebilirsiniz.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewRow(
            label: 'Okul / Pansiyon',
            value: _schoolNameController.text,
          ),
          _ReviewRow(label: 'Müdür', value: _principalNameController.text),
          _ReviewRow(
            label: 'Müdür yardımcısı',
            value: _deputyNameController.text,
          ),
          _ReviewRow(label: 'Tür', value: _boardingType?.label ?? '-'),
          _ReviewRow(label: 'Kademe', value: _educationLevel?.label ?? '-'),
          const SizedBox(height: 10),
          for (final section in sections)
            _ReviewRow(
              label: section.label,
              value: '${_blocks[section]!.length} blok',
            ),
        ],
      ),
    );
  }
}
