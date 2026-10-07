/// Bir eğitim öğretim yılı.
///
/// Türkiye'de eğitim öğretim yılı 1 Eylül'de başlar ve 31 Ağustos'ta biter.
/// Bu nedenle yıl, başlangıç yılıyla tutulur: 2025 değeri "2025-2026" yılını
/// ifade eder.
class EducationYear {
  const EducationYear({
    this.id,
    required this.startYear,
    this.isActive = false,
    this.createdAt,
  });

  final int? id;

  /// Başlangıç yılı (2025 -> 2025-2026).
  final int startYear;

  /// Kullanımda olan yıl mı.
  final bool isActive;

  final DateTime? createdAt;

  /// "2025-2026" biçiminde etiket.
  String get label => '$startYear-${startYear + 1}';

  int get endYear => startYear + 1;

  EducationYear copyWith({int? id, bool? isActive}) {
    return EducationYear(
      id: id ?? this.id,
      startYear: startYear,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EducationYear && other.startYear == startYear;
  }

  @override
  int get hashCode => startYear.hashCode;

  @override
  String toString() => 'EducationYear($label)';
}

/// Eğitim öğretim yılı 1 Eylül'de başladığı için, eylülden önceki aylar
/// bir önceki başlangıç yılına aittir.
int educationYearStartFor(DateTime date) =>
    date.month >= 9 ? date.year : date.year - 1;

/// Bugünün içinde bulunduğu eğitim öğretim yılının başlangıç yılı.
int currentEducationYearStart([DateTime? now]) =>
    educationYearStartFor(now ?? DateTime.now());

/// Bir eğitim öğretim yılına ait aylar, takvim yılıyla birlikte.
///
/// Eylül-Aralık başlangıç yılına, Ocak-Ağustos bir sonraki yıla aittir.
/// Nöbet listeleri bu çiftlerle saklanır.
List<({int year, int month})> educationYearMonths(int startYear) {
  return [
    for (var month = 9; month <= 12; month++) (year: startYear, month: month),
    for (var month = 1; month <= 8; month++)
      (year: startYear + 1, month: month),
  ];
}

/// Takvim yılı/ayının ait olduğu eğitim öğretim yılının başlangıç yılı.
int educationYearStartOfMonth(int year, int month) =>
    month >= 9 ? year : year - 1;
