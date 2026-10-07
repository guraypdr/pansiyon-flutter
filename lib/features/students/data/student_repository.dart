import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/education_year/data/education_year_scope.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';
import 'package:pansiyon_yonetim/features/students/data/student_excel_importer.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class StudentDataIntegrityException implements Exception {
  const StudentDataIntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Excel sütun anahtarı ile veritabanı sütun adı eşleşmesi.
///
/// İçe aktarma, Excel'de dolu olan alanları bildirir; bu alanlar veritabanı
/// sütun adlarıyla eşleştirilerek yazılır. Eşleşme yapılmazsa yalnızca
/// dolu hücreler korunur, dolu hücreli alanlar yanlışlıkla atlanır.
const _modelKeyByColumn = <String, String>{
  'full_name': 'fullName',
  'gender': 'gender',
  'national_id': 'nationalId',
  'school_id': 'school_id',
  'class_name': 'className',
  'section_name': 'sectionName',
  'school_number': 'schoolNumber',
  'birth_date': 'birthDate',
  'address': 'address',
  'phone': 'phone',
  'has_chronic_disease': 'chronicDisease',
  'chronic_disease_details': 'chronicDiseaseDetails',
  'has_allergy': 'allergy',
  'allergy_details': 'allergyDetails',
  'regular_medication': 'medication',
  'blood_type': 'bloodType',
  'has_psychological_condition': 'psychological',
  'psychological_condition_details': 'psychologicalDetails',
  'guardian_name': 'guardianName',
  'guardian_relation': 'guardianRelation',
  'guardian_phone': 'guardianPhone',
  'guardian_address': 'guardianAddress',
  'guardian2_name': 'guardian2Name',
  'guardian2_relation': 'guardian2Relation',
  'guardian2_phone': 'guardian2Phone',
  'guardian2_address': 'guardian2Address',
  'emergency_contact_name': 'emergencyContactName',
  'emergency_contact_phone': 'emergencyContactPhone',
  'boarding_registration_date': 'boardingRegistrationDate',
  'education_year': 'educationYear',
};

/// İçe aktarmanın kaç kayıt eklediğini ve kaç kaydı güncellediğini bildirir.
class StudentImportResult {
  const StudentImportResult({required this.added, required this.updated});

  /// Yeni açılan kayıt sayısı.
  final int added;

  /// T.C. Kimlik No eşleşmesiyle güncellenen kayıt sayısı.
  final int updated;

  int get total => added + updated;
}

abstract interface class StudentRepository {
  Future<List<Student>> getStudents({String query = '', int? educationYear});

  Future<Student?> getStudent(int id);

  Future<int> saveStudent(Student student);

  /// Öğrencileri verilen eğitim öğretim yılına taşır.
  ///
  /// Aktarım kopyalama değil taşımadır: öğrenci kaydı korunur, yılı
  /// değiştirilir. Dönen değer taşınan öğrenci sayısıdır.
  Future<int> transferStudents({
    required List<int> studentIds,
    required int educationYear,
  });

  Future<void> deleteStudent(int id);

  Future<List<School>> getSchools();

  /// Bir okulun belirli bir sınıf düzeyi için tanımlı şubelerini döndürür.
  Future<List<String>> getSchoolSections(int schoolId, String className);

  /// Okulun bir sınıf düzeyi için şubelerini kaydeder; boş listeye temizler.
  Future<void> saveSchoolSections({
    required int schoolId,
    required String className,
    required List<String> sections,
  });

  Future<int> saveSchool(School school);

  /// Okulu siler; bu okula bağlı öğrencilerin okul bağlantısı boşalır.
  ///
  /// Dönen değer silinen öğrenci sayısıdır.
  Future<int> deleteSchool(int id);

  Future<void> saveAttendance(StudentAttendance attendance);

  Future<List<StudentAttendance>> getAttendance({
    int? studentId,
    DateTime? date,
  });

