import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('pansiyon katlarından oda üretir ve yerleştirmeleri saklar', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final roomRepository = SqliteRoomRepository(database);
    final studentRepository = SqliteStudentRepository(database);
    addTearDown(database.close);

    const boardingInfo = BoardingInfoDraft(
      schoolName: 'Test Pansiyonu',
      principalName: 'Ayşe Yılmaz',
      principalPhone: '0312 555 10 10',
      deputyName: 'Mehmet Demir',
      deputyPhone: '0312 555 10 11',
      boardingType: BoardingType.mixed,
      educationLevel: EducationLevel.middleSchool,
      blocks: [
        BoardingBlockDraft(
          section: BoardingSection.girls,
          name: 'Kız Bloğu',
          standardRoomCapacity: 2,
          hasBasement: true,
          floors: [
            BoardingFloorDraft(
              floorNumber: 1,
              hasStudentRooms: true,
              studentRoomCount: 2,
              roomStartNumber: 101,
            ),
            BoardingFloorDraft(floorNumber: 2, hasStudentRooms: false),
          ],
        ),
        BoardingBlockDraft(
          section: BoardingSection.boys,
          name: 'Erkek Bloğu',
          standardRoomCapacity: 3,
          floors: [
            BoardingFloorDraft(
              floorNumber: 1,
              hasStudentRooms: true,
              studentRoomCount: 1,
              roomStartNumber: 101,
            ),
          ],
        ),
      ],
    );

    await roomRepository.syncRooms(boardingInfo);
    await roomRepository.syncRooms(boardingInfo);
    final rooms = await roomRepository.getRooms();

    expect(rooms, hasLength(3));
    expect(rooms[0].floorLabel, 'Bodrum Kat');
    expect(rooms[0].roomNumber, 101);
    expect(rooms[1].roomNumber, 102);
    expect(rooms[2].section, BoardingSection.boys);
    expect(rooms[2].roomNumber, 101);
    expect(rooms.every((room) => room.occupantCount == 0), isTrue);

    final firstStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Ali Yılmaz'),
    );
    final secondStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Ayşe Kaya'),
    );
    final thirdStudentId = await studentRepository.saveStudent(
      const Student(fullName: 'Mehmet Demir'),
    );

    await roomRepository.assignStudent(
      roomId: rooms[0].id,
      studentId: firstStudentId,
    );
    await roomRepository.assignStudent(
      roomId: rooms[0].id,
      studentId: secondStudentId,
    );
    await expectLater(
      roomRepository.assignStudent(
        roomId: rooms[0].id,
        studentId: thirdStudentId,
      ),
      throwsA(isA<StateError>()),
    );

    final assignedRooms = await roomRepository.getRooms();
    expect(assignedRooms[0].occupantCount, 2);
    expect(await roomRepository.getAssignments(), hasLength(2));
    await roomRepository.updateRoomCapacity(roomId: rooms[0].id, capacity: 3);
    expect((await roomRepository.getRooms())[0].capacity, 3);
    await expectLater(
      roomRepository.updateRoomCapacity(roomId: rooms[0].id, capacity: 1),
      throwsA(isA<StateError>()),
    );

    await roomRepository.unassignStudent(firstStudentId);
    expect(await roomRepository.getAssignments(), hasLength(1));
    expect((await roomRepository.getRooms())[0].occupantCount, 1);
  });

  test('pansiyon bilgisi olmayınca odaları temizler', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final roomRepository = SqliteRoomRepository(database);
    addTearDown(database.close);

    const boardingInfo = BoardingInfoDraft(
      schoolName: 'Test',
      principalName: 'Test',
      principalPhone: '0312 555 10 10',
      deputyName: 'Test',
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
              studentRoomCount: 1,
              roomStartNumber: 1,
            ),
          ],
        ),
      ],
    );

    await roomRepository.syncRooms(boardingInfo);
    expect(await roomRepository.getRooms(), hasLength(1));
    await roomRepository.syncRooms(null);
    expect(await roomRepository.getRooms(), isEmpty);
  });
}
