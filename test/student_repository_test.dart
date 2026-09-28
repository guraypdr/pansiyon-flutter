import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late SqliteStudentRepository repository;

  setUp(() {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    repository = SqliteStudentRepository(database);
  });

  tearDown(() => database.close());

  test('okul ve öğrenci bilgilerini kaydedip listeler', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );
    final studentId = await repository.saveStudent(
      Student(
        fullName: 'Ahmet Yılmaz',
        gender: StudentGender.male,
        nationalId: '12345678901',
        schoolId: schoolId,
        className: '11',
        sectionName: 'A',
        schoolNumber: '2026-001',
        birthDate: DateTime(2010, 5, 12),
        phone: '05321234567',
        motherName: 'Ayşe Yılmaz',
        fatherName: 'Mehmet Yılmaz',
        motherPhone: '05321234567',
        fatherPhone: '05327654321',
        boardingRegistrationDate: DateTime(2026, 9, 1),
      ),
    );

    final students = await repository.getStudents(query: 'ahmet');
    final student = await repository.getStudent(studentId);

    expect(students, hasLength(1));
    expect(student!.fullName, 'Ahmet Yılmaz');
    expect(student.gender, StudentGender.male);
    expect(student.schoolName, 'Atatürk Lisesi');
    expect(student.className, '11');
    expect(student.birthDate, DateTime(2010, 5, 12));
    expect(student.motherPhone, '0532 123 45 67');
  });

  test('T.C. Kimlik No ve okul numarası tekrarlarını reddeder', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );
    final firstStudentId = await repository.saveStudent(
      Student(
        fullName: 'Ahmet Yılmaz',
        nationalId: '12345678901',
        schoolId: schoolId,
        schoolNumber: '2026-001',
      ),
    );

    await expectLater(
      repository.saveStudent(
        const Student(
          fullName: 'Ayşe Kaya',
          nationalId: '12345678901',
          schoolNumber: '2026-002',
        ),
      ),
      throwsA(
        isA<StudentDataIntegrityException>().having(
          (error) => error.message,
          'message',
          'Bu T.C. Kimlik No başka bir öğrenciye ait.',
        ),
      ),
    );
    await expectLater(
      repository.saveStudent(
        Student(
          fullName: 'Mehmet Demir',
          nationalId: '12345678902',
          schoolId: schoolId,
          schoolNumber: '2026-001',
        ),
      ),
      throwsA(
        isA<StudentDataIntegrityException>().having(
          (error) => error.message,
          'message',
          'Bu okul numarası aynı okulda başka bir öğrenciye ait.',
        ),
      ),
    );

    await repository.saveStudent(
      Student(
        id: firstStudentId,
        fullName: 'Ahmet Yılmaz Güncel',
        nationalId: '12345678901',
        schoolId: schoolId,
        schoolNumber: '2026-001',
      ),
    );
    expect((await repository.getStudents()), hasLength(1));
  });

  test('kimlik ve okul numarası boş olan öğrenciler tekrarlanabilir', () async {
    await repository.saveStudent(const Student(fullName: 'Öğrenci Bir'));
    await repository.saveStudent(const Student(fullName: 'Öğrenci İki'));

    expect(await repository.getStudents(), hasLength(2));
  });

  test('okunan öğrenci metin ve telefon alanlarını biçimlendirir', () async {
    final studentId = await repository.saveStudent(
      const Student(
        fullName: 'ALİ YILMAZ',
        className: '11-A',
        sectionName: 'A',
        address: 'İSTANBUL KADIKÖY',
        phone: '05321234567',
        regularMedication: 'İLAÇ A',
      ),
    );

    final student = await repository.getStudent(studentId);

    expect(student!.fullName, 'Ali Yılmaz');
    expect(student.className, '11-A');
    expect(student.sectionName, 'A');
    expect(student.address, 'İstanbul Kadıköy');
    expect(student.phone, '0532 123 45 67');
    expect(student.regularMedication, 'İlaç A');
  });

  test('günlük izin ve disiplin kayıtlarını saklar', () async {
    final studentId = await repository.saveStudent(
      const Student(fullName: 'Deniz Kaya'),
    );
    final date = DateTime(2026, 9, 25);

    await repository.saveAttendance(
      StudentAttendance(
        studentId: studentId,
        date: date,
        status: StudentAttendanceStatus.homeLeave,
        note: 'Aile izni',
      ),
    );
    await repository.saveDisciplineIncident(
      StudentDisciplineIncident(
        studentId: studentId,
        date: date,
        description: 'Örnek disiplin kaydı',
      ),
    );

    final attendance = await repository.getAttendance(
      studentId: studentId,
      date: date,
    );
    final incidents = await repository.getDisciplineIncidents(studentId);

    expect(attendance.single.status, StudentAttendanceStatus.homeLeave);
    expect(attendance.single.note, 'Aile izni');
    expect(incidents.single.description, 'Örnek disiplin kaydı');
  });

  test('aynı öğrenci ve tarih için yoklama kaydını günceller', () async {
    final studentId = await repository.saveStudent(
      const Student(fullName: 'Elif Demir'),
    );
    final date = DateTime(2026, 9, 25);

    await repository.saveAttendance(
      StudentAttendance(
        studentId: studentId,
        date: date,
        status: StudentAttendanceStatus.present,
      ),
    );
    await repository.saveAttendance(
      StudentAttendance(
        studentId: studentId,
        date: date,
        status: StudentAttendanceStatus.medicalReport,
      ),
    );

    final attendance = await repository.getAttendance(
      studentId: studentId,
      date: date,
    );

    expect(attendance, hasLength(1));
    expect(attendance.single.status, StudentAttendanceStatus.medicalReport);
  });

  test('şubeler sınıf düzeyine göre kaydedilir ve büyük harfe çevrilir', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );

    await repository.saveSchoolSections(
      schoolId: schoolId,
      className: '9',
      sections: ['a', 'gd'],
    );
    await repository.saveSchoolSections(
      schoolId: schoolId,
      className: '10',
      sections: ['B'],
    );

    expect(await repository.getSchoolSections(schoolId, '9'), ['A', 'GD']);
    expect(await repository.getSchoolSections(schoolId, '10'), ['B']);
    expect(await repository.getSchoolSections(schoolId, '11'), isEmpty);

    final school = (await repository.getSchools()).single;
    expect(school.sectionsFor('9'), ['A', 'GD']);
    expect(school.sectionsFor('10'), ['B']);
    expect(school.sectionsFor('11'), isEmpty);
  });

  test('okul adı değişince şube tanımları korunur', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );
    await repository.saveSchoolSections(
      schoolId: schoolId,
      className: '9',
      sections: ['A', 'B'],
    );

    await repository.saveSchool(School(id: schoolId, name: 'Cumhuriyet Lisesi'));

    final school = (await repository.getSchools()).single;
    expect(school.name, 'Cumhuriyet Lisesi');
    expect(school.sectionsFor('9'), ['A', 'B']);
  });

  test('sınıf ve şube kart görünümünde doğru birleşir', () {
    expect(formatClassSectionLabel('9', 'A'), '9/A');
    expect(formatClassSectionLabel('9', 'GD'), '9/GD');
    expect(formatClassSectionLabel('9', '9/A'), '9/A');
    expect(
      formatClassSectionLabel('9', null),
      '9. Sınıf (Şube eklenmedi)',
    );
    expect(formatClassSectionLabel(null, 'A'), 'A');
    expect(formatClassSectionLabel(null, null), '');
  });

  test('kan grubu listesi tüm grupları ve bilinmeyeni içerir', () {
    expect(bloodGroupOptions, contains('0 Rh-'));
    expect(bloodGroupOptions, contains('AB Rh+'));
    expect(bloodGroupOptions, contains('Bilinmiyor'));
    expect(bloodGroupOptions, hasLength(9));
  });
}
