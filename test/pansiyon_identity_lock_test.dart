import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/pansiyon_identity.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/presentation/pansiyon_creation_view.dart';
import 'package:pansiyon_yonetim/features/settings/presentation/pansiyon_ayarlari_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _draft = BoardingInfoDraft(
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
      floors: [BoardingFloorDraft(floorNumber: 1, studentRoomCount: 12)],
    ),
  ],
);

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(AppNotifier.instance.hide);

  group('Pansiyon kimlik kilidi', () {
    test('dosya oluşturulurken kilit kapalıdır', () {
      // Yeni dosyada kimlik henüz seçilmediği için seçim yapılabilmeli.
      expect(
        PansiyonIdentityLock.isLocked(
          isCreatingFile: true,
          storedIdentity: null,
        ),
        isFalse,
      );
      expect(
        PansiyonIdentityLock.isLocked(
          isCreatingFile: true,
          storedIdentity: const PansiyonIdentity(
            boardingType: BoardingType.girls,
            educationLevel: EducationLevel.middleSchool,
          ),
        ),
        isFalse,
        reason: 'yeni dosyada önceki kimlik taşınmamalı',
      );
    });

    test('kayıtlı dosyada tür ve kademe kilitlidir', () {
      final identity = PansiyonIdentity.fromDraft(_draft);

      expect(
        PansiyonIdentityLock.isLocked(
          isCreatingFile: false,
          storedIdentity: identity,
        ),
        isTrue,
      );
    });

    test('kimlik kaydı yoksa dosya bozuk sayılır', () {
      // Yedekten geri yüklenmemiş bir dosyada kimlik yoktur; bu durumda
      // kilit "açık" kalmamalı, kullanıcı uyarılmalıdır.
      expect(
        PansiyonIdentityLock.isLocked(
          isCreatingFile: false,
          storedIdentity: null,
        ),
        isFalse,
      );
    });

    test('kilitleme metni alan adını ve yeni dosya yolunu içerir', () {
      for (final field in PansiyonLockedField.values) {
        final message = PansiyonIdentityLock.messageFor(field);
        expect(message, contains(field.label));
        expect(message, contains('değiştirilemez'));
        expect(message, contains('Yeni Pansiyon Oluştur'));
      }
    });

    test('kimlik taslaktan okunur', () {
      final identity = PansiyonIdentity.fromDraft(_draft);

      expect(identity.boardingType, BoardingType.girls);
      expect(identity.educationLevel, EducationLevel.middleSchool);
      expect(identity.boardingTypeLabel, 'Kız');
      expect(identity.educationLevelLabel, 'Ortaokul');
    });
  });

  group('Pansiyon Bilgileri ekranında kimlik kilidi', () {
    late AppDatabase database;
    late SqliteBoardingInfoRepository repository;

    setUp(() {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      repository = SqliteBoardingInfoRepository(database);
    });

    tearDown(() => database.close());

    Future<void> pumpForm(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await database.database;
        await repository.save(_draft);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonAyarlariPage(
              repository: repository,
              startInFormMode: true,
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('tür ve kademe kilitli değer olarak görünür', (tester) async {
      await pumpForm(tester);

      expect(
        find.byKey(const Key('boarding_type_locked_value')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('education_level_locked_value')),
        findsOneWidget,
      );
      expect(find.text('Kız'), findsOneWidget);
      expect(find.text('Ortaokul'), findsOneWidget);
    });

    testWidgets('tür ve kademe için açılır liste bulunmaz', (tester) async {
      await pumpForm(tester);

      // Değiştirilebilir bir alan kalmadığı için dropdown olmamalı.
      expect(find.byType(DropdownButton<BoardingType>), findsNothing);
      expect(find.byType(DropdownButton<EducationLevel>), findsNothing);
    });

    testWidgets('kilit bildirimi yeni dosya yolunu gösterir', (tester) async {
      await pumpForm(tester);

      expect(
        find.byKey(const Key('boarding_identity_lock_notice')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Yeni Pansiyon Oluştur'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('boarding_identity_missing_notice')),
        findsNothing,
      );
    });

    testWidgets('kimlik kaydı yoksa uyarı gösterilir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() => database.database);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonAyarlariPage(
              repository: repository,
              startInFormMode: true,
            ),
          ),
        ),
      );
      await settle(tester);

      expect(
        find.byKey(const Key('boarding_identity_missing_notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('boarding_identity_lock_notice')),
        findsNothing,
      );
    });

    testWidgets('kimlik kartı ilk adımda yer alır', (tester) async {
      await pumpForm(tester);

      // "Tür ve Kademe" ayrı bir adım değildir; ilk adımda kart olarak
      // bulunur ve adım göstergesi üç adım gösterir.
      expect(find.text('Pansiyon Türü Ve Kademesi'), findsOneWidget);
      expect(find.text('Genel Bilgiler'), findsOneWidget);
      expect(find.text('Bina Bilgileri'), findsOneWidget);
      expect(find.text('Kontrol ve Kayıt'), findsOneWidget);
      expect(find.text('Okul / Pansiyon Adı'), findsOneWidget);
    });

    testWidgets('kimlik kaydı eksikse özet ekranı forma yönlendirir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Yeni dosya yalnızca tür ve kademesiyle oluşturulur; okul adı boştur.
      await tester.runAsync(
        () => repository.save(
          const BoardingInfoDraft(
            schoolName: '',
            principalName: '',
            principalPhone: '',
            deputyName: '',
            deputyPhone: '',
            boardingType: BoardingType.girls,
            educationLevel: EducationLevel.middleSchool,
            blocks: [],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonAyarlariPage(repository: repository),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Pansiyon Bilgileri Eksik'), findsOneWidget);
      expect(
        find.byKey(const Key('boarding_info_incomplete_notice')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('add_boarding_info_button')), findsOneWidget);
      expect(find.byKey(const Key('edit_boarding_info_button')), findsNothing);
    });
  });

  group('Yeni pansiyon dosyası oluşturma ekranı', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('pansiyon_identity');
    });

    tearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });

    Future<void> pumpCreation(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonCreationView(
              directory: directory,
              controller: _RecordingFileActions(),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('yalnızca dosya adı, tür ve kademe sorar', (tester) async {
      await pumpCreation(tester);

      expect(
        find.byKey(const Key('pansiyon_create_file_name_field')),
        findsOneWidget,
      );
      expect(find.byType(AppDropdown<BoardingType>), findsOneWidget);
      expect(find.byType(AppDropdown<EducationLevel>), findsOneWidget);
      // Diğer bilgiler bu ekranda sorulmaz.
      expect(find.text('Okul / Pansiyon Adı'), findsNothing);
      expect(find.text('Okul Müdürü Adı'), findsNothing);
    });

    testWidgets('tür ve kademe seçilmeden dosya oluşturulmaz', (tester) async {
      final actions = _RecordingFileActions();
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonCreationView(
              directory: directory,
              controller: actions,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('pansiyon_create_submit_button')),
      );
      await tester.pump();

      expect(actions.createdDrafts, isEmpty);
      expect(
        find.text('Pansiyon türü ve kademesi seçilmelidir.'),
        findsOneWidget,
      );
    });

    testWidgets('dosya oluşturulurken yalnızca kimlik bilgileri kaydedilir', (
      tester,
    ) async {
      final actions = _RecordingFileActions();
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PansiyonCreationView(
              directory: directory,
              controller: actions,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('pansiyon_create_file_name_field')),
        'Kız Lisesi Pansiyonu',
      );
      await tester.pump();
      await tester.tap(find.byType(AppDropdown<BoardingType>));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Kız').last);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byType(AppDropdown<EducationLevel>));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Lise').last);
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(
        find.byKey(const Key('pansiyon_create_submit_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(actions.createdDrafts, hasLength(1));
      final draft = actions.createdDrafts.single;
      expect(draft.boardingType, BoardingType.girls);
      expect(draft.educationLevel, EducationLevel.highSchool);
      // Okul, yönetici ve bina bilgileri bu adımda girilmez.
      expect(draft.schoolName, isEmpty);
      expect(draft.principalName, isEmpty);
      expect(draft.blocks, isEmpty);
      expect(
        actions.createdFileNames.single,
        'Kız Lisesi Pansiyonu.pansiyon',
      );
      AppNotifier.instance.hide();
    });
  });
}

/// Oluşturma ekranının çağrılarını kaydeden sahte dosya işlemleri.
class _RecordingFileActions implements PansiyonFileActions {
  final PansiyonFileService fileService = PansiyonFileService();
  final createdDrafts = <BoardingInfoDraft>[];
  final createdFileNames = <String?>[];

  @override
  String fileNameForPansiyon(String pansiyonName) =>
      fileService.fileNameForPansiyon(pansiyonName);

  @override
  Future<PansiyonActivationResult> createPansiyonFile({
    required BoardingInfoDraft draft,
    required Directory directory,
    String? fileName,
  }) async {
    createdDrafts.add(draft);
    createdFileNames.add(fileName);
    return PansiyonActivationResult(
      filePath: fileName ?? '',
      kind: PansiyonActivationKind.created,
      pansiyonName: draft.schoolName,
    );
  }

  @override
  Future<PansiyonActivationResult?> openPansiyonFile(String filePath) async =>
      null;
}