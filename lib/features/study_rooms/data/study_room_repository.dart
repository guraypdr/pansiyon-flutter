import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/domain/study_room_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Etüt salonlarının okunması, düzenlenmesi ve öğrenci yerleştirilmesi.
abstract interface class StudyRoomRepository {
  Future<List<StudyRoom>> getStudyRooms();

  Future<List<StudyRoomAssignment>> getAssignments();

  /// Salonun ait olabileceği bölüm / blok / kat seçenekleri.
  Future<List<StudyRoomFloorOption>> getFloorOptions();

  Future<int> createStudyRoom({
    required String name,
    required BoardingSection section,
    required String blockName,
    required String floorLabel,
    required int floorNumber,
    required StudyRoomSeating seating,
    StudyRoomLayout? layout,
    int? tableSize,
    bool tablesHaveStudents = false,
  });

  Future<void> updateStudyRoom({
    required int id,
    required String name,
    required StudyRoomSeating seating,
    StudyRoomLayout? layout,
    int? tableSize,
    bool tablesHaveStudents = false,
  });

  /// Düzenin büyüme veya küçülme miktarı (artı ve eksi butonlarından gelir).
  ///
  /// Değerler negatif olursa ilgili alan küçültülür; her alan en az 1'de
  /// kalır. Kapasite otomatik yeniden hesaplanır, 300 sınırını aşarsa işlem
  /// yapılmaz ve hata fırlatılır.
  Future<StudyRoom> growLayout({
    required int studyRoomId,
    int columns = 0,
    int rows = 0,
    int uLeftSeats = 0,
    int uRightSeats = 0,
    int uBaseSeats = 0,
    int tableColumns = 0,
    int tableRows = 0,
  });

  Future<void> deleteStudyRoom(int id);

  /// Salonun öğrencilerini kattaki havuzdan yeniden dağıtır.
  ///
  /// Dönen değer yerleştirilen öğrenci sayısıdır.
  Future<int> autoPlaceStudents(int studyRoomId);

  /// Kat havuzları: her kat için salona yerleştirilmemiş öğrenciler.
  Future<List<StudyRoomFloorPool>> getFloorPools();

  /// Havuzdaki tek bir öğrenciyi belirtilen salona yerleştirir.
  Future<void> placeStudent({required int studyRoomId, required int studentId});

  /// Öğrenciyi salondan çıkarıp havuza geri alır.
  Future<void> releaseStudent(int studentId);
}

class SqliteStudyRoomRepository implements StudyRoomRepository {
  SqliteStudyRoomRepository(
    this._appDatabase, {
    BoardingInfoRepository? boardingInfoRepository,
  }) : _boardingInfoRepository = boardingInfoRepository;

  final AppDatabase _appDatabase;
  final BoardingInfoRepository? _boardingInfoRepository;

  /// Etüt salonu kapasitesi üst sınırı.
  static const maxCapacity = 300;

