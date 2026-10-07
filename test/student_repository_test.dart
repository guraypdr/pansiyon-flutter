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

  test('içe aktarılan öğrenciler etkin yıla alınır', () async {
    // Regresyon: education_year sütunu NOT NULL. Yazma yolu bu sütunu
    // atladığında içe aktarma "Excel dosyası okunamadı" gibi görünen bir
    // veritabanı hatasıyla tümüyle başarısız oluyordu.
    final imported = await repository.importStudents([
      const Student(fullName: 'Ali Yılmaz', className: '9'),
      const Student(fullName: 'Veli Kaya', className: '9'),
    ]);

    expect(imported.added, 2);
    expect(imported.updated, 0);

    // Aktif yıl varsayılan olarak listelenir; yıl dolu gelmelidir.
    final students = await repository.getStudents();
    expect(students, hasLength(2));
    for (final student in students) {
      expect(student.educationYear, isNotNull);
    }
    expect(students.first.educationYear, students.last.educationYear);
  });

  test('aynı T.C. ile içe aktarım kaydı günceller, yenisini açmaz', () async {
    await repository.saveStudent(
      const Student(fullName: 'İsmet Yıldız', nationalId: '12345678901'),
    );

    final result = await repository.importStudents([
      const Student(fullName: 'İsmet Yıldız', nationalId: '12345678901'),
    ]);

    expect(result.added, 0);
    expect(result.updated, 1);
    expect(await repository.getStudents(), hasLength(1));
  });

  test('güncellemede Excel dolu alanlar yazılır, boşlar korunur', () async {
    await repository.saveStudent(
      const Student(
        fullName: 'İsmet Yıldız',
        nationalId: '12345678901',
        address: 'Eski Adres',
        phone: '05320000000',
        guardianPhone: '0530 693 69 25',
        hasChronicDisease: true,
        chronicDiseaseDetails: 'Astım',
      ),
    );

    // Excel'de telefon değişmiş ve veli adı eklenmiş; adres, veli telefonu
    // ve sağlık alanları boş bırakılmış.
    await repository.importStudents(
      const [
        Student(
          fullName: 'İsmet Yıldız',
          nationalId: '12345678901',
          phone: '0555 111 22 33',
          guardianName: 'İsmet Veli',
        ),
      ],
      filledFieldsByIndex: {
        0: {'fullName', 'nationalId', 'phone', 'guardianName'},
      },
    );

    final student = (await repository.getStudents()).single;

    // Değişen ve eklenen alanlar yazıldı.
    expect(student.phone, '0555 111 22 33');
    expect(student.guardianName, 'İsmet Veli');

    // Excel'de boş olan alanlar korundu.
    expect(student.address, 'Eski Adres');
    expect(student.guardianPhone, '0530 693 69 25');
    expect(student.hasChronicDisease, isTrue);
    expect(student.chronicDiseaseDetails, 'Astım');
  });

  test('ayni okulda ayni okul numarasi reddedilir', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );
    await repository.saveStudent(
      Student(
        fullName: 'Ali Veli',
        nationalId: '11111111111',
        schoolId: schoolId,
        schoolNumber: '2026-001',
      ),
    );

    await expectLater(
      repository.importStudents([
        Student(
          fullName: 'Veli Kaya',
          nationalId: '22222222222',
          schoolId: schoolId,
          schoolNumber: '2026-001',
        ),
      ]),
      throwsA(isA<StudentDataIntegrityException>()),
    );
  });

  test('içe aktarımda verilen yıl korunur', () async {
    await repository.importStudents([
      const Student(fullName: 'Ali Yılmaz', educationYear: 2024),
    ]);

    final student = (await repository.getStudents(educationYear: 2024)).single;
    expect(student.educationYear, 2024);
  });

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
        guardianName: 'Ayşe Yılmaz',
        guardianPhone: '05321234567',
        guardian2Name: 'Mehmet Yılmaz',
        guardian2Phone: '05327654321',
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
    expect(student.guardianPhone, '0532 123 45 67');
    expect(student.guardian2Name, 'Mehmet Yılmaz');
    expect(student.guardian2Phone, '0532 765 43 21');
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

  test(
    'şubeler sınıf düzeyine göre kaydedilir ve büyük harfe çevrilir',
    () async {
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
    },
  );

  test('okul adı değişince şube tanımları korunur', () async {
    final schoolId = await repository.saveSchool(
      const School(name: 'Atatürk Lisesi'),
    );
    await repository.saveSchoolSections(
      schoolId: schoolId,
      className: '9',
      sections: ['A', 'B'],
    );

    await repository.saveSchool(
      School(id: schoolId, name: 'Cumhuriyet Lisesi'),
    );

    final school = (await repository.getSchools()).single;
    expect(school.name, 'Cumhuriyet Lisesi');
    expect(school.sectionsFor('9'), ['A', 'B']);
  });

  test('sınıf ve şube kart görünümünde doğru birleşir', () {
    expect(formatClassSectionLabel('9', 'A'), '9/A');
    expect(formatClassSectionLabel('9', 'GD'), '9/GD');
    expect(formatClassSectionLabel('9', '9/A'), '9/A');
    expect(formatClassSectionLabel('9', null), '9. Sınıf (Şube eklenmedi)');
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
