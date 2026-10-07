import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/education_year/data/education_year_repository.dart';
import 'package:pansiyon_yonetim/features/education_year/data/education_year_scope.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('eğitim yılı hesapları', () {
    test('eylülden sonrası içinde bulunan yılın başlangıç yılıdır', () {
      expect(educationYearStartFor(DateTime(2025, 9, 1)), 2025);
      expect(educationYearStartFor(DateTime(2025, 12, 31)), 2025);
      expect(educationYearStartFor(DateTime(2026, 8, 31)), 2025);
      expect(educationYearStartFor(DateTime(2026, 9, 1)), 2026);
      // Ağustos, bir sonraki takvim yılının eylülünde başlayan yıla aittir.
      expect(educationYearStartFor(DateTime(2026, 1, 15)), 2025);
    });

    test('yıl etiketi başlangıç ve bitiş yılını gösterir', () {
      expect(EducationYear(startYear: 2025).label, '2025-2026');
      expect(EducationYear(startYear: 2025).endYear, 2026);
    });

    test('yıl ayları eylülden ağustusa sırayla gelir', () {
      final months = educationYearMonths(2025);
      expect(months, hasLength(12));
      expect(months.first, (year: 2025, month: 9));
      expect(months.last, (year: 2026, month: 8));
    });

    test('ayın ait olduğu yıl eylül sınırına göre çözülür', () {
      expect(educationYearStartOfMonth(2025, 10), 2025);
      expect(educationYearStartOfMonth(2026, 3), 2025);
      expect(educationYearStartOfMonth(2026, 9), 2026);
    });
  });

  group('eğitim yılı repository', () {
    late AppDatabase database;
    late SqliteEducationYearRepository repository;

    setUp(() async {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      repository = SqliteEducationYearRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('ilk kurulumda bugünün yılı etkin olur', () async {
      final active = await repository.getActiveYear();

      expect(active, isNotNull);
      expect(active!.startYear, currentEducationYearStart());
      expect(active.isActive, isTrue);
    });

    test('yeni yıl boş başlar ve etkin olmaz', () async {
      final before = currentEducationYearStart();
      final created = await repository.createYear(before + 1);

      expect(created.startYear, before + 1);
      expect(created.isActive, isFalse);
      // Etkin yıl değişmez.
      expect((await repository.getActiveYear())!.startYear, before);
    });

    test('yıl etkinleştirilince diğerleri pasifleşir', () async {
      final first = (await repository.getActiveYear())!.startYear;
      await repository.createYear(first + 1);

      await repository.setActiveYear(first + 1);

      final years = await repository.getYears();
      expect(years.where((year) => year.isActive).single.startYear, first + 1);
      expect(
        years.firstWhere((year) => year.startYear == first).isActive,
        isFalse,
      );
    });

    test('etkin yıl silinemez', () async {
      final active = (await repository.getActiveYear())!.startYear;

      await expectLater(
        repository.deleteYear(active),
        throwsA(isA<StateError>()),
      );
    });

    test('pasif yıl silinir ve içeriği temizlenir', () async {
      final active = (await repository.getActiveYear())!.startYear;
      final students = SqliteStudentRepository(database);
      await repository.createYear(active + 1);
      await students.transferStudents(
        studentIds: [
          await students.saveStudent(const Student(fullName: 'Ali Veli')),
        ],
        educationYear: active + 1,
      );

      await repository.deleteYear(active + 1);

      expect(
        (await repository.getYears()).any(
          (year) => year.startYear == active + 1,
        ),
        isFalse,
      );
      expect((await students.getStudents(educationYear: active + 1)), isEmpty);
    });

    test('yıl özeti içerik sayılarını verir', () async {
      final active = (await repository.getActiveYear())!.startYear;
      final students = SqliteStudentRepository(database);
      final duty = SqliteDutyRepository(database);
      await students.saveStudent(const Student(fullName: 'Zeynep Kaya'));
      await duty.saveTeacher(const DutyTeacher(fullName: 'Ali Öğretmen'));

      final summary = await repository.loadSummary(active);

      expect(summary.studentCount, 1);
      expect(summary.teacherCount, 1);
      expect(summary.isEmpty, isFalse);
    });
  });

  group('veriler yıla göre ayrılır', () {
    late AppDatabase database;
    late SqliteStudentRepository students;
    late SqliteDutyRepository duty;
    late EducationYearScope scope;

    const previousYear = 2024;
    const activeYear = 2025;

    setUp(() async {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      scope = EducationYearScope(database);
      students = SqliteStudentRepository(database, yearScope: scope);
      duty = SqliteDutyRepository(database, yearScope: scope);
      await database.database;

      final years = SqliteEducationYearRepository(database);
      await years.createYear(previousYear);
      await years.createYear(activeYear);
      await years.setActiveYear(activeYear);
      scope.setActiveYear(activeYear);
    });

    tearDown(() async {
      await database.close();
    });

    test('yeni kayıtlar etkin yıla alınır', () async {
      final id = await students.saveStudent(const Student(fullName: 'Yeni'));

      final saved = await students.getStudent(id);
      expect(saved!.educationYear, activeYear);
    });

    test('liste yalnızca etkin yılın öğrencilerini döndürür', () async {
      await students.saveStudent(
        Student(fullName: 'Bu Yılın Öğrencisi', educationYear: activeYear),
      );
      await students.saveStudent(
        Student(fullName: 'Geçen Yılın Öğrencisi', educationYear: previousYear),
      );

      final list = await students.getStudents();

      expect(list.map((student) => student.fullName), ['Bu Yılın Öğrencisi']);
    });

    test('yıl değişince liste değişir', () async {
      await students.saveStudent(
        Student(fullName: 'Bu Yılın Öğrencisi', educationYear: activeYear),
      );
      await students.saveStudent(
        Student(fullName: 'Geçen Yılın Öğrencisi', educationYear: previousYear),
      );

      scope.setActiveYear(previousYear);
      final previous = await students.getStudents();

      expect(previous.map((student) => student.fullName), [
        'Geçen Yılın Öğrencisi',
      ]);
    });

    test('öğretmenler yıla göre ayrılır', () async {
      await duty.saveTeacher(
        DutyTeacher(fullName: 'Bu Yılın Öğretmeni', educationYear: activeYear),
      );
      await duty.saveTeacher(
        DutyTeacher(
          fullName: 'Geçen Yılın Öğretmeni',
          educationYear: previousYear,
        ),
      );

      final list = await duty.getTeachers();

      expect(list.map((teacher) => teacher.fullName), ['Bu Yılın Öğretmeni']);
    });

    test('aktarım öğrenciyi hedef yıla taşır', () async {
      final id = await students.saveStudent(
        const Student(fullName: 'Taşınacak Öğrenci'),
      );

      final moved = await students.transferStudents(
        studentIds: [id],
        educationYear: previousYear,
      );

      expect(moved, 1);
      // Etkin yıldan çıkar, hedef yıla geçer.
      expect(await students.getStudents(), isEmpty);
      expect(
        (await students.getStudents(
          educationYear: previousYear,
        )).single.fullName,
        'Taşınacak Öğrenci',
      );
    });

    test('aktarım öğretmeni hedef yıla taşır', () async {
      final id = await duty.saveTeacher(
        const DutyTeacher(fullName: 'Taşınacak Öğretmen'),
      );

      final moved = await duty.transferTeachers(
        teacherIds: [id],
        educationYear: previousYear,
      );

      expect(moved, 1);
      expect(await duty.getTeachers(), isEmpty);
      expect(
        (await duty.getTeachers(educationYear: previousYear)).single.fullName,
        'Taşınacak Öğretmen',
      );
    });

    test('nöbet listeleri ayın ait olduğu yıla göre saklanır', () async {
      // Ekim 2025 -> 2025-2026 yılı
      await duty.createMonthList(year: 2025, month: 10, sectionKey: null);
      // Mart 2026 -> 2025-2026 yılı da
      await duty.createMonthList(year: 2026, month: 3, sectionKey: null);
      // Eylül 2024 -> 2024-2025 yılı
      await duty.createMonthList(year: 2024, month: 9, sectionKey: null);

      final lists = await duty.getMonthLists(educationYear: activeYear);
      final months = lists.map((list) => list.month).toSet();

      expect(months, {10, 3});
      expect(
        (await duty.getMonthLists(
          educationYear: previousYear,
        )).map((list) => list.month),
        [9],
      );
    });

    test('aynı ay iki farklı yılda ayrı listeler olarak tutulur', () async {
      await duty.createMonthList(year: 2024, month: 10, sectionKey: null);
      await duty.createMonthList(year: 2025, month: 10, sectionKey: null);

      expect((await duty.getMonthLists(educationYear: 2024)), hasLength(1));
      expect((await duty.getMonthLists(educationYear: 2025)), hasLength(1));
    });
  });
}
