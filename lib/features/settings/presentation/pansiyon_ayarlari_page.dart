import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pansiyon_yonetim/core/backup/database_backup_service.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_edit_lock.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_type_change_impact.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/data/pansiyon_file_dialogs.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/presentation/pansiyon_creation_view.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

part 'pansiyon_ayarlari_form_models.dart';
part 'pansiyon_ayarlari_widgets.dart';

class PansiyonAyarlariPage extends StatefulWidget {
  const PansiyonAyarlariPage({
    super.key,
    required this.repository,
    this.onDirtyChanged,
    this.onSaveDraft,
    this.onSchoolNameChanged,
    this.pansiyonFileActions,
    this.pansiyonFileDialogs,
    this.onPansiyonActivated,
    this.showPansiyonFileOperations = true,
    this.editLock,
    this.startInFormMode = false,
    this.typeChangeAnalyzer,
    this.roomRepository,
    this.backupService,
  });

  final BoardingInfoRepository repository;
  final ValueChanged<bool>? onDirtyChanged;

  /// Kaydetme işlemini devralır.
  ///
  /// Verilirse formun [repository] kaydı yerine bu geri çağırma kullanılır ve
  /// `true` döndüğünde kayıt tamamlanmış kabul edilir. `false` veya hata
  /// durumunda form kaydedilmemiş olarak kalır.
  final Future<bool> Function(BoardingInfoDraft draft)? onSaveDraft;

  /// Okul / pansiyon adı değiştikçe bildirilir.
  final ValueChanged<String>? onSchoolNameChanged;

  /// Verilirse ekranda "Pansiyon Dosyası İşlemleri" bölümü gösterilir.
  final PansiyonFileActions? pansiyonFileActions;

  final PansiyonFileDialogs? pansiyonFileDialogs;
  final ValueChanged<PansiyonActivationResult>? onPansiyonActivated;

  /// Yeni pansiyon oluşturma formunun iç içe gösterilmesini engeller.
  final bool showPansiyonFileOperations;

  /// Kademe kilidi. Verilmezse kademe kilidi uygulanmaz.
  final BoardingInfoEditLock? editLock;

  /// Tür değişikliğinin etkisini analiz eder. Verilmezse onay istenmez.
  final BoardingTypeChangeAnalyzer? typeChangeAnalyzer;

  /// Kayıt sonrası odaların pansiyon bilgileriyle eşitlenmesi için kullanılır.
  final RoomRepository? roomRepository;

  /// Yedekleme ve geri yükleme kartı. Verilmezse kart gösterilmez.
  final DatabaseBackupService? backupService;

  /// true ise sayfa doğrudan dört adımlı formu açar.
  ///
  /// Varsayılan olarak sayfa özet görünümüyle açılır ve kullanıcı
  /// "Pansiyon Bilgileri Ekle/Düzenle" butonu ile formu açar.
  final bool startInFormMode;

  @override
  State<PansiyonAyarlariPage> createState() => _PansiyonAyarlariPageState();
}

class _PansiyonAyarlariPageState extends State<PansiyonAyarlariPage> {
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
  bool _isCreatingNewPansiyon = false;
  bool _isPansiyonFileBusy = false;
  Directory? _newPansiyonDirectory;
  PansiyonUsageInfo? _usage;
  EducationLevel? _storedEducationLevel;
  String? _levelLockMessage;
  BoardingInfoDraft? _loadedDraft;
  late bool _isFormOpen;

