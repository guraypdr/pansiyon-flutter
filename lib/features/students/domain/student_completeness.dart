import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

/// Öğrenci kaydında eksik bulunan bir alan.
class StudentMissingField {
  const StudentMissingField(this.label, {this.isCritical = false});

  /// Kullanıcıya gösterilen alan adı.
  final String label;

  /// Eksikliğin oda yerleştirme veya acil durumda sonucu değiştirip
  /// değiştirmediği.
  ///
  /// Kritik alanlar listede öne çıkarılır.
  final bool isCritical;
}

/// Öğrenci kaydında eksik alanları önem sırasına göre döndürür.
///
/// Boş bir liste dönerse kayıt tamamlanmış sayılır ve kartta uyarı
/// gösterilmez.
///
/// Acil iletişim bilgisi bilinçli olarak denetlenmez: formda alanı yok,
/// kayıt sırasında birinci veliden türetilir. Denetlenseydi veli adı
/// boş olduğu hâlde veli telefonu bulunan kayıtlarda kullanıcıya ulaşılabilir
/// bir numara olduğu halde "Acil İletişim eksik" uyarısı çıkardı. Eksik
/// veli adı zaten "Veli Adı" olarak bildiriliyor.
List<StudentMissingField> studentMissingFields(Student student) {
  final missing = <StudentMissingField>[];

  void require(String label, String? value, {bool isCritical = false}) {
    if ((value ?? '').trim().isEmpty) {
      missing.add(StudentMissingField(label, isCritical: isCritical));
    }
  }

  // Cinsiyet oda yerleştirme kurallarında kullanılır; eksikse öğrenci
  // yerleştirilemeyebilir.
  require('Cinsiyet', student.gender?.value, isCritical: true);
  require('T.C. Kimlik No', student.nationalId);
  require('Doğum Tarihi', student.birthDate?.toIso8601String());
  require('Okul', student.schoolName);
  require('Sınıf', student.className);
  require('Telefon', student.phone);
  require('Adres', student.address);

  require('Veli Adı', student.guardianName);
  require('Veli Telefonu', student.guardianPhone);

  return missing;
}

/// Eksik alanları tek satırlık özet metne çevirir.
String studentMissingSummary(List<StudentMissingField> fields) {
  if (fields.isEmpty) {
    return 'Eksik bilgi yok.';
  }
  final critical = fields.where((field) => field.isCritical).toList();
  final labels = fields.map((field) => field.label).join(', ');
  if (critical.isEmpty) {
    return 'Eksik bilgiler: $labels';
  }
  return 'Kritik eksik: ${critical.map((field) => field.label).join(', ')}'
      '\nEksik bilgiler: $labels';
}
