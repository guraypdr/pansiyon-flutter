import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('pansiyon bilgilerini ve katlarını yerel SQLite’a kaydeder', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = BoardingInfoRepository(database);
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
          studyRoomCount: 2,
          floors: [
            BoardingFloorDraft(floorNumber: 1, studentRoomCount: 12),
            BoardingFloorDraft(floorNumber: 2, studentRoomCount: 12),
          ],
        ),
        BoardingBlockDraft(
          section: BoardingSection.boys,
          name: 'Erkek Bloğu',
          standardRoomCapacity: 4,
          studyRoomCount: 1,
          floors: [BoardingFloorDraft(floorNumber: 1, studentRoomCount: 10)],
        ),
      ],
    );

    await repository.save(draft);
    final loaded = await repository.load();

    expect(loaded, isNotNull);
    expect(loaded!.schoolName, draft.schoolName);
    expect(loaded.boardingType, BoardingType.mixed);
    expect(loaded.blocks, hasLength(2));
    expect(loaded.blocks.first.floors, hasLength(2));
    expect(loaded.blocks.first.floors.last.studentRoomCount, 12);
  });
}
