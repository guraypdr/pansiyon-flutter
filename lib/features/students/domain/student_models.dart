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

enum StudentLivingArrangement {
  withMotherFather,
  withMother,
  withFather,
  other,
}

extension StudentLivingArrangementLabel on StudentLivingArrangement {
  String get label {
    switch (this) {
      case StudentLivingArrangement.withMotherFather:
        return 'Anne ve babasıyla';
      case StudentLivingArrangement.withMother:
        return 'Anneyle';
      case StudentLivingArrangement.withFather:
        return 'Babayla';
      case StudentLivingArrangement.other:
        return 'Diğer';
    }
  }

  String get value => name;
}

enum ParentLivingStatus { together, separate }

extension ParentLivingStatusLabel on ParentLivingStatus {
  String get label {
    switch (this) {
      case ParentLivingStatus.together:
        return 'Birlikte';
      case ParentLivingStatus.separate:
        return 'Ayrı';
    }
  }

  String get value => name;
}

class School {
  const School({this.id, required this.name});

  final int? id;
  final String name;
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
    this.hasPsychologicalCondition = false,
    this.psychologicalConditionDetails,
    this.livingArrangement = StudentLivingArrangement.withMotherFather,
    this.motherName,
    this.fatherName,
    this.motherPhone,
    this.fatherPhone,
    this.motherAlive = true,
    this.fatherAlive = true,
    this.parentsLiveTogether = ParentLivingStatus.together,
    this.guardianName,
    this.guardianRelation,
    this.guardianPhone,
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
  final bool hasPsychologicalCondition;
  final String? psychologicalConditionDetails;

  final StudentLivingArrangement livingArrangement;
  final String? motherName;
  final String? fatherName;
  final String? motherPhone;
  final String? fatherPhone;
  final bool motherAlive;
  final bool fatherAlive;
  final ParentLivingStatus parentsLiveTogether;
  final String? guardianName;
  final String? guardianRelation;
  final String? guardianPhone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? boardingRegistrationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Student withGender(StudentGender? value) {
    return Student(
      id: id,
      fullName: fullName,
      gender: value,
      nationalId: nationalId,
      schoolId: schoolId,
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
      schoolNumber: schoolNumber,
      birthDate: birthDate,
      address: address,
      phone: phone,
      hasChronicDisease: hasChronicDisease,
      chronicDiseaseDetails: chronicDiseaseDetails,
      hasAllergy: hasAllergy,
      allergyDetails: allergyDetails,
      regularMedication: regularMedication,
      hasPsychologicalCondition: hasPsychologicalCondition,
      psychologicalConditionDetails: psychologicalConditionDetails,
      livingArrangement: livingArrangement,
      motherName: motherName,
      fatherName: fatherName,
      motherPhone: motherPhone,
      fatherPhone: fatherPhone,
      motherAlive: motherAlive,
      fatherAlive: fatherAlive,
      parentsLiveTogether: parentsLiveTogether,
      guardianName: guardianName,
      guardianRelation: guardianRelation,
      guardianPhone: guardianPhone,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      boardingRegistrationDate: boardingRegistrationDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Student withSchoolId(int? value) {
    return Student(
      id: id,
      fullName: fullName,
      gender: gender,
      nationalId: nationalId,
      schoolId: value,
      schoolName: schoolName,
      className: className,
      sectionName: sectionName,
      schoolNumber: schoolNumber,
      birthDate: birthDate,
      address: address,
      phone: phone,
      hasChronicDisease: hasChronicDisease,
      chronicDiseaseDetails: chronicDiseaseDetails,
      hasAllergy: hasAllergy,
      allergyDetails: allergyDetails,
      regularMedication: regularMedication,
      hasPsychologicalCondition: hasPsychologicalCondition,
      psychologicalConditionDetails: psychologicalConditionDetails,
      livingArrangement: livingArrangement,
      motherName: motherName,
      fatherName: fatherName,
      motherPhone: motherPhone,
      fatherPhone: fatherPhone,
      motherAlive: motherAlive,
      fatherAlive: fatherAlive,
      parentsLiveTogether: parentsLiveTogether,
      guardianName: guardianName,
      guardianRelation: guardianRelation,
      guardianPhone: guardianPhone,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      boardingRegistrationDate: boardingRegistrationDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
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
    this.createdAt,
  });

  final int? id;
  final int studentId;
  final DateTime date;
  final String description;
  final DateTime? createdAt;
}
