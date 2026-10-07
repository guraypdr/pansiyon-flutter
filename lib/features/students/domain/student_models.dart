import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

enum StudentGender { female, male }

extension StudentGenderLabel on StudentGender {
  String get label {
    switch (this) {
      case StudentGender.female:
        return 'Kız';
      case StudentGender.male:
        return 'Erkek';
    }
  }

  String get value => name;
}

StudentGender? studentGenderFromValue(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  for (final gender in StudentGender.values) {
    if (gender.value == value ||
        gender.label.toLowerCase() == value.toLowerCase()) {
      return gender;
    }
  }
  return null;
}

/// Pansiyon türüne göre seçilebilecek cinsiyetler.
///
/// Karma pansiyonda iki cinsiyet de seçilebilir; tek cinsiyetli pansiyonda
/// cinsiyet kilitlidir.
List<StudentGender> allowedGendersForBoardingType(BoardingType? boardingType) {
  switch (boardingType) {
    case BoardingType.girls:
      return const [StudentGender.female];
    case BoardingType.boys:
      return const [StudentGender.male];
    case BoardingType.mixed:
    case null:
      return StudentGender.values;
  }
}

/// Pansiyon türü tek cinsiyet kilitliyse o cinsiyeti döner, aksi hâlde `null`.
StudentGender? lockedGenderForBoardingType(BoardingType? boardingType) {
  final allowed = allowedGendersForBoardingType(boardingType);
  return allowed.length == 1 ? allowed.first : null;
}

/// Öğrencinin cinsiyetini pansiyon türüne göre düzeltir.
///
/// `(düzeltilmiş öğrenci, düzeltme yapıldı mı)` döner.
(Student, bool) applyBoardingGenderConstraint(
  Student student,
  BoardingType? boardingType,
) {
  final locked = lockedGenderForBoardingType(boardingType);
  if (locked == null || student.gender == locked) {
    return (student, false);
  }
  return (student.withGender(locked), true);
}

enum StudentAttendanceStatus { present, homeLeave, medicalReport }

extension StudentAttendanceStatusLabel on StudentAttendanceStatus {
  String get label {
    switch (this) {
      case StudentAttendanceStatus.present:
        return 'Mevcut';
      case StudentAttendanceStatus.homeLeave:
        return 'Evci izinli';
      case StudentAttendanceStatus.medicalReport:
        return 'Raporlu';
    }
  }

  String get value => name;
}

/// Okul kaydı ve sınıf düzeyine bağlı şubeleri.
class School {
  const School({this.id, required this.name, this.sectionsByClass = const {}});

  final int? id;
  final String name;

  /// Sınıf düzeyi bazlı tanımlı şubeler: `{'9': ['A', 'GD'], '10': ['A']}`.
  final Map<String, List<String>> sectionsByClass;

  /// Bir sınıf düzeyi için tanımlı şubeler.
  List<String> sectionsFor(String? className) {
    if (className == null) {
      return const [];
    }
    return sectionsByClass[className.trim()] ?? const [];
  }

  School copyWith({
    int? id,
    String? name,
    Map<String, List<String>>? sectionsByClass,
  }) {
    return School(
      id: id ?? this.id,
      name: name ?? this.name,
      sectionsByClass: sectionsByClass ?? this.sectionsByClass,
    );
  }
}

/// Kan grubu seçenekleri; bilinmeyen de listelenir.
const bloodGroupOptions = <String>[
  'A Rh+',
  'A Rh-',
  'B Rh+',
  'B Rh-',
  'AB Rh+',
  'AB Rh-',
  '0 Rh+',
  '0 Rh-',
  'Bilinmiyor',
];

/// Sınıf düzeyi ve şubeyi kart görünümü için "9/A" biçiminde birleştirir.
/// Şube zaten sınıf düzeyiyle yazıldıysa (örn. "9/A") tekrar eklemez.
String formatClassSectionLabel(String? className, String? sectionName) {
  final classLevel = className?.trim() ?? '';
  final section = sectionName?.trim() ?? '';
  if (section.isEmpty) {
    if (classLevel.isEmpty) {
      return '';
    }
    return '$classLevel. Sınıf (Şube eklenmedi)';
  }
  if (classLevel.isEmpty) {
    return section;
  }
  if (section.toUpperCase().startsWith('$classLevel/')) {
    return section;
  }
  return '$classLevel/$section';
}

