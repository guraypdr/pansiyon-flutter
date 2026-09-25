import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

class BoardingRoom {
  const BoardingRoom({
    required this.id,
    required this.sourceKey,
    required this.blockName,
    required this.section,
    required this.floorLabel,
    required this.floorNumber,
    required this.roomNumber,
    required this.capacity,
    required this.occupantCount,
  });

  final int id;
  final String sourceKey;
  final String blockName;
  final BoardingSection section;
  final String floorLabel;
  final int floorNumber;
  final int roomNumber;
  final int capacity;
  final int occupantCount;

  int get availableCapacity {
    final remaining = capacity - occupantCount;
    return remaining > 0 ? remaining : 0;
  }

  String get sectionLabel => section.label;
}

class RoomAssignment {
  const RoomAssignment({
    required this.roomId,
    required this.studentId,
    this.assignedAt,
  });

  final int roomId;
  final int studentId;
  final DateTime? assignedAt;
}
