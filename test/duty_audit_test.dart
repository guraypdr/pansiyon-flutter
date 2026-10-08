import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_distribution.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

DutyTeacher teacher(
  int id,
  DutyPreference preference, {
  List<int>? weekdays,
  bool active = true,
}) {
  return DutyTeacher(
    id: id,
    fullName: 'Öğretmen $id',
    dutyPreference: preference,
    availableWeekdays: weekdays ?? const [1, 2, 3, 4, 5],
    isActive: active,
  );
}

int totalFor(List<DutyAssignment> result, int teacherId) =>
    result.where((a) => a.teacherId == teacherId).length;

({List<DutyAssignment> assignments, int unfilled}) run(
  List<DutyTeacher> teachers,
  List<DateTime> dates, {
  int dailyCount = 2,
  int maxConsecutive = 2,
}) {
  final input = DutyDistributionInput(
    year: 2026,
    month: 9,
    teachers: teachers,
    dutyDates: dates,
    dailyCount: dailyCount,
    maxConsecutive: maxConsecutive,
  );
  final assignments = DutyDistribution.generate(input);
  return (
    assignments: assignments,
    unfilled: DutyDistribution.unfilledSlotCount(input, assignments),
  );
}

void main() {
  // Eylül 2026 hafta içi günleri (pazartesiler 7, 14, 21, 28 dahil).
  final september = <DateTime>[
    for (final day in const [
      1, 2, 3, 4, 7, 8, 9, 10, 11, 14, 15, 16, 17, 18,
      21, 22, 23, 24, 25, 28, 29, 30,
    ])
      DateTime(2026, 9, day),
  ];

  group('KURAL 2 - müsait olmayan güne atama yapılmaz', () {
    test('yalnızca pazartesi müsait olan öğretmenler sadece pazartesi alır', () {
      final result = run(
        [
          teacher(1, DutyPreference.maximum, weekdays: const [1]),
          teacher(2, DutyPreference.maximum, weekdays: const [1]),
          teacher(3, DutyPreference.maximum, weekdays: const [1]),
        ],
        september,
        dailyCount: 2,
      );

      expect(result.assignments, isNotEmpty);
      for (final assignment in result.assignments) {
        expect(assignment.date.weekday, 1, reason: 'pazartesi olmalı');
      }
    });

    test('pasif öğretmen hiç nöbet almaz', () {
      final result = run(
        [
          teacher(1, DutyPreference.maximum),
          teacher(2, DutyPreference.maximum, active: false),
        ],
        september,
      );
      expect(totalFor(result.assignments, 2), 0);
    });
  });

  group('KURAL 3 - her öğretmene istente bağlı olmadan 1 nöbet', () {
    test('yeterli yuva varken minimum isteyen de 1 nöbet alır', () {
      final result = run(
        [
          teacher(1, DutyPreference.minimum),
          teacher(2, DutyPreference.balanced),
          teacher(3, DutyPreference.maximum),
        ],
        september,
      );
      for (final id in const [1, 2, 3]) {
        expect(
          totalFor(result.assignments, id),
          greaterThanOrEqualTo(1),
          reason: 'öğretmen $id nöbet almadı',
        );
      }
    });

    test('çok öğretmen varken de herkes en az 1 nöbet alır', () {
      // 6 öğretmen, yeterli yuva.
      final result = run(
        [
          for (var id = 1; id <= 6; id++)
            teacher(id, DutyPreference.minimum),
        ],
        september,
      );
      for (var id = 1; id <= 6; id++) {
        expect(
          totalFor(result.assignments, id),
          greaterThanOrEqualTo(1),
          reason: 'öğretmen $id nöbet almadı',
        );
      }
    });

    test('bir günde müsait olan herkes ilk günlerde nöbet alır', () {
      // Öğretmen 2 yalnızca 1 Ekim'de müsait; o gün kapasitesi var.
      final result = run(
        [
          teacher(1, DutyPreference.maximum),
          teacher(2, DutyPreference.minimum, weekdays: const [5]),
        ],
        september,
        dailyCount: 2,
      );
      expect(totalFor(result.assignments, 2), greaterThanOrEqualTo(1));
    });
  });

  group('KURAL 4 - dengeli 4, maksimum 8 tırmanışı', () {
    test('yeterli öğretmen varken dağıtım boş yuva bırakmaz', () {
      // 8 öğretmen x 8 = 64 kapasite; 44 yuvanın tamamı dolar.
      final result = run(
        [
          for (var id = 1; id <= 8; id++) teacher(id, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      expect(result.unfilled, 0);
      expect(result.assignments.length, 44);
    });

    test('dengeli 4 ve maksimum 8 hedefine tam ulaşılır', () {
      // 3 dengeli (4'er) + 5 maksimum (8'er) = 52 nöbet.
      // Tam 52 yuva: 26 gün x 2. Böylece üçüncü aşama hiç çalışmaz ve
      // dengeli isteyenler tam olarak 4'te kalır.
      final dates = <DateTime>[
        ...september,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
      ];
      final teachers = <DutyTeacher>[
        for (var id = 1; id <= 3; id++) teacher(id, DutyPreference.balanced),
        for (var id = 4; id <= 8; id++) teacher(id, DutyPreference.maximum),
      ];

      final result = run(teachers, dates, dailyCount: 2);

      for (var id = 1; id <= 3; id++) {
        expect(
          totalFor(result.assignments, id),
          DutyDistributionInput.balancedTarget,
          reason: 'dengeli öğretmen $id tam 4 almalıydı',
        );
      }
      for (var id = 4; id <= 8; id++) {
        expect(
          totalFor(result.assignments, id),
          DutyDistributionInput.maximumMonthlyDuty,
          reason: 'maksimum öğretmen $id tam 8 almalıydı',
        );
      }
      expect(result.unfilled, 0);
    });
  });

  group('KURAL 5 - minimum isteyenler fazla yuvada sınırlı kalır', () {
    test('bol yuvada minimum isteyen 2 nöbeti geçmez', () {
      final result = run(
        [
          teacher(1, DutyPreference.minimum),
          teacher(2, DutyPreference.minimum),
          for (var id = 3; id <= 12; id++) teacher(id, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      for (final id in const [1, 2]) {
        expect(
          totalFor(result.assignments, id),
          lessThanOrEqualTo(DutyDistributionInput.minimumFinal),
          reason: 'minimum isteyen öğretmen $id fazla nöbet aldı',
        );
      }
    });
  });

  group('KURAL 6 - 8 nöbetlik sert sınır', () {
    test('hiçbir istek tipinde 8 i geçmez', () {
      for (final preference in DutyPreference.values) {
        final result = run(
          [
            for (var id = 1; id <= 5; id++) teacher(id, preference),
          ],
          september,
          dailyCount: 2,
        );
        for (var id = 1; id <= 5; id++) {
          expect(
            totalFor(result.assignments, id),
            lessThanOrEqualTo(DutyDistributionInput.maximumMonthlyDuty),
            reason: '$preference öğretmen $id 8 i geçti',
          );
        }
      }
    });

    test('az öğretmenle dağılım 8 i aşmaz', () {
      final result = run(
        [
          teacher(1, DutyPreference.maximum),
          teacher(2, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      expect(totalFor(result.assignments, 1), lessThanOrEqualTo(8));
      expect(totalFor(result.assignments, 2), lessThanOrEqualTo(8));
    });
  });

  group('KAPASİTE - boş yuva durumu', () {
    test('yeterli öğretmen varsa hiçbir yuva boş kalmaz', () {
      // 6 öğretmen x 8 = 48 kapasite, 22 gün x 2 = 44 yuva.
      final result = run(
        [
          for (var id = 1; id <= 6; id++) teacher(id, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      expect(result.unfilled, 0);
    });

    test('öğretmen az ise boş yuva sayısı hesaplanır ve 8 sınırı korunur', () {
      // 3 öğretmen x 8 = 24 kapasite, 44 yuva -> 20 yuva boş kalır.
      final result = run(
        [
          teacher(1, DutyPreference.balanced),
          teacher(2, DutyPreference.maximum),
          teacher(3, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      expect(result.assignments.length, 24);
      expect(result.unfilled, 20);
    });

    test('tek öğretmen günde 2 yuvayı dolduramaz, boş yuva sayılır', () {
      // 1 öğretmen, 1 gün, günde 2 nöbet: aynı güne iki kez atanamayacağı
      // için 1 yuva boş kalır. Bu doğru davranıştır.
      final input = DutyDistributionInput(
        year: 2026,
        month: 9,
        teachers: [teacher(1, DutyPreference.maximum)],
        dutyDates: september.take(1).toList(),
        dailyCount: 2,
      );
      final assignments = DutyDistribution.generate(input);
      expect(assignments, hasLength(1));
      expect(DutyDistribution.unfilledSlotCount(input, assignments), 1);
    });
  });

  group('Diğer davranışlar korunur', () {
    test('aynı güne aynı öğretmen iki kez atanmaz', () {
      final result = run(
        [
          for (var id = 1; id <= 6; id++) teacher(id, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      final seen = <String>{};
      for (final assignment in result.assignments) {
        final key = '${dutyDateKey(assignment.date)}-${assignment.teacherId}';
        expect(seen.add(key), isTrue, reason: 'aynı gün iki kez atanmış');
      }
    });

    test('günlük nöbet sayısı ayarı aşılmaz', () {
      final result = run(
        [
          for (var id = 1; id <= 6; id++) teacher(id, DutyPreference.maximum),
        ],
        september,
        dailyCount: 2,
      );
      final perDate = <String, int>{};
      for (final assignment in result.assignments) {
        final key = dutyDateKey(assignment.date);
        perDate[key] = (perDate[key] ?? 0) + 1;
      }
      for (final entry in perDate.entries) {
        expect(entry.value, lessThanOrEqualTo(2), reason: entry.key);
      }
    });

    test('konumlar nöbetçi sırasına göre dağıtılır', () {
      final input = DutyDistributionInput(
        year: 2026,
        month: 9,
        teachers: [
          for (var id = 1; id <= 6; id++) teacher(id, DutyPreference.maximum),
        ],
        dutyDates: september,
        locations: const ['Nöbetçi Odası', 'Giriş'],
        dailyCount: 2,
      );
      final assignments = DutyDistribution.generate(input);
      final firstSlot = assignments
          .where((a) => a.date == september.first)
          .toList();
      expect(firstSlot.length, 2);
      expect(firstSlot.map((a) => a.location).toSet(), {'Nöbetçi Odası', 'Giriş'});
    });

    test('öğretmen veya gün yoksa boş liste döner', () {
      expect(run([], september).assignments, isEmpty);
      expect(
        run([teacher(1, DutyPreference.maximum)], const []).assignments,
        isEmpty,
      );
      expect(
        run([teacher(1, DutyPreference.maximum)], september, dailyCount: 0)
            .assignments,
        isEmpty,
      );
    });

    test('dağıtım aynı girdiyle aynı sonucu üretir', () {
      List<DutyTeacher> build() => [
        for (var id = 1; id <= 7; id++)
          teacher(id, DutyPreference.values[id % 3]),
      ];
      final first = run(build(), september).assignments;
      final second = run(build(), september).assignments;
      expect(
        first.map((a) => '${dutyDateKey(a.date)}-${a.teacherId}').toList(),
        second.map((a) => '${dutyDateKey(a.date)}-${a.teacherId}').toList(),
      );
    });
  });
}