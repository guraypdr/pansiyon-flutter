import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/education_year/data/education_year_scope.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract interface class DutyRepository {
  Future<List<DutyTeacher>> getTeachers({
    bool onlyActive = false,
    int? educationYear,
  });

  Future<int> saveTeacher(DutyTeacher teacher);

  Future<void> deleteTeacher(int id);

  /// Öğretmenleri verilen eğitim öğretim yılına taşır.
  ///
  /// Dönen değer taşınan öğretmen sayısıdır.
  Future<int> transferTeachers({
    required List<int> teacherIds,
    required int educationYear,
  });

  /// Bölüm bazında ortak nöbet ayarları (kapalı günler dahil).
  Future<DutySettings> getSettings(String? sectionKey);

  Future<void> saveSettings(DutySettings settings);

  /// Ay için pasif öğretmenler (bölüm bazında).
  Future<Set<int>> getMonthOffTeacherIds({
    required int year,
    required int month,
    String? sectionKey,
  });

  Future<void> saveMonthOffTeacherIds({
    required int year,
    required int month,
    String? sectionKey,
    required Set<int> teacherIds,
  });

  /// Ay listesi oluşturur; 	rue dönerse liste zaten vardı.
  Future<bool> createMonthList({
    required int year,
    required int month,
    String? sectionKey,
  });

  Future<List<DutyMonthList>> getMonthLists({int? year, int? educationYear});

  Future<List<DutyAssignment>> getAssignments({
    required int year,
    required int month,
    String? sectionKey,
  });

  /// Yıl içindeki tüm nöbet atamaları (istatistikler için).
  Future<List<DutyAssignment>> getYearAssignments(int year);

  Future<void> replaceAssignments({
    required int year,
    required int month,
    String? sectionKey,
    required List<DutyAssignment> assignments,
  });

  Future<void> deleteMonthList({
    required int year,
    required int month,
    String? sectionKey,
  });
}

const _noSection = '';

class SqliteDutyRepository implements DutyRepository {
  SqliteDutyRepository(this._appDatabase, {EducationYearScope? yearScope})
    : _yearScope = yearScope ?? EducationYearScope(_appDatabase);

  final AppDatabase _appDatabase;
  final EducationYearScope _yearScope;

  @override
  Future<List<DutyTeacher>> getTeachers({
    bool onlyActive = false,
    int? educationYear,
  }) async {
    final database = await _appDatabase.database;
    final year = educationYear ?? await _yearScope.activeYear();
    final rows = await database.query(
      'duty_teachers',
      where: onlyActive
          ? 'is_active = 1 AND education_year = ?'
          : 'education_year = ?',
      whereArgs: [year],
      orderBy: 'full_name COLLATE NOCASE',
    );
    return rows.map(_teacherFromRow).toList(growable: false);
  }

