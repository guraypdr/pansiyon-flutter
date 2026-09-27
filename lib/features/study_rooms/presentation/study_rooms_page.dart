import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/data/study_room_repository.dart';
import 'package:pansiyon_yonetim/features/study_rooms/domain/study_room_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/presentation/study_room_seating_preview.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_toggle.dart';

/// Etüt salonları ekranı.
///
/// Salonlar kullanıcı tarafından eklenir; her salonun bölümü, bloğu, katı,
/// kapasitesi ve oturma düzeni vardır. Kattaki öğrenciler otomatik yerleştirme
/// butonu ile salona dağıtılır, istenen öğrenci havuza geri alınabilir.
class StudyRoomsPage extends StatefulWidget {
  const StudyRoomsPage({
    super.key,
    required this.repository,
    required this.studentRepository,
  });

  final StudyRoomRepository repository;
  final StudentRepository studentRepository;

  @override
  State<StudyRoomsPage> createState() => _StudyRoomsPageState();
}

class _StudyRoomsPageState extends State<StudyRoomsPage> {
  List<StudyRoom> _rooms = const [];
  List<StudyRoomAssignment> _assignments = const [];
  List<Student> _students = const [];
  List<StudyRoomFloorOption> _floorOptions = const [];
  List<StudyRoomFloorPool> _pools = const [];
  bool _isLoading = true;
  bool _isWorking = false;

  String _sectionFilter = _allLabel;
  String _blockFilter = _allLabel;
  String _floorFilter = _allLabel;

