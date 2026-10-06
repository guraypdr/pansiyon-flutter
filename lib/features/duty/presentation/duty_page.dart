import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/user_error_message.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_teacher_excel_importer.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_distribution.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_report_print.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_roster_tab.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_settings_tab.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_stats_tab.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_teacher_dialogs.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_teacher_tab.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';

class DutyPage extends StatefulWidget {
  const DutyPage({
    super.key,
    required this.repository,
    required this.roomRepository,
    this.boardingInfoRepository,
  });

  final DutyRepository repository;
  final RoomRepository roomRepository;
  final BoardingInfoRepository? boardingInfoRepository;

  @override
  State<DutyPage> createState() => DutyPageState();
}

class DutyPageState extends State<DutyPage> {
  List<DutyTeacher> _teachers = const [];
  List<DutyMonthList> _monthLists = const [];
  Map<String, DutySettings> _settingsBySection = const {};
  Map<int, Map<int, int>> _teacherMonthCounts = const {};
  Set<int> _monthOffTeacherIds = const {};
  List<String> _floorOptions = const [];
  List<String> _sections = const [];
  bool _isMixedBoarding = false;
  String? _selectedListSection;
  int _selectedListYear = 0;
  int _selectedListMonth = 0;
  List<DutyAssignment> _selectedAssignments = const [];
  late int _selectedTab = 0;
  int _calendarYear = DateTime.now().year;
  int _calendarMonth = DateTime.now().month;
  String? _settingsSectionKey;
  bool _isLoading = true;
  bool _isPrinting = false;
  String _schoolName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<String?> get _sectionKeys =>
      _isMixedBoarding ? _sections : const <String?>[null];

  String _sectionLabel(String? key) => key ?? 'Tüm Bölümler';