  /// Belirtilen öğrencinin izin/rapor geçmişini en yeniden eskiye doğru döner.
  Future<List<StudentAttendance>> getAttendanceHistory(int studentId);

  Future<void> saveDisciplineIncident(StudentDisciplineIncident incident);

  Future<List<StudentDisciplineIncident>> getDisciplineIncidents(int studentId);

  /// Tüm disiplin kayıtlarını öğrenci adıyla birlikte en yeniden eskiye doğru döner.
  Future<List<StudentDisciplineIncident>> getAllDisciplineIncidents();

  Future<void> deleteDisciplineIncident(int id);

  Future<StudentImportResult> importStudents(
    List<Student> students, {
    Map<int, Set<String>> filledFieldsByIndex = const {},
  });
}

class SqliteStudentRepository implements StudentRepository {
  SqliteStudentRepository(this._appDatabase, {EducationYearScope? yearScope})
    : _yearScope = yearScope ?? EducationYearScope(_appDatabase);

  final AppDatabase _appDatabase;
  final EducationYearScope _yearScope;

  @override
  Future<List<Student>> getStudents({
    String query = '',
    int? educationYear,
  }) async {
    final database = await _appDatabase.database;
    final year = educationYear ?? await _yearScope.activeYear();
    final normalizedQuery = query.trim();
    final conditions = <String>['s.education_year = ?'];
    final parameters = <Object?>[year];
    if (normalizedQuery.isNotEmpty) {
      conditions.add(
        '(s.full_name LIKE ? OR s.school_number LIKE ? OR s.national_id LIKE ?)',
      );
      parameters.addAll([
        '%$normalizedQuery%',
        '%$normalizedQuery%',
        '%$normalizedQuery%',
      ]);
    }
    final rows = await database.rawQuery('''
      SELECT s.*, sch.name AS school_name
      FROM students s
      LEFT JOIN schools sch ON sch.id = s.school_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY s.full_name COLLATE NOCASE ASC
      ''', parameters);
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
    // Yeni kayıtlar etkin yıla alınır; mevcut kayıt yılını korur.
    final educationYear =
        student.educationYear ?? await _yearScope.activeYear();
    final values = _studentValues(student, now, educationYear);
    final id = student.id;

    return database.transaction((transaction) async {
      await _validateStudentUniqueness(transaction, student);
      if (id == null) {
        return transaction.insert('students', values);
      }

      await transaction.update(
        'students',
        values..remove('created_at'),
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    });
  }

  @override
  Future<int> transferStudents({
    required List<int> studentIds,
    required int educationYear,
  }) async {
    if (studentIds.isEmpty) {
      return 0;
    }
    final database = await _appDatabase.database;
    final placeholders = List.filled(studentIds.length, '?').join(', ');
    final updated = await database.update(
      'students',
      {'education_year': educationYear},
      where: 'id IN ($placeholders)',
      whereArgs: studentIds,
    );
    return updated;
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
    if (rows.isEmpty) {
      return const [];
    }
    final sectionRows = await database.query(
      'school_sections',
      orderBy: 'school_id, class_name, sort_order, name',
    );
    final sectionsBySchool = <int, Map<String, List<String>>>{};
    for (final row in sectionRows) {
      final schoolId = row['school_id'] as int;
      final className = (row['class_name'] as String?) ?? '';
      final classes = sectionsBySchool.putIfAbsent(
        schoolId,
        () => <String, List<String>>{},
      );
      (classes[className] ??= <String>[]).add(row['name'] as String);
    }

    final schools = <School>[];
    for (final row in rows) {
      final schoolId = row['id'] as int;
      schools.add(
        School(
          id: schoolId,
          name: row['name'] as String,
          sectionsByClass: sectionsBySchool[schoolId] ?? const {},
        ),
      );
    }
    return schools;
  }

  @override
  Future<List<String>> getSchoolSections(int schoolId, String className) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'school_sections',
      where: 'school_id = ? AND class_name = ?',
      whereArgs: [schoolId, className.trim()],
      orderBy: 'sort_order, name',
    );
    return [for (final row in rows) row['name'] as String];
  }

  @override
  Future<void> saveSchoolSections({
    required int schoolId,
    required String className,
    required List<String> sections,
  }) async {
    final level = className.trim();
    final database = await _appDatabase.database;
    await database.transaction((txn) async {
      await txn.delete(
        'school_sections',
        where: 'school_id = ? AND class_name = ?',
        whereArgs: [schoolId, level],
      );
      for (var index = 0; index < sections.length; index++) {
        final section = sections[index].trim().toUpperCase();
        if (section.isEmpty) {
          continue;
        }
        await txn.insert('school_sections', {
          'school_id': schoolId,
          'class_name': level,
          'name': section,
          'sort_order': index,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
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
  Future<int> deleteSchool(int id) async {
    final database = await _appDatabase.database;
    // Öğrenciler silinmez; yalnızca okul bağlantıları boşalır.
    final detached = await database.update(
      'students',
      {'school_id': null},
      where: 'school_id = ?',
      whereArgs: [id],
    );
    await database.delete('schools', where: 'id = ?', whereArgs: [id]);
    return detached;
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
  Future<List<StudentAttendance>> getAttendanceHistory(int studentId) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'student_attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
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
  Future<List<StudentDisciplineIncident>> getAllDisciplineIncidents() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery('''
      SELECT d.*, s.full_name AS student_name
      FROM student_discipline_incidents d
      INNER JOIN students s ON s.id = d.student_id
      ORDER BY d.incident_date DESC, d.id DESC
    ''');
    return rows
        .map(
          (row) => StudentDisciplineIncident(
            id: row['id'] as int,
            studentId: row['student_id'] as int,
            date: DateTime.parse(row['incident_date'] as String),
            description: row['description'] as String,
            studentName: row['student_name'] as String?,
            createdAt: _parseDateTime(row['created_at']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> deleteDisciplineIncident(int id) async {
    final database = await _appDatabase.database;
    await database.delete(
      'student_discipline_incidents',
      where: 'id = ?',
      whereArgs: [id],
    );
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
  Future<StudentImportResult> importStudents(
    List<Student> students, {
    Map<int, Set<String>> filledFieldsByIndex = const {},
  }) async {
    if (students.length > StudentExcelImporter.maxDataRows) {
      throw const StudentDataIntegrityException(
        'Tek seferde en fazla 300 öğrenci içe aktarılabilir.',
      );
    }
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    // İçe aktarılan kayıtlar da etkin eğitim yılına alınır; sütun NOT NULL
    // olduğu için bu çözümleme yapılmazsa yazma işlemi patlar.
    final activeYear = await _yearScope.activeYear();
    var added = 0;
    var updated = 0;
    await database.transaction((transaction) async {
      for (var index = 0; index < students.length; index++) {
        final student = students[index];
        final filled = filledFieldsByIndex[index];

        // T.C. Kimlik No ile eşleşen kayıt varsa yeni kayıt açılmaz,
        // mevcut kayıt güncellenir. Böylece düzeltme için yeniden içe
        // aktarma yapılabilir.
        final existingId = await _findExistingId(transaction, student);
        if (existingId == null) {
          await _validateStudentUniqueness(transaction, student);
          await transaction.insert(
            'students',
            _studentValues(student, now, student.educationYear ?? activeYear),
          );
          added++;
          continue;
        }

        await _validateStudentUniqueness(
          transaction,
          student.copyWith(id: existingId),
        );
        final merged = await _mergeForUpdate(
          transaction,
          existingId: existingId,
          student: student,
          now: now,
          activeYear: activeYear,
          filled: filled,
        );
        await transaction.update(
          'students',
          merged,
          where: 'id = ?',
          whereArgs: [existingId],
        );
        updated++;
      }
    });
    return StudentImportResult(added: added, updated: updated);
  }

  /// T.C. Kimlik No ile aynı kaydı bulur.
  ///
  /// Tek eşleştirme kuralı budur: öğrenci yalnızca T.C. Kimlik No ile
  /// tanınır. Okul numarası eşleştirmede kullanılmaz; T.C. numarası olmayan
  /// öğrenci içe aktarılamaz.
  Future<int?> _findExistingId(
    DatabaseExecutor executor,
    Student student,
  ) async {
    final nationalId = student.nationalId?.trim();
    if (nationalId == null || nationalId.isEmpty) {
      return null;
    }
    final rows = await executor.query(
      'students',
      columns: ['id'],
      where: 'TRIM(national_id) = ?',
      whereArgs: [nationalId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  /// Güncelleme için satır değerlerini hazırlar.
  ///
  /// [filled] verildiğinde yalnızca Excel'de dolu olan sütunlar yazılır;
  /// boş bırakılan hücreler kayıttaki mevcut değerini korur. Böylece
  /// "yalnızca Veli Adı'nı düzeltmek" için yapılan içe aktarma diğer
  /// alanları boşaltmaz.
  ///
  /// `created_at` hiçbir zaman değiştirilmez.
  Future<Map<String, Object?>> _mergeForUpdate(
    DatabaseExecutor executor, {
    required int existingId,
    required Student student,
    required String now,
    required int activeYear,
    required Set<String>? filled,
  }) async {
    final values = _studentValues(
      student,
      now,
      student.educationYear ?? activeYear,
    );
    values.remove('created_at');

    if (filled == null) {
      return values;
    }

    final current = await executor.query(
      'students',
      where: 'id = ?',
      whereArgs: [existingId],
      limit: 1,
    );
    if (current.isEmpty) {
      return values;
    }
    final existing = current.first;
    for (final column in values.keys.toList()) {
      final modelKey = _modelKeyByColumn[column];
      if (modelKey != null && filled.contains(modelKey)) {
        // Excel'de dolu: gelen değer yazılır. Böylece değişmiş telefon
        // veya veli bilgileri kayıtta güncellenir.
        continue;
      }
      // Excel'de boş: kayıttaki mevcut değer korunur.
      if (existing.containsKey(column)) {
        values[column] = existing[column];
      }
    }
    return values;
  }

  Future<void> _validateStudentUniqueness(
    DatabaseExecutor executor,
    Student student,
  ) async {
    // Tek tekrar kontrolü T.C. Kimlik No üzerinden yapılır. Okul numarası
    // bir kimlik değildir ve karşılaştırmada kullanılmaz.
    //
    // T.C. numarasının zorunlu olması giriş katmanında uygulanır (form ve
    // Excel içe aktarma). Burada numara boşsa karşılaştırılacak bir şey
    // yoktur; iç yazma yolları (testler, yedek geri yükleme) numarasız
    // kayıt kurabilmelidir.
    final nationalId = student.nationalId?.trim();
    if (nationalId == null || nationalId.isEmpty) {
      return;
    }
    final existing = await executor.query(
      'students',
      columns: ['id'],
      where: 'TRIM(national_id) = ? AND id != ?',
      whereArgs: [nationalId, student.id ?? -1],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const StudentDataIntegrityException(
        'Bu T.C. Kimlik No başka bir öğrenciye ait.',
      );
    }
  }

  /// Öğrenciyi `students` tablosunun satır değerlerine çevirir.
  ///
  /// [educationYear] zorunludur: sütun `NOT NULL` olduğu için atlanırsa
  /// yazma işlemi çalışma anında patlar. Zorunlu olması, yeni bir yazma
  /// yolunun bu sütunu unutmasını engeller.
  Map<String, Object?> _studentValues(
    Student student,
    String now,
    int educationYear,
  ) {
    return {
      'full_name': student.fullName.trim(),
      'gender': student.gender?.value,
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
      'blood_type': _nullableText(student.bloodType),
      'has_psychological_condition': student.hasPsychologicalCondition ? 1 : 0,
      'psychological_condition_details': _nullableText(
        student.psychologicalConditionDetails,
      ),
      'guardian_name': _nullableText(student.guardianName),
      'guardian_relation': _nullableText(student.guardianRelation),
      'guardian_phone': _nullableText(student.guardianPhone),
      'guardian_address': _nullableText(student.guardianAddress),
      'guardian2_name': _nullableText(student.guardian2Name),
      'guardian2_relation': _nullableText(student.guardian2Relation),
      'guardian2_phone': _nullableText(student.guardian2Phone),
      'guardian2_address': _nullableText(student.guardian2Address),
      'emergency_contact_name': _nullableText(student.emergencyContactName),
      'emergency_contact_phone': _nullableText(student.emergencyContactPhone),
      'boarding_registration_date': _dateOnlyOrNull(
        student.boardingRegistrationDate,
      ),
      'education_year': educationYear,
      'created_at': student.createdAt?.toUtc().toIso8601String() ?? now,
      'updated_at': now,
    };
  }

  Student _studentFromRow(Map<String, Object?> row) {
    return Student(
      id: row['id'] as int,
      fullName: _formatRequiredText(row['full_name']),
      gender: studentGenderFromValue(row['gender'] as String?),
      nationalId: row['national_id'] as String?,
      schoolId: row['school_id'] as int?,
      schoolName: _formatOptionalText(row['school_name']),
      className: _formatOptionalText(row['class_name']),
      // Şube kodu büyük harfli kısaltmalardır (A, GD); biçim değiştirilmez.
      sectionName: _rawText(row['section_name']),
      schoolNumber: _nullableText(row['school_number'] as String?),
      birthDate: _parseDateOnly(row['birth_date']),
      address: _formatOptionalText(row['address']),
      phone: _formatOptionalPhone(row['phone']),
      hasChronicDisease: _asBool(row['has_chronic_disease']),
      chronicDiseaseDetails: _formatOptionalText(
        row['chronic_disease_details'],
      ),
      hasAllergy: _asBool(row['has_allergy']),
      allergyDetails: _formatOptionalText(row['allergy_details']),
      regularMedication: _formatOptionalText(row['regular_medication']),
      bloodType: _formatOptionalText(row['blood_type']),
      hasPsychologicalCondition: _asBool(row['has_psychological_condition']),
      psychologicalConditionDetails: _formatOptionalText(
        row['psychological_condition_details'],
      ),
      guardianName: _formatOptionalText(row['guardian_name']),
      guardianRelation: _formatOptionalText(row['guardian_relation']),
      guardianPhone: _formatOptionalPhone(row['guardian_phone']),
      guardianAddress: _formatOptionalText(row['guardian_address']),
      guardian2Name: _formatOptionalText(row['guardian2_name']),
      guardian2Relation: _formatOptionalText(row['guardian2_relation']),
      guardian2Phone: _formatOptionalPhone(row['guardian2_phone']),
      guardian2Address: _formatOptionalText(row['guardian2_address']),
      emergencyContactName: _formatOptionalText(row['emergency_contact_name']),
      emergencyContactPhone: _formatOptionalPhone(
        row['emergency_contact_phone'],
      ),
      boardingRegistrationDate: _parseDateOnly(
        row['boarding_registration_date'],
      ),
      educationYear: row['education_year'] as int?,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }
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

String _formatRequiredText(Object? value) {
  return capitalizeWords(value?.toString().trim() ?? '');
}

String? _formatOptionalText(Object? value) {
  final formatted = _formatRequiredText(value);
  return formatted.isEmpty ? null : formatted;
}

String? _formatOptionalPhone(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : formatPhoneNumber(text);
}

String? _rawText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
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
