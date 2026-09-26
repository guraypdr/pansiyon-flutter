import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pansiyon_yonetim/app/pansiyon_yonetim_app.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_memory.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/data/pansiyon_file_dialogs.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

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

const _draftA = BoardingInfoDraft(
  schoolName: 'Pansiyon A',
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

const _draftB = BoardingInfoDraft(
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
  int maxRounds = 40,
}) async {
  for (var index = 0; index < maxRounds; index++) {
    if (condition()) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
}

Future<void> _settleReal(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
}

Future<void> _waitUntilFormReady(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }
}

void main() {
  tearDown(AppNotifier.instance.hide);

  late Directory rootDirectory;
  late _FakeFileDialogs dialogs;
  late PathProviderPlatform previousPathProvider;
  String? preparedActivePath;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_file_operations_test',
    );
    dialogs = _FakeFileDialogs();
    preparedActivePath = null;
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(rootDirectory.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPathProvider;
      if (await rootDirectory.exists()) {
        try {
          await rootDirectory.delete(recursive: true);
        } on FileSystemException {
          // Kapatılan veritabanı dosya kilitleri geçici olarak tutulabilir.
        }
      }
    });
  });

  /// Aktif pansiyon dosyasını hazırlar ve "son seçilen dosya" olarak hatırlatır.
  Future<String> prepareActivePansiyon(String schoolName) async {
    final service = PansiyonFileService();
    final info = await service.createEmptyPansiyonFile(
      pansiyonName: schoolName,
      directory: Directory(path.join(rootDirectory.path, 'aktif')),
    );
    final staging = await service.openSession(info.filePath);
    await SqliteBoardingInfoRepository(
      staging.database,
    ).save(schoolName == 'Pansiyon A' ? _draftA : _draftB);
    await staging.close();
    preparedActivePath = info.filePath;
    return info.filePath;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PansiyonYonetimApp(
        pansiyonFileDialogs: dialogs,
        pansiyonFileMemory: InMemoryPansiyonFileMemory(preparedActivePath),
      ),
    );
    await tester.pump();
  }

  Future<void> openBoardingInfoPage(WidgetTester tester) async {
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('app_frame')).evaluate().isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('sidebar_item_settings')));
    await tester.pump();
    await _settleReal(tester);
  }

  testWidgets('Ayarlar sayfasında dosya ve yedekleme kartları bulunur', (
    tester,
  ) async {
    await tester.runAsync(() => prepareActivePansiyon('Pansiyon A'));
    await pumpApp(tester);
    await openBoardingInfoPage(tester);

    // Sayfa özet görünümüyle açılır, form butonu ile açılır.
    expect(find.text('Kayıtlı Pansiyon Bilgileri'), findsOneWidget);
    expect(find.byKey(const Key('edit_boarding_info_button')), findsOneWidget);
    expect(find.byKey(const Key('boarding_step_progress')), findsNothing);
    // Kademe kilidi bildirimi özet kartında gösterilmez.
    expect(find.byKey(const Key('education_level_lock_notice')), findsNothing);

    expect(find.text('Dosya İşlemleri'), findsOneWidget);
    expect(find.text('Dosya İşlemleri Yap'), findsNothing);
    expect(
      find.byKey(const Key('new_pansiyon_operation_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('open_pansiyon_file_operation_button')),
      findsOneWidget,
    );
    expect(find.textContaining('mevcut veriler aktarılmaz'), findsOneWidget);
    // Dosya kartının üst açıklaması kaldırıldı.
    expect(find.textContaining('Aktif pansiyon dosyanızı'), findsNothing);

    // Yedekleme ve geri yükleme kartı yanında durur.
    expect(find.text('Yedekleme Ve Geri Yükleme'), findsOneWidget);
    expect(find.byKey(const Key('create_backup_button')), findsOneWidget);
    expect(find.byKey(const Key('restore_backup_button')), findsOneWidget);
    expect(find.textContaining('backups'), findsWidgets);

    // Alt iki kartın yüksekliği eşittir.
    expect(
      tester.getSize(find.byKey(const Key('file_operations_card'))).height,
      tester.getSize(find.byKey(const Key('backup_card'))).height,
    );

    expect(find.text('Pansiyonlarım'), findsNothing);

    // Düzenle butonu formu açar.
    await tester.tap(find.byKey(const Key('edit_boarding_info_button')));
    await tester.pump();
    await _settleReal(tester);
    expect(find.byKey(const Key('boarding_step_progress')), findsOneWidget);
    expect(
      find.byKey(const Key('new_pansiyon_operation_button')),
      findsNothing,
    );
  });

  testWidgets('arayüzden yeni pansiyon oluşturulur ve aktif olur', (
    tester,
  ) async {
    final activePath = (await tester.runAsync<String>(
      () => prepareActivePansiyon('Pansiyon A'),
    ))!;
    final newDirectory = Directory(
      path.join(rootDirectory.path, 'yeni_pansiyonlar'),
    );
    await tester.runAsync(() => newDirectory.create(recursive: true));
    dialogs.directory = newDirectory;
    await pumpApp(tester);
    await openBoardingInfoPage(tester);

    // Kaydedilmemiş değişiklik yoksa doğrudan klasör seçimi açılır.
    await tester.tap(find.byKey(const Key('new_pansiyon_operation_button')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('pansiyon_create_form')).evaluate().isNotEmpty,
    );

    expect(find.text('Yeni pansiyon oluştur'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('pansiyon_target_directory')))
          .data,
      newDirectory.path,
    );
    expect(find.text('Pansiyon Dosyası İşlemleri'), findsNothing);
    await _waitUntilFormReady(tester);

    // Kullanıcı yeni pansiyon adını yazar, dosya adı önizlemesi güncellenir.
    await tester.enterText(find.byType(TextFormField).first, 'Test Pansiyonu');
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('pansiyon_target_file_name')))
          .data,
      'Test Pansiyonu.pansiyon',
    );

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.text('Kaydet'));
    await _pumpUntil(
      tester,
      () => find
          .text('Test Pansiyonu.pansiyon oluşturuldu ve açıldı.')
          .evaluate()
          .isNotEmpty,
    );

    final createdPath = path.join(newDirectory.path, 'Test Pansiyonu.pansiyon');
    AppNotifier.instance.hide();
    await _settleReal(tester);

    // Yeni pansiyon açıldı: öğrenci yok, pansiyon adı Test Pansiyonu.
    expect(find.byKey(const ValueKey('app_shell_1')), findsOneWidget);
    expect(find.text('Test Pansiyonu'), findsWidgets);
    expect(find.text('Öğrenci'), findsOneWidget);

    // Eski dosya korundu.
    expect(File(activePath).existsSync(), isTrue);
    expect(File(createdPath).existsSync(), isTrue);
  });

  testWidgets('arayüzden başka pansiyon dosyası açılır', (tester) async {
    await tester.runAsync(() => prepareActivePansiyon('Pansiyon A'));
    final otherFile = await tester.runAsync(() async {
      final service = PansiyonFileService();
      final info = await service.createEmptyPansiyonFile(
        pansiyonName: 'Test Pansiyonu',
        directory: Directory(path.join(rootDirectory.path, 'baska_pansiyon')),
      );
      final staging = await service.openSession(info.filePath);
      await SqliteBoardingInfoRepository(staging.database).save(_draftB);
      await staging.close();
      return info.filePath;
    });
    dialogs.filePath = otherFile;
    await pumpApp(tester);
    await openBoardingInfoPage(tester);

    await tester.tap(
      find.byKey(const Key('open_pansiyon_file_operation_button')),
    );
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.byKey(const ValueKey('app_shell_1')).evaluate().isNotEmpty,
    );

    expect(dialogs.openFileCallCount, 1);
    AppNotifier.instance.hide();
    await _settleReal(tester);
    expect(find.text('Test Pansiyonu'), findsWidgets);
  });

  testWidgets('bozuk dosya arayüzden reddedilir ve aktif DB korunur', (
    tester,
  ) async {
    final activePath = (await tester.runAsync<String>(
      () => prepareActivePansiyon('Pansiyon A'),
    ))!;
    await tester.runAsync(
      () => File(
        path.join(rootDirectory.path, 'bozuk.pansiyon'),
      ).writeAsString('SQLite olmayan dosya'),
    );
    dialogs.filePath = path.join(rootDirectory.path, 'bozuk.pansiyon');
    await pumpApp(tester);
    await openBoardingInfoPage(tester);

    await tester.tap(
      find.byKey(const Key('open_pansiyon_file_operation_button')),
    );
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

    expect(find.byKey(const ValueKey('app_shell_1')), findsNothing);
    expect(find.byKey(const Key('app_frame')), findsOneWidget);
    expect(File(activePath).existsSync(), isTrue);
    AppNotifier.instance.hide();
  });
}