  @override
  void didUpdateWidget(covariant DutyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.repository.getTeachers(),
        widget.roomRepository.getRooms(),
        widget.repository.getMonthLists(),
        widget.boardingInfoRepository?.load() ??
            Future<BoardingInfoDraft?>.value(null),
        widget.repository.getYearAssignments(DateTime.now().year),
      ]);
      if (!mounted) {
        return;
      }
      final teachers = results[0] as List<DutyTeacher>;
      final rooms = results[1] as List<BoardingRoom>;
      final monthLists = results[2] as List<DutyMonthList>;
      final boardingInfo = results[3] as BoardingInfoDraft?;
      final yearAssignments = results[4] as List<DutyAssignment>;
      final sections = {for (final room in rooms) room.section.label}.toList();
      final isMixed = sections.length > 1;
      final sectionKeys = isMixed ? sections : <String?>[null];

      final settings = <String, DutySettings>{};
      for (final key in sectionKeys) {
        settings[key ?? _allKey] = await widget.repository.getSettings(key);
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _teachers = teachers;
        _monthLists = monthLists;
        _teacherMonthCounts = _buildTeacherMonthCounts(yearAssignments);
        _sections = sections;
        _isMixedBoarding = isMixed;
        _settingsBySection = settings;
        _floorOptions = _buildFloorOptions(rooms, boardingInfo);
        _schoolName = boardingInfo?.schoolName ?? '';
        _settingsSectionKey = _settingsSectionKey ?? sectionKeys.first;
        _isLoading = false;
      });
      await _loadSelectedList();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Nöbet bilgileri yüklenemedi.', AppNotificationTone.error);
    }
  }

  static const _allKey = '';

  Map<int, Map<int, int>> _buildTeacherMonthCounts(
    List<DutyAssignment> assignments,
  ) {
    final result = <int, Map<int, int>>{};
    for (final assignment in assignments) {
      final months = result.putIfAbsent(assignment.teacherId, () => {});
      months[assignment.month] = (months[assignment.month] ?? 0) + 1;
    }
    return result;
  }

  Future<void> _loadSelectedList() async {
    if (_selectedListYear == 0) {
      setState(() => _selectedAssignments = const []);
      return;
    }
    final assignments = await widget.repository.getAssignments(
      year: _selectedListYear,
      month: _selectedListMonth,
      sectionKey: _selectedListSection,
    );
    final off = await widget.repository.getMonthOffTeacherIds(
      year: _selectedListYear,
      month: _selectedListMonth,
      sectionKey: _selectedListSection,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedAssignments = assignments;
      _monthOffTeacherIds = off;
    });
  }

  /// Pansiyondaki tüm katları listeler; öğrenci odası olmayan katlar da dahildir.
  List<String> _buildFloorOptions(
    List<BoardingRoom> rooms,
    BoardingInfoDraft? boardingInfo,
  ) {
    final labels = <String>[];
    void add(String blockName, String floorLabel) {
      final label = '$blockName - $floorLabel';
      if (!labels.contains(label)) {
        labels.add(label);
      }
    }

    for (final block in boardingInfo?.blocks ?? const <BoardingBlockDraft>[]) {
      for (var index = 0; index < block.floors.length; index++) {
        add(block.name, _floorLabelFor(block.hasBasement, index));
      }
    }
    for (final room in rooms) {
      add(room.blockName, room.floorLabel);
    }
    return labels;
  }

  String _floorLabelFor(bool hasBasement, int index) {
    if (hasBasement && index == 0) {
      return 'Bodrum Kat';
    }
    final upper = index - (hasBasement ? 1 : 0);
    return upper == 0 ? 'Zemin Kat' : '$upper. Kat';
  }

  DutySettings get _settings =>
      _settingsBySection[_settingsSectionKey ?? _allKey] ??
      DutySettings(sectionKey: _settingsSectionKey);

  DutySettings _settingsFor(String? sectionKey) =>
      _settingsBySection[sectionKey ?? _allKey] ??
      DutySettings(sectionKey: sectionKey);

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  // --- Öğretmenler -------------------------------------------------------------

  Future<void> _openTeacherForm([DutyTeacher? teacher]) async {
    final result = await showDialog<DutyTeacher>(
      context: context,
      builder: (dialogContext) => DutyTeacherDialog(teacher: teacher),
    );
    if (result == null) {
      return;
    }
    try {
      await widget.repository.saveTeacher(result);
      _notify('Öğretmen kaydedildi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Öğretmen kaydedilemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _deleteTeacher(DutyTeacher teacher) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Öğretmeni sil'),
        content: Text('${teacher.fullName} kalıcı olarak silinsin mi?'),
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
    if (shouldDelete != true || teacher.id == null) {
      return;
    }
    try {
      await widget.repository.deleteTeacher(teacher.id!);
      _notify('Öğretmen silindi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Öğretmen silinemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _importFromExcel() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    final path = result.isEmpty ? null : result.single.path;
    if (path == null || !mounted) {
      return;
    }
    try {
      final preview = await const DutyTeacherExcelImporter().readFile(path);
      if (!mounted) {
        return;
      }
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => DutyImportDialog(preview: preview),
      );
      if (shouldImport != true) {
        return;
      }
      var added = 0;
      for (final row in preview.rows) {
        if (row.missingFields.contains('Ad Soyad')) {
          continue;
        }
        await widget.repository.saveTeacher(row.teacher);
        added++;
      }
      _notify('$added öğretmen eklendi.', AppNotificationTone.success);
      await _load();
    } catch (_) {
      _notify('Excel yüklenemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = const DutyTeacherExcelImporter().buildTemplate();
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Nöbet öğretmeni şablonunu kaydet',
        fileName: 'nöbet_ogretmen_sablonu.xlsx',
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
    } catch (_) {
      _notify('Excel şablonu oluşturulamadı.', AppNotificationTone.error);
    }
  }

  // --- Ay listeleri -------------------------------------------------------------

  Future<void> _createMonthList() async {
    final picked = await showDialog<(int, int)>(
      context: context,
      builder: (dialogContext) => const _MonthPickerDialog(),
    );
    if (picked == null) {
      return;
    }
    final (year, month) = picked;
    var existed = false;
    try {
      for (final key in _sectionKeys) {
        final alreadyExists = await widget.repository.createMonthList(
          year: year,
          month: month,
          sectionKey: key,
        );
        existed = existed || alreadyExists;
      }
    } catch (_) {
      _notify('Nöbet listesi oluşturulamadı.', AppNotificationTone.error);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedListYear = year;
      _selectedListMonth = month;
      _selectedListSection = _sectionKeys.first;
      _selectedTab = 0;
    });
    await _loadSelectedList();
    await _load();
    if (!mounted) {
      return;
    }
    if (existed) {
      _notify(
        '${dutyMonthTitle(year, month)} ayı için zaten nöbet listesi mevcut. '
        'Nöbet listelerinden ilgili aya gidip listeyi görüntüleyebilirsiniz.',
        AppNotificationTone.warning,
      );
    }
  }

  Future<void> _openList(DutyMonthList list) async {
    setState(() {
      _selectedListYear = list.year;
      _selectedListMonth = list.month;
      _selectedListSection = list.sectionKey;
    });
    await _loadSelectedList();
  }

  Future<void> _closeList() async {
    setState(() {
      _selectedListYear = 0;
      _selectedListMonth = 0;
      _selectedAssignments = const [];
    });
  }

  Future<void> _deleteList(DutyMonthList list) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nöbet listesini sil'),
        content: Text(
          '${list.title} • ${list.sectionLabel} listesi silinsin mi?',
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
    if (shouldDelete != true) {
      return;
    }
    try {
      await widget.repository.deleteMonthList(
        year: list.year,
        month: list.month,
        sectionKey: list.sectionKey,
      );
      _notify('Nöbet listesi silindi.', AppNotificationTone.success);
      if (list.year == _selectedListYear &&
          list.sectionKey == _selectedListSection) {
        await _closeList();
      }
      await _load();
    } catch (_) {
      _notify('Nöbet listesi silinemedi.', AppNotificationTone.error);
    }
  }

  // --- Dağıtım -----------------------------------------------------------------

  List<DutyTeacher> _availableTeachers(String? sectionKey) {
    final off = _monthOffTeacherIds;
    return _teachers
        .where((teacher) => teacher.isActive && !off.contains(teacher.id))
        .toList(growable: false);
  }

  List<DateTime> _dutyDatesFor(DutySettings settings) {
    return [
      for (final date in dutyMonthDates(_selectedListYear, _selectedListMonth))
        if (!settings.blackouts.contains(dutyDateKey(date))) date,
    ];
  }

  Future<void> _distribute() async {
    final sectionKey = _selectedListSection;
    final settings = _settingsFor(sectionKey);
    final teachers = _availableTeachers(sectionKey);
    if (teachers.isEmpty) {
      _notify('Bu bölüm için uygun öğretmen yok.', AppNotificationTone.error);
      return;
    }
    final dates = _dutyDatesFor(settings);
    if (dates.isEmpty) {
      _notify('Seçilen ayda nöbet günü kalmadı.', AppNotificationTone.error);
      return;
    }
    final assignments = DutyDistribution.generate(
      DutyDistributionInput(
        year: _selectedListYear,
        month: _selectedListMonth,
        teachers: teachers,
        dutyDates: dates,
        locations: settings.locations,
        dailyCount: settings.dailyCount,
        maxConsecutive: settings.maxConsecutive,
      ),
    );
    if (assignments.isEmpty) {
      _notify(
        'Dağıtım yapılamadı, öğretmenlerin müsait günlerini kontrol edin.',
        AppNotificationTone.error,
      );
      return;
    }
    try {
      await widget.repository.replaceAssignments(
        year: _selectedListYear,
        month: _selectedListMonth,
        sectionKey: sectionKey,
        assignments: assignments,
      );
      _notify(
        '${assignments.length} nöbet dağıtıldı.',
        AppNotificationTone.success,
      );
      await _loadSelectedList();
      await _load();
    } catch (error) {
      _notify(
        userErrorMessage(error, fallback: 'Nöbet dağıtılamadı.'),
        AppNotificationTone.error,
      );
    }
  }

  Future<void> _updateAssignment(int index, DutyAssignment value) async {
    final updated = [..._selectedAssignments];
    updated[index] = value;
    setState(() => _selectedAssignments = updated);
    await _persistAssignments();
  }

  /// Boş yuvadan seçim yap\u0131ld\u0131\u011f\u0131nda yeni atama ekler.
  Future<void> _updateAssignmentFromSlot(
    int index,
    DutyAssignment value,
  ) async {
    if (index >= 0) {
      await _updateAssignment(index, value);
      return;
    }
    final updated = [..._selectedAssignments, value];
    setState(() => _selectedAssignments = updated);
    await _persistAssignments();
  }

  Future<void> _removeAssignment(int index) async {
    final updated = [..._selectedAssignments]..removeAt(index);
    setState(() => _selectedAssignments = updated);
    await _persistAssignments();
  }

  Future<void> _persistAssignments() async {
    try {
      await widget.repository.replaceAssignments(
        year: _selectedListYear,
        month: _selectedListMonth,
        sectionKey: _selectedListSection,
        assignments: _selectedAssignments,
      );
      await _load();
    } catch (_) {
      _notify('Nöbet kaydedilemedi.', AppNotificationTone.error);
      await _loadSelectedList();
    }
  }

  // --- Ayarlar -----------------------------------------------------------------

  Future<void> _saveSettings(DutySettings settings) async {
    try {
      await widget.repository.saveSettings(settings);
      final updated = {..._settingsBySection};
      updated[settings.sectionKey ?? _allKey] = settings;
      if (mounted) {
        setState(() => _settingsBySection = updated);
      }
      _notify('Nöbet ayarları kaydedildi.', AppNotificationTone.success);
    } catch (_) {
      _notify('Ayarlar kaydedilemedi.', AppNotificationTone.error);
    }
  }

  Future<void> _toggleMonthOff(DutyTeacher teacher) async {
    final updated = {..._monthOffTeacherIds};
    if (updated.contains(teacher.id)) {
      updated.remove(teacher.id);
    } else if (teacher.id != null) {
      updated.add(teacher.id!);
    }
    try {
      await widget.repository.saveMonthOffTeacherIds(
        year: _selectedListYear,
        month: _selectedListMonth,
        sectionKey: _selectedListSection,
        teacherIds: updated,
      );
      if (mounted) {
        setState(() => _monthOffTeacherIds = updated);
      }
    } catch (_) {
      _notify('Kaydedilemedi.', AppNotificationTone.error);
    }
  }

  // --- Çıktı -------------------------------------------------------------------

  Future<void> _print(DutyReportKind kind) async {
    final allLists = await widget.repository.getMonthLists();
    if (!mounted) {
      return;
    }
    setState(() => _isPrinting = true);
    try {
      await printDutyReport(
        context: context,
        kind: kind,
        report: DutyReportData(
          schoolName: _schoolName,
          teachers: _teachers,
          lists: allLists,
          currentList: _selectedListYear == 0
              ? null
              : DutyMonthList(
                  year: _selectedListYear,
                  month: _selectedListMonth,
                  sectionKey: _selectedListSection,
                  assignmentCount: _selectedAssignments.length,
                ),
          currentAssignments: _selectedAssignments,
          settings: _settingsFor(_selectedListSection),
        ),
      );
    } catch (_) {
      _notify('Çıktı hazırlanamadı.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final inDetail = _selectedListYear != 0 && _selectedTab == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (inDetail)
                    IconButton(
                      key: const Key('duty_back_to_lists'),
                      onPressed: _closeList,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Listelere dön',
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inDetail
                              ? '${dutyMonthTitle(_selectedListYear, _selectedListMonth)} • '
                                    '${_sectionLabel(_selectedListSection)}'
                              : 'Nöbetler',
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
                      ],
                    ),
                  ),
                  _buildActions(inDetail),
                ],
              ),
              const SizedBox(height: 14),
              _buildTabBar(),
            ],
          ),
        ),
        Expanded(child: _buildContent(inDetail)),
      ],
    );
  }

  String get _summaryLine {
    final year = DateTime.now().year;
    final yearLists = _monthLists.where((item) => item.year == year).toList();
    final total = yearLists.fold<int>(
      0,
      (sum, item) => sum + item.assignmentCount,
    );
    return '${_teachers.length} öğretmen • $year yılında ${yearLists.length} liste • $total nöbet';
  }

  Widget _buildActions(bool inDetail) {
    if (inDetail) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<DutyReportKind>(
            key: const Key('duty_print_menu'),
            enabled: !_isPrinting,
            onSelected: _print,
            itemBuilder: (context) => [
              for (final kind in DutyReportKind.values)
                PopupMenuItem(value: kind, child: Text(kind.label)),
            ],
            child: Chip(
              avatar: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Çıktı Al'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('duty_distribute_button'),
            onPressed: _distribute,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('Otomatik Dağıt'),
          ),
        ],
      );
    }
    if (_selectedTab == 0) {
      return FilledButton.icon(
        key: const Key('duty_create_list_button'),
        onPressed: _createMonthList,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Nöbet Listesi Oluştur'),
      );
    }
    if (_selectedTab == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            key: const Key('duty_import_button'),
            onPressed: _importFromExcel,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Excelden Toplu Öğretmen Yükle'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('duty_template_button'),
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Şablon İndir'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('duty_add_teacher_button'),
            onPressed: () => _openTeacherForm(),
            icon: const Icon(Icons.person_add_alt_1, size: 20),
            label: const Text('Öğretmen Ekle'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTabBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: DutyTabBar(
        selectedIndex: _selectedTab,
        onSelected: (index) {
          if (index != 0) {
            _closeList();
          }
          setState(() => _selectedTab = index);
        },
      ),
    );
  }

  Widget _buildContent(bool inDetail) {
    switch (_selectedTab) {
      case 3:
        return DutyStatsTab(
          teachers: _teachers,
          lists: _monthLists,
          assignments: _selectedAssignments,
          year: DateTime.now().year,
          perTeacherMonth: _teacherMonthCounts,
        );
      case 1:
        return DutySettingsTab(
          settings: _settings,
          sections: _sectionKeys,
          selectedSectionKey: _settingsSectionKey,
          floorOptions: _floorOptions,
          calendarYear: _calendarYear,
          calendarMonth: _calendarMonth,
          onSectionChanged: (key) => setState(() => _settingsSectionKey = key),
          onCalendarChanged: (year, month) => setState(() {
            _calendarYear = year;
            _calendarMonth = month;
          }),
          onSaveSettings: _saveSettings,
        );
      case 2:
        return DutyTeacherTab(
          teachers: _teachers,
          monthOffTeacherIds: _selectedListYear == 0
              ? const {}
              : _monthOffTeacherIds,
          canToggleMonth: _selectedListYear != 0,
          onEdit: _openTeacherForm,
          onDelete: _deleteTeacher,
          onToggleMonth: _toggleMonthOff,
        );
      default:
        if (inDetail) {
          return DutyRosterTab(
            year: _selectedListYear,
            month: _selectedListMonth,
            settings: _settingsFor(_selectedListSection),
            assignments: _selectedAssignments,
            teachers: _availableTeachers(_selectedListSection),
            onAssignmentChanged: _updateAssignmentFromSlot,
            onAssignmentRemoved: _removeAssignment,
          );
        }
        return _buildMonthLists();
    }
  }

  Widget _buildMonthLists() {
    if (_monthLists.isEmpty) {
      return const _DutyEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Henüz nöbet listesi yok',
        message:
            'Nöbet Listesi Oluştur butonuyla ay seçip liste oluşturun, '
            'ardından Otomatik Dağıt ile nöbetleri yazdırın.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: _monthLists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final list = _monthLists[index];
        return _DutyMonthListCard(
          list: list,
          onOpen: () => unawaited(_openList(list)),
          onDelete: () => unawaited(_deleteList(list)),
        );
      },
    );
  }
}

