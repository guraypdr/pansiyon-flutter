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

  test('sürüm 1 veritabanını sürüm 2ye taşır', () async {
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

    expect(versionRows.single.values.single, 2);
    expect(
      indexes.any((row) => row['name'] == 'idx_boarding_school_info_updated'),
      isTrue,
    );
  });
}
