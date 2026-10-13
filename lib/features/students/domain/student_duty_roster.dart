import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

/// Nöbet dağıtımı için saf hesaplama yardımcıları.
///
/// Bu dosya veritabanına ve arayüze bağımlı değildir; oda sırasına göre
/// sıralama, ikişer gruplama ve arşivden düşen öğrencilere göre listenin
/// yeniden paketlenmesi burada yapılır.

/// Öğrencileri oda numarası sırasına göre sıralar.
///
/// Odası olmayan öğrenciler en sona gelir. Aynı odadaki öğrenciler ad
/// sırasına göre dizilir.
List<Student> sortStudentsByRoom(
  List<Student> students,
  int? Function(Student student) roomNumberOf,
) {
  final sorted = [...students];
  sorted.sort((a, b) {
    final roomA = roomNumberOf(a);
    final roomB = roomNumberOf(b);
    // Odası olmayanlar en sona.
    if (roomA == null && roomB == null) {
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    }
    if (roomA == null) return 1;
    if (roomB == null) return -1;
    final byRoom = roomA.compareTo(roomB);
    if (byRoom != 0) return byRoom;
    return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  });
  return sorted;
}

/// Sıralı öğrencileri ikişerli nöbet günlerine böler.
///
/// [startDate] ilk nöbet günüdür. [blackouts] içindeki günler atlanır ve
/// nöbetçiler bir sonraki güne kayar.
List<StudentDutyDay> buildStudentDutyDays({
  required List<int> studentIds,
  required DateTime startDate,
  Set<String> blackouts = const {},
}) {
  if (studentIds.isEmpty) {
    return const [];
  }

  final days = <StudentDutyDay>[];
  var sequence = 1;
  var cursor = DateTime(startDate.year, startDate.month, startDate.day);

  for (var index = 0; index < studentIds.length; index += studentDutyDailyCount) {
    final slice = studentIds.skip(index).take(studentDutyDailyCount).toList();
    // Kapalı günlere denk gelen nöbetler bir sonraki güre kayar.
    while (blackouts.contains(studentDutyDateKey(cursor))) {
      cursor = cursor.add(const Duration(days: 1));
    }
    days.add(StudentDutyDay(sequence: sequence, studentIds: slice));
    cursor = cursor.add(const Duration(days: 1));
    sequence++;
  }

  return days;
}

/// Bir tur için veri tabanına yazılacak girdileri üretir.
List<StudentDutyEntry> buildStudentDutyEntries({
  required int listId,
  required List<StudentDutyDay> days,
}) {
  final entries = <StudentDutyEntry>[];
  for (final day in days) {
    for (final studentId in day.studentIds) {
      entries.add(
        StudentDutyEntry(
          listId: listId,
          sequence: day.sequence,
          studentId: studentId,
        ),
      );
    }
  }
  return entries;
}

/// Bir turdaki öğrenci kimliklerini sıra numarasıyla döndürür.
///
/// Girdiler sıra sırasıyla düzleştirilir; her gün [studentDutyDailyCount]
/// öğrenci olacak şekilde okunur.
List<int> flattenStudentIds(List<StudentDutyEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) {
      final bySequence = a.sequence.compareTo(b.sequence);
      if (bySequence != 0) return bySequence;
      return a.studentId.compareTo(b.studentId);
    });
  return sorted.map((entry) => entry.studentId).toList();
}

/// Arşivlenen öğrenci listeden düştüğünde listeyi sıkıştırır.
///
/// Kayıtlı sıra içinde hâlâ arşivde olmayan öğrenciler korunur, düşenler
/// çıkarılır ve kalanlar baştan ikişerli paketlenerek yeniden numaralandırılır.
/// Böylece sonraki öğrenciler bir gün öne kayar.
List<StudentDutyDay> compactStudentDutyDays({
  required List<StudentDutyDay> days,
  required Set<int> archivedStudentIds,
}) {
  final keptIds = <int>[];
  for (final day in days) {
    for (final studentId in day.studentIds) {
      if (!archivedStudentIds.contains(studentId)) {
        keptIds.add(studentId);
      }
    }
  }
  if (keptIds.length == studentIdsLength(days)) {
    // Hiçbir öğrenci düşmediyse mevcut günleri koru.
    return days;
  }
  final compacted = <StudentDutyDay>[];
  var sequence = 1;
  for (var index = 0; index < keptIds.length; index += studentDutyDailyCount) {
    compacted.add(
      StudentDutyDay(
        sequence: sequence++,
        studentIds: keptIds.skip(index).take(studentDutyDailyCount).toList(),
      ),
    );
  }
  return compacted;
}

/// Günlerin toplam öğrenci sayısı.
int studentIdsLength(List<StudentDutyDay> days) =>
    days.fold(0, (sum, day) => sum + day.studentIds.length);