class _DutyMonthListCard extends StatelessWidget {
  const _DutyMonthListCard({
    required this.list,
    required this.onOpen,
    required this.onDelete,
  });

  final DutyMonthList list;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key(
          'duty_list_card_${list.year}_${list.month}_${list.sectionKey ?? 'all'}',
        ),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  '${list.month}',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${list.sectionLabel} • ${list.assignmentCount} nöbet',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
              IconButton(
                key: Key(
                  'duty_list_delete_${list.year}_${list.month}_${list.sectionKey ?? 'all'}',
                ),
                onPressed: onDelete,
                tooltip: 'Listeyi sil',
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.errorFeedback,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog();

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nöbet Listesi Oluştur'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppInlineDropdown<int>(
                    key: const Key('duty_picker_year'),
                    value: _year,
                    isExpanded: true,
                    items: [
                      for (var year = _year - 1; year <= _year + 2; year++)
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _year = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInlineDropdown<int>(
                    key: const Key('duty_picker_month'),
                    value: _month,
                    isExpanded: true,
                    items: [
                      for (var month = 1; month <= 12; month++)
                        DropdownMenuItem(
                          value: month,
                          child: Text(dutyMonthName(month)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _month = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Seçilen ay için nöbet listesi açılır. Karma pansiyonda her bölüm '
              'için ayrı liste oluşturulur.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('duty_picker_confirm'),
          onPressed: () => Navigator.of(context).pop((_year, _month)),
          child: const Text('Liste Oluştur'),
        ),
      ],
    );
  }
}

class _DutyEmptyState extends StatelessWidget {
  const _DutyEmptyState({
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: AppColors.lavender),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
