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

/// Anne, baba ve veli için eğitim durumu.
enum ParentEducationStatus {
  primarySchool,
  middleSchool,
  highSchool,
  higherEducation,
  unknown,
}

extension ParentEducationStatusLabel on ParentEducationStatus {
  String get label {
    switch (this) {
      case ParentEducationStatus.primarySchool:
        return 'İlkokul';
      case ParentEducationStatus.middleSchool:
        return 'Ortaokul';
      case ParentEducationStatus.highSchool:
        return 'Lise';
      case ParentEducationStatus.higherEducation:
        return 'Yükseköğretim';
      case ParentEducationStatus.unknown:
        return 'Bilinmiyor';
    }
  }

  String get value => name;
}

/// Eğitim durumunu değer ya da etiketten çözer.
///
/// Excel'den gelen hücreler etiketle ("Lise") ya da değerle ("highSchool")
/// yazılmış olabilir; büyük/küçük harf ve kenar boşlukları yok sayılır.
ParentEducationStatus? parentEducationFromValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  for (final status in ParentEducationStatus.values) {
    if (status.value.toLowerCase() == normalized ||
        status.label.toLowerCase() == normalized) {
      return status;
    }
  }
  return null;
}

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
    this.guardianIsOther = false,
    this.motherName,
    this.motherAlive = true,
    this.motherIsBiological = true,
    this.motherOccupation,
    this.motherEducation,
    this.motherPhone,
    this.motherAddress,
    this.motherHasSeparateAddress = false,
    this.fatherName,
    this.fatherAlive = true,
    this.fatherIsBiological = true,
    this.fatherOccupation,
    this.fatherEducation,
    this.fatherPhone,
    this.fatherAddress,
    this.fatherHasSeparateAddress = false,
    this.guardianName,
    this.guardianRelation,
    this.guardianPhone,
    this.guardianAddress,
    this.guardianOccupation,
    this.guardianEducation,
    this.guardianBirthDate,
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

  /// Veli anne ve babanın dışında biri mi?
  final bool guardianIsOther;
  final String? guardianName;
  final String? guardianRelation;
  final String? guardianPhone;
  final String? guardianAddress;
  final String? guardianOccupation;
  final ParentEducationStatus? guardianEducation;
  final DateTime? guardianBirthDate;

  final String? motherName;
  final bool motherAlive;
  final bool motherIsBiological;
  final String? motherOccupation;
  final ParentEducationStatus? motherEducation;
  final String? motherPhone;

  /// Anne için ayrı adres yazıldığında `true`.
  final bool motherHasSeparateAddress;
  final String? motherAddress;

  final String? fatherName;
  final bool fatherAlive;
  final bool fatherIsBiological;
  final String? fatherOccupation;
  final ParentEducationStatus? fatherEducation;
  final String? fatherPhone;

  /// Baba için ayrı adres yazıldığında `true`.
  final bool fatherHasSeparateAddress;
  final String? fatherAddress;

  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? boardingRegistrationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Anne ölüyse babanın adresi varsayılan olarak kullanılabilsin diye
  /// yaşayan ebeveynin adresi çözülür.
  ///
  /// Hiçbir ebeveyn adresi girilmemişse `null` döner; çağıran taraf öğrenci
  /// adresine düşmelidir.
  String? get effectiveAddress {
    if (motherAlive && motherAddress != null && motherAddress!.isNotEmpty) {
      return motherAddress;
    }
    if (fatherAlive && fatherAddress != null && fatherAddress!.isNotEmpty) {
      return fatherAddress;
    }
    return null;
  }

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
    bool? guardianIsOther,
    String? guardianName,
    bool? motherAlive,
    bool? fatherAlive,
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
      guardianIsOther: guardianIsOther ?? this.guardianIsOther,
      motherName: motherName,
      motherAlive: motherAlive ?? this.motherAlive,
      motherIsBiological: motherIsBiological,
      motherOccupation: motherOccupation,
      motherEducation: motherEducation,
      motherPhone: motherPhone,
      motherAddress: motherAddress,
      motherHasSeparateAddress: motherHasSeparateAddress,
      fatherName: fatherName,
      fatherAlive: fatherAlive ?? this.fatherAlive,
      fatherIsBiological: fatherIsBiological,
      fatherOccupation: fatherOccupation,
      fatherEducation: fatherEducation,
      fatherPhone: fatherPhone,
      fatherAddress: fatherAddress,
      fatherHasSeparateAddress: fatherHasSeparateAddress,
      guardianName: guardianName ?? this.guardianName,
      guardianRelation: guardianRelation,
      guardianPhone: guardianPhone,
      guardianAddress: guardianAddress,
      guardianOccupation: guardianOccupation,
      guardianEducation: guardianEducation,
      guardianBirthDate: guardianBirthDate,
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
