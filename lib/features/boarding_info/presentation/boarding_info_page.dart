import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

class PansiyonBilgileriPage extends StatefulWidget {
  const PansiyonBilgileriPage({super.key, required this.repository});

  final BoardingInfoRepository repository;

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

  Future<void> _load() async {
    try {
      final draft = await widget.repository.load();
      if (!mounted) {
        return;
      }
      if (draft != null) {
        _schoolNameController.text = draft.schoolName;
        _principalNameController.text = draft.principalName;
        _principalPhoneController.text = draft.principalPhone;
        _deputyNameController.text = draft.deputyName;
        _deputyPhoneController.text = draft.deputyPhone;
        _boardingType = draft.boardingType;
        _educationLevel = draft.educationLevel;
        _setBlocksFromDraft(draft.blocks);
      }
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
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
  }

  void _setEducationLevel(EducationLevel? value) {
    setState(() {
      _educationLevel = value;
      _selectionError = null;
    });
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
  }

  void _removeBlock(BoardingSection section, int index) {
    final block = _blocks[section]!.removeAt(index);
    block.dispose();
    setState(() {});
  }

  void _addFloor(_BlockForm block) {
    setState(() {
      block.floors.add(
        _FloorForm(floorNumber: block.floors.length + 1, studentRoomCount: ''),
      );
    });
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
        if (_validateBuildings()) {
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
      _showMessage(
        'Genel bilgiler ve telefon numaraları eksiksiz girilmelidir.',
      );
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

  bool _validateBuildings() {
    for (final section in _activeSections) {
      final blocks = _blocks[section]!;
      if (blocks.isEmpty) {
        _showMessage('En az bir blok bilgisi girilmelidir.');
        return false;
      }
      for (final block in blocks) {
        if (block.nameController.text.trim().isEmpty ||
            !_isPositiveNumber(block.capacityController.text) ||
            !_isPositiveNumber(block.studyController.text) ||
            block.floors.isEmpty ||
            block.floors.any(
              (floor) => !_isPositiveNumber(floor.roomCountController.text),
            )) {
          _showMessage('Blok, kat ve oda sayıları eksiksiz girilmelidir.');
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
        _showMessage('Pansiyon bilgileri kaydedildi.', isError: false);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Bilgiler kaydedilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  BoardingInfoDraft _buildDraft() {
    final blocks = <BoardingBlockDraft>[];
    for (final section in _activeSections) {
      for (final block in _blocks[section]!) {
        blocks.add(
          BoardingBlockDraft(
            section: section,
            name: block.nameController.text.trim(),
            standardRoomCapacity: int.parse(block.capacityController.text),
            studyRoomCount: int.parse(block.studyController.text),
            floors: [
              for (var index = 0; index < block.floors.length; index++)
                BoardingFloorDraft(
                  floorNumber: index + 1,
                  studentRoomCount: int.parse(
                    block.floors[index].roomCountController.text,
                  ),
                ),
            ],
          ),
        );
      }
    }

    return BoardingInfoDraft(
      schoolName: _schoolNameController.text,
      principalName: _principalNameController.text,
      principalPhone: _principalPhoneController.text,
      deputyName: _deputyNameController.text,
      deputyPhone: _deputyPhoneController.text,
      boardingType: _boardingType!,
      educationLevel: _educationLevel!,
      blocks: blocks,
    );
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) {
      return;
    }
    final backgroundColor = isError
        ? AppColors.errorFeedback
        : AppColors.successFeedback;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          content: Text(
            message,
            style: const TextStyle(
              color: AppColors.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
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
                child: Stepper(
                  type: horizontal
                      ? StepperType.horizontal
                      : StepperType.vertical,
                  currentStep: _currentStep,
                  onStepTapped: (step) {
                    if (step <= _currentStep) {
                      setState(() => _currentStep = step);
                    }
                  },
                  onStepContinue: _nextStep,
                  onStepCancel: _previousStep,
                  controlsBuilder: (context, details) {
                    return Row(
                      children: [
                        if (_currentStep > 0)
                          TextButton(
                            onPressed: _isSaving ? null : details.onStepCancel,
                            child: const Text('Geri'),
                          ),
                        const Spacer(),
                        if (_currentStep < 3)
                          FilledButton.icon(
                            onPressed: details.onStepContinue,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Devam'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : details.onStepContinue,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_isSaving ? 'Kaydediliyor' : 'Kaydet'),
                          ),
                      ],
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Genel Bilgiler'),
                      content: _buildGeneralStep(),
                      isActive: _currentStep >= 0,
                    ),
                    Step(
                      title: const Text('Tür ve Kademe'),
                      content: _buildTypeStep(),
                      isActive: _currentStep >= 1,
                    ),
                    Step(
                      title: const Text('Bina Bilgileri'),
                      content: _buildBuildingsStep(),
                      isActive: _currentStep >= 2,
                    ),
                    Step(
                      title: const Text('Kontrol ve Kayıt'),
                      content: _buildReviewStep(),
                      isActive: _currentStep >= 3,
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
      child: _FormSection(
        title: 'Okul ve yönetim bilgileri',
        subtitle: 'Pansiyonun temel kimlik ve iletişim bilgileri.',
        child: Column(
          children: [
            TextFormField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                labelText: 'Okul / Pansiyon adı',
                hintText: 'Örn. Atatürk Ortaokulu Pansiyonu',
              ),
              validator: (value) => _required(value, 'Okul / pansiyon adı'),
            ),
            const SizedBox(height: 14),
            _ResponsiveFields(
              children: [
                TextFormField(
                  controller: _principalNameController,
                  decoration: const InputDecoration(
                    labelText: 'Okul müdürü adı',
                  ),
                  validator: (value) => _required(value, 'Müdür adı'),
                ),
                TextFormField(
                  controller: _principalPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Müdür telefonu',
                  ),
                  validator: _phoneValidator,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ResponsiveFields(
              children: [
                TextFormField(
                  controller: _deputyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Müdür yardımcısı adı',
                  ),
                  validator: (value) =>
                      _required(value, 'Müdür yardımcısı adı'),
                ),
                TextFormField(
                  controller: _deputyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Müdür yardımcısı telefonu',
                  ),
                  validator: _phoneValidator,
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

class _FormSection extends StatelessWidget {
  const _FormSection({
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final BoardingType? value;
  final ValueChanged<BoardingType?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Pansiyon türü',
        errorText: errorText,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BoardingType>(
          value: value,
          isExpanded: true,
          hint: const Text('Seçiniz'),
          items: [
            for (final type in BoardingType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  const _LevelDropdown({required this.value, required this.onChanged});

  final EducationLevel? value;
  final ValueChanged<EducationLevel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Pansiyon kademesi'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EducationLevel>(
          value: value,
          isExpanded: true,
          hint: const Text('Seçiniz'),
          items: [
            for (final level in EducationLevel.values)
              DropdownMenuItem(value: level, child: Text(level.label)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BuildingSectionEditor extends StatelessWidget {
  const _BuildingSectionEditor({
    required this.section,
    required this.blocks,
    required this.onAddBlock,
    required this.onRemoveBlock,
    required this.onAddFloor,
    required this.onRemoveFloor,
  });

  final BoardingSection section;
  final List<_BlockForm> blocks;
  final VoidCallback onAddBlock;
  final ValueChanged<int> onRemoveBlock;
  final ValueChanged<_BlockForm> onAddFloor;
  final void Function(_BlockForm, int) onRemoveFloor;

  @override
  Widget build(BuildContext context) {
    return _FormSection(
      title: section.label,
      subtitle: 'Blok sayısı: ${blocks.length}',
      child: Column(
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            _BlockEditor(
              block: blocks[index],
              index: index,
              onRemove: () => onRemoveBlock(index),
              onAddFloor: () => onAddFloor(blocks[index]),
              onRemoveFloor: (floorIndex) =>
                  onRemoveFloor(blocks[index], floorIndex),
            ),
            if (index != blocks.length - 1) const SizedBox(height: 14),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddBlock,
              icon: const Icon(Icons.add),
              label: const Text('Blok ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockEditor extends StatelessWidget {
  const _BlockEditor({
    required this.block,
    required this.index,
    required this.onRemove,
    required this.onAddFloor,
    required this.onRemoveFloor,
  });

  final _BlockForm block;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onAddFloor;
  final ValueChanged<int> onRemoveFloor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(block.id),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softPurple,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Blok ${index + 1}',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bloğu sil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: block.nameController,
            decoration: const InputDecoration(labelText: 'Blok adı'),
            validator: (value) => _required(value, 'Blok adı'),
          ),
          const SizedBox(height: 12),
          _ResponsiveFields(
            children: [
              TextFormField(
                controller: block.capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Standart oda kapasitesi',
                ),
                validator: (value) =>
                    _positiveNumberValidator(value, 'Standart oda kapasitesi'),
              ),
              TextFormField(
                controller: block.studyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Etüt salonu sayısı',
                ),
                validator: (value) =>
                    _positiveNumberValidator(value, 'Etüt salonu sayısı'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Katlar ve oda sayıları',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Kat sayısı: ${block.floors.length}',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onAddFloor,
                icon: const Icon(Icons.add),
                label: const Text('Kat ekle'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (
            var floorIndex = 0;
            floorIndex < block.floors.length;
            floorIndex++
          ) ...[
            Row(
              children: [
                SizedBox(width: 74, child: Text('${floorIndex + 1}. Kat')),
                Expanded(
                  child: TextFormField(
                    controller: block.floors[floorIndex].roomCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Öğrenci odası sayısı',
                    ),
                    validator: (value) =>
                        _positiveNumberValidator(value, 'Öğrenci odası sayısı'),
                  ),
                ),
                IconButton(
                  tooltip: 'Katı sil',
                  onPressed: block.floors.length <= 1
                      ? null
                      : () => onRemoveFloor(floorIndex),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            if (floorIndex != block.floors.length - 1)
              const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _required(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label zorunludur.';
  }
  return null;
}

String? _phoneValidator(String? value) {
  final requiredError = _required(value, 'Telefon numarası');
  if (requiredError != null) {
    return requiredError;
  }
  if (!RegExp(r'^[0-9+()\-\s]{10,}$').hasMatch(value!.trim())) {
    return 'Geçerli bir telefon numarası girin.';
  }
  return null;
}

String? _positiveNumberValidator(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label zorunludur.';
  }
  final number = int.tryParse(value.trim());
  if (number == null || number <= 0) {
    return 'Sıfırdan büyük bir sayı girin.';
  }
  return null;
}

class _BlockForm {
  _BlockForm({
    required this.id,
    required this.section,
    required this.nameController,
    required this.capacityController,
    required this.studyController,
    required this.floors,
  });

  factory _BlockForm.newBlock(BoardingSection section, int index) {
    return _BlockForm(
      id: '${section.value}_${DateTime.now().microsecondsSinceEpoch}_$index',
      section: section,
      nameController: TextEditingController(
        text: '${section.label} Bloğu ${index + 1}',
      ),
      capacityController: TextEditingController(),
      studyController: TextEditingController(),
      floors: [_FloorForm(floorNumber: 1, studentRoomCount: '')],
    );
  }

  factory _BlockForm.fromDraft(BoardingBlockDraft draft, int index) {
    return _BlockForm(
      id: '${draft.section.value}_${DateTime.now().microsecondsSinceEpoch}_$index',
      section: draft.section,
      nameController: TextEditingController(text: draft.name),
      capacityController: TextEditingController(
        text: '${draft.standardRoomCapacity}',
      ),
      studyController: TextEditingController(text: '${draft.studyRoomCount}'),
      floors: [
        for (final floor in draft.floors)
          _FloorForm(
            floorNumber: floor.floorNumber,
            studentRoomCount: '${floor.studentRoomCount}',
          ),
      ],
    );
  }

  final String id;
  final BoardingSection section;
  final TextEditingController nameController;
  final TextEditingController capacityController;
  final TextEditingController studyController;
  final List<_FloorForm> floors;

  void dispose() {
    nameController.dispose();
    capacityController.dispose();
    studyController.dispose();
    for (final floor in floors) {
      floor.dispose();
    }
  }
}

class _FloorForm {
  _FloorForm({required this.floorNumber, required String studentRoomCount})
    : roomCountController = TextEditingController(text: studentRoomCount);

  int floorNumber;
  final TextEditingController roomCountController;

  void dispose() {
    roomCountController.dispose();
  }
}