  @override
  void initState() {
    super.initState();
    _isFormOpen = widget.startInFormMode;
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
      final results = await Future.wait<Object?>([
        widget.repository.load(),
        widget.editLock?.loadUsage() ?? Future<PansiyonUsageInfo?>.value(null),
      ]);
      final draft = results[0] as BoardingInfoDraft?;
      final usage = results[1] as PansiyonUsageInfo?;
      if (!mounted) {
        return;
      }
      if (draft != null) {
        _isApplyingDraft = true;
        try {
          _loadedDraft = draft;
          _schoolNameController.text = capitalizeWords(draft.schoolName);
          _principalNameController.text = capitalizeWords(draft.principalName);
          _principalPhoneController.text = formatPhoneNumber(
            draft.principalPhone,
          );
          _deputyNameController.text = capitalizeWords(draft.deputyName);
          _deputyPhoneController.text = formatPhoneNumber(draft.deputyPhone);
          _boardingType = draft.boardingType;
          _educationLevel = draft.educationLevel;
          _storedEducationLevel = draft.educationLevel;
          _setBlocksFromDraft(draft.blocks);
        } finally {
          _isApplyingDraft = false;
        }
      }
      _usage = usage;
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

  /// Kademe kilidi: kayıt varsa kademe değiştirilemez.
  bool get _isEducationLevelLocked => _usage?.hasData ?? false;

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

  // Kayıt yalnızca aktif türlerin bölümlerini içerir; tür değişiminde türe
  // ait olmayan blok ve odalar böylece kaybolmaz, temizlenir.
  List<BoardingSection> get _sectionsToSave => _activeSections;

  void _setBoardingType(BoardingType? value) async {
    if (value == null || value == _boardingType) {
      return;
    }
    final removedSections = _removedSectionsFor(value);
    var impact = const BoardingTypeChangeImpact(
      removedSections: [],
      removedSectionRoomCount: 0,
      affectedAssignmentCount: 0,
      conflictingStudentCount: 0,
    );
    final analyzer = widget.typeChangeAnalyzer;
    if (removedSections.isNotEmpty && analyzer != null) {
      try {
        impact = await analyzer.analyze(
          nextType: value,
          removedSections: removedSections,
        );
      } catch (_) {
        impact = const BoardingTypeChangeImpact(
          removedSections: [],
          removedSectionRoomCount: 0,
          affectedAssignmentCount: 0,
          conflictingStudentCount: 0,
        );
      }
    }
    if (impact.needsConfirmation && !await _confirmBoardingTypeChange(impact)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _boardingType = value;
      _selectionError = null;
      _levelLockMessage = null;
      for (final section in removedSections) {
        final blocks = _blocks[section]!;
        for (final block in blocks) {
          block.dispose();
        }
        blocks.clear();
      }
      for (final section in _activeSections) {
        _ensureSection(section);
      }
    });
    _setDirty(true);
  }

  /// Yeni türe ait olmayan bölümler.
  List<BoardingSection> _removedSectionsFor(BoardingType nextType) {
    final nextActive = switch (nextType) {
      BoardingType.girls => const [BoardingSection.girls],
      BoardingType.boys => const [BoardingSection.boys],
      BoardingType.mixed => const [BoardingSection.girls, BoardingSection.boys],
    };
    final removed = <BoardingSection>[];
    for (final section in BoardingSection.values) {
      if (!nextActive.contains(section) && _blocks[section]!.isNotEmpty) {
        removed.add(section);
      }
    }
    return removed;
  }

