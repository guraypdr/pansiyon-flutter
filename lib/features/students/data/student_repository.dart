import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract interface class StudentRepository {
  Future<List<Student>> getStudents({String query = ''});

  Future<Student?> getStudent(int id);

  Future<int> saveStudent(Student student);

  Future<void> deleteStudent(int id);

  Future<List<School>> getSchools();

  Future<int> saveSchool(School school);

  Future<void> saveAttendance(StudentAttendance attendance);

  Future<List<StudentAttendance>> getAttendance({
    int? studentId,
    DateTime? date,
  });

  Future<void> saveDisciplineIncident(StudentDisciplineIncident incident);

  Future<List<StudentDisciplineIncident>> getDisciplineIncidents(int studentId);

  Future<int> importStudents(List<Student> students);
}

class SqliteStudentRepository implements StudentRepository {
  SqliteStudentRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<Student>> getStudents({String query = ''}) async {
    final database = await _appDatabase.database;
    final normalizedQuery = query.trim();
    final rows = await database.rawQuery(
      '''
      SELECT s.*, sch.name AS school_name
      FROM students s
      LEFT JOIN schools sch ON sch.id = s.school_id
      ${normalizedQuery.isEmpty ? '' : 'WHERE s.full_name LIKE ? OR s.school_number LIKE ? OR s.national_id LIKE ?'}
      ORDER BY s.full_name COLLATE NOCASE ASC
      ''',
      normalizedQuery.isEmpty
          ? []
          : ['%$normalizedQuery%', '%$normalizedQuery%', '%$normalizedQuery%'],
    );
    return rows.map(_studentFromRow).toList(growable: false);
  }

