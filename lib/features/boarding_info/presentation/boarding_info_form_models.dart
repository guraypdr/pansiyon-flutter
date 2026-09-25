part of 'boarding_info_page.dart';

class _BlockForm {
  _BlockForm({
    required this.id,
    required this.section,
    required this.nameController,
    required this.capacityController,
    required this.studyController,
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
      studyController: TextEditingController(),
      hasBasement: false,
      floors: [
        _FloorForm(floorNumber: 1, studentRoomCount: '', roomStartNumber: '1'),
      ],
    );
  }

  factory _BlockForm.fromDraft(BoardingBlockDraft draft, int index) {
    return _BlockForm(
      id: '${draft.section.value}_${DateTime.now().microsecondsSinceEpoch}_$index',
      section: draft.section,
      nameController: TextEditingController(text: _capitalizeWords(draft.name)),
      capacityController: TextEditingController(
        text: '${draft.standardRoomCapacity}',
      ),
      studyController: TextEditingController(text: '${draft.studyRoomCount}'),
      hasBasement: draft.hasBasement,
      floors: [
        for (final floor in draft.floors)
          _FloorForm(
            floorNumber: floor.floorNumber,
            studentRoomCount: '${floor.studentRoomCount}',
            roomStartNumber: '${floor.roomStartNumber}',
          ),
      ],
    );
  }

  final String id;
  final BoardingSection section;
  final TextEditingController nameController;
  final TextEditingController capacityController;
  final TextEditingController studyController;
  bool hasBasement;
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
  _FloorForm({
    required this.floorNumber,
    required String studentRoomCount,
    required String roomStartNumber,
  }) : roomCountController = TextEditingController(text: studentRoomCount),
       roomStartNumberController = TextEditingController(text: roomStartNumber);

  int floorNumber;
  final TextEditingController roomCountController;
  final TextEditingController roomStartNumberController;

  void dispose() {
    roomCountController.dispose();
    roomStartNumberController.dispose();
  }
}
