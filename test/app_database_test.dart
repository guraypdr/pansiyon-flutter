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

  test('sürüm 1 veritabanını sürüm 18e taşır', () async {
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

    expect(versionRows.single.values.single, 18);
    final sectionColumns = await connection.rawQuery(
      "PRAGMA table_info('school_sections')",
    );
    expect(
      sectionColumns.map((row) => row['name']),
      containsAll(['school_id', 'class_name', 'name', 'sort_order']),
    );
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
    // Sürüm 18'de aile bilgileri yeniden kuruldu: yeni sütunlar geldi,
    // eski ikisi kaldırıldı.
    expect(
      studentColumns.map((row) => row['name']),
      containsAll([
        'guardian_is_other',
        'guardian_address',
        'guardian_occupation',
        'guardian_education',
        'guardian_birth_date',
        'mother_is_biological',
        'mother_occupation',
        'mother_education',
        'mother_address',
        'mother_has_separate_address',
        'father_is_biological',
        'father_occupation',
        'father_education',
        'father_address',
        'father_has_separate_address',
      ]),
    );
    expect(
      studentColumns.map((row) => row['name']),
      isNot(
        anyOf(
          contains('living_arrangement'),
          contains('parents_live_together'),
        ),
      ),
    );
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

  test(
    'sürüm 16 veritabanındaki eski şube tablosunu sınıf düzeyine taşır',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'pansiyon_database_v16_test',
      );
      final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
      final initialDatabase = AppDatabase(databasePath: databasePath);
      final initialConnection = await initialDatabase.database;
      // Sürüm 16'da sınıf düzeyi sütunu olmayan tabloyu taklit et.
      await initialConnection.execute('DROP TABLE school_sections');
      await initialConnection.execute('''
      CREATE TABLE school_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_id INTEGER NOT NULL,
        name TEXT NOT NULL COLLATE NOCASE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
      await initialConnection.execute('PRAGMA user_version = 16');
      await initialDatabase.close();

      final migratedDatabase = AppDatabase(databasePath: databasePath);
      addTearDown(() async {
        await migratedDatabase.close();
        await tempDirectory.delete(recursive: true);
      });

      final connection = await migratedDatabase.database;
      final sectionColumns = await connection.rawQuery(
        "PRAGMA table_info('school_sections')",
      );
      expect(sectionColumns.map((row) => row['name']), contains('class_name'));
      // Sütun eklendiği için şube sorgusu hata vermemeli.
      await connection.query('school_sections');
    },
  );

  test('sürüm 17 aile bilgilerini yeni şemaya taşır', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_database_v18_test',
    );
    final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
    final initialDatabase = AppDatabase(databasePath: databasePath);
    final initialConnection = await initialDatabase.database;

    // Sürüm 17'deki tabloyu taklit et: yeni sütunları düşür, eski ikisini
    // NOT NULL olarak geri ekle.
    for (final column in const [
      'guardian_is_other',
      'guardian_address',
      'guardian_occupation',
      'guardian_education',
      'guardian_birth_date',
      'mother_is_biological',
      'mother_occupation',
      'mother_education',
      'mother_address',
      'mother_has_separate_address',
      'father_is_biological',
      'father_occupation',
      'father_education',
      'father_address',
      'father_has_separate_address',
    ]) {
      await initialConnection.execute(
        'ALTER TABLE students DROP COLUMN $column',
      );
    }
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN living_arrangement TEXT NOT NULL DEFAULT 'withMotherFather'",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN parents_live_together TEXT NOT NULL DEFAULT 'together'",
    );
    await initialConnection.execute(
      '''
      INSERT INTO students (
        full_name, gender, mother_name, mother_phone, mother_alive,
        father_name, father_phone, father_alive,
        guardian_name, guardian_relation, guardian_phone,
        emergency_contact_name, emergency_contact_phone,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        'Zeynep Kaya',
        'female',
        'Ayşe Kaya',
        '0555 111 22 33',
        1,
        'Mehmet Kaya',
        '0555 444 55 66',
        1,
        'Nuriye Amca',
        'Amca',
        '0555 777 88 99',
        'Nuriye Amca',
        '0555 777 88 99',
        '2026-01-01T00:00:00.000Z',
        '2026-01-01T00:00:00.000Z',
      ],
    );
    await initialConnection.execute('PRAGMA user_version = 17');
    await initialDatabase.close();

    final migratedDatabase = AppDatabase(databasePath: databasePath);
    addTearDown(() async {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    });

    final connection = await migratedDatabase.database;
    expect(
      (await connection.rawQuery('PRAGMA user_version')).single.values.single,
      18,
    );

    final columns = (await connection.rawQuery(
      "PRAGMA table_info('students')",
    )).map((row) => row['name']).toList();
    expect(
      columns,
      isNot(
        anyOf(
          contains('living_arrangement'),
          contains('parents_live_together'),
        ),
      ),
    );

    // Mevcut aile verisi korunur.
    final rows = await connection.query('students');
    expect(rows, hasLength(1));
    final student = rows.single;
    expect(student['full_name'], 'Zeynep Kaya');
    expect(student['mother_name'], 'Ayşe Kaya');
    expect(student['mother_phone'], '0555 111 22 33');
    expect(student['father_name'], 'Mehmet Kaya');
    expect(student['guardian_name'], 'Nuriye Amca');
    expect(student['emergency_contact_name'], 'Nuriye Amca');

    // Yeni alanlar varsayılan değerle gelir.
    expect(student['guardian_is_other'], 0);
    expect(student['mother_is_biological'], 1);
    expect(student['mother_has_separate_address'], 0);
    expect(student['father_is_biological'], 1);
    expect(student['father_has_separate_address'], 0);
    expect(student['mother_occupation'], isNull);
    expect(student['guardian_birth_date'], isNull);

    // Index'ler tablo yeniden kurulduğu için geri gelir.
    final indexes = await connection.rawQuery("PRAGMA index_list('students')");
    expect(
      indexes.map((row) => row['name']),
      containsAll([
        'idx_students_school',
        'idx_students_national_id_unique',
        'idx_students_school_number_unique',
      ]),
    );

    // NOT NULL kaldırıldığı için yeni sütunlu bir kayıt eklenebilir.
    await connection.insert('students', {
      'full_name': 'Ali Veli',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
    expect(await connection.query('students'), hasLength(2));
  });
}