  @override
  Future<Student?> getStudent(int id) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
      SELECT s.*, sch.name AS school_name
      FROM students s
      LEFT JOIN schools sch ON sch.id = s.school_id
      WHERE s.id = ?
      LIMIT 1
      ''',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _studentFromRow(rows.first);
  }

  @override
  Future<int> saveStudent(Student student) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final values = _studentValues(student, now);
    final id = student.id;

    if (id == null) {
      return database.insert('students', values);
    }

    await database.update(
      'students',
      values..remove('created_at'),
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  @override
  Future<void> deleteStudent(int id) async {
    final database = await _appDatabase.database;
    await database.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<School>> getSchools() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'schools',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((row) => School(id: row['id'] as int, name: row['name'] as String))
        .toList(growable: false);
  }

  @override
  Future<int> saveSchool(School school) async {
    final name = school.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(school.name, 'name', 'Okul adı boş olamaz.');
    }

    final database = await _appDatabase.database;
    if (school.id == null) {
      final existing = await database.query(
        'schools',
        columns: ['id'],
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [name],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }
      return database.insert('schools', {
        'name': name,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    await database.update(
      'schools',
      {'name': name},
      where: 'id = ?',
      whereArgs: [school.id],
    );
    return school.id!;
  }

  @override
  Future<void> saveAttendance(StudentAttendance attendance) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert('student_attendance', {
      'student_id': attendance.studentId,
      'attendance_date': _dateOnly(attendance.date),
      'status': attendance.status.value,
      'note': _nullableText(attendance.note),
      'created_at': attendance.createdAt?.toUtc().toIso8601String() ?? now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<StudentAttendance>> getAttendance({
    int? studentId,
    DateTime? date,
  }) async {
    final database = await _appDatabase.database;
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (studentId != null) {
      conditions.add('student_id = ?');
      arguments.add(studentId);
    }
    if (date != null) {
      conditions.add('attendance_date = ?');
      arguments.add(_dateOnly(date));
    }
    final rows = await database.query(
      'student_attendance',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'attendance_date DESC, id DESC',
    );
    return rows
        .map(
          (row) => StudentAttendance(
            id: row['id'] as int,
            studentId: row['student_id'] as int,
            date: DateTime.parse(row['attendance_date'] as String),
            status: _attendanceStatusFromValue(row['status'] as String),
            note: row['note'] as String?,
            createdAt: _parseDateTime(row['created_at']),
            updatedAt: _parseDateTime(row['updated_at']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveDisciplineIncident(
    StudentDisciplineIncident incident,
  ) async {
    final database = await _appDatabase.database;
    await database.insert('student_discipline_incidents', {
      'student_id': incident.studentId,
      'incident_date': _dateOnly(incident.date),
      'description': incident.description.trim(),
      'created_at':
          incident.createdAt?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<StudentDisciplineIncident>> getDisciplineIncidents(
    int studentId,
  ) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'student_discipline_incidents',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'incident_date DESC, id DESC',
    );
    return rows
        .map(
          (row) => StudentDisciplineIncident(
            id: row['id'] as int,
            studentId: row['student_id'] as int,
            date: DateTime.parse(row['incident_date'] as String),
            description: row['description'] as String,
            createdAt: _parseDateTime(row['created_at']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> importStudents(List<Student> students) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    var imported = 0;
    await database.transaction((transaction) async {
      for (final student in students) {
        await transaction.insert('students', _studentValues(student, now));
        imported++;
      }
    });
    return imported;
  }

  Map<String, Object?> _studentValues(Student student, String now) {
    return {
      'full_name': student.fullName.trim(),
      'national_id': _nullableText(student.nationalId),
      'school_id': student.schoolId,
      'class_name': _nullableText(student.className),
      'section_name': _nullableText(student.sectionName),
      'school_number': _nullableText(student.schoolNumber),
      'birth_date': _dateOnlyOrNull(student.birthDate),
      'address': _nullableText(student.address),
      'phone': _nullableText(student.phone),
      'has_chronic_disease': student.hasChronicDisease ? 1 : 0,
      'chronic_disease_details': _nullableText(student.chronicDiseaseDetails),
      'has_allergy': student.hasAllergy ? 1 : 0,
      'allergy_details': _nullableText(student.allergyDetails),
      'regular_medication': _nullableText(student.regularMedication),
      'has_psychological_condition': student.hasPsychologicalCondition ? 1 : 0,
      'psychological_condition_details': _nullableText(
        student.psychologicalConditionDetails,
      ),
      'living_arrangement': student.livingArrangement.value,
      'mother_name': _nullableText(student.motherName),
      'father_name': _nullableText(student.fatherName),
      'mother_phone': _nullableText(student.motherPhone),
      'father_phone': _nullableText(student.fatherPhone),
      'mother_alive': student.motherAlive ? 1 : 0,
      'father_alive': student.fatherAlive ? 1 : 0,
      'parents_live_together': student.parentsLiveTogether.value,
      'guardian_name': _nullableText(student.guardianName),
      'guardian_relation': _nullableText(student.guardianRelation),
      'guardian_phone': _nullableText(student.guardianPhone),
      'emergency_contact_name': _nullableText(student.emergencyContactName),
      'emergency_contact_phone': _nullableText(student.emergencyContactPhone),
      'boarding_registration_date': _dateOnlyOrNull(
        student.boardingRegistrationDate,
      ),
      'created_at': student.createdAt?.toUtc().toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  Student _studentFromRow(Map<String, Object?> row) {
    return Student(
      id: row['id'] as int,
      fullName: row['full_name'] as String,
      nationalId: row['national_id'] as String?,
      schoolId: row['school_id'] as int?,
      schoolName: row['school_name'] as String?,
      className: row['class_name'] as String?,
      sectionName: row['section_name'] as String?,
      schoolNumber: row['school_number'] as String?,
      birthDate: _parseDateOnly(row['birth_date']),
      address: row['address'] as String?,
      phone: row['phone'] as String?,
      hasChronicDisease: _asBool(row['has_chronic_disease']),
      chronicDiseaseDetails: row['chronic_disease_details'] as String?,
      hasAllergy: _asBool(row['has_allergy']),
      allergyDetails: row['allergy_details'] as String?,
      regularMedication: row['regular_medication'] as String?,
      hasPsychologicalCondition: _asBool(row['has_psychological_condition']),
      psychologicalConditionDetails:
          row['psychological_condition_details'] as String?,
      livingArrangement: _livingArrangementFromValue(
        row['living_arrangement'] as String?,
      ),
      motherName: row['mother_name'] as String?,
      fatherName: row['father_name'] as String?,
      motherPhone: row['mother_phone'] as String?,
      fatherPhone: row['father_phone'] as String?,
      motherAlive: _asBool(row['mother_alive'], defaultValue: true),
      fatherAlive: _asBool(row['father_alive'], defaultValue: true),
      parentsLiveTogether: _parentLivingStatusFromValue(
        row['parents_live_together'] as String?,
      ),
      guardianName: row['guardian_name'] as String?,
      guardianRelation: row['guardian_relation'] as String?,
      guardianPhone: row['guardian_phone'] as String?,
      emergencyContactName: row['emergency_contact_name'] as String?,
      emergencyContactPhone: row['emergency_contact_phone'] as String?,
      boardingRegistrationDate: _parseDateOnly(
        row['boarding_registration_date'],
      ),
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }
}

StudentLivingArrangement _livingArrangementFromValue(String? value) {
  return StudentLivingArrangement.values.firstWhere(
    (item) => item.value == value,
    orElse: () => StudentLivingArrangement.withMotherFather,
  );
}

ParentLivingStatus _parentLivingStatusFromValue(String? value) {
  return ParentLivingStatus.values.firstWhere(
    (item) => item.value == value,
    orElse: () => ParentLivingStatus.together,
  );
}

StudentAttendanceStatus _attendanceStatusFromValue(String value) {
  return StudentAttendanceStatus.values.firstWhere(
    (item) => item.value == value,
    orElse: () => StudentAttendanceStatus.present,
  );
}

bool _asBool(Object? value, {bool defaultValue = false}) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  return defaultValue;
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _dateOnlyOrNull(DateTime? value) {
  return value == null ? null : _dateOnly(value);
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? _parseDateOnly(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
