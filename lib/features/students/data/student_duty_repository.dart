import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_roster.dart';

/// Öğrenci nöbet listelerinin kalıcı saklanması.
abstract interface class StudentDutyRepository {
  /// Son oluşturulan tur; henüz tur yoksa `null`.
  ///
  /// Her zaman en eski tur döner: nöbet listesi oluşturulduktan sonra bitince
  /// sıradaki tur bu listenin devamıdır.
  Future<StudentDutyList?> getCurrentList();

  /// Yeni bir tur oluşturur.
  Future<StudentDutyList> createList({required DateTime startDate});

  /// Mevcut turun girdilerini verilen günlerle tamamen değiştirir.
  Future<void> replaceEntries({
    required int listId,
    required List<StudentDutyDay> days,
  });

  /// Turu siler.
  Future<void> deleteList(int listId);

  /// Kapalı günlerin anahtarlarını okur (`yyyy-MM-dd`).
  Future<Set<String>> getBlackouts();

  /// Kapalı günleri verilen anahtarlarla tamamen değiştirir.
  Future<void> saveBlackouts(Set<String> blackoutKeys);

  /// Arşivlenen öğrenciler listeden düşer ve kalan öğrenciler ikişerli
  /// yeniden paketlenir.
  ///
  /// [allArchivedStudentIds] pansiyondan ayrılmış tüm öğrencileri içerir;
  /// düşen öğrenciden sonraki herkes bir gün öne kayar.
  Future<void> removeArchivedStudents(Set<int> allArchivedStudentIds);
}

class SqliteStudentDutyRepository implements StudentDutyRepository {
  SqliteStudentDutyRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<StudentDutyList?> getCurrentList() async {
    final database = await _appDatabase.database;
    final listRows = await database.query(
      'student_duty_lists',
      orderBy: 'id ASC',
      limit: 1,
    );
    if (listRows.isEmpty) {
      return null;
    }
    final row = listRows.first;
    final listId = row['id'] as int;
    final entryRows = await database.query(
      'student_duty_entries',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'sequence ASC, student_id ASC',
    );
    return StudentDutyList(
      id: listId,
      startDate: _parseDateOnly(row['start_date'] as String?),
      entries: [
        for (final entry in entryRows)
          StudentDutyEntry(
            id: entry['id'] as int?,
            listId: listId,
            sequence: entry['sequence'] as int,
            studentId: entry['student_id'] as int,
          ),
      ],
      createdAt: _parseDateTime(row['created_at'] as String?),
      updatedAt: _parseDateTime(row['updated_at'] as String?),
    );
  }

  @override
  Future<StudentDutyList> createList({required DateTime startDate}) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await database.insert('student_duty_lists', {
      'start_date': _dateOnly(startDate),
      'created_at': now,
      'updated_at': now,
    });
    return StudentDutyList(
      id: id,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      entries: const [],
      createdAt: DateTime.tryParse(now),
      updatedAt: DateTime.tryParse(now),
    );
  }

  @override
  Future<void> replaceEntries({
    required int listId,
    required List<StudentDutyDay> days,
  }) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.delete(
        'student_duty_entries',
        where: 'list_id = ?',
        whereArgs: [listId],
      );
      final batch = transaction.batch();
      for (final day in days) {
        for (final studentId in day.studentIds) {
          batch.insert('student_duty_entries', {
            'list_id': listId,
            'sequence': day.sequence,
            'student_id': studentId,
            'created_at': now,
          });
        }
      }
      await batch.commit(noResult: true);
      await transaction.update(
        'student_duty_lists',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [listId],
      );
    });
  }

  @override
  Future<void> deleteList(int listId) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'student_duty_entries',
        where: 'list_id = ?',
        whereArgs: [listId],
      );
      await transaction.delete(
        'student_duty_lists',
        where: 'id = ?',
        whereArgs: [listId],
      );
    });
  }

  @override
  Future<Set<String>> getBlackouts() async {
    final database = await _appDatabase.database;
    final rows = await database.query('student_duty_blackouts');
    return {
      for (final row in rows) row['blackout_date'] as String,
    };
  }

  @override
  Future<void> saveBlackouts(Set<String> blackoutKeys) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.delete('student_duty_blackouts');
      final batch = transaction.batch();
      for (final key in blackoutKeys) {
        batch.insert('student_duty_blackouts', {
          'blackout_date': key,
          'reason': null,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> removeArchivedStudents(Set<int> allArchivedStudentIds) async {
    final database = await _appDatabase.database;
    final listRows = await database.query(
      'student_duty_lists',
      orderBy: 'id ASC',
    );
    if (listRows.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final listRow in listRows) {
        final listId = listRow['id'] as int;
        final entryRows = await transaction.query(
          'student_duty_entries',
          where: 'list_id = ?',
          whereArgs: [listId],
          orderBy: 'sequence ASC, student_id ASC',
        );
        final days = _groupIntoDays(entryRows);
        final compacted = compactStudentDutyDays(
          days: days,
          // Yalnızca gerçekten arşivlenenler düşer; listede kalmış eski
          // arşiv kayıtları da bu arada temizlenir.
          archivedStudentIds: allArchivedStudentIds,
        );

        // Sıkıştırma bir şey değiştirmediyse yazmaya gerek yok.
        if (_sameStudentIds(days, compacted)) {
          continue;
        }

        await transaction.delete(
          'student_duty_entries',
          where: 'list_id = ?',
          whereArgs: [listId],
        );
        final batch = transaction.batch();
        for (final day in compacted) {
          for (final id in day.studentIds) {
            batch.insert('student_duty_entries', {
              'list_id': listId,
              'sequence': day.sequence,
              'student_id': id,
              'created_at': now,
            });
          }
        }
        await batch.commit(noResult: true);
        await transaction.update(
          'student_duty_lists',
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [listId],
        );
      }
    });
  }

  /// Satırları `sequence` numarasına göre nöbet günlerine dönüştürür.
  List<StudentDutyDay> _groupIntoDays(List<Map<String, Object?>> rows) {
    final bySequence = <int, List<int>>{};
    for (final row in rows) {
      bySequence
          .putIfAbsent(row['sequence'] as int, () => <int>[])
          .add(row['student_id'] as int);
    }
    final sequences = bySequence.keys.toList()..sort();
    return [
      for (final sequence in sequences)
        StudentDutyDay(
          sequence: sequence,
          studentIds: bySequence[sequence]!,
        ),
    ];
  }

  /// İki gün listesinin öğrenci kimlikleri aynı sırada mı?
  bool _sameStudentIds(List<StudentDutyDay> a, List<StudentDutyDay> b) {
    final flatA = _flatIds(a);
    final flatB = _flatIds(b);
    if (flatA.length != flatB.length) {
      return false;
    }
    for (var index = 0; index < flatA.length; index++) {
      if (flatA[index] != flatB[index]) {
        return false;
      }
    }
    return true;
  }

  List<int> _flatIds(List<StudentDutyDay> days) =>
      [for (final day in days) ...day.studentIds];
}

String _dateOnly(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _parseDateOnly(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) {
    return DateTime.now();
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime? _parseDateTime(String? value) => DateTime.tryParse(value ?? '');