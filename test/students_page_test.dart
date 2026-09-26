import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/presentation/students_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  tearDown(AppNotifier.instance.hide);

  testWidgets('öğrenci listesi ve ekleme formu açılır', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Henüz öğrenci eklenmemiş'), findsOneWidget);
    expect(find.text('Şablon'), findsOneWidget);
    await tester.tap(find.text('Öğrenci Ekle'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Ad Soyad'), findsOneWidget);
    final formDropdowns = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString().startsWith('DropdownButtonFormField'),
    );
    await tester.tap(formDropdowns.at(1));
    await tester.pump();
    await tester.tap(find.text('Kız').last);
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'ali yılmaz');
    await tester.tap(find.text('Devam'));
    await tester.pump();
    expect(find.text('İletişim Ve Sağlık Bilgileri'), findsOneWidget);
    await tester.tap(find.text('Devam'));
    await tester.pump();
    expect(find.text('Veli Ve Yaşam Bilgileri'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    });
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    expect(find.text('Ali Yılmaz'), findsOneWidget);
    AppNotifier.instance.hide();
  });

  testWidgets(
    'öğrenci ekleme formu sınıfları pansiyon kademesine göre listeler',
    (tester) async {
      final database = AppDatabase(databasePath: inMemoryDatabasePath);
      final studentRepository = SqliteStudentRepository(database);
      addTearDown(database.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StudentsPage(
              repository: studentRepository,
              boardingInfoRepository: _HighSchoolBoardingRepository(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      await tester.tap(find.text('Öğrenci Ekle'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      // Kız pansiyonunda cinsiyet kilitli olduğu için açılır liste kalmaz.
      expect(find.byKey(const Key('gender_locked_field')), findsOneWidget);
      final dropdowns = find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString().startsWith('DropdownButtonFormField'),
      );
      expect(dropdowns, findsNWidgets(2));
      await tester.ensureVisible(dropdowns.at(1));
      await tester.pump();
      await tester.tap(dropdowns.at(1));
      await tester.pump();

      expect(find.text('Hazırlık'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('öğrenci ekranı dar pencerede taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _HighSchoolBoardingRepository implements BoardingInfoRepository {
  @override
  Future<BoardingInfoDraft?> load() async => const BoardingInfoDraft(
    schoolName: 'Test Pansiyonu',
    principalName: 'Test',
    principalPhone: '0312 555 10 10',
    deputyName: 'Test',
    deputyPhone: '0312 555 10 11',
    boardingType: BoardingType.girls,
    educationLevel: EducationLevel.highSchool,
    blocks: [],
  );

  @override
  Future<void> save(BoardingInfoDraft draft) async {}
}
