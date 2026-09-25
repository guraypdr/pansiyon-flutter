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

extension BoardingSectionLabel on BoardingSection {
  String get label {
    switch (this) {
      case BoardingSection.common:
        return 'Ortak';
      case BoardingSection.girls:
        return 'Kız tarafı';
      case BoardingSection.boys:
        return 'Erkek tarafı';
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
  });

  final String schoolName;
  final String principalName;
  final String principalPhone;
  final String deputyName;
  final String deputyPhone;
  final BoardingType boardingType;
  final EducationLevel educationLevel;
  final List<BoardingBlockDraft> blocks;
}

class BoardingBlockDraft {
  const BoardingBlockDraft({
    required this.section,
    required this.name,
    required this.standardRoomCapacity,
    required this.studyRoomCount,
    required this.floors,
    this.hasBasement = false,
  });

  final BoardingSection section;
  final String name;
  final int standardRoomCapacity;
  final int studyRoomCount;
  final bool hasBasement;
  final List<BoardingFloorDraft> floors;
}

class BoardingFloorDraft {
  const BoardingFloorDraft({
    required this.floorNumber,
    required this.studentRoomCount,
    this.roomStartNumber = 1,
  });

  final int floorNumber;
  final int studentRoomCount;
  final int roomStartNumber;
}
