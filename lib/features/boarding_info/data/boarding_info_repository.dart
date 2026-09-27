import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

abstract interface class BoardingInfoRepository {
  Future<BoardingInfoDraft?> load();

  Future<void> save(BoardingInfoDraft draft);

  /// Lise kademesinde hazırlık sınıfının kullanılıp kullanılmayacağını
  /// tek başına günceller; blok ve kat kayıtlarına dokunmaz.
  Future<void> setPreparationGradeEnabled(bool enabled);
}

class SqliteBoardingInfoRepository implements BoardingInfoRepository {
  SqliteBoardingInfoRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
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
          hasBasement: _asBool(block['has_basement']),
          floors: [for (final floor in floorRows) _floorFromRow(floor)],
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
      hasPreparationGrade: _asBool(
        info['has_preparation_grade'],
        fallback: true,
      ),
    );
  }

  @override
  Future<void> setPreparationGradeEnabled(bool enabled) async {
    final database = await _appDatabase.database;
    await database.update('boarding_school_info', {
      'has_preparation_grade': enabled ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  BoardingFloorDraft _floorFromRow(Map<String, Object?> row) {
    final storedStudentRoomCount = _asInt(row['student_room_count']);
    final hasStudentRooms = _asBool(
      row['has_student_rooms'],
      fallback: (storedStudentRoomCount ?? 0) > 0,
    );
    final storedRoomStartNumber = _asInt(row['room_start_number']);

    return BoardingFloorDraft(
      floorNumber: row['floor_number'] as int,
      hasStudentRooms: hasStudentRooms,
      studentRoomCount: hasStudentRooms ? (storedStudentRoomCount ?? 0) : null,
      roomStartNumber: hasStudentRooms ? (storedRoomStartNumber ?? 1) : null,
    );
  }

  @override
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
        'has_preparation_grade': draft.hasPreparationGrade ? 1 : 0,
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
          // Eski şema sütunu artık kullanılmaz; sütun NOT NULL olduğu için
          // sıfır yazılır.
          'study_room_count': 0,
          'has_basement': block.hasBasement ? 1 : 0,
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
            'has_student_rooms': floor.hasStudentRooms ? 1 : 0,
            'student_room_count': floor.studentRoomCount ?? 0,
            'room_start_number': floor.roomStartNumber ?? 0,
            'has_study_room': 0,
            'study_room_count': 0,
            'sort_order': floorIndex,
          });
        }
      }
    });
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return fallback;
}
