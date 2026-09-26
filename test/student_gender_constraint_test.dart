import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_form_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('pansiyon türüne göre cinsiyet kuralları', () {
    test('karma pansiyonda iki cinsiyet seçilebilir', () {
      expect(
        allowedGendersForBoardingType(BoardingType.mixed),
        StudentGender.values,
      );
      expect(lockedGenderForBoardingType(BoardingType.mixed), isNull);
    });

    test('kız pansiyonunda cinsiyet kıza kilitlidir', () {
      expect(allowedGendersForBoardingType(BoardingType.girls), [
        StudentGender.female,
      ]);
      expect(
        lockedGenderForBoardingType(BoardingType.girls),
        StudentGender.female,
      );
    });

    test('erkek pansiyonunda cinsiyet erkeğe kilitlidir', () {
      expect(allowedGendersForBoardingType(BoardingType.boys), [
        StudentGender.male,
      ]);
      expect(
        lockedGenderForBoardingType(BoardingType.boys),
        StudentGender.male,
      );
    });

    test('pansiyon bilgisi yoksa cinsiyet serbesttir', () {
      expect(allowedGendersForBoardingType(null), StudentGender.values);
      expect(lockedGenderForBoardingType(null), isNull);
    });

    test('kurallı öğrenci kız pansiyonunda kız olur', () {
      const student = Student(
        fullName: 'Ali Veli',
        gender: StudentGender.male,
        className: '9',
      );

      final (constrained, corrected) = applyBoardingGenderConstraint(
        student,
        BoardingType.girls,
      );

      expect(constrained.gender, StudentGender.female);
      expect(corrected, isTrue);
      expect(constrained.fullName, 'Ali Veli');
    });

    test('kurallı öğrenci erkek pansiyonunda erkek olur', () {
      const student = Student(
        fullName: 'Deniz Kaya',
        gender: StudentGender.female,
      );

      final (constrained, corrected) = applyBoardingGenderConstraint(
        student,
        BoardingType.boys,
      );

      expect(constrained.gender, StudentGender.male);
      expect(corrected, isTrue);
    });

    test('karma pansiyonda cinsiyet değişmez', () {
      const student = Student(fullName: 'Ali Veli', gender: StudentGender.male);

      final (constrained, corrected) = applyBoardingGenderConstraint(
        student,
        BoardingType.mixed,
      );

      expect(constrained.gender, StudentGender.male);
      expect(corrected, isFalse);
    });

    test('cinsiyeti uygun öğrenci yeniden düzeltilmez', () {
      const student = Student(
        fullName: 'Zeynep Şahin',
        gender: StudentGender.female,
      );

      final (constrained, corrected) = applyBoardingGenderConstraint(
        student,
        BoardingType.girls,
      );

      expect(constrained.gender, StudentGender.female);
      expect(corrected, isFalse);
    });
  });

  group('öğrenci formunda cinsiyet alanı', () {
    late AppDatabase database;
    late SqliteStudentRepository repository;

    setUp(() {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      repository = SqliteStudentRepository(database);
    });

    tearDown(() => database.close());

    Future<void> pumpForm(
      WidgetTester tester, {
      required BoardingType boardingType,
      Student? student,
    }) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await database.database;
        await repository.saveStudent(
          student ??
              const Student(fullName: 'Ali Veli', gender: StudentGender.male),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StudentFormDialog(
              repository: repository,
              schools: const [],
              boardingType: boardingType,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    testWidgets('kız pansiyonunda cinsiyet kilitli görünür', (tester) async {
      await pumpForm(tester, boardingType: BoardingType.girls);

      expect(find.byKey(const Key('gender_locked_field')), findsOneWidget);
      expect(find.text('Kız'), findsOneWidget);
      expect(find.text('Cinsiyet'), findsOneWidget);
      expect(
        find.text('Pansiyon türü Kız olduğu için cinsiyet sabittir.'),
        findsOneWidget,
      );
      expect(
        find.byType(DropdownButtonFormField<StudentGender?>),
        findsNothing,
      );
    });

    testWidgets('erkek pansiyonunda cinsiyet erkek olarak kilitlenir', (
      tester,
    ) async {
      await pumpForm(tester, boardingType: BoardingType.boys);

      expect(find.byKey(const Key('gender_locked_field')), findsOneWidget);
      expect(find.text('Erkek'), findsOneWidget);
      expect(
        find.text('Pansiyon türü Erkek olduğu için cinsiyet sabittir.'),
        findsOneWidget,
      );
    });

    testWidgets('karma pansiyonda cinsiyet seçilebilir', (tester) async {
      await pumpForm(tester, boardingType: BoardingType.mixed);

      expect(find.byKey(const Key('gender_locked_field')), findsNothing);
      expect(
        find.byType(DropdownButtonFormField<StudentGender?>),
        findsOneWidget,
      );
    });
  });
}
