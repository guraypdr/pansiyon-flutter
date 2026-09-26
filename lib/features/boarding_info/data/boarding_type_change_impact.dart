import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

/// Pansiyon türü değişikliğinin mevcut veri üzerindeki etkisi.
class BoardingTypeChangeImpact {
  const BoardingTypeChangeImpact({
    required this.removedSections,
    required this.removedSectionRoomCount,
    required this.affectedAssignmentCount,
    required this.conflictingStudentCount,
  });

  final List<BoardingSection> removedSections;

  /// Yeni türe ait olmayan, silinecek oda sayısı.
  final int removedSectionRoomCount;

  /// Silinecek odalara yerleştirilmiş öğrenci ataması sayısı.
  final int affectedAssignmentCount;

  /// Yeni türle cinsiyet olarak uyuşmayan öğrenci sayısı.
  final int conflictingStudentCount;

  bool get needsConfirmation =>
      removedSectionRoomCount > 0 || conflictingStudentCount > 0;

  String get summary {
    final parts = <String>[];
    if (removedSectionRoomCount > 0) {
      parts.add(
        '$removedSectionRoomCount oda silinecek'
        '${affectedAssignmentCount > 0 ? ' ve bu odalara yerleştirilmiş '
                  '$affectedAssignmentCount öğrencinin oda ataması kaldırılacak' : ''}.',
      );
    }
    if (conflictingStudentCount > 0) {
      parts.add(
        '$conflictingStudentCount öğrencinin cinsiyeti yeni pansiyon türüyle '
        'uyuşmuyor; bu öğrenciler kayıtlı kalır ve öğrenci ekranından '
        'düzenlenmelidir.',
      );
    }
    return parts.join(' ');
  }
}

/// Pansiyon türü değişikliğinin neyi etkilediğini analiz eder.
class BoardingTypeChangeAnalyzer {
  const BoardingTypeChangeAnalyzer(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<BoardingTypeChangeImpact> analyze({
    required BoardingType? nextType,
    required List<BoardingSection> removedSections,
  }) async {
    final database = await _appDatabase.database;
    var removedRoomCount = 0;
    var assignmentCount = 0;
    for (final section in removedSections) {
      final roomRows = await database.rawQuery(
        'SELECT COUNT(*) FROM boarding_rooms WHERE section = ?',
        [section.value],
      );
      removedRoomCount += _asInt(roomRows.first.values.first);
      final assignmentRows = await database.rawQuery(
        'SELECT COUNT(*) FROM room_assignments a '
        'JOIN boarding_rooms r ON r.id = a.room_id WHERE r.section = ?',
        [section.value],
      );
      assignmentCount += _asInt(assignmentRows.first.values.first);
    }

    var conflictingStudents = 0;
    final conflictingGender = switch (nextType) {
      BoardingType.girls => 'male',
      BoardingType.boys => 'female',
      BoardingType.mixed || null => null,
    };
    if (conflictingGender != null) {
      final studentRows = await database.rawQuery(
        'SELECT COUNT(*) FROM students WHERE gender = ?',
        [conflictingGender],
      );
      conflictingStudents = _asInt(studentRows.first.values.first);
    }

    return BoardingTypeChangeImpact(
      removedSections: removedSections,
      removedSectionRoomCount: removedRoomCount,
      affectedAssignmentCount: assignmentCount,
      conflictingStudentCount: conflictingStudents,
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
