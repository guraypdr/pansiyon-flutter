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

  test('sürüm 1 veritabanını sürüm 21e taşır', () async {
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

    expect(versionRows.single.values.single, 21);
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
    // Sürüm 20'de aile alanları iki veliye indirgenmiş durumda.
    expect(
      studentColumns.map((row) => row['name']),
      containsAll([
        'guardian_name',
        'guardian_relation',
        'guardian_phone',
        'guardian_address',
        'guardian2_name',
        'guardian2_relation',
        'guardian2_phone',
        'guardian2_address',
      ]),
    );
    expect(
      studentColumns.map((row) => row['name']),
      isNot(
        anyOf(
          contains('living_arrangement'),
          contains('parents_live_together'),
          contains('mother_'),
          contains('father_'),
          contains('guardian_is_other'),
        ),
      ),
    );
    expect(
      studentColumns.map((row) => row['name']),
      isNot(
        anyOf(
          contains('guardian_occupation'),
          contains('guardian_education'),
          contains('guardian_birth_date'),
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

  test('sürüm 19 aile alanlarını iki veliye taşır', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_database_v18_test',
    );
    final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
    final initialDatabase = AppDatabase(databasePath: databasePath);
    final initialConnection = await initialDatabase.database;

    // Sürüm 19'daki tabloyu taklit et: aile sütunlarını düşürüp eski
    // living_arrangement / parents_live_together sütunlarını geri ekle.
    for (final column in const [
      'guardian2_name',
      'guardian2_relation',
      'guardian2_phone',
      'guardian2_address',
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
      "ALTER TABLE students ADD COLUMN guardian_is_other INTEGER NOT NULL DEFAULT 0",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN mother_name TEXT",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN mother_phone TEXT",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN mother_alive INTEGER NOT NULL DEFAULT 1",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN father_name TEXT",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN father_phone TEXT",
    );
    await initialConnection.execute(
      "ALTER TABLE students ADD COLUMN father_alive INTEGER NOT NULL DEFAULT 1",
    );
    await initialConnection.execute(
      '''
      INSERT INTO students (
        full_name, gender, mother_name, mother_phone, mother_alive,
        father_name, father_phone, father_alive,
        guardian_name, guardian_relation, guardian_phone,
        emergency_contact_name, emergency_contact_phone,
        education_year, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        2025,
        '2026-01-01T00:00:00.000Z',
        '2026-01-01T00:00:00.000Z',
      ],
    );
    await initialConnection.execute('PRAGMA user_version = 19');
    await initialDatabase.close();

    final migratedDatabase = AppDatabase(databasePath: databasePath);
    addTearDown(() async {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    });

    final connection = await migratedDatabase.database;
    expect(
      (await connection.rawQuery('PRAGMA user_version')).single.values.single,
      21,
    );

    final columns = (await connection.rawQuery(
      "PRAGMA table_info('students')",
    )).map((row) => row['name']).toList();
    expect(
      columns,
      containsAll([
        'guardian2_name',
        'guardian2_relation',
        'guardian2_phone',
        'guardian2_address',
      ]),
    );
    expect(
      columns,
      isNot(
        anyOf(
          contains('living_arrangement'),
          contains('parents_live_together'),
          contains('mother_'),
          contains('father_'),
          contains('guardian_is_other'),
        ),
      ),
    );

    // Birincil veli verisi korunur, eski aile alanları kaybolur.
    final rows = await connection.query('students');
    expect(rows, hasLength(1));
    final student = rows.single;
    expect(student['full_name'], 'Zeynep Kaya');
    expect(student['guardian_name'], 'Nuriye Amca');
    expect(student['guardian_relation'], 'Amca');
    expect(student['emergency_contact_name'], 'Nuriye Amca');
    expect(student['guardian2_name'], isNull);

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

    // Yeni sütunlu bir kayıt eklenebilir.
    await connection.insert('students', {
      'full_name': 'Ali Veli',
      'education_year': 2025,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
    expect(await connection.query('students'), hasLength(2));
  });

  test('sürüm 17 verisini zincirleme olarak 20ye taşır', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_database_chain_test',
    );
    final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
    final initialDatabase = AppDatabase(databasePath: databasePath);
    final initialConnection = await initialDatabase.database;

    // Sürüm 17 tablosunu taklit et: yıl sütunu ve veli 2 sütunları yok.
    await initialConnection.execute(
      'DROP INDEX IF EXISTS idx_students_education_year',
    );
    for (final column in const [
      'education_year',
      'guardian2_name',
      'guardian2_relation',
      'guardian2_phone',
      'guardian2_address',
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
      "ALTER TABLE students ADD COLUMN guardian_is_other INTEGER NOT NULL DEFAULT 0",
    );
    await initialConnection.execute(
      'ALTER TABLE students ADD COLUMN mother_name TEXT',
    );
    await initialConnection.execute(
      'ALTER TABLE students ADD COLUMN mother_phone TEXT',
    );
    await initialConnection.execute(
      'ALTER TABLE students ADD COLUMN mother_alive INTEGER NOT NULL DEFAULT 1',
    );
    await initialConnection.execute(
      'ALTER TABLE students ADD COLUMN father_name TEXT',
    );
    await initialConnection.execute(
      'ALTER TABLE students ADD COLUMN father_phone TEXT',
    );
    await initialConnection.execute(
      'ALTER TABLE students ADD COLUMN father_alive INTEGER NOT NULL DEFAULT 1',
    );
    await initialConnection.execute(
      '''
      INSERT INTO students (
        full_name, mother_name, guardian_name, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?)
    ''',
      [
        'Zeynep Kaya',
        'Ayşe Kaya',
        'Nuriye Amca',
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
      21,
    );

    final columns = (await connection.rawQuery(
      "PRAGMA table_info('students')",
    )).map((row) => row['name']).toList();
    expect(
      columns,
      containsAll([
        'education_year',
        'guardian2_name',
        'guardian2_relation',
        'guardian2_phone',
        'guardian2_address',
      ]),
    );
    expect(
      columns,
      isNot(
        anyOf(
          contains('living_arrangement'),
          contains('parents_live_together'),
          contains('mother_'),
          contains('father_'),
          contains('guardian_is_other'),
        ),
      ),
    );

    // Yıl kapsamı boş kalmaz: sürüm 19 migrasyonu etkin yılı atar.
    final student = (await connection.query('students')).single;
    expect(student['guardian_name'], 'Nuriye Amca');
    expect(student['education_year'], isNotNull);
  });

  test('sürüm 20 bozuk öğrenci atıflarını onarır', () async {
    // Regresyon: sürüm 18 ve 20'de "ALTER TABLE students RENAME TO
    // students_legacy" çalıştırıldığında SQLite, diğer tabloların
    // `students` atıflarını da yeniden adlandırıyordu. students_legacy
    // silinince oda ataması, etüt ataması, yoklama ve disiplin
    // kayıtlarının tamamı var olmayan tabloya bağlanıyor ve her ekleme
    // "no such table: main.students_legacy" ile başarısız oluyordu.
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_database_fk_repair_test',
    );
    final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
    final initialDatabase = AppDatabase(databasePath: databasePath);
    final initialConnection = await initialDatabase.database;

    // Sürüm 20'un bıraktığı bozuk hâli taklit et.
    for (final entry in const {
      'room_assignments': '''
        CREATE TABLE room_assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_id INTEGER NOT NULL,
          student_id INTEGER NOT NULL,
          assigned_at TEXT NOT NULL,
          UNIQUE (student_id),
          FOREIGN KEY (room_id) REFERENCES boarding_rooms (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES "students_legacy" (id) ON DELETE CASCADE
        )
      ''',
      'student_attendance': '''
        CREATE TABLE student_attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          attendance_date TEXT NOT NULL,
          status TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE (student_id, attendance_date),
          FOREIGN KEY (student_id) REFERENCES "students_legacy" (id) ON DELETE CASCADE
        )
      ''',
    }.entries) {
      await initialConnection.execute('DROP TABLE ${entry.key}');
      await initialConnection.execute(entry.value);
    }
    await initialConnection.execute('PRAGMA user_version = 20');
    await initialDatabase.close();

    final migratedDatabase = AppDatabase(databasePath: databasePath);
    addTearDown(() async {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    });

    final connection = await migratedDatabase.database;
    expect(
      (await connection.rawQuery('PRAGMA user_version')).single.values.single,
      21,
    );

    final schemas = await connection.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      schemas
          .where((row) => '${row['sql']}'.contains('students_legacy'))
          .map((row) => row['name']),
      isEmpty,
      reason: 'öğrenci atıfları students_legacy içermemeli',
    );

    // Onarılan atıflar gerçekten çalışır.
    final studentId = await connection.insert('students', {
      'full_name': 'Ali Vırlaz',
      'education_year': 2026,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
    await connection.insert('student_attendance', {
      'student_id': studentId,
      'attendance_date': '2026-01-01',
      'status': 'present',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
    expect(await connection.query('student_attendance'), hasLength(1));

    // foreign_key_check, var olmayan tabloya kalan atıf varsa satır döndürür.
    expect(await connection.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('sürüm 18 verisini eğitim yılı kapsamına taşır', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_database_v19_test',
    );
    final databasePath = path.join(tempDirectory.path, 'pansiyon.db');
    final initialDatabase = AppDatabase(databasePath: databasePath);
    final initialConnection = await initialDatabase.database;

    // Sürüm 18'de yıl sütunu yok; öğrenci ve öğretmen eklenip yıl sütunu
    // düşürülür.
    await initialConnection.execute(
      'ALTER TABLE students DROP COLUMN education_year',
    );
    await initialConnection.execute(
      'ALTER TABLE duty_teachers DROP COLUMN education_year',
    );
    await initialConnection.execute('DROP TABLE education_years');
    await initialConnection.execute(
      'ALTER TABLE duty_lists RENAME TO duty_lists_keep',
    );
    await initialConnection.execute('''
      CREATE TABLE duty_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        section_key TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (year, month, section_key)
      )
    ''');
    await initialConnection.execute(
      'INSERT INTO duty_lists (year, month, section_key, created_at) '
      'VALUES (2025, 10, ?, ?)',
      ['', '2025-09-01T00:00:00.000Z'],
    );
    await initialConnection.execute('DROP TABLE duty_lists_keep');
    await initialConnection.execute(
      '''
      INSERT INTO students (
        full_name, created_at, updated_at
      ) VALUES (?, ?, ?)
    ''',
      ['Zeynep Kaya', '2025-09-01T00:00:00.000Z', '2025-09-01T00:00:00.000Z'],
    );
    await initialConnection.execute(
      '''
      INSERT INTO duty_teachers (full_name, created_at, updated_at)
      VALUES (?, ?, ?)
    ''',
      ['Ali Öğretmen', '2025-09-01T00:00:00.000Z', '2025-09-01T00:00:00.000Z'],
    );
    await initialConnection.execute('PRAGMA user_version = 18');
    await initialDatabase.close();

    final migratedDatabase = AppDatabase(databasePath: databasePath);
    addTearDown(() async {
      await migratedDatabase.close();
      await tempDirectory.delete(recursive: true);
    });

    final connection = await migratedDatabase.database;
    expect(
      (await connection.rawQuery('PRAGMA user_version')).single.values.single,
      21,
    );

    // Bugünün yılı etkin olarak oluşturulur.
    final years = await connection.query('education_years');
    expect(years, hasLength(1));
    expect(years.single['is_active'], 1);

    // Mevcut kayıtlar etkin yıla atanır.
    final students = await connection.query('students');
    expect(students.single['education_year'], years.single['start_year']);
    final teachers = await connection.query('duty_teachers');
    expect(teachers.single['education_year'], years.single['start_year']);
    final lists = await connection.query('duty_lists');
    expect(lists.single['education_year'], years.single['start_year']);
    // Takvim koordinatları korunur.
    expect(lists.single['year'], 2025);
    expect(lists.single['month'], 10);
  });
}
