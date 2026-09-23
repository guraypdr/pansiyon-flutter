import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/presentation/boarding_info_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('Pansiyon Bilgileri formu temel adımları gösterir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = BoardingInfoRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: PansiyonBilgileriPage(repository: repository)),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('Genel Bilgiler'), findsOneWidget);
    expect(find.byKey(const Key('boarding_step_progress')), findsOneWidget);
    expect(find.text('Okul / Pansiyon adı'), findsOneWidget);
    expect(find.text('Tür ve Kademe'), findsOneWidget);
    expect(find.text('Bina Bilgileri'), findsOneWidget);
    expect(find.text('Kontrol ve Kayıt'), findsOneWidget);
    final firstField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(TextField),
      ),
    );
    final enabledBorder =
        firstField.decoration?.enabledBorder as OutlineInputBorder;
    expect(
      enabledBorder.borderSide.color,
      AppColors.secondary.withValues(alpha: 0.32),
    );
    expect(tester.takeException(), isNull);
  });
}
