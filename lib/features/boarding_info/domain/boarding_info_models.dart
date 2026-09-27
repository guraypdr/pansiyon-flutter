enum BoardingType { girls, boys, mixed }

enum EducationLevel { middleSchool, highSchool }

enum BoardingSection { common, girls, boys }

extension BoardingTypeLabel on BoardingType {
  String get label {
    switch (this) {
      case BoardingType.girls:
        return 'Kız';
      case BoardingType.boys:
        return 'Erkek';
      case BoardingType.mixed:
        return 'Karma';
    }
  }

  String get value => name;
}

extension EducationLevelLabel on EducationLevel {
  String get label {
    switch (this) {
      case EducationLevel.middleSchool:
        return 'Ortaokul';
      case EducationLevel.highSchool:
        return 'Lise';
    }
  }

  String get value => name;
}

/// Lise kademesinde hazırlık sınıfının seçeneklerde yer alıp almadığı.
List<String> classLevelsForEducationLevel(
  EducationLevel? level, {
  bool hasPreparationGrade = true,
}) {
  if (level == null) {
    return const [];
  }
  if (level == EducationLevel.middleSchool) {
    return const ['5', '6', '7', '8'];
  }
  return hasPreparationGrade
      ? const ['Hazırlık', '9', '10', '11', '12']
      : const ['9', '10', '11', '12'];
}

extension BoardingSectionLabel on BoardingSection {
  String get label {
    switch (this) {
      case BoardingSection.common:
        return 'Ortak Bölüm';
      case BoardingSection.girls:
        return 'Kız Bölümü';
      case BoardingSection.boys:
        return 'Erkek Bölümü';
    }
  }

  String get value => name;
}

BoardingType boardingTypeFromValue(String value) {
  return BoardingType.values.firstWhere(
    (type) => type.value == value,
    orElse: () => BoardingType.mixed,
  );
}

EducationLevel educationLevelFromValue(String value) {
  return EducationLevel.values.firstWhere(
    (level) => level.value == value,
    orElse: () => EducationLevel.middleSchool,
  );
}

BoardingSection boardingSectionFromValue(String value) {
  return BoardingSection.values.firstWhere(
    (section) => section.value == value,
    orElse: () => BoardingSection.common,
  );
}

class BoardingInfoDraft {
  const BoardingInfoDraft({
    required this.schoolName,
    required this.principalName,
    required this.principalPhone,
    required this.deputyName,
    required this.deputyPhone,
    required this.boardingType,
    required this.educationLevel,
    required this.blocks,
    this.hasPreparationGrade = true,
  });

  final String schoolName;
  final String principalName;
  final String principalPhone;
  final String deputyName;
  final String deputyPhone;
  final BoardingType boardingType;
  final EducationLevel educationLevel;
  final List<BoardingBlockDraft> blocks;

  /// Lise kademesinde "Hazırlık" sınıfı kullanılıyor mu?
  ///
  /// Kullanılmıyorsa sınıf düzeyi listelerinden "Hazırlık" çıkarılır.
  final bool hasPreparationGrade;
}

class BoardingBlockDraft {
  const BoardingBlockDraft({
    required this.section,
    required this.name,
    required this.standardRoomCapacity,
    required this.floors,
    this.hasBasement = false,
  });

  final BoardingSection section;
  final String name;
  final int standardRoomCapacity;
  final bool hasBasement;
  final List<BoardingFloorDraft> floors;
}

class BoardingFloorDraft {
  const BoardingFloorDraft({
    required this.floorNumber,
    this.hasStudentRooms = true,
    this.studentRoomCount,
    this.roomStartNumber = 1,
  });

  final int floorNumber;
  final bool hasStudentRooms;
  final int? studentRoomCount;
  final int? roomStartNumber;
}
