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
      nameController: TextEditingController(
        text: '${section.label} Bloğu ${index + 1}',
      ),
      capacityController: TextEditingController(),
      hasBasement: false,
      floors: [
        _FloorForm(
          floorNumber: 1,
          hasStudentRooms: false,
          studentRoomCount: '',
          roomStartNumber: '',
          hasStudyRoom: false,
          studyRoomCount: '',
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
            hasStudyRoom: floor.hasStudyRoom,
            studyRoomCount: floor.studyRoomCount?.toString() ?? '',
          ),
      ],
    );
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
    required this.hasStudyRoom,
    required String studentRoomCount,
    required String roomStartNumber,
    required String studyRoomCount,
  }) : roomCountController = TextEditingController(text: studentRoomCount),
       roomStartNumberController = TextEditingController(text: roomStartNumber),
       studyRoomCountController = TextEditingController(text: studyRoomCount);

  int floorNumber;
  bool hasStudentRooms;
  bool hasStudyRoom;
  final TextEditingController roomCountController;
  final TextEditingController roomStartNumberController;
  final TextEditingController studyRoomCountController;

  void dispose() {
    roomCountController.dispose();
    roomStartNumberController.dispose();
    studyRoomCountController.dispose();
  }
}
