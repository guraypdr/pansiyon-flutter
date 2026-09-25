part of 'boarding_info_page.dart';

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
      nameController: TextEditingController(text: _capitalizeWords(draft.name)),
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
