import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/data/pansiyon_file_dialogs.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/presentation/pansiyon_start_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

class _FakeFileDialogs implements PansiyonFileDialogs {
  Directory? directory;
  String? filePath;
  int saveDirectoryCallCount = 0;
  int openFileCallCount = 0;

  @override
  Future<Directory?> pickSaveDirectory({
    // ignore: unused_element_parameter
    String? suggestedFileName,
  }) async {
    saveDirectoryCallCount++;
    return directory;
  }

  @override
  Future<String?> pickPansiyonFile() async {
    openFileCallCount++;
    return filePath;
  }
}

class _FakeFileActions implements PansiyonFileActions {
  _FakeFileActions({required this.fileService});

  final PansiyonFileService fileService;
  final createdDrafts = <BoardingInfoDraft>[];
  final createdDirectories = <Directory>[];
  final openedPaths = <String>[];
  PansiyonActivationResult? createResult;
  PansiyonActivationResult? openResult;
  Object? createError;
  Object? openError;

  @override
  String fileNameForPansiyon(String pansiyonName) =>
      fileService.fileNameForPansiyon(pansiyonName);

  @override
  Future<PansiyonActivationResult> createPansiyonFile({
    required BoardingInfoDraft draft,
    required Directory directory,
  }) async {
    createdDrafts.add(draft);
    createdDirectories.add(directory);
    final error = createError;
    if (error != null) {
      throw error;
    }
    return createResult ??
        PansiyonActivationResult(
          filePath: path.join(
            directory.path,
            fileNameForPansiyon(draft.schoolName),
          ),
          kind: PansiyonActivationKind.created,
          pansiyonName: draft.schoolName,
        );
  }

  @override
  Future<PansiyonActivationResult?> openPansiyonFile(String filePath) async {
    openedPaths.add(filePath);
    final error = openError;
    if (error != null) {
      throw error;
    }
    return openResult;
  }
}

const _prefilledDraft = BoardingInfoDraft(
  schoolName: 'Atatürk Ortaokulu Pansiyonu',
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
      floors: [
        BoardingFloorDraft(
          floorNumber: 1,
          hasStudentRooms: true,
          studentRoomCount: 4,
          roomStartNumber: 101,
          hasStudyRoom: false,
        ),
      ],
    ),
  ],
);

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxRounds = 60,
}) async {
  for (var index = 0; index < maxRounds; index++) {
    if (condition()) {
      await tester.pump();
      return;
    }
    if (index % 10 == 9) {
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pump();
    }
  }
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 3]) async {
  for (var index = 0; index < count; index++) {
    await tester.pump(const Duration(milliseconds: 220));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 6; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }
}

Future<void> _waitUntilFormReady(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await _settle(tester);
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump();
      return;
    }
  }
}

