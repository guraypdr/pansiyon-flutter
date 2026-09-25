import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
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
    await tester.tap(find.text('Öğrenci Ekle'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Ad Soyad'), findsOneWidget);

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
