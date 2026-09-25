import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/boarding_info/presentation/boarding_info_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  tearDown(AppNotifier.instance.hide);

  testWidgets('Pansiyon Bilgileri formu temel adımları gösterir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteBoardingInfoRepository(database);
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
    expect(find.text('Okul Ve Yönetim Bilgileri'), findsOneWidget);
    final sectionTitle = tester.widget<Text>(
      find.text('Okul Ve Yönetim Bilgileri'),
    );
    expect(sectionTitle.style?.color, AppColors.sidebar);
    expect(find.byKey(const Key('boarding_step_progress')), findsOneWidget);
    expect(find.text('Okul / Pansiyon Adı'), findsOneWidget);
    expect(find.text('Tür ve Kademe'), findsOneWidget);
    expect(find.text('Bina Bilgileri'), findsOneWidget);
    expect(find.text('Kontrol ve Kayıt'), findsOneWidget);
    final schoolLabel = tester.widget<Text>(find.text('Okul / Pansiyon Adı'));
    expect(schoolLabel.style?.color, AppColors.secondary);
    final firstField = tester.widget<TextField>(
      find.descendant(
        of: find.byType(TextFormField).first,
        matching: find.byType(TextField),
      ),
    );
    final enabledBorder =
        firstField.decoration?.enabledBorder as OutlineInputBorder;
    expect(enabledBorder.borderSide.color, AppColors.inputBorder);
    expect(firstField.style?.fontWeight, FontWeight.w700);
    expect(firstField.decoration?.labelText, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form değişikliklerini dirty callback ile bildirir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteBoardingInfoRepository(database);
    addTearDown(database.close);
    var isDirty = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PansiyonBilgileriPage(
            repository: repository,
            onDirtyChanged: (value) => isDirty = value,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Test pansiyonu');
    await tester.pump();

    expect(isDirty, isTrue);
  });

  testWidgets('metin alanlarını büyük başlatır ve telefonları sınırlar', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteBoardingInfoRepository(database);
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

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'atatürk ortaokulu pansiyonu');
    await tester.enterText(fields.at(1), 'ayşe yılmaz');
    await tester.enterText(fields.at(2), '+90 555 123 45 67');

    final schoolField = tester.widget<TextFormField>(fields.at(0));
    final principalField = tester.widget<TextFormField>(fields.at(1));
    final phoneField = tester.widget<TextFormField>(fields.at(2));

    expect(schoolField.controller!.text, 'Atatürk Ortaokulu Pansiyonu');
    expect(principalField.controller!.text, 'Ayşe Yılmaz');
    expect(phoneField.controller!.text, '9055 512 34 56');
    expect(phoneField.controller!.text.replaceAll(' ', '').length, 11);
  });

  testWidgets('bina adımında boş alanların form hatasını gösterir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteBoardingInfoRepository(database);
    addTearDown(database.close);

    await tester.runAsync(
      () => repository.save(
        const BoardingInfoDraft(
          schoolName: 'Test Pansiyonu',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.girls,
          educationLevel: EducationLevel.middleSchool,
          blocks: [],
        ),
      ),
    );

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

    await tester.tap(find.text('Devam'));
    await tester.pump();
    final typeInput = tester.widget<InputDecorator>(
      find.byType(InputDecorator).first,
    );
    final typeInputBorder =
        typeInput.decoration.enabledBorder! as OutlineInputBorder;
    expect(typeInputBorder.borderSide.color, AppColors.inputBorder);
    expect(typeInput.decoration.fillColor, AppColors.inputSurface);

    await tester.tap(find.text('Devam'));
    await tester.pump();
    await tester.tap(find.text('Devam'));
    await tester.pump();

    expect(find.text('Standart oda kapasitesi zorunludur.'), findsOneWidget);
  });

  testWidgets('pasifleşen ortak blokları kaydederken korur', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteBoardingInfoRepository(database);
    addTearDown(database.close);

    await tester.runAsync(
      () => repository.save(
        const BoardingInfoDraft(
          schoolName: 'Test Pansiyonu',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.girls,
          educationLevel: EducationLevel.middleSchool,
          blocks: [
            BoardingBlockDraft(
              section: BoardingSection.common,
              name: 'Ortak Blok',
              standardRoomCapacity: 4,
              studyRoomCount: 1,
              floors: [BoardingFloorDraft(floorNumber: 1, studentRoomCount: 8)],
            ),
            BoardingBlockDraft(
              section: BoardingSection.girls,
              name: 'Kız Bloğu',
              standardRoomCapacity: 4,
              studyRoomCount: 2,
              floors: [
                BoardingFloorDraft(floorNumber: 1, studentRoomCount: 12),
              ],
            ),
          ],
        ),
      ),
    );

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

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Devam'));
      await tester.pump();
    }
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    AppNotifier.instance.hide();

    final saved = await tester.runAsync<BoardingInfoDraft?>(
      () => repository.load(),
    );
    expect(saved, isNotNull);
    expect(
      saved!.blocks.where((block) => block.section == BoardingSection.common),
      hasLength(1),
    );
  });

  testWidgets('bina adımında bodrum ve oda başlangıç numaralarını gösterir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteBoardingInfoRepository(database);
    addTearDown(database.close);

    await tester.runAsync(
      () => repository.save(
        const BoardingInfoDraft(
          schoolName: 'Test Pansiyonu',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.girls,
          educationLevel: EducationLevel.middleSchool,
          blocks: [
            BoardingBlockDraft(
              section: BoardingSection.girls,
              name: 'Kız Bloğu',
              standardRoomCapacity: 4,
              studyRoomCount: 1,
              hasBasement: true,
              floors: [
                BoardingFloorDraft(
                  floorNumber: 1,
                  studentRoomCount: 8,
                  roomStartNumber: 101,
                ),
                BoardingFloorDraft(
                  floorNumber: 2,
                  studentRoomCount: 10,
                  roomStartNumber: 201,
                ),
              ],
            ),
          ],
        ),
      ),
    );

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

    await tester.tap(find.text('Devam'));
    await tester.pump();
    await tester.tap(find.text('Devam'));
    await tester.pump();

    expect(find.text('Bodrum Kat'), findsOneWidget);
    expect(find.text('Zemin Kat'), findsOneWidget);
    expect(find.text('Oda Başlangıç Numarası'), findsNWidgets(2));
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

    final basementSwitch = find.byType(Switch).first;
    await tester.ensureVisible(basementSwitch);
    await tester.pump();
    await tester.tap(basementSwitch);
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(find.text('Bodrum Kat'), findsNothing);
    expect(find.text('Zemin Kat'), findsOneWidget);
    expect(find.text('1. Kat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
