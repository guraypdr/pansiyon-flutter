/// Öğrenci nöbeti için domain modelleri.
///
/// Nöbet listesi ay bazında tutulmaz: bir liste (tur) seçilen başlangıç
/// tarihinden itibaren ilerler ve tüm öğrenciler bir kez görev alıp liste
/// bittiğinde yeni bir tur başlatılır.
library;

/// Nöbet günü başına düşen öğrenci sayısı.
///
/// Her gün iki öğrenci görev alır; son gün tek öğrenci kalabilir.
const int studentDutyDailyCount = 2;

/// Bir öğrencinin nöbet girdisi.
///
/// Nöbet günü `sequence` (1 tabanlı sıra) ile belirlenir; aynı güne düşen iki
/// öğrenci aynı `sequence` değerini taşır.
class StudentDutyEntry {
  const StudentDutyEntry({
    this.id,
    required this.listId,
    required this.sequence,
    required this.studentId,
  });

  final int? id;
  final int listId;

  /// Nöbet gününün sırası, 1'den başlar.
  final int sequence;

  final int studentId;

  StudentDutyEntry copyWith({int? id, int? listId, int? sequence, int? studentId}) {
    return StudentDutyEntry(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      sequence: sequence ?? this.sequence,
      studentId: studentId ?? this.studentId,
    );
  }
}

/// Bir nöbet turu.
class StudentDutyList {
  const StudentDutyList({
    this.id,
    required this.startDate,
    required this.entries,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;

  /// Listenin ilk nöbet günü.
  final DateTime startDate;

  /// Turdaki tüm öğrenci girdileri; `sequence` sırasına göre saklanır.
  final List<StudentDutyEntry> entries;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Turdaki benzersiz öğrenci sayısı.
  int get studentCount => entries.map((entry) => entry.studentId).toSet().length;

  /// Turdaki nöbet günü sayısı.
  int get dayCount {
    if (entries.isEmpty) {
      return 0;
    }
    return entries.map((entry) => entry.sequence).reduce((a, b) => a > b ? a : b);
  }

  bool get isEmpty => entries.isEmpty;

  /// Nöbet günlerini öğrenci çiftleriyle döndürür.
  ///
  /// Her gün [studentDutyDailyCount] öğrenci döner; son gün tek öğrenciyle
  /// bitebilir.
  List<StudentDutyDay> get days {
    final bySequence = <int, List<int>>{};
    for (final entry in entries) {
      bySequence.putIfAbsent(entry.sequence, () => <int>[]).add(entry.studentId);
    }
    final sequences = bySequence.keys.toList()..sort();
    return [
      for (final sequence in sequences)
        StudentDutyDay(sequence: sequence, studentIds: bySequence[sequence]!),
    ];
  }
}

/// Bir nöbet günü ve o gün görev alan öğrenciler.
class StudentDutyDay {
  const StudentDutyDay({required this.sequence, required this.studentIds});

  /// Nöbet gününün sırası, 1'den başlar.
  final int sequence;

  /// O gün görev alan öğrenci kimlikleri, sıralı.
  final List<int> studentIds;
}

/// Nöbet günü anahtarı: `yyyy-MM-dd`.
String studentDutyDateKey(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}