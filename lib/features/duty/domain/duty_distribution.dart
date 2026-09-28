import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

/// Nöbet dağıtım kuralları:
/// 1. Birinci turda herkese birer nöbet yazılır.
/// 2. Nöbetler yalnızca öğretmenin müsait olduğu günlere yazılır.
/// 3. Sonraki turlarda dengeli isteyenlere haftada bir, maksimum isteyenlere
///    ayda en çok 8 nöbet dağıtılır; minimum isteyenler yalnızca ilk turda kalır.
/// 4. Üst üste nöbet verilmemeye çalışılır.
/// Her bölüm kendi ayarlarıyla ayrı ayrı dağıtılır.
class DutyDistributionInput {
  const DutyDistributionInput({
    required this.year,
    required this.month,
    required this.teachers,
    required this.dutyDates,
    this.locations = const [],
    this.dailyCount = 2,
    this.maxConsecutive = 2,
  });

  final int year;
  final int month;
  final List<DutyTeacher> teachers;
  final List<DateTime> dutyDates;
  final List<String> locations;
  final int dailyCount;
  final int maxConsecutive;

  static const int maximumMonthlyDuty = 8;
}

class DutyDistribution {
  const DutyDistribution._();

  static List<DutyAssignment> generate(DutyDistributionInput input) {
    final teachers = input.teachers.where((item) => item.isActive).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (teachers.isEmpty || input.dutyDates.isEmpty || input.dailyCount <= 0) {
      return const [];
    }

    final totals = <int, int>{for (final t in teachers) t.id!: 0};
    final streaks = <int, int>{for (final t in teachers) t.id!: 0};
    final lastDates = <int, DateTime>{};
    final weekly = <int, Map<int, int>>{for (final t in teachers) t.id!: {}};
    final perDateCount = <DateTime, int>{};
    final assignedByDate = <DateTime, Set<int>>{};
    final assignments = <DutyAssignment>[];

    var round = 0;
    while (round < 40) {
      var assignedInRound = 0;
      for (final date in input.dutyDates) {
        final week = _weekKey(date);
        for (var slot = 0; slot < input.dailyCount; slot++) {
          if ((perDateCount[date] ?? 0) >= input.dailyCount) {
            break;
          }
          final teacher = _pickTeacher(
            input: input,
            date: date,
            week: week,
            round: round,
            teachers: teachers,
            totals: totals,
            streaks: streaks,
            weekly: weekly,
            assignedByDate: assignedByDate,
          );
          if (teacher == null) {
            continue;
          }
          assignments.add(
            DutyAssignment(
              year: input.year,
              month: input.month,
              date: date,
              teacherId: teacher.id!,
              location: input.locations.isEmpty
                  ? null
                  : input.locations[slot % input.locations.length],
            ),
          );
          perDateCount[date] = (perDateCount[date] ?? 0) + 1;
          (assignedByDate[date] ??= {}).add(teacher.id!);
          totals[teacher.id!] = totals[teacher.id!]! + 1;
          final last = lastDates[teacher.id!];
          streaks[teacher.id!] =
              (last != null && last.difference(date).inDays == -1)
              ? streaks[teacher.id!]! + 1
              : 1;
          lastDates[teacher.id!] = date;
          (weekly[teacher.id!] ??= {})[week] =
              (weekly[teacher.id!]![week] ?? 0) + 1;
          assignedInRound++;
        }
      }
      if (assignedInRound == 0) {
        break;
      }
      round++;
    }
    return assignments;
  }

  static DutyTeacher? _pickTeacher({
    required DutyDistributionInput input,
    required DateTime date,
    required int week,
    required int round,
    required List<DutyTeacher> teachers,
    required Map<int, int> totals,
    required Map<int, int> streaks,
    required Map<int, Map<int, int>> weekly,
    required Map<DateTime, Set<int>> assignedByDate,
  }) {
    DutyTeacher? best(List<DutyTeacher> pool) {
      final sorted = [...pool]
        ..sort((a, b) {
          final countCompare = totals[a.id]!.compareTo(totals[b.id]!);
          if (countCompare != 0) {
            return countCompare;
          }
          return a.fullName.compareTo(b.fullName);
        });
      return sorted.isEmpty ? null : sorted.first;
    }

    bool withinLimit(DutyTeacher teacher) {
      if (round == 0) {
        return totals[teacher.id!] == 0;
      }
      return switch (teacher.dutyPreference) {
        DutyPreference.minimum => false,
        DutyPreference.balanced => (weekly[teacher.id!]![week] ?? 0) < 1,
        DutyPreference.maximum =>
          totals[teacher.id!]! < DutyDistributionInput.maximumMonthlyDuty,
      };
    }

    bool streakOk(DutyTeacher teacher) {
      if (input.maxConsecutive <= 0) {
        return true;
      }
      return streaks[teacher.id!]! < input.maxConsecutive;
    }

    final taken = assignedByDate[date] ?? const <int>{};
    final available = teachers
        .where((t) => t.isAvailableOn(date))
        .where((t) => !taken.contains(t.id))
        .toList();
    return best(
          available.where((t) => withinLimit(t) && streakOk(t)).toList(),
        ) ??
        best(available.where(withinLimit).toList());
  }

  static int _weekKey(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return monday.year * 100 + monday.month;
  }
}

/// Nöbet puanı: her nöbet günü 1 puandır.
int dutyScore(int dutyCount) => dutyCount;
