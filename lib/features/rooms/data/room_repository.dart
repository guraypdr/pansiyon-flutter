import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/domain/room_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

abstract interface class RoomRepository {
  Future<void> syncRooms(BoardingInfoDraft? boardingInfo);

  Future<List<BoardingRoom>> getRooms();

  Future<List<RoomAssignment>> getAssignments();

  Future<void> updateRoomCapacity({required int roomId, required int capacity});

  Future<void> assignStudent({required int roomId, required int studentId});

  Future<void> unassignStudent(int studentId);
}

class SqliteRoomRepository implements RoomRepository {
  SqliteRoomRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> syncRooms(BoardingInfoDraft? boardingInfo) async {
    final database = await _appDatabase.database;
    final seeds = boardingInfo == null
        ? const <_RoomSeed>[]
        : _buildRoomSeeds(boardingInfo);
    final now = DateTime.now().toUtc().toIso8601String();

    await database.transaction((transaction) async {
      final existingRows = await transaction.query(
        'boarding_rooms',
        columns: ['id', 'source_key'],
      );
      final existingByKey = {
        for (final row in existingRows) row['source_key'] as String: row,
      };
      final desiredKeys = <String>{};

      for (final seed in seeds) {
        desiredKeys.add(seed.sourceKey);
        final existing = existingByKey[seed.sourceKey];
        if (existing == null) {
          await transaction.insert('boarding_rooms', {
            'source_key': seed.sourceKey,
            'block_name': seed.blockName,
            'section': seed.section.value,
            'floor_label': seed.floorLabel,
            'floor_number': seed.floorNumber,
            'room_number': seed.roomNumber,
            'capacity': seed.capacity,
            'sort_order': seed.sortOrder,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          // Kapasite kullanıcı tarafından değiştirilebildiği için mevcut
          // odada korunur; yalnızca kaynak bilgiler güncellenir.
          await transaction.update(
            'boarding_rooms',
            {
              'block_name': seed.blockName,
              'section': seed.section.value,
              'floor_label': seed.floorLabel,
              'floor_number': seed.floorNumber,
              'room_number': seed.roomNumber,
              'sort_order': seed.sortOrder,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
        }
      }

      final staleKeys = existingByKey.keys
          .where((key) => !desiredKeys.contains(key))
          .toList(growable: false);
      for (final sourceKey in staleKeys) {
        await transaction.delete(
          'boarding_rooms',
          where: 'source_key = ?',
          whereArgs: [sourceKey],
        );
      }
    });
  }

  @override
  Future<List<BoardingRoom>> getRooms() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery('''
      SELECT
        r.*,
        COUNT(a.id) AS occupant_count
      FROM boarding_rooms r
      LEFT JOIN room_assignments a ON a.room_id = r.id
      GROUP BY r.id
      ORDER BY r.sort_order ASC, r.room_number ASC
    ''');
    return rows.map(_roomFromRow).toList(growable: false);
  }

  @override
  Future<List<RoomAssignment>> getAssignments() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'room_assignments',
      orderBy: 'assigned_at ASC, id ASC',
    );
    return rows
        .map(
          (row) => RoomAssignment(
            roomId: row['room_id'] as int,
            studentId: row['student_id'] as int,
            assignedAt: _parseDateTime(row['assigned_at']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> updateRoomCapacity({
    required int roomId,
    required int capacity,
  }) async {
    if (capacity <= 0) {
      throw ArgumentError.value(
        capacity,
        'capacity',
        'Kapasite sıfırdan büyük olmalıdır.',
      );
    }
    final database = await _appDatabase.database;
    final roomRows = await database.query(
      'boarding_rooms',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    if (roomRows.isEmpty) {
      throw StateError('Oda bulunamadı.');
    }
    final occupantRows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM room_assignments WHERE room_id = ?',
      [roomId],
    );
    final occupantCount = _asInt(occupantRows.first['count']) ?? 0;
    if (occupantCount > capacity) {
      throw StateError(
        'Oda kapasitesi mevcut öğrenci sayısından küçük olamaz.',
      );
    }
    await database.update(
      'boarding_rooms',
      {
        'capacity': capacity,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  @override
  Future<void> assignStudent({
    required int roomId,
    required int studentId,
  }) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final roomRows = await transaction.query(
        'boarding_rooms',
        columns: ['id', 'capacity', 'section'],
        where: 'id = ?',
        whereArgs: [roomId],
        limit: 1,
      );
      if (roomRows.isEmpty) {
        throw StateError('Oda bulunamadı.');
      }
      final studentRows = await transaction.query(
        'students',
        columns: ['id', 'gender'],
        where: 'id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      if (studentRows.isEmpty) {
        throw StateError('Öğrenci bulunamadı.');
      }
      final studentGender = studentGenderFromValue(
        studentRows.first['gender'] as String?,
      );
      if (studentGender == null) {
        throw StateError(
          'Cinsiyet bilgisi olmayan öğrenci odaya yerleştirilemez.',
        );
      }
      final roomSection = roomRows.first['section'] as String;
      if (roomSection == BoardingSection.girls.value &&
          studentGender != StudentGender.female) {
        throw StateError('Bu odaya yalnızca kız öğrenci yerleştirilebilir.');
      }
      if (roomSection == BoardingSection.boys.value &&
          studentGender != StudentGender.male) {
        throw StateError('Bu odaya yalnızca erkek öğrenci yerleştirilebilir.');
      }

      final existingRows = await transaction.query(
        'room_assignments',
        columns: ['id', 'room_id'],
        where: 'student_id = ?',
        whereArgs: [studentId],
        limit: 1,
      );
      if (existingRows.isNotEmpty && existingRows.first['room_id'] == roomId) {
        return;
      }

      final occupantRows = await transaction.rawQuery(
        '''
          SELECT COUNT(*) AS count
          FROM room_assignments
          WHERE room_id = ? AND student_id != ?
        ''',
        [roomId, studentId],
      );
      final occupantCount = _asInt(occupantRows.first['count']) ?? 0;
      final capacity = roomRows.first['capacity'] as int;
      if (occupantCount >= capacity) {
        throw StateError('Oda kapasitesi dolu.');
      }

      if (existingRows.isEmpty) {
        await transaction.insert('room_assignments', {
          'room_id': roomId,
          'student_id': studentId,
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await transaction.update(
          'room_assignments',
          {
            'room_id': roomId,
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existingRows.first['id']],
        );
      }
    });
  }

  @override
  Future<void> unassignStudent(int studentId) async {
    final database = await _appDatabase.database;
    await database.delete(
      'room_assignments',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  List<_RoomSeed> _buildRoomSeeds(BoardingInfoDraft boardingInfo) {
    final seeds = <_RoomSeed>[];
    for (
      var blockIndex = 0;
      blockIndex < boardingInfo.blocks.length;
      blockIndex++
    ) {
      final block = boardingInfo.blocks[blockIndex];
      for (var floorIndex = 0; floorIndex < block.floors.length; floorIndex++) {
        final floor = block.floors[floorIndex];
        final roomCount = floor.studentRoomCount;
        final roomStart = floor.roomStartNumber;
        if (!floor.hasStudentRooms ||
            roomCount == null ||
            roomCount <= 0 ||
            roomStart == null ||
            roomStart <= 0) {
          continue;
        }
        final floorLabel = _floorLabel(
          hasBasement: block.hasBasement,
          index: floorIndex,
        );
        for (var offset = 0; offset < roomCount; offset++) {
          final roomNumber = roomStart + offset;
          final sourceKey = [
            block.section.value,
            blockIndex,
            block.name.trim(),
            floorIndex,
            roomNumber,
          ].join('|');
          seeds.add(
            _RoomSeed(
              sourceKey: sourceKey,
              blockName: block.name.trim(),
              section: block.section,
              floorLabel: floorLabel,
              floorNumber: floorIndex + 1,
              roomNumber: roomNumber,
              capacity: block.standardRoomCapacity,
              sortOrder: blockIndex * 100000 + floorIndex * 1000 + offset,
            ),
          );
        }
      }
    }
    return seeds;
  }
}

class _RoomSeed {
  const _RoomSeed({
    required this.sourceKey,
    required this.blockName,
    required this.section,
    required this.floorLabel,
    required this.floorNumber,
    required this.roomNumber,
    required this.capacity,
    required this.sortOrder,
  });

  final String sourceKey;
  final String blockName;
  final BoardingSection section;
  final String floorLabel;
  final int floorNumber;
  final int roomNumber;
  final int capacity;
  final int sortOrder;
}

BoardingRoom _roomFromRow(Map<String, Object?> row) {
  return BoardingRoom(
    id: row['id'] as int,
    sourceKey: row['source_key'] as String,
    blockName: row['block_name'] as String,
    section: boardingSectionFromValue(row['section'] as String),
    floorLabel: row['floor_label'] as String,
    floorNumber: row['floor_number'] as int,
    roomNumber: row['room_number'] as int,
    capacity: row['capacity'] as int,
    occupantCount: _asInt(row['occupant_count']) ?? 0,
  );
}

String _floorLabel({required bool hasBasement, required int index}) {
  if (hasBasement && index == 0) {
    return 'Bodrum Kat';
  }
  final upperFloorNumber = index - (hasBasement ? 1 : 0);
  if (upperFloorNumber == 0) {
    return 'Zemin Kat';
  }
  return '$upperFloorNumber. Kat';
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

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