  @override
  Future<List<StudyRoom>> getStudyRooms() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery('''
      SELECT
        s.*,
        COUNT(a.id) AS occupant_count
      FROM boarding_study_rooms s
      LEFT JOIN study_room_assignments a ON a.study_room_id = s.id
      GROUP BY s.id
      ORDER BY s.sort_order ASC, s.floor_number ASC, s.id ASC
    ''');
    final currentFloors = await _currentFloors(database);
    return rows
        .map((row) => _roomFromRow(row, currentFloors: currentFloors))
        .toList(growable: false);
  }

  /// Güncel oda kayıtlarından bölüm ve kat numarasına karşılık gelen blok adı
  /// ile kat etiketi. Salon kaydı eski blok adını taşısa bile eşleşme güncel
  /// veriye göre yapılır.
  Future<Map<String, _CurrentFloor>> _currentFloors(Database database) async {
    final rows = await database.rawQuery('''
      SELECT section, block_name, floor_label, floor_number
      FROM boarding_rooms
      GROUP BY section, block_name, floor_label, floor_number
    ''');
    return {
      for (final row in rows)
        '${row['section']}|${row['floor_number']}': _CurrentFloor(
          blockName: row['block_name'] as String,
          floorLabel: row['floor_label'] as String,
        ),
    };
  }

  StudyRoom _roomFromRow(
    Map<String, Object?> row, {
    Map<String, _CurrentFloor> currentFloors = const {},
  }) {
    final seating = studyRoomSeatingFromValue(row['seating'] as String);
    final tableSize = row['table_size'] as int?;
    final tablesHaveStudents = (row['tables_have_students'] as int? ?? 0) != 0;
    final layout = _layoutFromRow(row, seating);
    final section = boardingSectionFromValue(row['section'] as String);
    final floorNumber = row['floor_number'] as int;
    final current = currentFloors['${section.value}|$floorNumber'];
    return StudyRoom(
      id: row['id'] as int,
      name: row['name'] as String,
      section: section,
      // Blok adı ve kat etiketi güncel pansiyon bilgisinden gelir.
      blockName: current?.blockName ?? row['block_name'] as String,
      floorLabel: current?.floorLabel ?? row['floor_label'] as String,
      floorNumber: floorNumber,
      capacity: row['capacity'] as int,
      seating: seating,
      layout: layout,
      tableSize: tableSize,
      tablesHaveStudents: tablesHaveStudents,
      occupantCount: row['occupant_count'] as int? ?? 0,
    );
  }

  /// Satırdaki sayaçları okur; sıfır değerler düzen varsayılanına döner.
  StudyRoomLayout _layoutFromRow(
    Map<String, Object?> row,
    StudyRoomSeating seating,
  ) {
    final defaults = StudyRoomLayout.defaultsFor(seating);
    int read(String column, int fallback) {
      final value = row[column] as int?;
      return value == null || value <= 0 ? fallback : value;
    }

    return StudyRoomLayout(
      columns: read('seat_columns', defaults.columns),
      rows: read('seat_rows', defaults.rows),
      uLeftSeats: read('u_left_seats', defaults.uLeftSeats),
      uRightSeats: read('u_right_seats', defaults.uRightSeats),
      uBaseSeats: read('u_base_seats', defaults.uBaseSeats),
      tableColumns: read('table_columns', defaults.tableColumns),
      tableRows: read('table_rows', defaults.tableRows),
    );
  }

  @override
  Future<List<StudyRoomAssignment>> getAssignments() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'study_room_assignments',
      orderBy: 'assigned_at ASC, id ASC',
    );
    return rows
        .map(
          (row) => StudyRoomAssignment(
            studyRoomId: row['study_room_id'] as int,
            studentId: row['student_id'] as int,
            assignedAt: DateTime.tryParse(row['assigned_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<StudyRoomFloorOption>> getFloorOptions() async {
    final boardingInfo = await _boardingInfoRepository?.load();
    if (boardingInfo == null) {
      return const [];
    }
    final options = <StudyRoomFloorOption>[];
    for (final block in boardingInfo.blocks) {
      for (var index = 0; index < block.floors.length; index++) {
        options.add(
          StudyRoomFloorOption(
            section: block.section,
            blockName: block.name.trim(),
            floorLabel: _floorLabel(
              hasBasement: block.hasBasement,
              index: index,
            ),
            floorNumber: index + 1,
          ),
        );
      }
    }
    return options;
  }

  @override
  @override
  Future<int> createStudyRoom({
    required String name,
    required BoardingSection section,
    required String blockName,
    required String floorLabel,
    required int floorNumber,
    required StudyRoomSeating seating,
    StudyRoomLayout? layout,
    int? tableSize,
    bool tablesHaveStudents = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Etüt salonu adı boş olamaz.');
    }
    final trimmedBlock = blockName.trim();
    if (trimmedBlock.isEmpty) {
      throw ArgumentError.value(blockName, 'blockName', 'Blok boş olamaz.');
    }
    final trimmedFloor = floorLabel.trim();
    if (trimmedFloor.isEmpty) {
      throw ArgumentError.value(
        floorLabel,
        'floorLabel',
        'Kat bilgisi boş olamaz.',
      );
    }
    final effectiveLayout = layout ?? StudyRoomLayout.defaultsFor(seating);
    if (seating.asksTableSize && (tableSize == null || tableSize <= 0)) {
      throw ArgumentError.value(
        tableSize,
        'tableSize',
        'Masa kaç kişilik girilmelidir.',
      );
    }
    final capacity = effectiveLayout.capacityOf(
      seating,
      tableSize: tableSize ?? 4,
      tableHeads: tablesHaveStudents,
    );
    _validateCapacity(capacity);

    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return database.transaction((transaction) async {
      final existing = await transaction.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS max_order '
        'FROM boarding_study_rooms',
      );
      final nextOrder = ((existing.first['max_order'] as int?) ?? -1) + 1;
      return transaction.insert('boarding_study_rooms', {
        'name': trimmedName,
        'section': section.value,
        'block_name': trimmedBlock,
        'floor_label': trimmedFloor,
        'floor_number': floorNumber,
        'capacity': capacity,
        'seating': seating.value,
        'table_size': seating.asksTableSize ? tableSize : null,
        'tables_have_students': tablesHaveStudents ? 1 : 0,
        ..._layoutValues(effectiveLayout),
        'sort_order': nextOrder,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  @override
  Future<void> updateStudyRoom({
    required int id,
    required String name,
    required StudyRoomSeating seating,
    StudyRoomLayout? layout,
    int? tableSize,
    bool tablesHaveStudents = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Etüt salonu adı boş olamaz.');
    }
    if (seating.asksTableSize && (tableSize == null || tableSize <= 0)) {
      throw ArgumentError.value(
        tableSize,
        'tableSize',
        'Masa kaç kişilik girilmelidir.',
      );
    }
    final existingLayout = await _layoutOf(id);
    final effectiveLayout = layout ?? existingLayout.layout;
    final capacity = effectiveLayout.capacityOf(
      seating,
      tableSize: tableSize ?? 4,
      tableHeads: tablesHaveStudents,
    );
    _validateCapacity(capacity);

    final occupantCount = await _occupantCount(id);
    if (capacity < occupantCount) {
      throw StateError(
        'Etüt salonu kapasitesi, içerideki $occupantCount öğrenci nedeniyle '
        '$capacity olamaz.',
      );
    }
    final database = await _appDatabase.database;
    final updated = await database.update(
      'boarding_study_rooms',
      {
        'name': trimmedName,
        'capacity': capacity,
        'seating': seating.value,
        'table_size': seating.asksTableSize ? tableSize : null,
        'tables_have_students': tablesHaveStudents ? 1 : 0,
        ..._layoutValues(effectiveLayout),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      throw StateError('Etüt salonu bulunamadı.');
    }
  }

  @override
  Future<StudyRoom> growLayout({
    required int studyRoomId,
    int columns = 0,
    int rows = 0,
    int uLeftSeats = 0,
    int uRightSeats = 0,
    int uBaseSeats = 0,
    int tableColumns = 0,
    int tableRows = 0,
  }) async {
    final room = await _layoutOf(studyRoomId);
    final current = room.layout;
    int grow(int value, int delta) => (value + delta).clamp(1, 999);
    final next = current.copyWith(
      columns: grow(current.columns, columns),
      rows: grow(current.rows, rows),
      uLeftSeats: grow(current.uLeftSeats, uLeftSeats),
      uRightSeats: grow(current.uRightSeats, uRightSeats),
      uBaseSeats: grow(current.uBaseSeats, uBaseSeats),
      tableColumns: grow(current.tableColumns, tableColumns),
      tableRows: grow(current.tableRows, tableRows),
    );
    final capacity = next.capacityOf(
      room.seating,
      tableSize: room.tableSize ?? 4,
      tableHeads: room.tablesHaveStudents,
    );
    _validateCapacity(capacity);
    final occupantCount = await _occupantCount(studyRoomId);
    if (capacity < occupantCount) {
      throw StateError(
        'Etüt salonu kapasitesi, içerideki $occupantCount öğrenci nedeniyle '
        '$capacity olamaz.',
      );
    }
    final database = await _appDatabase.database;
    await database.update(
      'boarding_study_rooms',
      {
        'capacity': capacity,
        ..._layoutValues(next),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [studyRoomId],
    );
    return room.copyWithLayout(layout: next, capacity: capacity);
  }

  Map<String, Object?> _layoutValues(StudyRoomLayout layout) {
    return {
      'seat_columns': layout.columns,
      'seat_rows': layout.rows,
      'u_left_seats': layout.uLeftSeats,
      'u_right_seats': layout.uRightSeats,
      'u_base_seats': layout.uBaseSeats,
      'table_columns': layout.tableColumns,
      'table_rows': layout.tableRows,
    };
  }

  Future<StudyRoom> _layoutOf(int id) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'boarding_study_rooms',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Etüt salonu bulunamadı.');
    }
    return _roomFromRow(rows.first);
  }

  Future<int> _occupantCount(int studyRoomId) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS total FROM study_room_assignments '
      'WHERE study_room_id = ?',
      [studyRoomId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  @override
  Future<void> deleteStudyRoom(int id) async {
    final database = await _appDatabase.database;
    await database.delete(
      'boarding_study_rooms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> autoPlaceStudents(int studyRoomId) async {
    final database = await _appDatabase.database;
    final roomRows = await database.query(
      'boarding_study_rooms',
      where: 'id = ?',
      whereArgs: [studyRoomId],
      limit: 1,
    );
    if (roomRows.isEmpty) {
      throw StateError('Etüt salonu bulunamadı.');
    }
    final room = roomRows.first;
    final capacity = room['capacity'] as int;
    final blockName =
        await _currentBlockName(
          database,
          room['section'] as String,
          room['floor_number'],
        ) ??
        room['block_name'] as String;
    final pool = await _floorStudentPool(
      database,
      section: room['section'] as String,
      blockName: blockName,
      floorNumber: room['floor_number'] as int,
    );
    if (pool.isEmpty) {
      return 0;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    return database.transaction((transaction) async {
      // Önce bu salonun mevcut yerleşimi temizlenir; öğrenciler havuza döner.
      await transaction.delete(
        'study_room_assignments',
        where: 'study_room_id = ?',
        whereArgs: [studyRoomId],
      );
      final alreadyPlaced = await transaction.rawQuery(
        'SELECT student_id FROM study_room_assignments',
      );
      final placedIds = {
        for (final row in alreadyPlaced) row['student_id'] as int,
      };

      var placed = 0;
      for (final studentId in pool) {
        if (placed >= capacity) {
          break;
        }
        if (placedIds.contains(studentId)) {
          continue;
        }
        await transaction.insert('study_room_assignments', {
          'study_room_id': studyRoomId,
          'student_id': studentId,
          'assigned_at': now,
        });
        placedIds.add(studentId);
        placed++;
      }
      return placed;
    });
  }

  @override
  Future<List<StudyRoomFloorPool>> getFloorPools() async {
    final database = await _appDatabase.database;
    // Salona yerleştirilmemiş, olanda uyuyan öğrenciler kat havuzudur.
    final rows = await database.rawQuery('''
      SELECT
        r.section,
        r.block_name,
        r.floor_label,
        r.floor_number,
        s.id AS student_id
      FROM boarding_rooms r
      JOIN room_assignments ra ON ra.room_id = r.id
      JOIN students s ON s.id = ra.student_id
      LEFT JOIN study_room_assignments sa ON sa.student_id = s.id
      WHERE sa.id IS NULL
        AND (r.section <> 'girls' OR s.gender = 'female')
        AND (r.section <> 'boys' OR s.gender = 'male')
      GROUP BY r.section, r.block_name, r.floor_label, r.floor_number, s.id
      ORDER BY r.sort_order ASC, r.floor_number ASC, s.full_name COLLATE NOCASE ASC
    ''');

    final poolByFloor = <String, StudyRoomFloorPool>{};
    final idsByFloor = <String, List<int>>{};
    for (final row in rows) {
      final section = boardingSectionFromValue(row['section'] as String);
      final blockName = row['block_name'] as String;
      final floorLabel = row['floor_label'] as String;
      final floorNumber = row['floor_number'] as int;
      final key = '${section.value}|$blockName|$floorNumber';
      poolByFloor.putIfAbsent(
        key,
        () => StudyRoomFloorPool(
          section: section,
          blockName: blockName,
          floorLabel: floorLabel,
          floorNumber: floorNumber,
          studentIds: const [],
        ),
      );
      (idsByFloor[key] ??= <int>[]).add(row['student_id'] as int);
    }

    return [
      for (final entry in poolByFloor.entries)
        StudyRoomFloorPool(
          section: entry.value.section,
          blockName: entry.value.blockName,
          floorLabel: entry.value.floorLabel,
          floorNumber: entry.value.floorNumber,
          studentIds: List<int>.unmodifiable(idsByFloor[entry.key] ?? const []),
        ),
    ];
  }

  @override
  Future<void> placeStudent({
    required int studyRoomId,
    required int studentId,
  }) async {
    final database = await _appDatabase.database;
    final roomRows = await database.query(
      'boarding_study_rooms',
      where: 'id = ?',
      whereArgs: [studyRoomId],
      limit: 1,
    );
    if (roomRows.isEmpty) {
      throw StateError('Etüt salonu bulunamadı.');
    }
    final room = roomRows.first;
    final capacity = room['capacity'] as int;
    final section = room['section'] as String;
    final blockName =
        await _currentBlockName(database, section, room['floor_number']) ??
        room['block_name'] as String;

    final studentRows = await database.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (studentRows.isEmpty) {
      throw StateError('Öğrenci bulunamadı.');
    }
    final gender = studentRows.first['gender'] as String?;
    if (section == 'girls' && gender != 'female') {
      throw StateError('Bu salon kız bölümüne ait.');
    }
    if (section == 'boys' && gender != 'male') {
      throw StateError('Bu salon erkek bölümüne ait.');
    }

    final occupantRows = await database.rawQuery(
      'SELECT COUNT(*) AS total FROM study_room_assignments '
      'WHERE study_room_id = ?',
      [studyRoomId],
    );
    final occupantCount = (occupantRows.first['total'] as int?) ?? 0;
    if (occupantCount >= capacity) {
      throw StateError(
        'Etüt salonu kapasitesi dolu ($occupantCount / $capacity).',
      );
    }

    // Öğrenci gerçekten bu salonun katında uyuyor mu?
    final floorMatch = await database.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM room_assignments ra
      JOIN boarding_rooms r ON r.id = ra.room_id
      WHERE ra.student_id = ?
        AND r.section = ?
        AND r.block_name = ?
        AND r.floor_number = ?
      ''',
      [studentId, section, blockName, room['floor_number']],
    );
    if ((floorMatch.first['total'] as int? ?? 0) == 0) {
      throw StateError(
        'Öğrenci bu salonun katında uyumuyor. '
        'Önce öğrenciyi salonun bulunduğu kata taşıyın.',
      );
    }

    await database.insert('study_room_assignments', {
      'study_room_id': studyRoomId,
      'student_id': studentId,
      'assigned_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> releaseStudent(int studentId) async {
    final database = await _appDatabase.database;
    await database.delete(
      'study_room_assignments',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
  }

  /// Bölüm ve kat numarasına ait güncel blok adını döndürür.
  Future<String?> _currentBlockName(
    DatabaseExecutor database,
    String section,
    Object? floorNumber,
  ) async {
    final rows = await database.query(
      'boarding_rooms',
      columns: ['block_name'],
      where: 'section = ? AND floor_number = ?',
      whereArgs: [section, floorNumber],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['block_name'] as String?;
  }

  /// O katta uyuyan ve salonun bölümüne uyan öğrenci havuzunu döndürür.
  Future<List<int>> _floorStudentPool(
    DatabaseExecutor database, {
    required String section,
    required String blockName,
    required int floorNumber,
  }) async {
    final requiredGender = switch (section) {
      'girls' => 'female',
      'boys' => 'male',
      _ => null,
    };
    final rows = await database.rawQuery(
      '''
      SELECT s.id, s.gender
      FROM students s
      JOIN room_assignments ra ON ra.student_id = s.id
      JOIN boarding_rooms r ON r.id = ra.room_id
      WHERE r.section = ?
        AND r.block_name = ?
        AND r.floor_number = ?
        AND (? IS NULL OR s.gender = ?)
      GROUP BY s.id
      ORDER BY s.full_name COLLATE NOCASE ASC
      ''',
      [section, blockName, floorNumber, requiredGender, requiredGender],
    );
    return [for (final row in rows) row['id'] as int];
  }

  void _validateCapacity(int capacity) {
    if (capacity <= 0) {
      throw ArgumentError.value(
        capacity,
        'capacity',
        'Kapasite sıfırdan büyük olmalıdır.',
      );
    }
    if (capacity > maxCapacity) {
      throw ArgumentError.value(
        capacity,
        'capacity',
        'Kapasite en fazla $maxCapacity olabilir.',
      );
    }
  }

  String _floorLabel({required bool hasBasement, required int index}) {
    if (hasBasement && index == 0) {
      return 'Bodrum Kat';
    }
    final number = index - (hasBasement ? 1 : 0);
    if (number == 0) {
      return 'Zemin Kat';
    }
    return '$number. Kat';
  }
}

/// Pansiyon bilgilerinden gelen güncel kat bilgisi.
class _CurrentFloor {
  const _CurrentFloor({required this.blockName, required this.floorLabel});

  final String blockName;
  final String floorLabel;
}