  static const _allLabel = 'Tümü';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.repository.getStudyRooms(),
        widget.repository.getAssignments(),
        widget.studentRepository.getStudents(),
        widget.repository.getFloorOptions(),
        widget.repository.getFloorPools(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _rooms = results[0] as List<StudyRoom>;
        _assignments = results[1] as List<StudyRoomAssignment>;
        _students = results[2] as List<Student>;
        _floorOptions = results[3] as List<StudyRoomFloorOption>;
        _pools = results[4] as List<StudyRoomFloorPool>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _notify('Etüt salonları okunamadı.');
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

  List<String> get _sectionOptions => <String>{
    _allLabel,
    for (final room in _rooms) room.sectionLabel,
  }.toList(growable: false);

  List<String> get _blockOptions => <String>{
    _allLabel,
    for (final room in _rooms) room.blockName,
  }.toList(growable: false);

  List<String> get _floorOptionsForFilter => <String>{
    _allLabel,
    for (final room in _rooms) room.floorLabel,
  }.toList(growable: false);

  List<StudyRoom> get _visibleRooms {
    return _rooms
        .where((room) {
          if (_sectionFilter != _allLabel &&
              room.sectionLabel != _sectionFilter) {
            return false;
          }
          if (_blockFilter != _allLabel && room.blockName != _blockFilter) {
            return false;
          }
          if (_floorFilter != _allLabel && room.floorLabel != _floorFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<Student> get _studentsById => _students;

  Student? _studentById(int id) {
    for (final student in _studentsById) {
      if (student.id == id) {
        return student;
      }
    }
    return null;
  }

  List<Student> _assignedStudents(StudyRoom room) {
    final ids = _assignments
        .where((assignment) => assignment.studyRoomId == room.id)
        .map((assignment) => assignment.studentId);
    return [for (final id in ids) ?_studentById(id)];
  }

  String get _summaryLine {
    if (_rooms.isEmpty) {
      return '0 salon kayıtlı';
    }
    final total = _rooms.fold<int>(0, (sum, room) => sum + room.capacity);
    final occupied = _rooms.fold<int>(
      0,
      (sum, room) => sum + room.occupantCount,
    );
    return '${_rooms.length} salon • $occupied / $total kişi • '
        '${_poolStudents.length} öğrenci havuzda';
  }

  /// Filtrelere uyan, hiçbir salona yerleştirilmemiş öğrenciler.
  List<Student> get _poolStudents {
    final ids = <int>{for (final pool in _visiblePools) ...pool.studentIds};
    return [for (final id in ids) ?_studentById(id)];
  }

  List<StudyRoomFloorPool> get _visiblePools {
    return _pools
        .where((pool) {
          if (_sectionFilter != _allLabel &&
              pool.section.label != _sectionFilter) {
            return false;
          }
          if (_blockFilter != _allLabel && pool.blockName != _blockFilter) {
            return false;
          }
          if (_floorFilter != _allLabel && pool.floorLabel != _floorFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Verilen salonla aynı katta bulunan salonlar (manuel yerleştirme için).
  List<StudyRoom> _roomsOnSameFloor(StudyRoomFloorPool pool) {
    return _visibleRooms
        .where(
          (room) =>
              room.section == pool.section &&
              room.blockName == pool.blockName &&
              room.floorNumber == pool.floorNumber,
        )
        .toList(growable: false);
  }

  Future<void> _growLayout(
    StudyRoom room, {
    int columns = 0,
    int rows = 0,
    int uLeftSeats = 0,
    int uRightSeats = 0,
    int uBaseSeats = 0,
    int tableColumns = 0,
    int tableRows = 0,
  }) async {
    setState(() => _isWorking = true);
    try {
      await widget.repository.growLayout(
        studyRoomId: room.id,
        columns: columns,
        rows: rows,
        uLeftSeats: uLeftSeats,
        uRightSeats: uRightSeats,
        uBaseSeats: uBaseSeats,
        tableColumns: tableColumns,
        tableRows: tableRows,
      );
      await _load();
      if (mounted) {
        setState(() => _isWorking = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isWorking = false);
      }
      _notify(_errorMessageFor(error));
    }
  }

  Future<void> _placeStudent(StudyRoom room, Student student) async {
    setState(() => _isWorking = true);
    try {
      await widget.repository.placeStudent(
        studyRoomId: room.id,
        studentId: student.id!,
      );
      await _load();
      if (mounted) {
        setState(() => _isWorking = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isWorking = false);
      }
      _notify(_errorMessageFor(error));
    }
  }

  String _errorMessageFor(Object error) {
    final text = error.toString();
    if (text.startsWith('Bad state:')) {
      return text.replaceFirst('Bad state: ', '');
    }
    return 'Öğrenci yerleştirilemedi.';
  }

  Future<void> _openCreateDialog() async {
    if (_floorOptions.isEmpty) {
      _notify(
        'Önce Ayarlar > Pansiyon Bilgileri içinde blok ve kat tanımlayın.',
      );
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _StudyRoomFormDialog(
        repository: widget.repository,
        floorOptions: _floorOptions,
        roomCount: _rooms.length + 1,
      ),
    );
    if (created == true) {
      await _load();
      _notify('Etüt salonu eklendi.', AppNotificationTone.success);
    }
  }

  Future<void> _openEditDialog(StudyRoom room) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _StudyRoomFormDialog(
        repository: widget.repository,
        floorOptions: _floorOptions,
        roomCount: _rooms.length + 1,
        existing: room,
      ),
    );
    if (saved == true) {
      await _load();
      _notify('Etüt salonu güncellendi.', AppNotificationTone.success);
    }
  }

  Future<void> _deleteRoom(StudyRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Etüt salonu silinsin mi?'),
        content: Text(
          '"${room.name}" silinecek. Salona yerleştirilmiş öğrenciler '
          'havuza geri döner.',
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
    setState(() => _isWorking = true);
    try {
      await widget.repository.deleteStudyRoom(room.id);
      await _load();
      if (mounted) {
        _notify('Etüt salonu silindi.', AppNotificationTone.success);
      }
    } catch (_) {
      _notify('Etüt salonu silinemedi.');
    }
  }

  Future<void> _autoPlace(StudyRoom room) async {
    setState(() => _isWorking = true);
    try {
      final placed = await widget.repository.autoPlaceStudents(room.id);
      await _load();
      if (mounted) {
        setState(() => _isWorking = false);
        _notify(
          placed == 0
              ? 'Bu salona yerleştirilecek öğrenci bulunamadı.'
              : '$placed öğrenci otomatik yerleştirildi.',
          placed == 0 ? AppNotificationTone.error : AppNotificationTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isWorking = false);
      }
      _notify('Öğrenciler yerleştirilemedi.');
    }
  }

  Future<void> _releaseStudent(Student student) async {
    setState(() => _isWorking = true);
    try {
      await widget.repository.releaseStudent(student.id!);
      await _load();
      if (mounted) {
        setState(() => _isWorking = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isWorking = false);
      }
      _notify('Öğrenci havuza alınamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visibleRooms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Etüt Salonları',
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
              const SizedBox(height: 14),
              _buildToolbar(),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1040;
              final roomsList = visible.isEmpty
                  ? _EmptyStudyRooms(hasAnyRoom: _rooms.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final room = visible[index];
                        return _StudyRoomCard(
                          room: room,
                          students: _assignedStudents(room),
                          isWorking: _isWorking,
                          onEdit: () => _openEditDialog(room),
                          onDelete: () => _deleteRoom(room),
                          onAutoPlace: () => _autoPlace(room),
                          onReleaseStudent: _releaseStudent,
                          onGrowLayout:
                              ({
                                int columns = 0,
                                int rows = 0,
                                int uLeftSeats = 0,
                                int uRightSeats = 0,
                                int uBaseSeats = 0,
                                int tableColumns = 0,
                                int tableRows = 0,
                              }) => _growLayout(
                                room,
                                columns: columns,
                                rows: rows,
                                uLeftSeats: uLeftSeats,
                                uRightSeats: uRightSeats,
                                uBaseSeats: uBaseSeats,
                                tableColumns: tableColumns,
                                tableRows: tableRows,
                              ),
                        );
                      },
                    );
              if (!wide) {
                return Column(
                  children: [
                    Expanded(child: roomsList),
                    SizedBox(
                      height: constraints.maxHeight < 640 ? 230 : 290,
                      child: _buildPoolPanel(horizontal: false),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: roomsList),
                  const SizedBox(width: 14),
                  SizedBox(width: 340, child: _buildPoolPanel()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPoolPanel({bool horizontal = true}) {
    final pools = _visiblePools;
    final total = _poolStudents.length;
    return Container(
      margin: EdgeInsets.fromLTRB(horizontal ? 0 : 20, 8, 20, 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Öğrenci Havuzu',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$total öğrenci',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Salona yerleştirilmemiş, o katta uyuyan öğrenciler.',
            style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: total == 0
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Havuzda öğrenci yok. Katlardaki tüm öğrenciler '
                        'salonlara yerleştirilmiş.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final pool in pools)
                        if (pool.studentIds.isNotEmpty) ...[
                          Text(
                            pool.label,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final id in pool.studentIds)
                                if (_studentById(id) case final student?)
                                  _PoolStudentChip(
                                    key: Key('pool_student_$id'),
                                    student: student,
                                    rooms: _roomsOnSameFloor(pool),
                                    isWorking: _isWorking,
                                    onPlace: (room) =>
                                        _placeStudent(room, student),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = <Widget>[
          _StudyFilterButton(
            filterKey: const Key('study_section_filter'),
            label: 'Bölüm',
            value: _sectionFilter,
            options: _sectionOptions,
            onSelected: (value) => setState(() => _sectionFilter = value),
          ),
          _StudyFilterButton(
            filterKey: const Key('study_block_filter'),
            label: 'Blok',
            value: _blockFilter,
            options: _blockOptions,
            onSelected: (value) => setState(() => _blockFilter = value),
          ),
          _StudyFilterButton(
            filterKey: const Key('study_floor_filter'),
            label: 'Kat',
            value: _floorFilter,
            options: _floorOptionsForFilter,
            onSelected: (value) => setState(() => _floorFilter = value),
          ),
        ];
        final actions = <Widget>[
          FilledButton.icon(
            key: const Key('add_study_room_button'),
            onPressed: _isWorking ? null : _openCreateDialog,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Etüt Salonu Ekle'),
          ),
        ];
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: filters),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: actions.first),
            ],
          );
        }
        return Row(
          children: [
            for (final filter in filters) ...[filter, const SizedBox(width: 8)],
            const Spacer(),
            actions.first,
          ],
        );
      },
    );
  }
}

/// Etüt salonu ekleme / düzenleme diyaloğu.
///
/// Bölüm, blok ve kat seçeneklerinden yalnızca birer tane varsa sorulmaz.
class _StudyRoomFormDialog extends StatefulWidget {
  const _StudyRoomFormDialog({
    required this.repository,
    required this.floorOptions,
    required this.roomCount,
    this.existing,
  });

  final StudyRoomRepository repository;
  final List<StudyRoomFloorOption> floorOptions;
  final int roomCount;
  final StudyRoom? existing;

  @override
  State<_StudyRoomFormDialog> createState() => _StudyRoomFormDialogState();
}

class _StudyRoomFormDialogState extends State<_StudyRoomFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _tableSizeController;

  late StudyRoomFloorOption _option;
  late StudyRoomSeating _seating;
  late StudyRoomLayout _layout;
  bool _tablesHaveStudents = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<BoardingSection> get _sectionChoices {
    final sections = <BoardingSection>{
      for (final option in widget.floorOptions) option.section,
    };
    if (sections.length == 1) {
      return sections.toList(growable: false);
    }
    final list = sections.toList();
    list.sort((a, b) => a.index.compareTo(b.index));
    return list;
  }

  List<String> get _blockChoices {
    final names = <String>{
      for (final option in widget.floorOptions)
        if (_sectionChoices.length == 1 || option.section == _option.section)
          option.blockName,
    };
    return _withSingleOrSorted(names);
  }

  List<String> get _floorChoices {
    final labels = <String>{
      for (final option in widget.floorOptions)
        if (option.section == _option.section &&
            option.blockName == _option.blockName)
          option.floorLabel,
    };
    return _withSingleOrSorted(labels);
  }

  List<String> _withSingleOrSorted(Set<String> values) {
    if (values.length == 1) {
      return values.toList(growable: false);
    }
    final list = values.toList();
    list.sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _option = existing == null
        ? widget.floorOptions.first
        : widget.floorOptions.firstWhere(
            (option) =>
                option.section == existing.section &&
                option.blockName == existing.blockName &&
                option.floorLabel == existing.floorLabel,
            orElse: () => widget.floorOptions.first,
          );
    _nameController = TextEditingController(
      text: existing?.name ?? 'Etüt Salonu ${widget.roomCount}',
    );
    _seating = existing?.seating ?? StudyRoomSeating.single;
    _layout = existing?.layout ?? StudyRoomLayout.defaultsFor(_seating);
    _tablesHaveStudents = existing?.tablesHaveStudents ?? true;
    _tableSizeController = TextEditingController(
      text: existing?.tableSize == null ? '4' : '${existing!.tableSize}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tableSizeController.dispose();
    super.dispose();
  }

  int get _capacity => _layout.capacityOf(
    _seating,
    tableSize: int.tryParse(_tableSizeController.text.trim()) ?? 4,
    tableHeads: _tablesHaveStudents,
  );

  /// Sayaçları artırır veya azaltır; en küçük değer 1'dir.
  void _bump({
    int columns = 0,
    int rows = 0,
    int uLeftSeats = 0,
    int uRightSeats = 0,
    int uBaseSeats = 0,
    int tableColumns = 0,
    int tableRows = 0,
  }) {
    setState(() {
      _layout = StudyRoomLayout(
        columns: (_layout.columns + columns).clamp(1, 999),
        rows: (_layout.rows + rows).clamp(1, 999),
        uLeftSeats: (_layout.uLeftSeats + uLeftSeats).clamp(1, 999),
        uRightSeats: (_layout.uRightSeats + uRightSeats).clamp(1, 999),
        uBaseSeats: (_layout.uBaseSeats + uBaseSeats).clamp(1, 999),
        tableColumns: (_layout.tableColumns + tableColumns).clamp(1, 999),
        tableRows: (_layout.tableRows + tableRows).clamp(1, 999),
      );
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Etüt salonu adı boş olamaz.');
      return;
    }
    final tableSize = _seating.asksTableSize
        ? int.tryParse(_tableSizeController.text.trim())
        : null;
    if (_seating.asksTableSize && (tableSize == null || tableSize <= 0)) {
      setState(() => _errorMessage = 'Masa kaç kişilik girilmelidir.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await _create(name, tableSize);
      } else {
        await _update(existing, name, tableSize);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = _messageFor(error);
        });
      }
    }
  }

  Future<void> _create(String name, int? tableSize) async {
    await widget.repository.createStudyRoom(
      name: name,
      section: _option.section,
      blockName: _option.blockName,
      floorLabel: _option.floorLabel,
      floorNumber: _option.floorNumber,
      seating: _seating,
      layout: _layout,
      tableSize: tableSize,
      tablesHaveStudents: _tablesHaveStudents,
    );
  }

  Future<void> _update(StudyRoom existing, String name, int? tableSize) async {
    await widget.repository.updateStudyRoom(
      id: existing.id,
      name: name,
      seating: _seating,
      layout: _layout,
      tableSize: tableSize,
      tablesHaveStudents: _tablesHaveStudents,
    );
  }

  String _messageFor(Object error) {
    final text = error.toString();
    if (text.startsWith('Invalid argument')) {
      final message = text.split(': ').last.split(').').last;
      return message.isEmpty ? 'Değer geçersiz.' : message;
    }
    if (text.startsWith('Bad state:')) {
      return text.replaceFirst('Bad state: ', '');
    }
    return 'Etüt salonu kaydedilemedi.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Etüt Salonu Ekle' : 'Etüt Salonu Düzenle',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                label: 'Salon adı',
                child: TextField(
                  key: const Key('study_room_name_field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [capitalizeWordsFormatter],
                ),
              ),
              if (_sectionChoices.length > 1)
                _field(
                  label: 'Bölüm',
                  child: _Dropdown<BoardingSection>(
                    fieldKey: const Key('study_room_section_dropdown'),
                    value: _option.section,
                    options: _sectionChoices,
                    labelOf: (section) => section.label,
                    onChanged: (value) => setState(() {
                      _option = _firstOptionFor(
                        section: value,
                        blockName: _blockChoices.first,
                        floorLabel: _floorChoices.first,
                      );
                    }),
                  ),
                ),
              if (_blockChoices.length > 1)
                _field(
                  label: 'Blok',
                  child: _Dropdown<String>(
                    fieldKey: const Key('study_room_block_dropdown'),
                    value: _option.blockName,
                    options: _blockChoices,
                    onChanged: (value) => setState(() {
                      _option = _firstOptionFor(
                        section: _option.section,
                        blockName: value,
                        floorLabel: _floorChoices.first,
                      );
                    }),
                  ),
                ),
              if (_floorChoices.length > 1)
                _field(
                  label: 'Kat',
                  child: _Dropdown<String>(
                    fieldKey: const Key('study_room_floor_dropdown'),
                    value: _option.floorLabel,
                    options: _floorChoices,
                    onChanged: (value) => setState(() {
                      _option = _firstOptionFor(
                        section: _option.section,
                        blockName: _option.blockName,
                        floorLabel: value,
                      );
                    }),
                  ),
                ),
              _field(
                label: 'Konum',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: Text(_option.label, style: AppTheme.inputTextStyle),
                ),
              ),
              _field(
                label: 'Oturma düzeni',
                child: _Dropdown<StudyRoomSeating>(
                  fieldKey: const Key('study_room_seating_dropdown'),
                  value: _seating,
                  options: StudyRoomSeating.values,
                  labelOf: (seating) => seating.label,
                  onChanged: (value) => setState(() {
                    _seating = value;
                    _layout = StudyRoomLayout.defaultsFor(value);
                  }),
                ),
              ),
              if (_seating.asksTableSize) ...[
                _field(
                  label: 'Masa kaç kişilik',
                  child: TextField(
                    key: const Key('study_room_table_size_field'),
                    controller: _tableSizeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                AppToggle(
                  key: const Key('study_room_tables_have_students'),
                  label: 'Masa başlarında oturan var mı?',
                  value: _tablesHaveStudents,
                  onChanged: (value) =>
                      setState(() => _tablesHaveStudents = value),
                ),
              ],
              _field(
                label: 'Düzen',
                child: _LayoutCounterField(
                  keyPrefix: 'dialog_',
                  seating: _seating,
                  layout: _layout,
                  capacity: _capacity,
                  onAddColumns: () => _bump(columns: 1),
                  onRemoveColumns: () => _bump(columns: -1),
                  onAddRows: () => _bump(rows: 1),
                  onRemoveRows: () => _bump(rows: -1),
                  onAddULeft: () => _bump(uLeftSeats: 1),
                  onRemoveULeft: () => _bump(uLeftSeats: -1),
                  onAddURight: () => _bump(uRightSeats: 1),
                  onRemoveURight: () => _bump(uRightSeats: -1),
                  onAddUBase: () => _bump(uBaseSeats: 1),
                  onRemoveUBase: () => _bump(uBaseSeats: -1),
                  onAddTableColumn: () => _bump(tableColumns: 1),
                  onRemoveTableColumn: () => _bump(tableColumns: -1),
                  onAddTableRow: () => _bump(tableRows: 1),
                  onRemoveTableRow: () => _bump(tableRows: -1),
                ),
              ),
              _field(
                label: 'Düzen görünümü',
                child: StudyRoomSeatingMap(
                  key: const Key('study_room_seating_preview'),
                  seating: _seating,
                  students: const [],
                  layout: _layout,
                  tableSize:
                      int.tryParse(_tableSizeController.text.trim()) ?? 4,
                  tablesHaveStudents: _tablesHaveStudents,
                  height: 200,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.errorFeedback,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('study_room_submit_button'),
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Kaydediliyor' : 'Kaydet'),
        ),
      ],
    );
  }

  StudyRoomFloorOption _firstOptionFor({
    required BoardingSection section,
    required String blockName,
    required String floorLabel,
  }) {
    for (final option in widget.floorOptions) {
      if (option.section == section &&
          option.blockName == blockName &&
          option.floorLabel == floorLabel) {
        return option;
      }
    }
    return widget.floorOptions.first;
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capitalizeWords(label),
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.fieldKey,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelOf,
  });

  final Key fieldKey;
  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final String Function(T value)? labelOf;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        key: fieldKey,
        value: value,
        isExpanded: true,
        style: AppTheme.inputTextStyle,
        items: [
          for (final option in options)
            DropdownMenuItem<T>(
              value: option,
              child: Text(labelOf?.call(option) ?? '$option'),
            ),
        ],
        onChanged: (selected) {
          if (selected != null) {
            onChanged(selected);
          }
        },
      ),
    );
  }
}

class _StudyFilterButton extends StatelessWidget {
  const _StudyFilterButton({
    required this.filterKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final Key filterKey;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isActive = value != _StudyRoomsPageState._allLabel;
    return PopupMenuButton<int>(
      key: filterKey,
      tooltip: '$label filtresi',
      offset: const Offset(0, 44),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.inputBorder),
      ),
      onSelected: (index) => onSelected(options[index]),
      itemBuilder: (context) => [
        for (var index = 0; index < options.length; index++)
          PopupMenuItem<int>(value: index, child: Text(options[index])),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: $value',
              style: TextStyle(
                color: isActive ? AppColors.primaryDark : AppColors.darkText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyRoomCard extends StatelessWidget {
  const _StudyRoomCard({
    required this.room,
    required this.students,
    required this.isWorking,
    required this.onEdit,
    required this.onDelete,
    required this.onAutoPlace,
    required this.onReleaseStudent,
    required this.onGrowLayout,
  });

  final StudyRoom room;
  final List<Student> students;
  final bool isWorking;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAutoPlace;
  final ValueChanged<Student> onReleaseStudent;
  final void Function({
    int columns,
    int rows,
    int uLeftSeats,
    int uRightSeats,
    int uBaseSeats,
    int tableColumns,
    int tableRows,
  })
  onGrowLayout;

  String get _seatingDetail {
    if (room.seating.asksTableSize) {
      final size = room.tableSize ?? 0;
      return '${room.seating.label} • $size kişilik masa'
          '${room.tablesHaveStudents ? ' • Masa başlarında öğrenci var' : ''}';
    }
    return room.seating.label;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('study_room_card_${room.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${room.sectionLabel} • ${room.blockName} • ${room.floorLabel}',
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              _SeatingChip(label: _seatingDetail),
              const SizedBox(width: 8),
              IconButton(
                key: Key('study_room_edit_${room.id}'),
                tooltip: 'Düzenle',
                onPressed: isWorking ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: Key('study_room_delete_${room.id}'),
                tooltip: 'Sil',
                onPressed: isWorking ? null : onDelete,
                color: AppColors.errorFeedback,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OccupancyBar(
                occupied: room.occupantCount,
                capacity: room.capacity,
              ),
              const SizedBox(width: 12),
              Text(
                '${room.occupantCount} / ${room.capacity} kişi',
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                key: Key('study_room_auto_place_${room.id}'),
                onPressed: isWorking ? null : onAutoPlace,
                icon: const Icon(Icons.auto_awesome_motion_outlined, size: 20),
                label: const Text('Otomatik Yerleştir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Düzen büyütme butonları: kapasite otomatik artar.
          _LayoutCounterField(
            keyPrefix: 'grow_${room.id}_',
            seating: room.seating,
            layout: room.layout,
            capacity: room.capacity,
            onAddColumns: () => onGrowLayout(columns: 1),
            onRemoveColumns: () => onGrowLayout(columns: -1),
            onAddRows: () => onGrowLayout(rows: 1),
            onRemoveRows: () => onGrowLayout(rows: -1),
            onAddULeft: () => onGrowLayout(uLeftSeats: 1),
            onRemoveULeft: () => onGrowLayout(uLeftSeats: -1),
            onAddUBase: () => onGrowLayout(uBaseSeats: 1),
            onRemoveUBase: () => onGrowLayout(uBaseSeats: -1),
            onAddURight: () => onGrowLayout(uRightSeats: 1),
            onRemoveURight: () => onGrowLayout(uRightSeats: -1),
            onAddTableColumn: () => onGrowLayout(tableColumns: 1),
            onRemoveTableColumn: () => onGrowLayout(tableColumns: -1),
            onAddTableRow: () => onGrowLayout(tableRows: 1),
            onRemoveTableRow: () => onGrowLayout(tableRows: -1),
          ),
          const SizedBox(height: 12),
          // Seçilen düzene göre öğrencilerin yerleşimini gösteren canlı plan.
          StudyRoomSeatingMap(
            key: Key('study_room_map_${room.id}'),
            seating: room.seating,
            students: students,
            layout: room.layout,
            tableSize: room.tableSize ?? 4,
            tablesHaveStudents: room.tablesHaveStudents,
            height: 240,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Yerleştirilen öğrenciler',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${students.length} kişi',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (students.isEmpty)
            const Text(
              'Henüz öğrenci yerleştirilmedi.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final student in students)
                  _PlacedStudentChip(
                    key: Key('study_room_student_${room.id}_${student.id}'),
                    student: student,
                    isWorking: isWorking,
                    onRelease: () => onReleaseStudent(student),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SeatingChip extends StatelessWidget {
  const _SeatingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softMagenta.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OccupancyBar extends StatelessWidget {
  const _OccupancyBar({required this.occupied, required this.capacity});

  final int occupied;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    final ratio = capacity <= 0 ? 0.0 : (occupied / capacity).clamp(0.0, 1.0);
    return SizedBox(
      width: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          backgroundColor: AppColors.inputBorder,
          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
        ),
      ),
    );
  }
}

class _PlacedStudentChip extends StatelessWidget {
  const _PlacedStudentChip({
    super.key,
    required this.student,
    required this.isWorking,
    required this.onRelease,
  });

  final Student student;
  final bool isWorking;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            student.fullName,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: Key('release_student_${student.id}'),
            tooltip: 'Havuza al',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: isWorking ? null : onRelease,
            icon: const Icon(Icons.close, size: 15),
          ),
        ],
      ),
    );
  }
}

/// Düzen sayaçlarını artı butonlarıyla yöneten alan.
///
/// Kapasite buradan hesaplanır: tekli ve çiftli sıralarda yana ve arkaya
/// sıra, köşeli U düzeninde bacak ve taban, grup düzeninde ise yatay ve dikey
/// masa eklenir.
class _LayoutCounterField extends StatelessWidget {
  const _LayoutCounterField({
    required this.seating,
    required this.layout,
    required this.capacity,
    required this.keyPrefix,
    this.onAddColumns,
    this.onRemoveColumns,
    this.onAddRows,
    this.onRemoveRows,
    this.onAddULeft,
    this.onRemoveULeft,
    this.onAddURight,
    this.onRemoveURight,
    this.onAddUBase,
    this.onRemoveUBase,
    this.onAddTableColumn,
    this.onRemoveTableColumn,
    this.onAddTableRow,
    this.onRemoveTableRow,
  });

  final StudyRoomSeating seating;
  final StudyRoomLayout layout;
  final int capacity;
  final String keyPrefix;
  final VoidCallback? onAddColumns;
  final VoidCallback? onRemoveColumns;
  final VoidCallback? onAddRows;
  final VoidCallback? onRemoveRows;
  final VoidCallback? onAddULeft;
  final VoidCallback? onRemoveULeft;
  final VoidCallback? onAddURight;
  final VoidCallback? onRemoveURight;
  final VoidCallback? onAddUBase;
  final VoidCallback? onRemoveUBase;
  final VoidCallback? onAddTableColumn;
  final VoidCallback? onRemoveTableColumn;
  final VoidCallback? onAddTableRow;
  final VoidCallback? onRemoveTableRow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Otomatik kapasite',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$capacity kişi',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final counter in _counters)
                _CounterChip(counter: counter, keyPrefix: keyPrefix),
            ],
          ),
        ],
      ),
    );
  }

  List<_Counter> get _counters {
    switch (seating) {
      case StudyRoomSeating.single:
      case StudyRoomSeating.pair:
        return [
          _Counter(
            'columns',
            'Yana sıra',
            layout.columns,
            onAddColumns,
            onRemoveColumns,
            minValue: 1,
          ),
          _Counter(
            'rows',
            'Arkaya sıra',
            layout.rows,
            onAddRows,
            onRemoveRows,
            minValue: 1,
          ),
        ];
      case StudyRoomSeating.horseshoe:
        return [
          _Counter(
            'u_left',
            'Sol bacak',
            layout.uLeftSeats,
            onAddULeft,
            onRemoveULeft,
            minValue: 1,
          ),
          _Counter(
            'u_base',
            'Taban',
            layout.uBaseSeats,
            onAddUBase,
            onRemoveUBase,
            minValue: 1,
          ),
          _Counter(
            'u_right',
            'Sağ bacak',
            layout.uRightSeats,
            onAddURight,
            onRemoveURight,
            minValue: 1,
          ),
        ];
      case StudyRoomSeating.groupTables:
        return [
          _Counter(
            'table_columns',
            'Yatay masa',
            layout.tableColumns,
            onAddTableColumn,
            onRemoveTableColumn,
            minValue: 1,
          ),
          _Counter(
            'table_rows',
            'Dikey masa',
            layout.tableRows,
            onAddTableRow,
            onRemoveTableRow,
            minValue: 1,
          ),
        ];
    }
  }
}

class _Counter {
  const _Counter(
    this.key,
    this.label,
    this.value,
    this.onAdd,
    this.onRemove, {
    required this.minValue,
  });

  final String key;
  final String label;
  final int value;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final int minValue;

  String get displayText => '$label: $value';
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.counter, required this.keyPrefix});

  final _Counter counter;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            counter.displayText,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            key: Key('${keyPrefix}minus_${counter.key}'),
            tooltip: '${counter.label} azalt',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: counter.value > counter.minValue
                ? counter.onRemove
                : null,
            icon: const Icon(Icons.remove, size: 16),
          ),
          IconButton(
            key: Key('${keyPrefix}plus_${counter.key}'),
            tooltip: '${counter.label} ekle',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: counter.onAdd,
            icon: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
    );
  }
}

class _PoolStudentChip extends StatelessWidget {
  const _PoolStudentChip({
    super.key,
    required this.student,
    required this.rooms,
    required this.isWorking,
    required this.onPlace,
  });

