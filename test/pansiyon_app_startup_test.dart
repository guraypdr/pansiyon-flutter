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
  String? filePath;

  @override
  Future<Directory?> pickSaveDirectory({
    // ignore: unused_element_parameter
    String? suggestedFileName,
  }) async => null;

  @override
  Future<String?> pickPansiyonFile() async => filePath;
}

const _draft = BoardingInfoDraft(
  schoolName: 'Atatürk Ortaokulu Pansiyonu',
  principalName: 'Ayşe Yılmaz',
  principalPhone: '0312 555 10 10',
  deputyName: 'Mehmet Demir',
  deputyPhone: '0312 555 10 11',
  boardingType: BoardingType.girls,
  educationLevel: EducationLevel.middleSchool,
  blocks: [],
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

void main() {
  tearDown(AppNotifier.instance.hide);

  late Directory rootDirectory;
  late _FakeFileDialogs dialogs;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    rootDirectory = await Directory.systemTemp.createTemp(
      'pansiyon_app_startup_test',
    );
    dialogs = _FakeFileDialogs();
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

  Future<void> pumpApp(
    WidgetTester tester, {
    PansiyonFileMemory? memory,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      PansiyonYonetimApp(
        pansiyonFileDialogs: dialogs,
        pansiyonFileMemory: memory,
      ),
    );
    await tester.pump();
  }

  testWidgets('yeni kurulumda başlangıç ekranı gösterir', (tester) async {
    await pumpApp(tester);
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('pansiyon_start_page')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('pansiyon_start_page')), findsOneWidget);
    expect(find.text('Henüz bir pansiyon oluşturulmadı.'), findsOneWidget);
    expect(find.text('Yeni Pansiyon Oluştur'), findsOneWidget);
    expect(find.text('Pansiyon Dosyası Aç'), findsOneWidget);
    expect(find.byKey(const Key('app_frame')), findsNothing);
    expect(
      find.byKey(const Key('last_pansiyon_file_missing_notice')),
      findsNothing,
    );
  });

  testWidgets('varsayılan pansiyon.db olsa da otomatik açılmaz', (
    tester,
  ) async {
    final legacyPath = await tester.runAsync(() async {
      final service = PansiyonFileService();
      final info = await service.createEmptyPansiyonFile(
        pansiyonName: _draft.schoolName,
        directory: Directory(path.join(rootDirectory.path, 'kaynak')),
      );
      final staging = await service.openSession(info.filePath);
      await SqliteBoardingInfoRepository(staging.database).save(_draft);
      await staging.close();
      final targetDirectory = Directory(
        path.join(rootDirectory.path, 'pansiyon_yonetim'),
      );
      await targetDirectory.create(recursive: true);
      final targetPath = path.join(targetDirectory.path, 'pansiyon.db');
      await File(info.filePath).copy(targetPath);
      return targetPath;
    });
    expect(File(legacyPath!).existsSync(), isTrue);

    await pumpApp(tester);
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('pansiyon_start_page')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('pansiyon_start_page')), findsOneWidget);
    expect(find.byKey(const Key('app_frame')), findsNothing);
  });

  testWidgets('son seçilen pansiyon dosyası otomatik açılır', (tester) async {
    final rememberedPath = await tester.runAsync(() async {
      final service = PansiyonFileService();
      final info = await service.createEmptyPansiyonFile(
        pansiyonName: _draft.schoolName,
        directory: Directory(path.join(rootDirectory.path, 'hatirlanan')),
      );
      final staging = await service.openSession(info.filePath);
      await SqliteBoardingInfoRepository(staging.database).save(_draft);
      await staging.close();
      return info.filePath;
    });

    await pumpApp(tester, memory: InMemoryPansiyonFileMemory(rememberedPath));
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('app_frame')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('pansiyon_start_page')), findsNothing);
    expect(find.text('Ana Sayfa'), findsWidgets);

    AppNotifier.instance.hide();
    await _settleReal(tester);
    expect(find.text('Atatürk Ortaokulu Pansiyonu'), findsWidgets);
  });

  testWidgets('son seçilen dosya silinmişse başlangıç ekranı gelir', (
    tester,
  ) async {
    await pumpApp(
      tester,
      memory: InMemoryPansiyonFileMemory(
        path.join(rootDirectory.path, 'silinmis.pansiyon'),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('pansiyon_start_page')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('pansiyon_start_page')), findsOneWidget);
    expect(
      find.byKey(const Key('last_pansiyon_file_missing_notice')),
      findsOneWidget,
    );
  });

  testWidgets('dosya açılınca AppShell yeni key ile yeniden oluşur', (
    tester,
  ) async {
    final preparedPath = await tester.runAsync(() async {
      final service = PansiyonFileService();
      final info = await service.createEmptyPansiyonFile(
        pansiyonName: _draft.schoolName,
        directory: Directory(path.join(rootDirectory.path, 'hazir')),
      );
      final staging = await service.openSession(info.filePath);
      await SqliteBoardingInfoRepository(staging.database).save(_draft);
      await staging.close();
      return info.filePath;
    });
    dialogs.filePath = preparedPath;

    await pumpApp(tester);
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('pansiyon_start_page')).evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('open_pansiyon_file_button')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('app_frame')).evaluate().isNotEmpty,
    );

    expect(find.byKey(const Key('pansiyon_start_page')), findsNothing);
    expect(find.byKey(const Key('app_frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_shell_1')), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsWidgets);

    AppNotifier.instance.hide();
    await _settleReal(tester);
    expect(find.text('Atatürk Ortaokulu Pansiyonu'), findsWidgets);
  });
}
