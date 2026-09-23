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
    expect(find.byType(Stepper), findsOneWidget);
    expect(find.text('Okul / Pansiyon adı'), findsOneWidget);
    expect(find.text('Pansiyon türü'), findsOneWidget);
    expect(find.text('Pansiyon kademesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