  DutyTeacher _teacherFromRow(Map<String, Object?> row) {
    return DutyTeacher(
      id: row['id'] as int,
      fullName: formatDutyTeacherName(row['full_name'] as String),
      nationalId: row['national_id'] as String?,
      phone: _formatPhone(row['phone']),
      school: row['school'] as String?,
      branch: row['branch'] as String?,
      hasDutyTraining: (row['has_duty_training'] as int) == 1,
      dutyPreference: DutyPreferenceLabel.fromValue(
        row['duty_preference'] as String?,
      ),
      availableWeekdays: _parseWeekdays(row['available_weekdays'] as String?),
      isActive: (row['is_active'] as int) == 1,
      educationYear: row['education_year'] as int?,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }

  @override
  Future<int> saveTeacher(DutyTeacher teacher) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      'full_name': formatDutyTeacherName(teacher.fullName),
      'national_id': _nullableText(teacher.nationalId),
      'phone': _nullableText(teacher.phone),
      'school': _nullableText(teacher.school),
      'branch': _nullableText(teacher.branch),
      'has_duty_training': teacher.hasDutyTraining ? 1 : 0,
      'duty_preference': teacher.dutyPreference.value,
      'available_weekdays': _formatWeekdays(teacher.availableWeekdays),
      'is_active': teacher.isActive ? 1 : 0,
      'updated_at': now,
    };
    if (teacher.id == null) {
      return database.insert('duty_teachers', {
        ...values,
        'created_at': now,
        // Yeni öğretmen etkin yıla eklenir.
        'education_year':
            teacher.educationYear ?? await _yearScope.activeYear(),
      });
    }
    return database.update(
      'duty_teachers',
      values,
      where: 'id = ?',
      whereArgs: [teacher.id],
    );
  }

  @override
  Future<int> transferTeachers({
    required List<int> teacherIds,
    required int educationYear,
  }) async {
    if (teacherIds.isEmpty) {
      return 0;
    }
    final database = await _appDatabase.database;
    final placeholders = List.filled(teacherIds.length, '?').join(', ');
    return database.update(
      'duty_teachers',
      {'education_year': educationYear},
      where: 'id IN ($placeholders)',
      whereArgs: teacherIds,
    );
  }

  @override
  Future<void> deleteTeacher(int id) async {
    final database = await _appDatabase.database;
    await database.delete('duty_teachers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<DutySettings> getSettings(String? sectionKey) async {
    final database = await _appDatabase.database;
    final key = sectionKey ?? _noSection;
    final rows = await database.query(
      'duty_settings',
      where: 'section_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return DutySettings(sectionKey: sectionKey);
    }
    final row = rows.first;
    final locations = await database.query(
      'duty_settings_locations',
      where: 'section_key = ?',
      whereArgs: [key],
      orderBy: 'sort_order',
    );
    final blackouts = await database.query(
      'duty_blackouts',
      where: 'section_key = ?',
      whereArgs: [key],
    );
    return DutySettings(
      sectionKey: sectionKey,
      dailyCount: row['daily_count'] as int,
      maxConsecutive: row['max_consecutive'] as int,
      locations: [for (final item in locations) item['label'] as String],
      blackouts: {
        for (final item in blackouts) item['blackout_date'] as String,
      },
    );
  }

  @override
  Future<void> saveSettings(DutySettings settings) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final key = settings.sectionKey ?? _noSection;
    await database.transaction((txn) async {
      final existing = await txn.query(
        'duty_settings',
        where: 'section_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('duty_settings', {
          'section_key': key,
          'daily_count': settings.dailyCount,
          'max_consecutive': settings.maxConsecutive,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          'duty_settings',
          {
            'daily_count': settings.dailyCount,
            'max_consecutive': settings.maxConsecutive,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }

      await txn.delete(
        'duty_settings_locations',
        where: 'section_key = ?',
        whereArgs: [key],
      );
      for (var index = 0; index < settings.locations.length; index++) {
        await txn.insert('duty_settings_locations', {
          'section_key': key,
          'label': settings.locations[index].trim(),
          'sort_order': index,
        });
      }

      await txn.delete(
        'duty_blackouts',
        where: 'section_key = ?',
        whereArgs: [key],
      );
      for (final blackout in settings.blackouts) {
        await txn.insert('duty_blackouts', {
          'section_key': key,
          'blackout_date': blackout,
          'reason': null,
        });
      }
    });
  }

  @override
  Future<Set<int>> getMonthOffTeacherIds({
    required int year,
    required int month,
    String? sectionKey,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'duty_month_teacher_off',
      where: 'year = ? AND month = ? AND section_key = ?',
      whereArgs: [year, month, sectionKey ?? _noSection],
    );
    return {for (final row in rows) row['teacher_id'] as int};
  }

  @override
  Future<void> saveMonthOffTeacherIds({
    required int year,
    required int month,
    String? sectionKey,
    required Set<int> teacherIds,
  }) async {
    final database = await _appDatabase.database;
    final key = sectionKey ?? _noSection;
    await database.transaction((txn) async {
      await txn.delete(
        'duty_month_teacher_off',
        where: 'year = ? AND month = ? AND section_key = ?',
        whereArgs: [year, month, key],
      );
      for (final teacherId in teacherIds) {
        await txn.insert('duty_month_teacher_off', {
          'year': year,
          'month': month,
          'section_key': key,
          'teacher_id': teacherId,
        });
      }
    });
  }

  @override
  Future<bool> createMonthList({
    required int year,
    required int month,
    String? sectionKey,
  }) async {
    final database = await _appDatabase.database;
    final key = sectionKey ?? _noSection;
    // Liste, ait olduğu eğitim öğretim yılında saklanır.
    final educationYear = educationYearStartOfMonth(year, month);
    final existing = await database.query(
      'duty_lists',
      where:
          'education_year = ? AND year = ? AND month = ? AND section_key = ?',
      whereArgs: [educationYear, year, month, key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return true;
    }
    await database.insert('duty_lists', {
      'year': year,
      'month': month,
      'section_key': key,
      'education_year': educationYear,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return false;
  }

  @override
  Future<List<DutyMonthList>> getMonthLists({
    int? year,
    int? educationYear,
  }) async {
    final database = await _appDatabase.database;
    final scope = educationYear ?? await _yearScope.activeYear();
    final conditions = <String>['l.education_year = ?'];
    final parameters = <Object?>[scope];
    if (year != null) {
      conditions.add('l.year = ?');
      parameters.add(year);
    }
    final rows = await database.rawQuery('''
      SELECT l.year, l.month, l.section_key,
             (SELECT COUNT(*) FROM duty_assignments a
               WHERE a.year = l.year AND a.month = l.month
                 AND a.section_key = l.section_key) AS total
      FROM duty_lists l
      WHERE ${conditions.join(' AND ')}
      ORDER BY l.year DESC, l.month DESC, l.section_key
    ''', parameters);
    return [
      for (final row in rows)
        DutyMonthList(
          year: row['year'] as int,
          month: row['month'] as int,
          sectionKey: (row['section_key'] as String?) == _noSection
              ? null
              : row['section_key'] as String,
          assignmentCount: row['total'] as int,
        ),
    ];
  }

  @override
  Future<List<DutyAssignment>> getAssignments({
    required int year,
    required int month,
    String? sectionKey,
  }) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'duty_assignments',
      where: 'year = ? AND month = ? AND section_key = ?',
      whereArgs: [year, month, sectionKey ?? _noSection],
      orderBy: 'duty_date, id',
    );
    return [
      for (final row in rows)
        DutyAssignment(
          id: row['id'] as int,
          year: row['year'] as int,
          month: row['month'] as int,
          date: DateTime.parse(row['duty_date'] as String),
          teacherId: row['teacher_id'] as int,
          location: row['location'] as String?,
        ),
    ];
  }

  @override
  Future<List<DutyAssignment>> getYearAssignments(int year) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'duty_assignments',
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'duty_date',
    );
    return [
      for (final row in rows)
        DutyAssignment(
          id: row['id'] as int,
          year: row['year'] as int,
          month: row['month'] as int,
          date: DateTime.parse(row['duty_date'] as String),
          teacherId: row['teacher_id'] as int,
          location: row['location'] as String?,
        ),
    ];
  }

  @override
  Future<void> replaceAssignments({
    required int year,
    required int month,
    String? sectionKey,
    required List<DutyAssignment> assignments,
  }) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final key = sectionKey ?? _noSection;
    await database.transaction((txn) async {
      await txn.delete(
        'duty_assignments',
        where: 'year = ? AND month = ? AND section_key = ?',
        whereArgs: [year, month, key],
      );
      await txn.insert('duty_lists', {
        'year': year,
        'month': month,
        'section_key': key,
        'education_year': educationYearStartOfMonth(year, month),
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      for (final assignment in assignments) {
        await txn.insert('duty_assignments', {
          'year': year,
          'month': month,
          'duty_date': dutyDateKey(assignment.date),
          'teacher_id': assignment.teacherId,
          'section_key': key,
          'location': _nullableText(assignment.location),
          'created_at': now,
        });
      }
    });
  }

  @override
  Future<void> deleteMonthList({
    required int year,
    required int month,
    String? sectionKey,
  }) async {
    final database = await _appDatabase.database;
    final key = sectionKey ?? _noSection;
    await database.delete(
      'duty_assignments',
      where: 'year = ? AND month = ? AND section_key = ?',
      whereArgs: [year, month, key],
    );
    await database.delete(
      'duty_lists',
      where:
          'education_year = ? AND year = ? AND month = ? AND section_key = ?',
      whereArgs: [educationYearStartOfMonth(year, month), year, month, key],
    );
  }

  String _formatWeekdays(List<int> weekdays) {
    final sorted = weekdays.toSet().toList()..sort();
    return sorted.isEmpty ? '' : sorted.join(',');
  }

  List<int> _parseWeekdays(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    return [for (final part in value.split(',')) ?int.tryParse(part.trim())];
  }

  String? _formatPhone(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : formatPhoneNumber(text);
  }

  String? _nullableText(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