void main() {
  tearDown(AppNotifier.instance.hide);

  late Directory rootDirectory;
  late PansiyonDatabaseSession session;
  late _FakeFileDialogs dialogs;
  late _FakeFileActions actions;
  late List<PansiyonActivationResult> activations;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_start_page_test',
    );
    session = PansiyonDatabaseSession(
      databasePath: path.join(rootDirectory.path, 'pansiyon.db'),
    );
    addTearDown(session.close);
    dialogs = _FakeFileDialogs();
    actions = _FakeFileActions(fileService: PansiyonFileService());
    activations = [];
  });

  tearDown(() async {
    if (await rootDirectory.exists()) {
      try {
        await rootDirectory.delete(recursive: true);
      } on FileSystemException {
        // Kapatılan veritabanı dosya kilitleri geçici olarak tutulabilir.
      }
    }
  });

  Future<void> pumpStartPage(
    WidgetTester tester, {
    bool prefillBoardingInfo = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Oturumu gerçek zaman diliminde aç ki form yüklemesi önbellekten gelsin.
    await tester.runAsync(() async {
      await session.open();
      if (prefillBoardingInfo) {
        await SqliteBoardingInfoRepository(
          session.database,
        ).save(_prefilledDraft);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PansiyonStartPage(
          controller: actions,
          boardingInfoRepository: SqliteBoardingInfoRepository(
            session.database,
          ),
          dialogs: dialogs,
          onPansiyonActivated: activations.add,
        ),
      ),
    );
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('pansiyon_start_page')).evaluate().isNotEmpty,
    );
  }

  testWidgets('başlangıç ekranı iki aksiyonu gösterir', (tester) async {
    await pumpStartPage(tester);

    expect(find.byKey(const Key('pansiyon_start_page')), findsOneWidget);
    expect(find.text('Henüz bir pansiyon oluşturulmadı.'), findsOneWidget);
    expect(find.text('Yeni Pansiyon Oluştur'), findsOneWidget);
    expect(find.text('Pansiyon Dosyası Aç'), findsOneWidget);
    expect(find.text('Pansiyonlarım'), findsNothing);
    expect(find.byKey(const Key('pansiyon_create_form')), findsNothing);
  });

  testWidgets('klasör seçiminden vazgeçilirse form açılmaz', (tester) async {
    await pumpStartPage(tester);

    await tester.tap(find.byKey(const Key('new_pansiyon_button')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('Henüz bir pansiyon oluşturulmadı.').evaluate().isEmpty,
      maxRounds: 5,
    );

    expect(dialogs.saveDirectoryCallCount, 1);
    expect(find.byKey(const Key('pansiyon_create_form')), findsNothing);
    expect(find.text('Yeni Pansiyon Oluştur'), findsOneWidget);
  });

  testWidgets('oluşturma formu form verisini dosyaya aktarır', (tester) async {
    dialogs.directory = Directory(
      path.join(rootDirectory.path, 'yeni_pansiyon'),
    );
    actions.createResult = PansiyonActivationResult(
      filePath: path.join(
        dialogs.directory!.path,
        'Atatürk Ortaokulu Pansiyonu.pansiyon',
      ),
      kind: PansiyonActivationKind.created,
      pansiyonName: 'Atatürk Ortaokulu Pansiyonu',
    );
    await pumpStartPage(tester, prefillBoardingInfo: true);

    await tester.tap(find.byKey(const Key('new_pansiyon_button')));
    await tester.pump();
    await _waitUntilFormReady(tester);
    expect(find.byKey(const Key('pansiyon_create_form')), findsOneWidget);

    expect(find.text('Yeni pansiyon oluştur'), findsOneWidget);
    expect(
      find.text(dialogs.directory!.path, findRichText: true),
      findsWidgets,
    );

    // Önceden kayıtlı form üç adımda ilerler ve kaydedilir.
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Devam'));
      await _pumpFrames(tester);
    }
    await tester.tap(find.text('Kaydet'));
    await _pumpUntil(tester, () => activations.isNotEmpty);

    expect(activations, hasLength(1));
    expect(activations.single.kind, PansiyonActivationKind.created);
    expect(actions.createdDrafts, hasLength(1));
    expect(
      actions.createdDrafts.single.schoolName,
      'Atatürk Ortaokulu Pansiyonu',
    );
    expect(actions.createdDrafts.single.boardingType, BoardingType.girls);
    expect(
      actions.createdDrafts.single.educationLevel,
      EducationLevel.middleSchool,
    );
    expect(actions.createdDrafts.single.blocks, hasLength(1));
    expect(actions.createdDirectories.single.path, dialogs.directory!.path);
    AppNotifier.instance.hide();
  });

  testWidgets('okul adı yazıldıkça dosya adı önizlemesi güncellenir', (
    tester,
  ) async {
    dialogs.directory = Directory(
      path.join(rootDirectory.path, 'yeni_pansiyon'),
    );
    await pumpStartPage(tester);

    await tester.tap(find.byKey(const Key('new_pansiyon_button')));
    await tester.pump();
    await _waitUntilFormReady(tester);
    expect(find.byKey(const Key('pansiyon_create_form')), findsOneWidget);

    expect(
      tester
          .widget<Text>(find.byKey(const Key('pansiyon_target_file_name')))
          .data,
      'pansiyon.pansiyon',
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'Şehit Ahmet Yılmaz Pansiyonu',
    );
    await tester.pump();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('pansiyon_target_file_name')))
          .data,
      'Şehit Ahmet Yılmaz Pansiyonu.pansiyon',
    );
  });

  testWidgets('oluşturma hatasında kullanıcı dostu mesaj gösterir', (
    tester,
  ) async {
    dialogs.directory = Directory(
      path.join(rootDirectory.path, 'yeni_pansiyon'),
    );
    actions.createError = const PansiyonActivationException(
      'Bu adla kayıtlı bir pansiyon dosyası zaten var. '
      'Farklı bir ad veya klasör seçebilirsiniz.',
    );
    await pumpStartPage(tester, prefillBoardingInfo: true);

    await tester.tap(find.byKey(const Key('new_pansiyon_button')));
    await tester.pump();
    await _waitUntilFormReady(tester);
    expect(find.byKey(const Key('pansiyon_create_form')), findsOneWidget);

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Devam'));
      await _pumpFrames(tester);
    }
    await tester.tap(find.text('Kaydet'));
    await _pumpUntil(
      tester,
      () => find.textContaining('zaten var').evaluate().isNotEmpty,
    );

    expect(activations, isEmpty);
    expect(find.byKey(const Key('pansiyon_create_form')), findsOneWidget);
    expect(
      find.text(
        'Bu adla kayıtlı bir pansiyon dosyası zaten var. '
        'Farklı bir ad veya klasör seçebilirsiniz.',
      ),
      findsOneWidget,
    );
    AppNotifier.instance.hide();
  });

  testWidgets('geçerli .pansiyon dosyasını açar', (tester) async {
    const targetPath = 'C:\\Pansiyonlar\\mevcut.pansiyon';
    dialogs.filePath = targetPath;
    actions.openResult = const PansiyonActivationResult(
      filePath: targetPath,
      kind: PansiyonActivationKind.opened,
    );
    await pumpStartPage(tester);

    await tester.tap(find.byKey(const Key('open_pansiyon_file_button')));
    await tester.pump();
    await _pumpUntil(tester, () => activations.isNotEmpty);

    expect(dialogs.openFileCallCount, 1);
    expect(actions.openedPaths, [targetPath]);
    expect(activations, hasLength(1));
    expect(activations.single.kind, PansiyonActivationKind.opened);
    expect(activations.single.fileName, 'mevcut.pansiyon');
    AppNotifier.instance.hide();
  });

  testWidgets('açma hatasında kullanıcı dostu mesaj gösterir', (tester) async {
    dialogs.filePath = 'C:\\Pansiyonlar\\bozuk.pansiyon';
    actions.openError = const PansiyonActivationException(
      'Seçtiğiniz pansiyon dosyası geçerli değil veya bozulmuş olabilir.',
    );
    await pumpStartPage(tester);

    await tester.tap(find.byKey(const Key('open_pansiyon_file_button')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find
          .text(
            'Seçtiğiniz pansiyon dosyası geçerli değil veya bozulmuş olabilir.',
          )
          .evaluate()
          .isNotEmpty,
    );

    expect(activations, isEmpty);
    expect(find.text('Henüz bir pansiyon oluşturulmadı.'), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    AppNotifier.instance.hide();
  });

  testWidgets('dosya seçiminden vazgeçilirse aktif DB değişmez', (
    tester,
  ) async {
    await pumpStartPage(tester);
    final oldPath = await session.activePath();

    await tester.tap(find.byKey(const Key('open_pansiyon_file_button')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('Henüz bir pansiyon oluşturulmadı.').evaluate().isEmpty,
      maxRounds: 5,
    );

    expect(dialogs.openFileCallCount, 1);
    expect(actions.openedPaths, isEmpty);
    expect(activations, isEmpty);
    expect(await session.activePath(), oldPath);
  });
}
