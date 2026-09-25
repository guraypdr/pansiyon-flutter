import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'pansiyon bilgilerini ve kat alanlarını yerel SQLite’a kaydeder',
    () async {
      final database = AppDatabase(databasePath: inMemoryDatabasePath);
      final repository = SqliteBoardingInfoRepository(database);
      addTearDown(database.close);

      const draft = BoardingInfoDraft(
        schoolName: 'Atatürk Ortaokulu Pansiyonu',
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
            standardRoomCapacity: 4,
            studyRoomCount: 9,
            hasBasement: true,
            floors: [
              BoardingFloorDraft(
                floorNumber: 1,
                hasStudentRooms: true,
                studentRoomCount: 12,
                roomStartNumber: 101,
                hasStudyRoom: true,
                studyRoomCount: 2,
              ),
              BoardingFloorDraft(
                floorNumber: 2,
                hasStudentRooms: false,
                hasStudyRoom: false,
              ),
            ],
          ),
          BoardingBlockDraft(
            section: BoardingSection.boys,
            name: 'Erkek Bloğu',
            standardRoomCapacity: 4,
            floors: [
              BoardingFloorDraft(
                floorNumber: 1,
                hasStudentRooms: true,
                studentRoomCount: 10,
                roomStartNumber: 301,
                hasStudyRoom: true,
                studyRoomCount: 1,
              ),
            ],
          ),
        ],
      );

      await repository.save(draft);
      final loaded = await repository.load();

      expect(loaded, isNotNull);
      expect(loaded!.schoolName, draft.schoolName);
      expect(loaded.boardingType, BoardingType.mixed);
      expect(loaded.blocks, hasLength(2));
      expect(loaded.blocks.first.hasBasement, isTrue);
      expect(loaded.blocks.first.floors, hasLength(2));
      expect(loaded.blocks.first.floors.first.hasStudentRooms, isTrue);
      expect(loaded.blocks.first.floors.first.roomStartNumber, 101);
      expect(loaded.blocks.first.floors.first.studyRoomCount, 2);
      expect(loaded.blocks.first.floors.last.hasStudentRooms, isFalse);
      expect(loaded.blocks.first.floors.last.studentRoomCount, isNull);
      expect(loaded.blocks.first.floors.last.roomStartNumber, isNull);
      expect(loaded.blocks.first.floors.last.hasStudyRoom, isFalse);
      expect(loaded.blocks.first.floors.last.studyRoomCount, isNull);
      expect(loaded.blocks.last.floors.single.roomStartNumber, 301);
      expect(loaded.blocks.last.floors.single.studyRoomCount, 1);
    },
  );
}
