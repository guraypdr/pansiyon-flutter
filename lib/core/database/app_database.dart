import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pansiyon_yonetim/core/database/sqflite_bootstrap.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase({String? databasePath}) : _databasePath = databasePath;

  static int get databaseVersion => _databaseVersion;

  static const _databaseVersion = 15;

  final String? _databasePath;
  Database? _database;
  Future<Database>? _databaseFuture;

  Future<Database> get database {
    final database = _database;
    if (database != null) {
      return Future.value(database);
    }

    final existing = _databaseFuture;
    if (existing != null) {
      return existing;
    }

    late final Future<Database> opening;
    opening = _openDatabase()
        .then((database) {
          _database = database;
          return database;
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (identical(_databaseFuture, opening)) {
            _databaseFuture = null;
          }
          Error.throwWithStackTrace(error, stackTrace);
        });
    _databaseFuture = opening;
    return opening;
  }

  Future<String> filePath() async {
    final override = _databasePath;
    if (override != null) {
      if (override == inMemoryDatabasePath) {
        throw UnsupportedError(
          'Bellek içi veritabanı için dosya yedeği alınamaz.',
        );
      }
      return override;
    }
    return _defaultDatabasePath();
  }

  Future<Database> _openDatabase() async {
    ensureSqfliteFfiInitialized();
    final databaseFile = _databasePath ?? await _defaultDatabasePath();
    return openDatabase(
      databaseFile,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2 && newVersion >= 2) {
          await _createIndexes(db);
        }
        if (oldVersion < 3 && newVersion >= 3) {
          await _createStudentSchema(db);
        }
        if (oldVersion < 4 && newVersion >= 4) {
          await _addBoardingRoomFields(db);
        }
        if (oldVersion < 5 && newVersion >= 5) {
          await _addBoardingFloorFeatureFields(db);
        }
        if (oldVersion < 6 && newVersion >= 6) {
          await _createRoomSchema(db);
        }
        if (oldVersion < 7 && newVersion >= 7) {
          await _addStudentGenderField(db);
        }
        if (oldVersion < 8 && newVersion >= 8) {
          await _addStudentUniquenessIndexes(db);
        }
        if (oldVersion < 9 && newVersion >= 9) {
          await _addPreparationGradeField(db);
        }
        if (oldVersion < 10 && newVersion >= 10) {
          await _createStudyRoomSchema(db);
        }
        if (oldVersion < 11 && newVersion >= 11) {
          await _addStudyRoomLayoutFields(db);
        }
        if (oldVersion < 12 && newVersion >= 12) {
          await _addStudentBloodTypeField(db);
        }
        if (oldVersion < 13 && newVersion >= 13) {
          await _createDutySchema(db);
        }
        if (oldVersion < 14 && newVersion >= 14) {
          await _upgradeDutySchemaV14(db);
        }
        if (oldVersion < 15 && newVersion >= 15) {
          await _addDutyListsTable(db);
        }
      },
    );
  }

  Future<String> _defaultDatabasePath() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      path.join(supportDirectory.path, 'pansiyon_yonetim'),
    );
    await databaseDirectory.create(recursive: true);
    return path.join(databaseDirectory.path, 'pansiyon.db');
  }

  Future<void> _createSchema(Database db) async {
    await _createDutySchema(db);
    await db.execute('''
      CREATE TABLE boarding_school_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_name TEXT NOT NULL,
        principal_name TEXT NOT NULL,
        principal_phone TEXT NOT NULL,
        deputy_name TEXT NOT NULL,
        deputy_phone TEXT NOT NULL,
        boarding_type TEXT NOT NULL,
        education_level TEXT NOT NULL,
        has_preparation_grade INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE boarding_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_info_id INTEGER NOT NULL,
        section TEXT NOT NULL,
        name TEXT NOT NULL,
        standard_room_capacity INTEGER NOT NULL,
        study_room_count INTEGER NOT NULL,
        has_basement INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (school_info_id) REFERENCES boarding_school_info (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE boarding_floors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        block_id INTEGER NOT NULL,
        floor_number INTEGER NOT NULL,
        student_room_count INTEGER NOT NULL DEFAULT 0,
        room_start_number INTEGER NOT NULL DEFAULT 0,
        has_student_rooms INTEGER NOT NULL DEFAULT 0,
        has_study_room INTEGER NOT NULL DEFAULT 0,
        study_room_count INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (block_id) REFERENCES boarding_blocks (id) ON DELETE CASCADE
      )
    ''');
    await _createIndexes(db);
    await _createRoomSchema(db);
    await _createStudentSchema(db);
    await _createStudyRoomSchema(db);
  }

  Future<void> _createRoomSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS boarding_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_key TEXT NOT NULL UNIQUE,
        block_name TEXT NOT NULL,
        section TEXT NOT NULL,
        floor_label TEXT NOT NULL,
        floor_number INTEGER NOT NULL,
        room_number INTEGER NOT NULL,
        capacity INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS room_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        assigned_at TEXT NOT NULL,
        UNIQUE (student_id),
        FOREIGN KEY (room_id) REFERENCES boarding_rooms (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_boarding_rooms_section_floor '
      'ON boarding_rooms (section, floor_label, sort_order)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_room_assignments_room '
      'ON room_assignments (room_id)',
    );
  }

  /// Etüt salonu ve salonlara öğrenci yerleştirme tabloları.
  /// Nöbet tabloları bölüm bazlı ortak ayarlara göre yeniden kurulur.
  /// Öğretmen kayıtları korunur.
  /// Nöbet listeleri tablosunu oluşturur ve mevcut atamalardan geri doldurur.
  Future<void> _addDutyListsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        section_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (year, month, section_key)
      )
    ''');
    await db.execute('''
      INSERT OR IGNORE INTO duty_lists (year, month, section_key, created_at)
      SELECT DISTINCT year, month, section_key, created_at
      FROM duty_assignments
    ''');
  }

  Future<void> _upgradeDutySchemaV14(Database db) async {
    for (final table in const [
      'duty_lists',
      'duty_assignments',
      'duty_blackouts',
      'duty_settings_locations',
      'duty_settings',
      'duty_month_teacher_off',
      'duty_month_locations',
      'duty_month_blackouts',
      'duty_months',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
    await _createDutySchema(db);
  }

  Future<void> _createDutySchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_teachers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        national_id TEXT,
        phone TEXT,
        school TEXT,
        branch TEXT,
        has_duty_training INTEGER NOT NULL DEFAULT 0,
        duty_preference TEXT NOT NULL DEFAULT 'balanced',
        available_weekdays TEXT NOT NULL DEFAULT '1,2,3,4,5',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        section_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (year, month, section_key)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_key TEXT NOT NULL UNIQUE,
        daily_count INTEGER NOT NULL DEFAULT 2,
        max_consecutive INTEGER NOT NULL DEFAULT 2,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_settings_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_key TEXT NOT NULL,
        label TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_blackouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        section_key TEXT NOT NULL,
        blackout_date TEXT NOT NULL,
        reason TEXT,
        UNIQUE (section_key, blackout_date)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_month_teacher_off (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        section_key TEXT NOT NULL,
        teacher_id INTEGER NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES duty_teachers (id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        duty_date TEXT NOT NULL,
        teacher_id INTEGER NOT NULL,
        section_key TEXT NOT NULL,
        location TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES duty_teachers (id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_duty_assignment_unique '
      'ON duty_assignments (year, month, section_key, duty_date, teacher_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_duty_assignment_month '
      'ON duty_assignments (year, month, section_key, duty_date)',
    );
  }

  Future<void> _createStudyRoomSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS boarding_study_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        section TEXT NOT NULL,
        block_name TEXT NOT NULL,
        floor_label TEXT NOT NULL,
        floor_number INTEGER NOT NULL,
        capacity INTEGER NOT NULL,
        seating TEXT NOT NULL,
        table_size INTEGER,
        tables_have_students INTEGER NOT NULL DEFAULT 0,
        seat_columns INTEGER NOT NULL DEFAULT 0,
        seat_rows INTEGER NOT NULL DEFAULT 0,
        u_left_seats INTEGER NOT NULL DEFAULT 0,
        u_right_seats INTEGER NOT NULL DEFAULT 0,
        u_base_seats INTEGER NOT NULL DEFAULT 0,
        table_columns INTEGER NOT NULL DEFAULT 0,
        table_rows INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_room_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        study_room_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        assigned_at TEXT NOT NULL,
        UNIQUE (student_id),
        FOREIGN KEY (study_room_id) REFERENCES boarding_study_rooms (id)
          ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_rooms_section_floor '
      'ON boarding_study_rooms (section, block_name, floor_number, sort_order)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_room_assignments_room '
      'ON study_room_assignments (study_room_id)',
    );
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_boarding_blocks_school '
      'ON boarding_blocks (school_info_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_boarding_floors_block '
      'ON boarding_floors (block_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_boarding_school_info_updated '
      'ON boarding_school_info (updated_at)',
    );
  }

  Future<void> _addBoardingRoomFields(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'boarding_blocks',
      column: 'has_basement',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'boarding_floors',
      column: 'room_start_number',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
  }

  Future<void> _addBoardingFloorFeatureFields(Database db) async {
    final addedStudentRoomsFlag = await _addColumnIfMissing(
      db,
      table: 'boarding_floors',
      column: 'has_student_rooms',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    final addedStudyRoomFlag = await _addColumnIfMissing(
      db,
      table: 'boarding_floors',
      column: 'has_study_room',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    final addedStudyRoomCount = await _addColumnIfMissing(
      db,
      table: 'boarding_floors',
      column: 'study_room_count',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );

    if (addedStudentRoomsFlag) {
      await db.execute('''
        UPDATE boarding_floors
        SET has_student_rooms = CASE
          WHEN student_room_count > 0 THEN 1
          ELSE 0
        END
      ''');
    }

    if (addedStudyRoomFlag || addedStudyRoomCount) {
      await db.execute('''
        UPDATE boarding_floors
        SET has_study_room = CASE
          WHEN (
            SELECT study_room_count
            FROM boarding_blocks
            WHERE boarding_blocks.id = boarding_floors.block_id
          ) > 0 THEN 1
          ELSE 0
        END,
        study_room_count = COALESCE((
          SELECT study_room_count
          FROM boarding_blocks
          WHERE boarding_blocks.id = boarding_floors.block_id
        ), 0)
      ''');
    }
  }

  Future<bool> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final alreadyExists = columns.any((row) => row['name'] == column);
    if (alreadyExists) {
      return false;
    }
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    return true;
  }

  Future<void> _addStudentGenderField(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'students',
      column: 'gender',
      definition: 'TEXT',
    );
  }

  /// Lise kademesinde hazırlık sınıfı kullanım bilgisi.
  Future<void> _addPreparationGradeField(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'boarding_school_info',
      column: 'has_preparation_grade',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
  }

  /// Etüt salonlarının düzen sayacı sütunları (kapasite otomatik hesaplanır).
  Future<void> _addStudyRoomLayoutFields(Database db) async {
    const definitions = <String, String>{
      'seat_columns': 'INTEGER NOT NULL DEFAULT 0',
      'seat_rows': 'INTEGER NOT NULL DEFAULT 0',
      'u_left_seats': 'INTEGER NOT NULL DEFAULT 0',
      'u_right_seats': 'INTEGER NOT NULL DEFAULT 0',
      'u_base_seats': 'INTEGER NOT NULL DEFAULT 0',
      'table_columns': 'INTEGER NOT NULL DEFAULT 0',
      'table_rows': 'INTEGER NOT NULL DEFAULT 0',
    };
    for (final entry in definitions.entries) {
      await _addColumnIfMissing(
        db,
        table: 'boarding_study_rooms',
        column: entry.key,
        definition: entry.value,
      );
    }
  }

  Future<void> _addStudentBloodTypeField(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'students',
      column: 'blood_type',
      definition: 'TEXT',
    );
  }

  Future<void> _createStudentSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schools (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        gender TEXT,
        national_id TEXT,
        school_id INTEGER,
        class_name TEXT,
        section_name TEXT,
        school_number TEXT,
        birth_date TEXT,
        address TEXT,
        phone TEXT,
        has_chronic_disease INTEGER NOT NULL DEFAULT 0,
        chronic_disease_details TEXT,
        has_allergy INTEGER NOT NULL DEFAULT 0,
        allergy_details TEXT,
        regular_medication TEXT,
        blood_type TEXT,
        has_psychological_condition INTEGER NOT NULL DEFAULT 0,
        psychological_condition_details TEXT,
        living_arrangement TEXT NOT NULL,
        mother_name TEXT,
        father_name TEXT,
        mother_phone TEXT,
        father_phone TEXT,
        mother_alive INTEGER NOT NULL DEFAULT 1,
        father_alive INTEGER NOT NULL DEFAULT 1,
        parents_live_together TEXT NOT NULL,
        guardian_name TEXT,
        guardian_relation TEXT,
        guardian_phone TEXT,
        emergency_contact_name TEXT,
        emergency_contact_phone TEXT,
        boarding_registration_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        attendance_date TEXT NOT NULL,
        status TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (student_id, attendance_date),
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_discipline_incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        incident_date TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_school ON students (school_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_attendance_date '
      'ON student_attendance (attendance_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_student_discipline_date '
      'ON student_discipline_incidents (incident_date)',
    );
    await _addStudentUniquenessIndexes(db);
  }

  Future<void> _addStudentUniquenessIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_national_id_lookup '
      'ON students (national_id)',
    );
    final duplicateNationalIds = await db.rawQuery('''
      SELECT national_id
      FROM students
      WHERE national_id IS NOT NULL AND TRIM(national_id) <> ''
      GROUP BY TRIM(national_id)
      HAVING COUNT(*) > 1
      LIMIT 1
    ''');
    if (duplicateNationalIds.isEmpty) {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_students_national_id_unique
        ON students (national_id)
        WHERE national_id IS NOT NULL AND TRIM(national_id) <> ''
      ''');
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_school_number_lookup '
      'ON students (school_id, school_number)',
    );
    final duplicateSchoolNumbers = await db.rawQuery('''
      SELECT school_id, school_number
      FROM students
      WHERE school_id IS NOT NULL
        AND school_number IS NOT NULL
        AND TRIM(school_number) <> ''
      GROUP BY school_id, TRIM(school_number)
      HAVING COUNT(*) > 1
      LIMIT 1
    ''');
    if (duplicateSchoolNumbers.isEmpty) {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_students_school_number_unique
        ON students (school_id, school_number)
        WHERE school_id IS NOT NULL
          AND school_number IS NOT NULL
          AND TRIM(school_number) <> ''
      ''');
    }
  }

  Future<void> close() async {
    final database = _database;
    final databaseFuture = _databaseFuture;
    _database = null;
    _databaseFuture = null;

    if (database != null) {
      await database.close();
      return;
    }
    if (databaseFuture != null) {
      final openedDatabase = await databaseFuture;
      await openedDatabase.close();
    }
  }
}
