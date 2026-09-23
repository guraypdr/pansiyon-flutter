import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase({String? databasePath}) : _databasePath = databasePath;

  final String? _databasePath;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final databaseFile = _databasePath ?? await _defaultDatabasePath();
    _database = await openDatabase(
      databaseFile,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    return _database!;
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
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (block_id) REFERENCES boarding_blocks (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_boarding_blocks_school ON boarding_blocks (school_info_id)',
    );
    await db.execute(
      'CREATE INDEX idx_boarding_floors_block ON boarding_floors (block_id)',
    );
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
