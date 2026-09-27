part of 'pansiyon_ayarlari_page.dart';

class _BlockForm {
  _BlockForm({
    required this.id,
    required this.section,
    required this.nameController,
    required this.capacityController,
    required this.floors,
    required this.hasBasement,
  });

  factory _BlockForm.newBlock(BoardingSection section, int index) {
    return _BlockForm(
      id: '${section.value}_${DateTime.now().microsecondsSinceEpoch}_$index',
      section: section,
      nameController: TextEditingController(text: _defaultBlockName(index)),
      capacityController: TextEditingController(),
      hasBasement: false,
      floors: [
        _FloorForm(
          floorNumber: 1,
          hasStudentRooms: false,
          studentRoomCount: '',
          roomStartNumber: '',
        ),
      ],
    );
  }

  factory _BlockForm.fromDraft(BoardingBlockDraft draft, int index) {
    return _BlockForm(
      id: '${draft.section.value}_${DateTime.now().microsecondsSinceEpoch}_$index',
      section: draft.section,
      nameController: TextEditingController(text: capitalizeWords(draft.name)),
      capacityController: TextEditingController(
        text: '${draft.standardRoomCapacity}',
      ),
      hasBasement: draft.hasBasement,
      floors: [
        for (final floor in draft.floors)
          _FloorForm(
            floorNumber: floor.floorNumber,
            hasStudentRooms: floor.hasStudentRooms,
            studentRoomCount: floor.studentRoomCount?.toString() ?? '',
            roomStartNumber: floor.roomStartNumber?.toString() ?? '',
          ),
      ],
    );
  }

  /// Varsayılan blok adı: A Blok, B Blok, C Blok ...
  static String _defaultBlockName(int index) {
    final letter = String.fromCharCode('A'.codeUnitAt(0) + index);
    return '$letter Blok';
  }

  final String id;
  final BoardingSection section;
  final TextEditingController nameController;
  final TextEditingController capacityController;
  bool hasBasement;
  final List<_FloorForm> floors;

  void dispose() {
    nameController.dispose();
    capacityController.dispose();
    for (final floor in floors) {
      floor.dispose();
    }
  }
}

class _FloorForm {
  _FloorForm({
    required this.floorNumber,
    required this.hasStudentRooms,
    required String studentRoomCount,
    required String roomStartNumber,
  }) : roomCountController = TextEditingController(text: studentRoomCount),
       roomStartNumberController = TextEditingController(text: roomStartNumber);

  int floorNumber;
  bool hasStudentRooms;
  final TextEditingController roomCountController;
  final TextEditingController roomStartNumberController;

  void dispose() {
    roomCountController.dispose();
    roomStartNumberController.dispose();
  }
}
