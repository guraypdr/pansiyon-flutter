import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';

/// Nöbet dağıtım kuralları:
///
/// 1. Birinci aşamada **her aktif öğretmene birer nöbet** yazılır; nöbet
///    isteğine bakılmaz.
/// 2. Nöbetler yalnızca öğretmenin müsait olduğu günlere yazılır; bu kural
///    istisnasızdır.
/// 3. Kalan nöbetler önce dengeli ve maksimum isteyenlere dağıtılır.
///    Maksimum isteyenler ayda en çok 8, dengeli isteyenler 4 nöbete kadar
///    tırmanır.
/// 4. Hâlâ boş yuva varsa son aşamada dengeli isteyenler 4'ün üzerine
///    çıkar, minimum isteyenler ikinci nöbetlerini alır.
/// 5. **Hiçbir öğretmen ayda 8 nöbeti geçmez.**
///
/// Kurallar bittikten sonra yuva kalırsa doldurulmaz; nöbet isteği bu
/// şekilde korunur. Kalan sayı [unfilledSlotCount] ile öğrenilir ve
/// kullanıcıya bildirilir.
///
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

  /// Bir öğretmenin alabileceği en fazla nöbet (sert sınır).
  static const int maximumMonthlyDuty = 8;

  /// Dengeli isteyenlerin tırmanacağı hedef.
  static const int balancedTarget = 4;

  /// Minimum isteyenlerin son aşamada alacağı toplam nöbet.
  static const int minimumFinal = 2;
}

/// Bir turda yapılabilecek en fazla geçiş. Her turda bir nöbet daha dağıtılır;
/// bu tavan yalnızca sonsuz döngüye karşı güvenlik amaçlıdır.
const int _maxRounds = 40;

class DutyDistribution {
  const DutyDistribution._();

  static List<DutyAssignment> generate(DutyDistributionInput input) {
    final teachers = input.teachers
        .where((item) => item.isActive && item.id != null)
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    if (teachers.isEmpty || input.dutyDates.isEmpty || input.dailyCount <= 0) {
      return const [];
    }

    final state = _FillState(input, teachers);

    // Aşama 1: her öğretmene bir nöbet, istek gözetilmez.
    state.fill((teacher) => state.totals[teacher.id] == 0);

    // Aşama 2: dengeli ve maksimum isteyenler tırmanır.
    state.fill((teacher) {
      final total = state.totals[teacher.id]!;
      return switch (teacher.dutyPreference) {
        DutyPreference.minimum => false,
        DutyPreference.balanced => total < DutyDistributionInput.balancedTarget,
        DutyPreference.maximum =>
          total < DutyDistributionInput.maximumMonthlyDuty,
      };
    });

    // Aşama 3: yine boş yuva varsa dengeli isteyenler devam eder, minimum
    // isteyenler ikinci nöbetlerini alır.
    state.fill((teacher) {
      final total = state.totals[teacher.id]!;
      final limit = teacher.dutyPreference == DutyPreference.minimum
          ? DutyDistributionInput.minimumFinal
          : DutyDistributionInput.maximumMonthlyDuty;
      return total < limit;
    });

    // Bundan sonrası isteğe bağlı: minimum isteyenlerin tavanı dolduğu için
    // boş yuva kalabilir. Kalan yuva, 8 nöbetlik sınırı bozulmadan
    // doldurulamaz; bu yüzden kullanıcıya bildirilir, gizlice dağıtılmaz.
    return state.assignments;
  }

  /// Verilen dağıtımda doldurulamayan nöbet yuvası sayısı.
  ///
  /// Öğretmen sayısı az, gün çok olduğunda yuvular boş kalabilir. Bu
  /// durum sessizce geçmemelidir.
  static int unfilledSlotCount(
    DutyDistributionInput input,
    List<DutyAssignment> assignments,
  ) {
    final total = input.dutyDates.length * input.dailyCount;
    final remaining = total - assignments.length;
    return remaining < 0 ? 0 : remaining;
  }
}

/// Bir dağıtım aşamasının çalışma durumu.
class _FillState {
  _FillState(this.input, this.teachers) {
    for (final teacher in teachers) {
      totals[teacher.id!] = 0;
      streaks[teacher.id!] = 0;
    }
  }

  final DutyDistributionInput input;
  final List<DutyTeacher> teachers;

  final assignments = <DutyAssignment>[];
  final totals = <int, int>{};
  final streaks = <int, int>{};
  final lastDates = <int, DateTime>{};
  final assignedByDate = <DateTime, Set<int>>{};
  final slotTaken = <DateTime, int>{};

  /// [accept] öğretmenin bu aşamaya uygun olup olmadığını belirler.
  ///
  /// İlerleme durulana kadar tur tur tekrar eder. Böylece "dengeli 4'e,
  /// maksimum 8'e ulaşana kadar devam et" kuralı kendiliğinden sağlanır.
  void fill(bool Function(DutyTeacher teacher) accept) {
    for (var round = 0; round < _maxRounds; round++) {
      var progress = false;
      for (final date in input.dutyDates) {
        for (var slot = 0; slot < input.dailyCount; slot++) {
          if ((slotTaken[date] ?? 0) >= input.dailyCount) {
            break;
          }
          final teacher = _pick(date, accept);
          if (teacher == null) {
            continue;
          }
          _assign(date, slot, teacher);
          progress = true;
        }
      }
      if (!progress) {
        return;
      }
    }
  }

  void _assign(DateTime date, int slot, DutyTeacher teacher) {
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
    slotTaken[date] = (slotTaken[date] ?? 0) + 1;
    (assignedByDate[date] ??= {}).add(teacher.id!);
    totals[teacher.id!] = totals[teacher.id!]! + 1;

    final last = lastDates[teacher.id!];
    streaks[teacher.id!] =
        (last != null && last.difference(date).inDays == -1)
        ? streaks[teacher.id!]! + 1
        : 1;
    lastDates[teacher.id!] = date;
  }

  DutyTeacher? _pick(DateTime date, bool Function(DutyTeacher) accept) {
    final taken = assignedByDate[date] ?? const <int>{};
    final candidates = teachers
        .where((teacher) => teacher.isAvailableOn(date))
        .where((teacher) => !taken.contains(teacher.id))
        .where(accept)
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final countCompare = totals[a.id]!.compareTo(totals[b.id]!);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.fullName.compareTo(b.fullName);
    });

    // Üst üste nöbet kuralı öncelikli değildir: yalnızca seri oluşturmayan
    // aday varsa o seçilir, yoksa kural esnetilir ve gün boş bırakılmaz.
    if (input.maxConsecutive <= 0) {
      return candidates.first;
    }
    for (final candidate in candidates) {
      if (streaks[candidate.id]! < input.maxConsecutive) {
        return candidate;
      }
    }
    return candidates.first;
  }
}

/// Nöbet puanı: her nöbet günü 1 puandır.
int dutyScore(int dutyCount) => dutyCount;
