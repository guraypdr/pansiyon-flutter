import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({
    super.key,
    required this.roomRepository,
    required this.boardingInfoRepository,
    required this.studentRepository,
  });

  final RoomRepository roomRepository;
  final BoardingInfoRepository boardingInfoRepository;
  final StudentRepository studentRepository;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  static const _allFilter = 'Tümü';

  List<BoardingRoom> _rooms = const [];
  List<Student> _students = const [];
  List<RoomAssignment> _assignments = const [];
  String _selectedFloor = _allFilter;
  String _selectedClass = _allFilter;
  bool _showOccupied = true;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final boardingInfo = await widget.boardingInfoRepository.load();
      await widget.roomRepository.syncRooms(boardingInfo);
      await _refreshData();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Odalar yüklenemedi. Bilgileri kontrol edip tekrar deneyin.';
      });
    }
  }

  Future<void> _refreshData() async {
    final rooms = await widget.roomRepository.getRooms();
    final students = await widget.studentRepository.getStudents();
    final assignments = await widget.roomRepository.getAssignments();
    if (!mounted) {
      return;
    }
    final floors = <String>{
      _allFilter,
      ...rooms.map((room) => room.floorLabel),
    };
    final classes = <String>{_allFilter, ...students.map(_classFilterValue)};
    setState(() {
      _rooms = rooms;
      _students = students;
      _assignments = assignments;
      if (!floors.contains(_selectedFloor)) {
        _selectedFloor = _allFilter;
      }
      if (!classes.contains(_selectedClass)) {
        _selectedClass = _allFilter;
      }
      _isLoading = false;
    });
  }

  String _classFilterValue(Student student) {
    final value = student.className?.trim();
    return value == null || value.isEmpty ? 'Sınıf belirtilmedi' : value;
  }

  Map<int, Student> get _studentsById {
    return {
      for (final student in _students)
        if (student.id != null) student.id!: student,
    };
  }

  Set<int> get _assignedStudentIds {
    return _assignments.map((assignment) => assignment.studentId).toSet();
  }

  Map<int, List<Student>> get _studentsByRoom {
    final result = <int, List<Student>>{};
    final studentsById = _studentsById;
    for (final assignment in _assignments) {
      final student = studentsById[assignment.studentId];
      if (student == null) {
        continue;
      }
      result.putIfAbsent(assignment.roomId, () => []).add(student);
    }
    return result;
  }

  List<BoardingRoom> get _filteredRooms {
    return _rooms
        .where(
          (room) =>
              _selectedFloor == _allFilter || room.floorLabel == _selectedFloor,
        )
        .where((room) => _showOccupied || room.occupantCount == 0)
        .toList(growable: false);
  }

  List<Student> get _availableStudents {
    final assignedIds = _assignedStudentIds;
    return _students
        .where(
          (student) =>
              student.id != null &&
              !assignedIds.contains(student.id) &&
              (_selectedClass == _allFilter ||
                  _classFilterValue(student) == _selectedClass),
        )
        .toList(growable: false);
  }

  List<String> get _floorFilters {
    return <String>{
      _allFilter,
      ..._rooms.map((room) => room.floorLabel),
    }.toList()..sort((a, b) {
      if (a == _allFilter) {
        return -1;
      }
      if (b == _allFilter) {
        return 1;
      }
      return a.compareTo(b);
    });
  }

  List<String> get _classFilters {
    return <String>{_allFilter, ..._students.map(_classFilterValue)}.toList()
      ..sort((a, b) {
        if (a == _allFilter) {
          return -1;
        }
        if (b == _allFilter) {
          return 1;
        }
        return a.compareTo(b);
      });
  }

  List<_RoomGroup> get _roomGroups {
    final groups = <_RoomGroup>[];
    for (final room in _filteredRooms) {
      final key = '${room.section.value}|${room.blockName}|${room.floorLabel}';
      _RoomGroup? group;
      for (final item in groups) {
        if (item.key == key) {
          group = item;
          break;
        }
      }
      if (group == null) {
        group = _RoomGroup(
          key: key,
          section: room.section,
          blockName: room.blockName,
          floorLabel: room.floorLabel,
        );
        groups.add(group);
      }
      group.rooms.add(room);
    }
    return groups;
  }

  Future<void> _assignStudent(BoardingRoom room, Student student) async {
    if (student.id == null || !_canAccept(room, student)) {
      return;
    }
    try {
      await widget.roomRepository.assignStudent(
        roomId: room.id,
        studentId: student.id!,
      );
      await _refreshData();
      _notify(
        '${student.fullName} ${room.roomNumber} numaralı odaya yerleştirildi.',
        AppNotificationTone.success,
      );
    } catch (error) {
      _notify(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  bool _canAccept(BoardingRoom room, Student student) {
    return student.id != null &&
        !_assignedStudentIds.contains(student.id) &&
        room.availableCapacity > 0;
  }

  Future<void> _removeStudent(Student student) async {
    if (student.id == null) {
      return;
    }
    try {
      await widget.roomRepository.unassignStudent(student.id!);
      await _refreshData();
      _notify(
        '${student.fullName} öğrenci havuzuna geri alındı.',
        AppNotificationTone.success,
      );
    } catch (_) {
      _notify('Öğrenci yerleştirmesi kaldırılamadı.');
    }
  }

  Future<void> _editCapacity(BoardingRoom room) async {
    final controller = TextEditingController(text: '${room.capacity}');
    final capacity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Oda ${room.roomNumber} Kapasitesi'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Kapasite'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null && value > 0) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (capacity == null) {
      return;
    }
    try {
      await widget.roomRepository.updateRoomCapacity(
        roomId: room.id,
        capacity: capacity,
      );
      await _refreshData();
      _notify(
        'Oda ${room.roomNumber} kapasitesi güncellendi.',
        AppNotificationTone.success,
      );
    } catch (error) {
      _notify(error.toString().replaceFirst('Bad state: ', ''));
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _RoomsEmptyState(
        icon: Icons.error_outline,
        title: 'Odalar yüklenemedi',
        message: _errorMessage!,
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Tekrar dene'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            children: [
              _buildToolbar(),
              const SizedBox(height: 14),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _buildRoomsPanel()),
                          const SizedBox(width: 14),
                          SizedBox(width: 350, child: _buildStudentsPanel()),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildRoomsPanel()),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: constraints.maxHeight < 650 ? 245 : 310,
                            child: _buildStudentsPanel(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardSurface, AppColors.cardSurfaceAccent],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.meeting_room_outlined, color: AppColors.primary),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Oda Yerleştirme',
                  style: TextStyle(
                    color: AppColors.sidebar,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Odaları Güncelle'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Dolu odaları göster'),
                  selected: _showOccupied,
                  onSelected: (value) => setState(() => _showOccupied = value),
                ),
                const SizedBox(width: 8),
                for (final floor in _floorFilters) ...[
                  FilterChip(
                    label: Text(floor),
                    selected: _selectedFloor == floor,
                    onSelected: (_) => setState(() => _selectedFloor = floor),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsPanel() {
    final groups = _roomGroups;
    final items = <Widget>[];
    for (final group in groups) {
      items.add(_RoomGroupHeader(group: group));
      for (final room in group.rooms) {
        items.add(
          _RoomDropCard(
            room: room,
            students: _studentsByRoom[room.id] ?? const [],
            onEditCapacity: () => _editCapacity(room),
            onRemoveStudent: _removeStudent,
            canAccept: _canAccept,
            onAccept: _assignStudent,
          ),
        );
      }
    }

    return _RoomsPanel(
      title: 'Odalar',
      icon: Icons.meeting_room_outlined,
      trailing: '${_filteredRooms.length} oda',
      child: groups.isEmpty
          ? const _RoomsEmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'Henüz oda oluşmadı',
              message:
                  'Pansiyon bilgilerinde öğrenci odası olan katları kaydedin.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => items[index],
            ),
    );
  }

  Widget _buildStudentsPanel() {
    final availableStudents = _availableStudents;
    return _RoomsPanel(
      title: 'Öğrenci Havuzu',
      icon: Icons.groups_outlined,
      trailing: '${availableStudents.length} öğrenci',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final className in _classFilters) ...[
                    ChoiceChip(
                      label: Text(className),
                      selected: _selectedClass == className,
                      onSelected: (_) =>
                          setState(() => _selectedClass = className),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: availableStudents.isEmpty
                ? const _RoomsEmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'Öğrenci yok',
                    message:
                        'Tüm öğrenciler yerleştirilmiş veya seçilen filtreye uyan öğrenci bulunmuyor.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    itemCount: availableStudents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = availableStudents[index];
                      return _DraggableStudentCard(
                        key: ValueKey('student_pool_${student.id}'),
                        student: student,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoomGroup {
  _RoomGroup({
    required this.key,
    required this.section,
    required this.blockName,
    required this.floorLabel,
  });

  final String key;
  final BoardingSection section;
  final String blockName;
  final String floorLabel;
  final List<BoardingRoom> rooms = [];
}

class _RoomGroupHeader extends StatelessWidget {
  const _RoomGroupHeader({required this.group});

  final _RoomGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.softPurple.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.apartment_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${group.section.label} • ${group.blockName} • ${group.floorLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.darkText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomDropCard extends StatelessWidget {
  const _RoomDropCard({
    required this.room,
    required this.students,
    required this.onEditCapacity,
    required this.onRemoveStudent,
    required this.canAccept,
    required this.onAccept,
  });

  final BoardingRoom room;
  final List<Student> students;
  final VoidCallback onEditCapacity;
  final ValueChanged<Student> onRemoveStudent;
  final bool Function(BoardingRoom room, Student student) canAccept;
  final Future<void> Function(BoardingRoom room, Student student) onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Student>(
      onWillAcceptWithDetails: (details) => canAccept(room, details.data),
      onAcceptWithDetails: (details) => onAccept(room, details.data),
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          key: ValueKey('room_${room.id}'),
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.softMagenta.withValues(alpha: 0.42)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: highlighted ? AppColors.primary : AppColors.inputBorder,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.bed_outlined,
                      color: AppColors.primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Oda ${room.roomNumber}',
                      style: const TextStyle(
                        color: AppColors.sidebar,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${students.length}/${room.capacity}',
                    style: TextStyle(
                      color: students.length >= room.capacity
                          ? AppColors.errorFeedback
                          : AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapasiteyi değiştir',
                    onPressed: onEditCapacity,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                room.blockName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (students.isEmpty)
                Text(
                  'Öğrenciyi buraya sürükleyin',
                  style: TextStyle(
                    color: AppColors.secondaryText.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                for (final student in students)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Öğrenciyi çıkar',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onRemoveStudent(student),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableStudentCard extends StatelessWidget {
  const _DraggableStudentCard({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final card = _StudentCard(student: student);
    return Draggable<Student>(
      data: student,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 300, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.softMagenta,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(student.fullName),
              style: const TextStyle(
                color: AppColors.sidebar,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    student.className ?? 'Sınıf yok',
                    student.sectionName ?? '',
                  ].where((value) => value.isNotEmpty).join(' / '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.drag_indicator, color: AppColors.secondaryText),
        ],
      ),
    );
  }
}

class _RoomsPanel extends StatelessWidget {
  const _RoomsPanel({
    required this.title,
    required this.icon,
    required this.trailing,
    required this.child,
  });

  final String title;
  final IconData icon;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.sidebar,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  trailing,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RoomsEmptyState extends StatelessWidget {
  const _RoomsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 42,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.sidebar,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return '?';
  }
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }
  return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
      .toUpperCase();
}