class Student {
  const Student({
    this.id,
    required this.fullName,
    this.gender,
    this.nationalId,
    this.schoolId,
    this.schoolName,
    this.className,
    this.sectionName,
    this.schoolNumber,
    this.birthDate,
    this.address,
    this.phone,
    this.hasChronicDisease = false,
    this.chronicDiseaseDetails,
    this.hasAllergy = false,
    this.allergyDetails,
    this.regularMedication,
    this.bloodType,
    this.hasPsychologicalCondition = false,
    this.psychologicalConditionDetails,
    this.guardianName,
    this.guardianRelation,
    this.guardianPhone,
    this.guardianAddress,
    this.guardian2Name,
    this.guardian2Relation,
    this.guardian2Phone,
    this.guardian2Address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.boardingRegistrationDate,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String fullName;
  final StudentGender? gender;
  final String? nationalId;
  final int? schoolId;
  final String? schoolName;
  final String? className;
  final String? sectionName;
  final String? schoolNumber;
  final DateTime? birthDate;
  final String? address;
  final String? phone;

  final bool hasChronicDisease;
  final String? chronicDiseaseDetails;
  final bool hasAllergy;
  final String? allergyDetails;
  final String? regularMedication;
  final String? bloodType;
  final bool hasPsychologicalCondition;
  final String? psychologicalConditionDetails;

  /// Birincil veli (anne, baba veya başka bir yakın).
  final String? guardianName;
  final String? guardianRelation;
  final String? guardianPhone;
  final String? guardianAddress;

  /// İkincil veli. Aynı alanlara sahiptir.
  final String? guardian2Name;
  final String? guardian2Relation;
  final String? guardian2Phone;
  final String? guardian2Address;

  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? boardingRegistrationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Yalnızca verilen alanları değiştirilmiş yeni bir öğrenci döndürür.
  ///
  /// `null` verilen alanlar **korunur**, `null`'a temizlenmez. Temizleme
  /// gereken durumlar doğrudan [Student] kurucusuyla karşılanır.
  Student copyWith({
    int? id,
    String? fullName,
    StudentGender? gender,
    int? schoolId,
    String? className,
    String? sectionName,
    String? guardianName,
  }) {
    return Student(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      nationalId: nationalId,
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      schoolNumber: schoolNumber,
      birthDate: birthDate,
      address: address,
      phone: phone,
      hasChronicDisease: hasChronicDisease,
      chronicDiseaseDetails: chronicDiseaseDetails,
      hasAllergy: hasAllergy,
      allergyDetails: allergyDetails,
      regularMedication: regularMedication,
      bloodType: bloodType,
      hasPsychologicalCondition: hasPsychologicalCondition,
      psychologicalConditionDetails: psychologicalConditionDetails,
      guardianName: guardianName ?? this.guardianName,
      guardianRelation: guardianRelation,
      guardianPhone: guardianPhone,
      guardianAddress: guardianAddress,
      guardian2Name: guardian2Name,
      guardian2Relation: guardian2Relation,
      guardian2Phone: guardian2Phone,
      guardian2Address: guardian2Address,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      boardingRegistrationDate: boardingRegistrationDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Student withGender(StudentGender? value) => copyWith(gender: value);

  Student withSchoolId(int? value) => copyWith(schoolId: value);
}

class StudentAttendance {
  const StudentAttendance({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int studentId;
  final DateTime date;
  final StudentAttendanceStatus status;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class StudentDisciplineIncident {
  const StudentDisciplineIncident({
    this.id,
    required this.studentId,
    required this.date,
    required this.description,
    this.studentName,
    this.createdAt,
  });

  final int? id;
  final int studentId;
  final DateTime date;
  final String description;

  /// Liste ekranlarında öğrenci adıyla birlikte gösterilir.
  final String? studentName;
  final DateTime? createdAt;
}
