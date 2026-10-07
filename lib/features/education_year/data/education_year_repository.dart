import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show ConflictAlgorithm;
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';

/// Eğitim öğretim yıllarını yönetir.
abstract interface class EducationYearRepository {
  /// Tanımlı yıllar, yeniden eskiye.
  Future<List<EducationYear>> getYears();

  /// Kullanımda olan yıl. Hiç yıl yoksa `null`.
  Future<EducationYear?> getActiveYear();

  /// Yeni yıl oluşturur. Veriler kopyalanmaz; yıl boş başlar.
  Future<EducationYear> createYear(int startYear);

  /// Verilen yılı etkinleştirir; diğerleri pasifleşir.
  Future<void> setActiveYear(int startYear);

  /// Verilen yılı siler.
  ///
  /// Etkin yıl silinemez; en az bir yıl kalmalıdır.
  Future<void> deleteYear(int startYear);

  /// Öğrenci, öğretmen ve nöbet listesi sayılarıyla birlikte yıl özeti.
  Future<EducationYearSummary> loadSummary(int startYear);
}

/// Bir yılın içerik sayıları.
class EducationYearSummary {
  const EducationYearSummary({
    required this.year,
    required this.studentCount,
    required this.teacherCount,
    required this.dutyListCount,
  });

  final EducationYear year;
  final int studentCount;
  final int teacherCount;
  final int dutyListCount;

  bool get isEmpty => studentCount == 0 && teacherCount == 0;
}

class SqliteEducationYearRepository implements EducationYearRepository {
  SqliteEducationYearRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<EducationYear>> getYears() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'education_years',
      orderBy: 'start_year DESC',
    );
    return rows.map(_yearFromRow).toList(growable: false);
  }

  @override
  Future<EducationYear?> getActiveYear() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'education_years',
      where: 'is_active = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : _yearFromRow(rows.first);
  }

  @override
  Future<EducationYear> createYear(int startYear) async {
    final database = await _appDatabase.database;
    await database.insert('education_years', {
      'start_year': startYear,
      'is_active': 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final years = await getYears();
    return years.firstWhere((year) => year.startYear == startYear);
  }

  @override
  Future<void> setActiveYear(int startYear) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.update('education_years', {'is_active': 0});
      await transaction.update(
        'education_years',
        {'is_active': 1},
        where: 'start_year = ?',
        whereArgs: [startYear],
      );
    });
  }

  @override
  Future<void> deleteYear(int startYear) async {
    final database = await _appDatabase.database;
    final active = await getActiveYear();
    if (active != null && active.startYear == startYear) {
      throw StateError('Kullanımda olan eğitim öğretim yılı silinemez.');
    }
    await database.transaction((transaction) async {
      await transaction.delete(
        'students',
        where: 'education_year = ?',
        whereArgs: [startYear],
      );
      await transaction.delete(
        'duty_teachers',
        where: 'education_year = ?',
        whereArgs: [startYear],
      );
      await transaction.delete(
        'duty_lists',
        where: 'education_year = ?',
        whereArgs: [startYear],
      );
      await transaction.delete(
        'education_years',
        where: 'start_year = ?',
        whereArgs: [startYear],
      );
    });
  }

  @override
  Future<EducationYearSummary> loadSummary(int startYear) async {
    final database = await _appDatabase.database;
    Future<int> count(String table) async {
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS total FROM $table WHERE education_year = ?',
        [startYear],
      );
      return _asInt(rows.first.values.first);
    }

    return EducationYearSummary(
      year: EducationYear(startYear: startYear),
      studentCount: await count('students'),
      teacherCount: await count('duty_teachers'),
      dutyListCount: await count('duty_lists'),
    );
  }

  EducationYear _yearFromRow(Map<String, Object?> row) {
    return EducationYear(
      id: row['id'] as int?,
      startYear: row['start_year'] as int,
      isActive: (row['is_active'] as int? ?? 0) == 1,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
