import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase({String? databasePath}) : _databasePath = databasePath;

  static const _databaseVersion = 4;

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

  Future<Database> _openDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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
        student_room_count INTEGER NOT NULL,
        room_start_number INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (block_id) REFERENCES boarding_blocks (id) ON DELETE CASCADE
      )
    ''');
    await _createIndexes(db);
    await _createStudentSchema(db);
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

  Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final alreadyExists = columns.any((row) => row['name'] == column);
    if (alreadyExists) {
      return;
    }
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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
