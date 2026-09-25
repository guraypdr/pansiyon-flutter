import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/home/data/dashboard_repository.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('dashboard özetini gerçek kayıtlardan hesaplar', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);
    final boardingInfoRepository = SqliteBoardingInfoRepository(database);
    final studentRepository = SqliteStudentRepository(database);
    final roomRepository = SqliteRoomRepository(database);
    final dashboardRepository = RepositoryDashboardRepository(
      boardingInfoRepository: boardingInfoRepository,
      studentRepository: studentRepository,
      roomRepository: roomRepository,
    );

    await boardingInfoRepository.save(
      const BoardingInfoDraft(
        schoolName: 'Test Pansiyonu',
        principalName: 'Ayşe Yılmaz',
        principalPhone: '0312 555 10 10',
        deputyName: 'Mehmet Demir',
        deputyPhone: '0312 555 10 11',
        boardingType: BoardingType.girls,
        educationLevel: EducationLevel.middleSchool,
        blocks: [
          BoardingBlockDraft(
            section: BoardingSection.girls,
            name: 'Kız Bloğu',
            standardRoomCapacity: 2,
            floors: [
              BoardingFloorDraft(
                floorNumber: 1,
                hasStudentRooms: true,
                studentRoomCount: 2,
                roomStartNumber: 101,
                hasStudyRoom: false,
              ),
            ],
          ),
        ],
      ),
    );
    final firstStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Elif Kaya', gender: StudentGender.female),
    );
    final secondStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Zeynep Demir', gender: StudentGender.female),
    );

    await roomRepository.syncRooms(await boardingInfoRepository.load());
    final rooms = await roomRepository.getRooms();
    await roomRepository.assignStudent(
      roomId: rooms.first.id,
      studentId: firstStudentId,
    );

    final summary = await dashboardRepository.load();

    expect(summary.schoolName, 'Test Pansiyonu');
    expect(summary.studentCount, 2);
    expect(summary.roomCount, 2);
    expect(summary.blockCount, 1);
    expect(summary.totalCapacity, 4);
    expect(summary.occupiedBeds, 1);
    expect(summary.emptyBeds, 3);
    expect(summary.occupancyRate, closeTo(0.25, 0.0001));
    expect(secondStudentId, isNotNull);
  });
}
