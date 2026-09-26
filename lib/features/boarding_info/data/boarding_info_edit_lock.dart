import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

/// Pansiyonda kayıt bulunup bulunmadığı.
class PansiyonUsageInfo {
  const PansiyonUsageInfo({
    required this.studentCount,
    required this.roomCount,
  });

  final int studentCount;
  final int roomCount;

  /// Kademe kilidi için ölçüt: öğrenci veya oda kaydı varsa kilitlenir.
  bool get hasData => studentCount > 0 || roomCount > 0;

  String get description {
    if (studentCount == 0 && roomCount == 0) {
      return 'Pansiyonda henüz öğrenci veya oda kaydı yok.';
    }
    if (studentCount > 0 && roomCount > 0) {
      return '$studentCount öğrenci ve $roomCount oda kaydı var.';
    }
    if (studentCount > 0) {
      return '$studentCount öğrenci kaydı var.';
    }
    return '$roomCount oda kaydı var.';
  }
}

enum BoardingInfoLockAction { allowed, blocked }

class BoardingInfoLockDecision {
  const BoardingInfoLockDecision._(this.action, this.message);

  factory BoardingInfoLockDecision.allowed() =>
      const BoardingInfoLockDecision._(BoardingInfoLockAction.allowed, null);

  factory BoardingInfoLockDecision.blocked(String message) =>
      BoardingInfoLockDecision._(BoardingInfoLockAction.blocked, message);

  final BoardingInfoLockAction action;
  final String? message;

  bool get isBlocked => action == BoardingInfoLockAction.blocked;
}

/// Kademe kilidini uygular.
///
/// Kural: pansiyonda öğrenci veya oda kaydı varsa kademe değiştirilemez.
/// Böylece öğrenci sınıfları ile pansiyon kademesi tutarlı kalır.
class BoardingInfoEditLock {
  const BoardingInfoEditLock(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<PansiyonUsageInfo> loadUsage() async {
    final database = await _appDatabase.database;
    final studentRows = await database.rawQuery(
      'SELECT COUNT(*) FROM students',
    );
    final roomRows = await database.rawQuery(
      'SELECT COUNT(*) FROM boarding_rooms',
    );
    return PansiyonUsageInfo(
      studentCount: _asInt(studentRows.first.values.first),
      roomCount: _asInt(roomRows.first.values.first),
    );
  }

  static BoardingInfoLockDecision decide({
    required PansiyonUsageInfo usage,
    required EducationLevel? storedLevel,
    required EducationLevel? nextLevel,
  }) {
    if (storedLevel == null || nextLevel == null || storedLevel == nextLevel) {
      return BoardingInfoLockDecision.allowed();
    }
    if (!usage.hasData) {
      return BoardingInfoLockDecision.allowed();
    }
    return BoardingInfoLockDecision.blocked(
      'Kademe değiştirilemez. ${usage.description} Kademeyi değiştirmek için '
      '"Yeni Pansiyon Oluştur" işlemini kullanın; yeni pansiyon boş olarak '
      'başlar ve mevcut veriler aktarılmaz.',
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
