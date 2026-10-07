import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pansiyon_yonetim/core/database/sqflite_bootstrap.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase({String? databasePath}) : _databasePath = databasePath;

  static int get databaseVersion => _databaseVersion;

  static const _databaseVersion = 22;

  final String? _databasePath;
  int? _activeEducationYear;
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

  /// Kullanımda olan eğitim öğretim yılının başlangıç yılı.
  ///
  /// Değer veritabanı açılışında bir kez okunur ve önbelleğe alınır; her
  /// sorgu için ayrı sorgu yapılmaz. [setActiveEducationYear] ile geçici
  /// olarak değiştirilebilir.
  Future<int> activeEducationYear() async {
    final cached = _activeEducationYear;
    if (cached != null) {
      return cached;
    }
    final resolved = await _readActiveEducationYear();
    _activeEducationYear = resolved;
    return resolved;
  }

  /// Etkin yılı uygulama genelinde değiştirir.
  void setActiveEducationYear(int startYear) {
    _activeEducationYear = startYear;
  }

  Future<int> _readActiveEducationYear() async {
    try {
      final database = await this.database;
      return _readActiveEducationYearFrom(database);
    } catch (_) {
      return currentEducationYearStart();
    }
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
    final opened = await openDatabase(
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
        if (oldVersion < 16 && newVersion >= 16) {
          await _createSchoolSectionsSchema(db);
        }
        if (oldVersion < 17 && newVersion >= 17) {
          // Şubeler artık sınıf düzeyine bağlı; eski tabloyu yeniden kurarız.
          await db.execute('DROP TABLE IF EXISTS school_sections');
          await _createSchoolSectionsSchema(db);
        }
        if (oldVersion < 18 && newVersion >= 18) {
          await _upgradeStudentFamilyFields(db);
        }
        if (oldVersion < 19 && newVersion >= 19) {
          await _addEducationYearScope(db);
        }
        if (oldVersion < 20 && newVersion >= 20) {
          await _replaceFamilyFieldsWithGuardians(db);
        }
        if (oldVersion < 21 && newVersion >= 21) {
          await _repairStudentForeignKeys(db);
        }
        if (oldVersion < 22 && newVersion >= 22) {
          await db.execute(
            'DROP INDEX IF EXISTS idx_students_school_number_unique',
          );
        }
      },
    );
    // Etkin eğitim yılı şema hazır olduktan sonra bir kez okunur; sayfa
    // yüklemelerinde ek sorgu oluşmaz.
    _activeEducationYear = await _readActiveEducationYearFrom(opened);
    return opened;
  }

  Future<int> _readActiveEducationYearFrom(Database database) async {
    try {
      final rows = await database.query(
        'education_years',
        where: 'is_active = 1',
        limit: 1,
      );
      if (rows.isEmpty) {
        return currentEducationYearStart();
      }
      return rows.first['start_year'] as int? ?? currentEducationYearStart();
    } catch (_) {
      return currentEducationYearStart();
    }
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
    await _createEducationYearSchema(db);
    await _seedActiveEducationYear(db);
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

  /// Her okul ve sınıf düzeyi için şube (A, B, GD ...) tanımlarını tutan tablo.
  Future<void> _createSchoolSectionsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS school_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        school_id INTEGER NOT NULL,
        class_name TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL COLLATE NOCASE,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE CASCADE,
        UNIQUE (school_id, class_name, name)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_school_sections_school '
      'ON school_sections (school_id, class_name, sort_order)',
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
        education_year INTEGER NOT NULL,
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
        education_year INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (education_year, year, month, section_key)
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

  /// Sürüm 18 ve 20'de boşa düşen öğrenci yabancı anahtarlarını onarır.
  ///
  /// `ALTER TABLE students RENAME TO students_legacy` çalıştırıldığında
  /// SQLite, diğer tabloların `students` atıflarını da yeni tablo adına
  /// yazar. Eski tablo silinince bu atıflar var olmayan bir tabloya
  /// döner ve o tablolara kayıt eklemek "no such table" hatasıyla
  /// başarısız olur. Etkilenen tablolar: oda atamaları, etüt salonu
  /// atamaları, yoklama ve disiplin kayıtları.
  ///
  /// Tablolar yalnızca atıfları bozulduysa yeniden kurulur.
  Future<void> _repairStudentForeignKeys(Database db) async {
    const broken = <String, String>{
      'room_assignments': '''
      CREATE TABLE room_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        assigned_at TEXT NOT NULL,
        UNIQUE (student_id),
        FOREIGN KEY (room_id) REFERENCES boarding_rooms (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''',
      'study_room_assignments': '''
      CREATE TABLE study_room_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        study_room_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        assigned_at TEXT NOT NULL,
        UNIQUE (student_id),
        FOREIGN KEY (study_room_id) REFERENCES boarding_study_rooms (id)
          ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
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
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''',
      'student_discipline_incidents': '''
      CREATE TABLE student_discipline_incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        incident_date TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''',
    };

    final existing = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'table'",
    );
    final dangling = <String, String>{};
    for (final row in existing) {
      final name = row['name'] as String;
      final sql = (row['sql'] as String?) ?? '';
      if (broken.containsKey(name) && sql.contains('students_legacy')) {
        dangling[name] = sql;
      }
    }
    if (dangling.isEmpty) {
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    await db.execute('PRAGMA legacy_alter_table = 1');
    try {
      for (final name in dangling.keys) {
        await _rebuildWithStudentForeignKey(
          db,
          table: name,
          targetSql: broken[name]!,
        );
      }
      await _createIndexes(db);
    } finally {
      await db.execute('PRAGMA legacy_alter_table = 0');
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  /// Tabloyu yeniden adlandırıp doğru yabancı anahtarla yeniden kurar.
  ///
  /// `legacy_alter_table` açıkken yeniden adlandırma, diğer tabloların
  /// atıflarını yeniden yazmaz.
  Future<void> _rebuildWithStudentForeignKey(
    Database db, {
    required String table,
    required String targetSql,
  }) async {
    final legacyName = '${table}_fkfix';
    await db.execute('ALTER TABLE $table RENAME TO $legacyName');
    await db.execute(targetSql);
    final columns = await db.rawQuery("PRAGMA table_info('$legacyName')");
    final columnList = columns
        .map((row) => row['name'] as String)
        .where((name) => name != 'id')
        .toList();
    if (columnList.isNotEmpty) {
      final names = columnList.join(', ');
      await db.execute(
        'INSERT INTO $table (${columnList.join(', ')}) '
        'SELECT $names FROM $legacyName',
      );
    }
    await db.execute('DROP TABLE $legacyName');
  }

  /// Aile bilgilerini iki veli alanıyla değiştirir (sürüm 20).
  ///
  /// Anne/baba alanları kullanıcı talebiyle tamamen kaldırıldı; yerine ikinci
  /// veli için dört sütun eklendi. Mevcut birincil veli verisi korunur.
  ///
  /// `students` tablosu `duty_lists` ile aynı nedenle yeniden kurulur:
  /// silinen sütunlar birden fazla olduğundan sıralı düşürmek yerine temiz
  /// bir tablo kurmak daha güvenlidir.
  Future<void> _replaceFamilyFieldsWithGuardians(Database db) async {
    final existing = await db.rawQuery(
      "SELECT name FROM pragma_table_info('students') WHERE name = ?",
      ['guardian_is_other'],
    );
    if (existing.isEmpty) {
      await _addGuardian2Columns(db);
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    // legacy_alter_table açıkken yeniden adlandırma, diğer tabloların
    // `students` atıflarını yeni tablo adına yazmaz. Yazılırsa oda
    // ataması, yoklama ve disiplin kayıtları var olmayan tabloya
    // bağlanır ve ekleme işlemleri "no such table" ile başarısız olur.
    await db.execute('PRAGMA legacy_alter_table = 1');
    try {
      await db.execute('ALTER TABLE students RENAME TO students_legacy');
      await db.execute('''
        CREATE TABLE students (
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
          guardian_name TEXT,
          guardian_relation TEXT,
          guardian_phone TEXT,
          guardian_address TEXT,
          guardian2_name TEXT,
          guardian2_relation TEXT,
          guardian2_phone TEXT,
          guardian2_address TEXT,
          emergency_contact_name TEXT,
          emergency_contact_phone TEXT,
          boarding_registration_date TEXT,
          education_year INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO students (
          id, full_name, gender, national_id, school_id, class_name,
          section_name, school_number, birth_date, address, phone,
          has_chronic_disease, chronic_disease_details, has_allergy,
          allergy_details, regular_medication, blood_type,
          has_psychological_condition, psychological_condition_details,
          guardian_name, guardian_relation, guardian_phone, guardian_address,
          guardian2_name, guardian2_relation, guardian2_phone, guardian2_address,
          emergency_contact_name, emergency_contact_phone,
          boarding_registration_date, education_year, created_at, updated_at
        )
        SELECT
          id, full_name, gender, national_id, school_id, class_name,
          section_name, school_number, birth_date, address, phone,
          has_chronic_disease, chronic_disease_details, has_allergy,
          allergy_details, regular_medication, blood_type,
          has_psychological_condition, psychological_condition_details,
          guardian_name, guardian_relation, guardian_phone, guardian_address,
          NULL, NULL, NULL, NULL,
          emergency_contact_name, emergency_contact_phone,
          boarding_registration_date, education_year, created_at, updated_at
        FROM students_legacy
      ''');
      await db.execute('DROP TABLE students_legacy');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_students_school ON students (school_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_students_education_year '
        'ON students (education_year)',
      );
      await _createIndexes(db);
      await _addStudentUniquenessIndexes(db);
    } finally {
      await db.execute('PRAGMA legacy_alter_table = 0');

      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _addGuardian2Columns(Database db) async {
    for (final column in const [
      'guardian2_name',
      'guardian2_relation',
      'guardian2_phone',
      'guardian2_address',
    ]) {
      await _addColumnIfMissing(
        db,
        table: 'students',
        column: column,
        definition: 'TEXT',
      );
    }
  }

  /// Eğitim öğretim yılı tablosunu oluşturur.
  Future<void> _createEducationYearSchema(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS education_years (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      start_year INTEGER NOT NULL UNIQUE,
      is_active INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''');
  }

  /// İlk kurulumda bugünün eğitim öğretim yılını etkin olarak ekler.
  Future<void> _seedActiveEducationYear(Database db) async {
    final existing = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM education_years',
    );
    if (_countOf(existing) > 0) {
      return;
    }
    await db.insert('education_years', {
      'start_year': currentEducationYearStart(),
      'is_active': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  int _countOf(List<Map<String, Object?>> rows) {
    final value = rows.first.values.first;
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  /// Verileri eğitim öğretim yılına göre ayırır (sürüm 19).
  ///
  /// `education_years` tablosu oluşturulur ve içinde bugünün yılı etkin
  /// olarak eklenir. Öğrenci, öğretmen ve nöbet listesi tablolarına
  /// `education_year` sütunu eklenir; mevcut kayıtlar etkin yıla atanır.
  ///
  /// `duty_lists` benzersizlik kısıtı yılı da içerecek şekilde değiştiği
  /// için bu tablo yeniden kurulur.
  Future<void> _addEducationYearScope(Database db) async {
    final startYear = currentEducationYearStart();
    final now = DateTime.now().toUtc().toIso8601String();

    await db.execute('''
      CREATE TABLE IF NOT EXISTS education_years (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_year INTEGER NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'INSERT OR IGNORE INTO education_years '
      '(start_year, is_active, created_at) VALUES (?, 1, ?)',
      [startYear, now],
    );
    // İlk eklenen yıl etkindir; sonraki yıllar pasif açılır.
    await db.execute(
      'UPDATE education_years SET is_active = 0 WHERE start_year <> ?',
      [startYear],
    );

    await _addColumnIfMissing(
      db,
      table: 'students',
      column: 'education_year',
      definition: 'INTEGER NOT NULL DEFAULT $startYear',
    );
    await _addColumnIfMissing(
      db,
      table: 'duty_teachers',
      column: 'education_year',
      definition: 'INTEGER NOT NULL DEFAULT $startYear',
    );

    await db.update('students', {
      'education_year': startYear,
    }, where: 'education_year IS NULL');
    await db.update('duty_teachers', {
      'education_year': startYear,
    }, where: 'education_year IS NULL');

    await _rebuildDutyListsForEducationYear(db, startYear);

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_students_education_year '
      'ON students (education_year)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_duty_teachers_education_year '
      'ON duty_teachers (education_year)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_duty_lists_education_year '
      'ON duty_lists (education_year)',
    );
  }

  /// `duty_lists` tablosunu yıl kapsamıyla yeniden kurar.
  Future<void> _rebuildDutyListsForEducationYear(
    Database db,
    int startYear,
  ) async {
    final existing = await db.rawQuery(
      "SELECT name FROM pragma_table_info('duty_lists') WHERE name = ?",
      ['education_year'],
    );
    if (existing.isNotEmpty) {
      return;
    }

    await db.execute('ALTER TABLE duty_lists RENAME TO duty_lists_legacy');
    await db.execute('''
      CREATE TABLE duty_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        section_key TEXT NOT NULL,
        education_year INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (education_year, year, month, section_key)
      )
    ''');
    await db.execute(
      '''
      INSERT INTO duty_lists (year, month, section_key, education_year, created_at)
      SELECT year, month, section_key, ?, created_at FROM duty_lists_legacy
    ''',
      [startYear],
    );
    await db.execute('DROP TABLE duty_lists_legacy');
  }

  Future<void> _addStudentBloodTypeField(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'students',
      column: 'blood_type',
      definition: 'TEXT',
    );
  }

  /// Aile bilgilerini yeni akışa taşır (sürüm 18).
  ///
  /// `living_arrangement` ve `parents_live_together` sütunları `NOT NULL`
  /// olduğu için yalnızca yeni sütun eklemek yetmez: eski sütunlar kayıtta
  /// doldurulmayacağı için `students` tablosu yeniden kurulur. Mevcut
  /// `guardian_*`, `mother_*` ve `father_*` verileri yeni sütunlara taşınır;
  /// eski iki alanın değerleri kullanıcı talebiyle silinir.
  ///
  /// `student_attendance` ve `room_assignments` yabancı anahtarları
  /// `ON DELETE CASCADE` tanımlı olduğundan silme sırasında onları da
  /// korumak için yabancı anahtar denetimi geçici olarak kapatılır ve
  /// atamalar yeniden bağlanır.
  Future<void> _upgradeStudentFamilyFields(Database db) async {
    final existing = await db.rawQuery(
      "SELECT name FROM pragma_table_info('students') WHERE name = ?",
      ['mother_name'],
    );
    if (existing.isEmpty) {
      // Sütun yoksa şema zaten hedef hâlindedir.
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    // Bkz. sürüm 20 migrasyonundaki açıklama: yeniden adlandırma, diğer
    // tabloların `students` atıflarını bozmamalıdır.
    await db.execute('PRAGMA legacy_alter_table = 1');
    try {
      await db.execute('ALTER TABLE students RENAME TO students_legacy');
      await db.execute('''
        CREATE TABLE students (
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
          guardian_is_other INTEGER NOT NULL DEFAULT 0,
          guardian_name TEXT,
          guardian_relation TEXT,
          guardian_phone TEXT,
          guardian_address TEXT,
          guardian_occupation TEXT,
          guardian_education TEXT,
          guardian_birth_date TEXT,
          mother_name TEXT,
          mother_alive INTEGER NOT NULL DEFAULT 1,
          mother_is_biological INTEGER NOT NULL DEFAULT 1,
          mother_occupation TEXT,
          mother_education TEXT,
          mother_phone TEXT,
          mother_address TEXT,
          mother_has_separate_address INTEGER NOT NULL DEFAULT 0,
          father_name TEXT,
          father_alive INTEGER NOT NULL DEFAULT 1,
          father_is_biological INTEGER NOT NULL DEFAULT 1,
          father_occupation TEXT,
          father_education TEXT,
          father_phone TEXT,
          father_address TEXT,
          father_has_separate_address INTEGER NOT NULL DEFAULT 0,
          emergency_contact_name TEXT,
          emergency_contact_phone TEXT,
          boarding_registration_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (school_id) REFERENCES schools (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO students (
          id, full_name, gender, national_id, school_id, class_name,
          section_name, school_number, birth_date, address, phone,
          has_chronic_disease, chronic_disease_details, has_allergy,
          allergy_details, regular_medication, blood_type,
          has_psychological_condition, psychological_condition_details,
          guardian_is_other, guardian_name, guardian_relation, guardian_phone,
          guardian_address, guardian_occupation, guardian_education,
          guardian_birth_date, mother_name, mother_alive, mother_is_biological,
          mother_occupation, mother_education, mother_phone, mother_address,
          mother_has_separate_address, father_name, father_alive,
          father_is_biological, father_occupation, father_education,
          father_phone, father_address, father_has_separate_address,
          emergency_contact_name, emergency_contact_phone,
          boarding_registration_date, created_at, updated_at
        )
        SELECT
          id, full_name, gender, national_id, school_id, class_name,
          section_name, school_number, birth_date, address, phone,
          has_chronic_disease, chronic_disease_details, has_allergy,
          allergy_details, regular_medication, blood_type,
          has_psychological_condition, psychological_condition_details,
          0, guardian_name, guardian_relation, guardian_phone,
          NULL, NULL, NULL, NULL,
          mother_name, mother_alive, 1,
          NULL, NULL, mother_phone, NULL, 0,
          father_name, father_alive, 1,
          NULL, NULL, father_phone, NULL, 0,
          emergency_contact_name, emergency_contact_phone,
          boarding_registration_date, created_at, updated_at
        FROM students_legacy
      ''');
      await db.execute('DROP TABLE students_legacy');
      // students tablosuna bağlı index'ler tablo silinince kaybolur.
      // idx_students_school _createStudentSchema'ın sonunda, diğerleri
      // _createIndexes ve _addStudentUniquenessIndexes içinde oluşturulur;
      // hepsi IF NOT EXISTS kullandığı için yeniden çağırmak güvenlidir.
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_students_school ON students (school_id)',
      );
      await _createIndexes(db);
      await _addStudentUniquenessIndexes(db);
    } finally {
      await db.execute('PRAGMA legacy_alter_table = 0');
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _createStudentSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schools (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await _createSchoolSectionsSchema(db);
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
        guardian_name TEXT,
        guardian_relation TEXT,
        guardian_phone TEXT,
        guardian_address TEXT,
        guardian2_name TEXT,
        guardian2_relation TEXT,
        guardian2_phone TEXT,
        guardian2_address TEXT,
        emergency_contact_name TEXT,
        emergency_contact_phone TEXT,
        boarding_registration_date TEXT,
        education_year INTEGER NOT NULL,
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
    // Okul numarası artık benzersizlik kısıtı değildir (sürüm 22): tek
    // tekrar kuralı T.C. Kimlik No'dur. Yalnızca arama için kullanılır.
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
