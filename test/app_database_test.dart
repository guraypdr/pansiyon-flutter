import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('aynı anda veritabanı açılışlarını tekilleştirir', () async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);

    final first = database.database;
    final second = database.database;

    expect(identical(first, second), isTrue);
    expect(await second, same(await first));
  });

  test('sürüm 1 veritabanını sürüm 8e taşır', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_database_test',
    );
    final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
    final initialDatabase = AppDatabase(databasePath: databasePath);
    final initialConnection = await initialDatabase.database;
    await initialConnection.execute(
      'DROP INDEX idx_boarding_school_info_updated',
    );
    await initialConnection.execute('PRAGMA user_version = 1');
    await initialDatabase.close();

    final migratedDatabase = AppDatabase(databasePath: databasePath);
    addTearDown(() async {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    });

    final connection = await migratedDatabase.database;
    final versionRows = await connection.rawQuery('PRAGMA user_version');
    final indexes = await connection.rawQuery(
      "PRAGMA index_list('boarding_school_info')",
    );
    final tables = await connection.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    expect(versionRows.single.values.single, 8);
    final blockColumns = await connection.rawQuery(
      "PRAGMA table_info('boarding_blocks')",
    );
    final floorColumns = await connection.rawQuery(
      "PRAGMA table_info('boarding_floors')",
    );
    final studentColumns = await connection.rawQuery(
      "PRAGMA table_info('students')",
    );
    expect(blockColumns.map((row) => row['name']), contains('has_basement'));
    expect(studentColumns.map((row) => row['name']), contains('gender'));
    expect(
      floorColumns.map((row) => row['name']),
      containsAll([
        'room_start_number',
        'has_student_rooms',
        'has_study_room',
        'study_room_count',
      ]),
    );
    expect(
      tables.map((row) => row['name']),
      containsAll([
        'schools',
        'students',
        'student_attendance',
        'boarding_rooms',
        'room_assignments',
      ]),
    );
    expect(
      indexes.any((row) => row['name'] == 'idx_boarding_school_info_updated'),
      isTrue,
    );
    final studentIndexes = await connection.rawQuery(
      "PRAGMA index_list('students')",
    );
    expect(
      studentIndexes.map((row) => row['name']),
      containsAll([
        'idx_students_national_id_unique',
        'idx_students_school_number_unique',
      ]),
    );
  });
}