  final Student student;
  final List<StudyRoom> rooms;
  final bool isWorking;
  final ValueChanged<StudyRoom> onPlace;

  @override
  Widget build(BuildContext context) {
    final available = [
      for (final room in rooms)
        if (room.availableCapacity > 0) room,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            student.fullName,
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(
                Icons.block,
                size: 14,
                color: AppColors.secondaryText,
              ),
            )
          else
            PopupMenuButton<int>(
              key: Key('place_student_${student.id}'),
              tooltip: 'Salona yerleştir',
              offset: const Offset(0, 32),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.inputBorder),
              ),
              onSelected: (index) => onPlace(available[index]),
              itemBuilder: (context) => [
                for (var index = 0; index < available.length; index++)
                  PopupMenuItem<int>(
                    value: index,
                    child: Text(
                      '${available[index].name} '
                      '(${available[index].availableCapacity} boş)',
                    ),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.add_circle_outline, size: 16),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyStudyRooms extends StatelessWidget {
  const _EmptyStudyRooms({required this.hasAnyRoom});

  final bool hasAnyRoom;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasAnyRoom
                  ? 'Seçilen filtrelere uyan etüt salonu yok'
                  : 'Henüz etüt salonu eklenmedi',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasAnyRoom
                  ? 'Filtreleri değiştirerek diğer salonları görebilirsiniz.'
                  : 'Etüt Salonu Ekle butonuyla ilk salonunuzu oluşturun.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
