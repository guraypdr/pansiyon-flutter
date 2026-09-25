import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';

class DashboardSummary {
  const DashboardSummary({
    this.schoolName,
    this.boardingType,
    this.educationLevel,
    required this.studentCount,
    required this.roomCount,
    required this.blockCount,
    required this.totalCapacity,
    required this.occupiedBeds,
    required this.emptyBeds,
    required this.occupancyRate,
  });

  final String? schoolName;
  final BoardingType? boardingType;
  final EducationLevel? educationLevel;
  final int studentCount;
  final int roomCount;
  final int blockCount;
  final int totalCapacity;
  final int occupiedBeds;
  final int emptyBeds;
  final double occupancyRate;

  bool get hasBoardingInfo => schoolName != null;
}

abstract interface class DashboardRepository {
  Future<DashboardSummary> load();
}

class RepositoryDashboardRepository implements DashboardRepository {
  RepositoryDashboardRepository({
    required BoardingInfoRepository boardingInfoRepository,
    required StudentRepository studentRepository,
    required RoomRepository roomRepository,
  }) : _boardingInfoRepository = boardingInfoRepository,
       _studentRepository = studentRepository,
       _roomRepository = roomRepository;

  final BoardingInfoRepository _boardingInfoRepository;
  final StudentRepository _studentRepository;
  final RoomRepository _roomRepository;

  @override
  Future<DashboardSummary> load() async {
    final boardingInfo = await _boardingInfoRepository.load();
    await _roomRepository.syncRooms(boardingInfo);
    final students = await _studentRepository.getStudents();
    final rooms = await _roomRepository.getRooms();

    var totalCapacity = 0;
    var occupiedBeds = 0;
    for (final room in rooms) {
      totalCapacity += room.capacity;
      occupiedBeds += room.occupantCount;
    }
    final emptyBeds = (totalCapacity - occupiedBeds)
        .clamp(0, totalCapacity)
        .toInt();
    final occupancyRate = totalCapacity == 0
        ? 0.0
        : occupiedBeds / totalCapacity;

    return DashboardSummary(
      schoolName: boardingInfo?.schoolName,
      boardingType: boardingInfo?.boardingType,
      educationLevel: boardingInfo?.educationLevel,
      studentCount: students.length,
      roomCount: rooms.length,
      blockCount: boardingInfo?.blocks.length ?? 0,
      totalCapacity: totalCapacity,
      occupiedBeds: occupiedBeds,
      emptyBeds: emptyBeds,
      occupancyRate: occupancyRate,
    );
  }
}
