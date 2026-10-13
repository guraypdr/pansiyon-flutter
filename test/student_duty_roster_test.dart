import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_roster.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

Student student(int id, String name) =>
    Student(id: id, fullName: name);

void main() {
  group('Oda sırasına göre sıralama', () {
    test('oda numarası küçükten büyüğe sıralanır', () {
      final list = [
        student(1, 'Zeynep'),
        student(2, 'Ali'),
        student(3, 'Ayşe'),
      ];
      // 3 -> oda 102, 1 -> oda 101, 2 -> oda 101
      final rooms = {1: 101, 2: 101, 3: 102};

      final sorted = sortStudentsByRoom(list, (s) => rooms[s.id]);

      // 101'deki iki öğrenci ada göre (Ali, Zeynep), ardından 102 (Ayşe).
      expect(sorted.map((s) => s.id), [2, 1, 3]);
    });

    test('odası olmayanlar en sona gelir', () {
      final list = [student(1, 'Odasız'), student(2, 'Odalı')];
      final rooms = {2: 205};

      final sorted = sortStudentsByRoom(list, (s) => rooms[s.id]);

      expect(sorted.map((s) => s.id), [2, 1]);
    });

    test('aynı odadaki öğrenciler ada göre sıralanır', () {
      final list = [student(1, 'Zeynep'), student(2, 'Ali')];
      final rooms = {1: 101, 2: 101};

      final sorted = sortStudentsByRoom(list, (s) => rooms[s.id]);

      expect(sorted.map((s) => s.fullName), ['Ali', 'Zeynep']);
    });
  });

  group('İkişer nöbet günü dağıtımı', () {
    test('her gün iki öğrenci yerleşir', () {
      final days = buildStudentDutyDays(
        studentIds: [1, 2, 3, 4],
        startDate: DateTime(2026, 10, 1),
      );

      expect(days.length, 2);
      expect(days[0].studentIds, [1, 2]);
      expect(days[1].studentIds, [3, 4]);
    });

    test('tek öğrenci kalırsa son gün tek kişilik olur', () {
      final days = buildStudentDutyDays(
        studentIds: [1, 2, 3],
        startDate: DateTime(2026, 10, 1),
      );

      expect(days.length, 2);
      expect(days[1].studentIds, [3]);
    });

    test('kapalı günler atlanır ve nöbetçiler kayar', () {
      final days = buildStudentDutyDays(
        studentIds: [1, 2, 3, 4],
        startDate: DateTime(2026, 10, 1),
        blackouts: {'2026-10-02'},
      );

      expect(days.length, 2);
      expect(days[0].studentIds, [1, 2]);
      // 2 Ekim kapalı olduğu için ikinci çift 3 Ekim'e kayar.
      expect(days[1].studentIds, [3, 4]);
    });

    test('art arda kapalı günler de atlanır', () {
      final days = buildStudentDutyDays(
        studentIds: [1, 2, 3, 4],
        startDate: DateTime(2026, 10, 1),
        blackouts: {'2026-10-02', '2026-10-03'},
      );

      expect(days.length, 2);
      expect(days[0].studentIds, [1, 2]);
      expect(days[1].studentIds, [3, 4]);
    });

    test('öğrenci yoksa gün de oluşmaz', () {
      final days = buildStudentDutyDays(
        studentIds: const [],
        startDate: DateTime(2026, 10, 1),
      );

      expect(days, isEmpty);
    });
  });

  group('Girdi üretimi', () {
    test('her öğrenci için sıra numaralı girdi yazılır', () {
      final entries = buildStudentDutyEntries(
        listId: 5,
        days: const [
          StudentDutyDay(sequence: 1, studentIds: [1, 2]),
          StudentDutyDay(sequence: 2, studentIds: [3]),
        ],
      );

      expect(entries.length, 3);
      expect(entries.every((e) => e.listId == 5), isTrue);
      expect(entries.first.sequence, 1);
      expect(entries.last.sequence, 2);
    });

    test('girdiler sıraya göre düzleştirilir', () {
      final entries = <StudentDutyEntry>[
        const StudentDutyEntry(listId: 1, sequence: 2, studentId: 3),
        const StudentDutyEntry(listId: 1, sequence: 1, studentId: 2),
        const StudentDutyEntry(listId: 1, sequence: 1, studentId: 1),
      ];

      expect(flattenStudentIds(entries), [1, 2, 3]);
    });
  });

  group('Arşivlenen öğrenci listeyi bir öne kaydırır', () {
    List<StudentDutyDay> build() => const [
          StudentDutyDay(sequence: 1, studentIds: [1, 2]),
          StudentDutyDay(sequence: 2, studentIds: [3, 4]),
          StudentDutyDay(sequence: 3, studentIds: [5, 6]),
          StudentDutyDay(sequence: 4, studentIds: [7, 8]),
        ];

    test('arşivlenen öğrenci listeden düşer', () {
      final compacted = compactStudentDutyDays(
        days: build(),
        archivedStudentIds: {3},
      );

      final ids = compacted.expand((day) => day.studentIds).toList();
      expect(ids, isNot(contains(3)));
    });

    test('kalan öğrenciler ikişerli yeniden paketlenir', () {
      final compacted = compactStudentDutyDays(
        days: build(),
        archivedStudentIds: {3},
      );

      expect(compacted.length, 4);
      expect(compacted[0].studentIds, [1, 2]);
      // 3 gittiği için 4 öne kayar ve 3. günün başına gelir.
      expect(compacted[1].studentIds, [4, 5]);
      expect(compacted[2].studentIds, [6, 7]);
      expect(compacted[3].studentIds, [8]);
    });

    test('gün sıraları 1 den başlayarak sıkışır', () {
      final compacted = compactStudentDutyDays(
        days: build(),
        archivedStudentIds: {3},
      );

      expect(compacted.map((day) => day.sequence), [1, 2, 3, 4]);
    });

    test('arşivlenen öğrenci yoksa liste değişmez', () {
      final original = build();

      final compacted = compactStudentDutyDays(
        days: original,
        archivedStudentIds: const {},
      );

      expect(compacted.length, original.length);
      expect(compacted[1].studentIds, [3, 4]);
    });

    test('listenin tamamı arşive düşerse liste boşalır', () {
      final compacted = compactStudentDutyDays(
        days: build(),
        archivedStudentIds: {1, 2, 3, 4, 5, 6, 7, 8},
      );

      expect(compacted, isEmpty);
    });

    test('iki öğrenci arşive düşerse bir gün eksilir', () {
      final compacted = compactStudentDutyDays(
        days: build(),
        archivedStudentIds: {5, 6},
      );

      expect(compacted.length, 3);
      expect(compacted[2].studentIds, [7, 8]);
    });
  });

  group('Tur istatistikleri', () {
    test('öğrenci ve gün sayısı hesaplanır', () {
      final list = StudentDutyList(
        startDate: DateTime(2026, 10, 1),
        entries: const [
          StudentDutyEntry(listId: 1, sequence: 1, studentId: 1),
          StudentDutyEntry(listId: 1, sequence: 1, studentId: 2),
          StudentDutyEntry(listId: 1, sequence: 2, studentId: 3),
        ],
      );

      expect(list.studentCount, 3);
      expect(list.dayCount, 2);
    });

    test('günler nöbetçilerle birlikte döner', () {
      final list = StudentDutyList(
        startDate: DateTime(2026, 10, 1),
        entries: const [
          StudentDutyEntry(listId: 1, sequence: 1, studentId: 2),
          StudentDutyEntry(listId: 1, sequence: 1, studentId: 1),
          StudentDutyEntry(listId: 1, sequence: 2, studentId: 3),
        ],
      );

      final days = list.days;
      expect(days.length, 2);
      expect(days.first.sequence, 1);
      expect(days.first.studentIds.length, 2);
      expect(days.last.studentIds, [3]);
    });
  });

  group('Tarih anahtarı', () {
    test('gg-aa-yyyy biçiminde anahtar üretir', () {
      expect(studentDutyDateKey(DateTime(2026, 9, 1)), '2026-09-01');
    });
  });
}