  Future<bool> _confirmBoardingTypeChange(
    BoardingTypeChangeImpact impact,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Pansiyon türünü değiştir'),
          content: Text(
            'Bu değişiklikle birlikte türe ait olmayan bloklar ve odalar '
            'kaldırılır. ${impact.summary}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Değiştir ve temizle'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _setEducationLevel(EducationLevel? value) {
    if (value != null && value != _storedEducationLevel) {
      final decision = BoardingInfoEditLock.decide(
        usage: _usage ?? const PansiyonUsageInfo(studentCount: 0, roomCount: 0),
        storedLevel: _storedEducationLevel,
        nextLevel: value,
      );
      if (decision.isBlocked) {
        setState(() => _levelLockMessage = decision.message);
        _notify(decision.message!);
        return;
      }
    }
    setState(() {
      _educationLevel = value;
      _selectionError = null;
      _levelLockMessage = null;
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
        phoneNumberValidator(
              _principalPhoneController.text,
              isRequired: true,
            ) ==
            null &&
        phoneNumberValidator(_deputyPhoneController.text, isRequired: true) ==
            null;
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
            !isPositiveNumber(block.capacityController.text) ||
            block.floors.isEmpty ||
            block.floors.any(
              (floor) =>
                  (floor.hasStudentRooms &&
                      (!isPositiveNumber(
                            floor.roomStartNumberController.text,
                          ) ||
                          !isPositiveNumber(floor.roomCountController.text))) ||
                  (floor.hasStudyRoom &&
                      !isPositiveNumber(floor.studyRoomCountController.text)),
            )) {
          _notify('Blok, kat ve oda sayıları eksiksiz girilmelidir.');
          return false;
        }
      }
    }
    return true;
  }

  bool isPositiveNumber(String value) {
    final number = int.tryParse(value.trim());
    return number != null && number > 0;
  }

  Future<void> _save() async {
    final levelDecision = BoardingInfoEditLock.decide(
      usage: _usage ?? const PansiyonUsageInfo(studentCount: 0, roomCount: 0),
      storedLevel: _storedEducationLevel,
      nextLevel: _educationLevel,
    );
    if (levelDecision.isBlocked) {
      setState(() => _levelLockMessage = levelDecision.message);
      _notify(levelDecision.message!);
      return;
    }
    if (!_validateGeneralValues() ||
        !_validateSelections() ||
        !_validateBuildings()) {
      return;
    }

    final draft = _buildDraft();
    setState(() => _isSaving = true);
    try {
      final completed = await _persistDraft(draft);
      if (!mounted || !completed) {
        return;
      }
      _setDirty(false);
      _loadedDraft = draft;
      _storedEducationLevel = draft.educationLevel;
      // Odalar pansiyon bilgileriyle eşitlenir; türe ait olmayan odalar
      // ve onların atamaları bu adımda temizlenir.
      final roomRepository = widget.roomRepository;
      if (roomRepository != null) {
        try {
          await roomRepository.syncRooms(draft);
        } catch (_) {}
      }
      if (_showsPansiyonFileOperations) {
        setState(() => _isFormOpen = false);
      }
      _notify('Pansiyon bilgileri kaydedildi.', AppNotificationTone.success);
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

  Future<bool> _persistDraft(BoardingInfoDraft draft) async {
    final saveDraft = widget.onSaveDraft;
    if (saveDraft != null) {
      return saveDraft(draft);
    }
    await widget.repository.save(draft);
    return true;
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
      principalPhone: normalizePhoneNumber(_principalPhoneController.text),
      deputyName: _deputyNameController.text,
      deputyPhone: normalizePhoneNumber(_deputyPhoneController.text),
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

  PansiyonFileDialogs get _pansiyonFileDialogs =>
      widget.pansiyonFileDialogs ?? const FilePickerPansiyonFileDialogs();

  bool get _showsPansiyonFileOperations =>
      widget.showPansiyonFileOperations && widget.pansiyonFileActions != null;

  /// Yeni bir pansiyon dosyası oluşturma akışını başlatır.
  Future<void> _startCreateNewPansiyon() async {
    if (_isPansiyonFileBusy || widget.pansiyonFileActions == null) {
      return;
    }
    if (_isDirty && !await _confirmDiscardChanges()) {
      return;
    }
    setState(() => _isPansiyonFileBusy = true);
    try {
      final directory = await _pansiyonFileDialogs.pickSaveDirectory();
      if (!mounted) {
        return;
      }
      if (directory == null) {
        setState(() => _isPansiyonFileBusy = false);
        return;
      }
      _setDirty(false);
      setState(() {
        _isPansiyonFileBusy = false;
        _newPansiyonDirectory = directory;
        _isCreatingNewPansiyon = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isPansiyonFileBusy = false);
        _notify('Kaydedilecek klasör seçilemedi.');
      }
    }
  }

  /// Daha önce oluşturulmuş bir `.pansiyon` dosyasını açar.
  Future<void> _openPansiyonFile() async {
    final actions = widget.pansiyonFileActions;
    if (_isPansiyonFileBusy || actions == null) {
      return;
    }
    if (_isDirty && !await _confirmDiscardChanges()) {
      return;
    }
    setState(() => _isPansiyonFileBusy = true);
    try {
      final filePath = await _pansiyonFileDialogs.pickPansiyonFile();
      if (!mounted) {
        return;
      }
      if (filePath == null) {
        setState(() => _isPansiyonFileBusy = false);
        return;
      }
      final result = await actions.openPansiyonFile(filePath);
      if (!mounted) {
        return;
      }
      setState(() => _isPansiyonFileBusy = false);
      if (result == null) {
        return;
      }
      _setDirty(false);
      _notify('${result.fileName} açıldı.', AppNotificationTone.success);
      widget.onPansiyonActivated?.call(result);
    } on PansiyonActivationException catch (error) {
      if (mounted) {
        setState(() => _isPansiyonFileBusy = false);
        _notify(error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isPansiyonFileBusy = false);
        _notify('Pansiyon dosyası açılamadı. Lütfen tekrar deneyin.');
      }
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kaydedilmemiş değişiklikler'),
          content: const Text(
            'Pansiyon bilgilerinde kaydedilmemiş değişiklikler var. '
            'Bu değişiklikler bırakılsın mı?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Bırak ve devam et'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _exitNewPansiyonCreation() {
    setState(() {
      _isCreatingNewPansiyon = false;
      _newPansiyonDirectory = null;
    });
  }

  void _openForm() {
    setState(() {
      _isFormOpen = true;
      _currentStep = 0;
    });
  }

  Future<void> _closeForm() async {
    if (_isDirty && !await _confirmDiscardChanges()) {
      return;
    }
    setState(() {
      _isFormOpen = false;
      _currentStep = 0;
    });
    _setDirty(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }

    final newPansiyonDirectory = _newPansiyonDirectory;
    if (_isCreatingNewPansiyon && newPansiyonDirectory != null) {
      final actions = widget.pansiyonFileActions;
      if (actions != null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: PansiyonCreationView(
            directory: newPansiyonDirectory,
            controller: actions,
            boardingInfoRepository: widget.repository,
            onPansiyonActivated: widget.onPansiyonActivated,
            onDirtyChanged: widget.onDirtyChanged,
            onCancel: _exitNewPansiyonCreation,
          ),
        );
      }
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
                child: _isFormOpen
                    ? _buildFormArea(horizontal)
                    : _buildOverviewArea(horizontal),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Sayfa açılışında görünen özet: kayıtlı bilgiler ve iki dosya işlemi.
  Widget _buildOverviewArea(bool horizontal) {
    final draft = _loadedDraft;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormSection(
            title: draft == null
                ? 'Pansiyon bilgileri eksik'
                : 'Kayıtlı pansiyon bilgileri',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (draft != null) ...[
                  _ReviewRow(label: 'Okul / Pansiyon', value: draft.schoolName),
                  _ReviewRow(label: 'Müdür', value: draft.principalName),
                  _ReviewRow(
                    label: 'Müdür yardımcısı',
                    value: draft.deputyName,
                  ),
                  _ReviewRow(label: 'Tür', value: draft.boardingType.label),
                  _ReviewRow(
                    label: 'Kademe',
                    value: draft.educationLevel.label,
                  ),
                  _ReviewRow(
                    label: 'Bloklar',
                    value: '${draft.blocks.length} blok',
                  ),
                  const SizedBox(height: 6),
                ],
                Align(
                  alignment: horizontal
                      ? Alignment.centerLeft
                      : Alignment.center,
                  child: FilledButton.icon(
                    key: Key(
                      draft == null
                          ? 'add_boarding_info_button'
                          : 'edit_boarding_info_button',
                    ),
                    onPressed: _openForm,
                    icon: Icon(
                      draft == null
                          ? Icons.playlist_add_rounded
                          : Icons.edit_outlined,
                    ),
                    label: Text(
                      draft == null
                          ? 'Pansiyon Bilgileri Ekle'
                          : 'Bilgileri Düzenle',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = <Widget>[
                KeyedSubtree(
                  key: const Key('file_operations_card'),
                  child: _buildFileOperationsCard(),
                ),
                if (widget.backupService != null)
                  KeyedSubtree(
                    key: const Key('backup_card'),
                    child: _buildBackupCard(),
                  ),
              ];
              // Alt iki kartın yüksekliği her durumda eşit olsun.
              if (constraints.maxWidth < 760) {
                return IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cards.first,
                      const SizedBox(height: 16),
                      if (cards.length > 1) cards[1],
                    ],
                  ),
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards.first),
                    const SizedBox(width: 16),
                    if (cards.length > 1) Expanded(child: cards[1]),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileOperationsCard() {
    return _FormSection(
      title: 'Dosya İşlemleri',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const Key('new_pansiyon_operation_button'),
                onPressed: _isPansiyonFileBusy ? null : _startCreateNewPansiyon,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Yeni Pansiyon Oluştur'),
              ),
              OutlinedButton.icon(
                key: const Key('open_pansiyon_file_operation_button'),
                onPressed: _isPansiyonFileBusy ? null : _openPansiyonFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Pansiyon Dosyası Aç'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Yeni Pansiyon Oluştur boş bir pansiyon dosyası oluşturur; mevcut '
            'veriler aktarılmaz. Pansiyon Dosyası Aç daha önce oluşturduğunuz '
            'dosyayı açar.',
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard() {
    return _BackupRestoreCard(
      backupService: widget.backupService!,
      onChanged: () {
        _usage = null;
        _loadUsage();
      },
    );
  }

  Future<void> _loadUsage() async {
    final editLock = widget.editLock;
    if (editLock == null) {
      return;
    }
    try {
      final usage = await editLock.loadUsage();
      if (mounted) {
        setState(() => _usage = usage);
      }
    } catch (_) {}
  }

  /// Dört adımlı bilgi formu.
  Widget _buildFormArea(bool horizontal) {
    return Column(
      children: [
        if (_showsPansiyonFileOperations) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('close_boarding_form_button'),
              onPressed: _isSaving ? null : _closeForm,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Pansiyon bilgilerine dön'),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
        Expanded(child: SingleChildScrollView(child: _buildCurrentStep())),
        const SizedBox(height: 16),
        _StepControls(
          currentStep: _currentStep,
          isSaving: _isSaving,
          onBack: _previousStep,
          onNext: _nextStep,
        ),
      ],
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
                inputFormatters: [capitalizeWordsFormatter],
                style: AppTheme.inputTextStyle,
                decoration: const InputDecoration(),
                onChanged: (value) => widget.onSchoolNameChanged?.call(value),
                validator: (value) =>
                    requiredField(value, 'Okul / pansiyon adı'),
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
                    inputFormatters: [capitalizeWordsFormatter],
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: (value) => requiredField(value, 'Müdür adı'),
                  ),
                ),
                _LabelledField(
                  label: 'Müdür telefonu',
                  child: TextFormField(
                    controller: _principalPhoneController,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: formattedPhoneInputFormatters,
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: (value) =>
                        phoneNumberValidator(value, isRequired: true),
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
                    inputFormatters: [capitalizeWordsFormatter],
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: (value) =>
                        requiredField(value, 'Müdür yardımcısı adı'),
                  ),
                ),
                _LabelledField(
                  label: 'Müdür yardımcısı telefonu',
                  child: TextFormField(
                    controller: _deputyPhoneController,
                    keyboardType: TextInputType.phone,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: formattedPhoneInputFormatters,
                    style: AppTheme.inputTextStyle,
                    decoration: const InputDecoration(),
                    validator: (value) =>
                        phoneNumberValidator(value, isRequired: true),
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
          _buildLevelField(),
        ],
      ),
    );
  }

  Widget _buildLevelField() {
    final locked = _isEducationLevelLocked;
    return _LabelledField(
      label: 'Pansiyon kademesi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: _standardInputDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EducationLevel>(
                      value: _educationLevel,
                      isExpanded: true,
                      style: AppTheme.inputTextStyle,
                      items: [
                        for (final level in EducationLevel.values)
                          DropdownMenuItem(
                            value: level,
                            child: Text(level.label),
                          ),
                      ],
                      onChanged: locked ? null : _setEducationLevel,
                    ),
                  ),
                ),
                if (locked)
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.secondary,
                  ),
              ],
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('education_level_lock_notice'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardSurfaceAccent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Text(
                'Kademe kilitli. ${_usage?.description ?? ''} Değiştirmek için '
                '"Yeni Pansiyon Oluştur" işlemini kullanın.',
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_levelLockMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _levelLockMessage!,
              key: const Key('education_level_lock_message'),
              style: const TextStyle(
                color: AppColors.errorFeedback,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
