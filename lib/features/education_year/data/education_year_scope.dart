import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';

/// Etkin eğitim öğretim yılını sunar.
///
/// Veri katmanı bileşenleri (öğrenci, öğretmen, nöbet listesi) yılı kendi
/// aramalarında öğrenemez; okuma [AppDatabase.activeEducationYear] üzerinden
/// yapılır ve veritabanı açılışında bir kez çözülür.
///
/// [setActiveYear] çağrıldığında yıl uygulama genelinde değişir.
class EducationYearScope {
  EducationYearScope(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Yıl değiştirildiğinde çağrılır.
  void setActiveYear(int startYear) {
    _appDatabase.setActiveEducationYear(startYear);
  }

  /// Etkin yılın başlangıç yılı.
  ///
  /// Hiç yıl tanımlanmamışsa bugünün yılına düşer.
  Future<int> activeYear() => _appDatabase.activeEducationYear();

  /// Etkin yılı verilen yıl listesine göre çözer; yoksa bugünün yılı.
  Future<int> activeYearFrom(List<EducationYear> years) async {
    for (final year in years) {
      if (year.isActive) {
        setActiveYear(year.startYear);
        return year.startYear;
      }
    }
    final fallback = currentEducationYearStart();
    setActiveYear(fallback);
    return fallback;
  }
}
