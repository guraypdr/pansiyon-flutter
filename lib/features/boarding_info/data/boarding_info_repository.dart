import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

class BoardingInfoRepository {
  BoardingInfoRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<BoardingInfoDraft?> load() async {
    final database = await _appDatabase.database;
    final infoRows = await database.query(
      'boarding_school_info',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (infoRows.isEmpty) {
      return null;
    }

    final info = infoRows.first;
    final schoolInfoId = info['id'] as int;
    final blockRows = await database.query(
      'boarding_blocks',
      where: 'school_info_id = ?',
      whereArgs: [schoolInfoId],
      orderBy: 'sort_order ASC',
    );
    final blocks = <BoardingBlockDraft>[];
    for (final block in blockRows) {
      final blockId = block['id'] as int;
      final floorRows = await database.query(
        'boarding_floors',
        where: 'block_id = ?',
        whereArgs: [blockId],
        orderBy: 'sort_order ASC',
      );
      blocks.add(
        BoardingBlockDraft(
          section: boardingSectionFromValue(block['section'] as String),
          name: block['name'] as String,
          standardRoomCapacity: block['standard_room_capacity'] as int,
          studyRoomCount: block['study_room_count'] as int,
          floors: [
            for (final floor in floorRows)
              BoardingFloorDraft(
                floorNumber: floor['floor_number'] as int,
                studentRoomCount: floor['student_room_count'] as int,
              ),
          ],
        ),
      );
    }

    return BoardingInfoDraft(
      schoolName: info['school_name'] as String,
      principalName: info['principal_name'] as String,
      principalPhone: info['principal_phone'] as String,
      deputyName: info['deputy_name'] as String,
      deputyPhone: info['deputy_phone'] as String,
      boardingType: boardingTypeFromValue(info['boarding_type'] as String),
      educationLevel: educationLevelFromValue(
        info['education_level'] as String,
      ),
      blocks: blocks,
    );
  }

  Future<void> save(BoardingInfoDraft draft) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await database.transaction((transaction) async {
      await transaction.delete('boarding_school_info');
      final schoolInfoId = await transaction.insert('boarding_school_info', {
        'school_name': draft.schoolName.trim(),
        'principal_name': draft.principalName.trim(),
        'principal_phone': draft.principalPhone.trim(),
        'deputy_name': draft.deputyName.trim(),
        'deputy_phone': draft.deputyPhone.trim(),
        'boarding_type': draft.boardingType.value,
        'education_level': draft.educationLevel.value,
        'created_at': now,
        'updated_at': now,
      });

      for (var blockIndex = 0; blockIndex < draft.blocks.length; blockIndex++) {
        final block = draft.blocks[blockIndex];
        final blockId = await transaction.insert('boarding_blocks', {
          'school_info_id': schoolInfoId,
          'section': block.section.value,
          'name': block.name.trim(),
          'standard_room_capacity': block.standardRoomCapacity,
          'study_room_count': block.studyRoomCount,
          'sort_order': blockIndex,
        });

        for (
          var floorIndex = 0;
          floorIndex < block.floors.length;
          floorIndex++
        ) {
          final floor = block.floors[floorIndex];
          await transaction.insert('boarding_floors', {
            'block_id': blockId,
            'floor_number': floor.floorNumber,
            'student_room_count': floor.studentRoomCount,
            'sort_order': floorIndex,
          });
        }
      }
    });
  }
}
