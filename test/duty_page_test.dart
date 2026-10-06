import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_page.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _draft = BoardingInfoDraft(
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
        ),
      ],
    ),
  ],
);

/// Ay listesi silinmesi başarısız olan repository.
///
/// Gerçek repository'ye devredilir; yalnızca [deleteMonthList] hata fırlatır.
class _FailingDeleteDutyRepository implements DutyRepository {
  _FailingDeleteDutyRepository(this._delegate);

  final DutyRepository _delegate;

  @override
  Future<void> deleteMonthList({
    required int year,
    required int month,
    String? sectionKey,
  }) async {
    throw StateError('nöbet listesi silinemedi');
  }

  @override
  Future<List<DutyTeacher>> getTeachers({bool onlyActive = false}) =>
      _delegate.getTeachers(onlyActive: onlyActive);

  @override
  Future<int> saveTeacher(DutyTeacher teacher) =>
      _delegate.saveTeacher(teacher);

  @override
  Future<void> deleteTeacher(int id) => _delegate.deleteTeacher(id);

  @override
  Future<DutySettings> getSettings(String? sectionKey) =>
      _delegate.getSettings(sectionKey);

  @override
  Future<void> saveSettings(DutySettings settings) =>
      _delegate.saveSettings(settings);

  @override
  Future<Set<int>> getMonthOffTeacherIds({
    required int year,
    required int month,
    String? sectionKey,
  }) => _delegate.getMonthOffTeacherIds(
    year: year,
    month: month,
    sectionKey: sectionKey,
  );

  @override
  Future<void> saveMonthOffTeacherIds({
    required int year,
    required int month,
    String? sectionKey,
    required Set<int> teacherIds,
  }) => _delegate.saveMonthOffTeacherIds(
    year: year,
    month: month,
    sectionKey: sectionKey,
    teacherIds: teacherIds,
  );

  @override
  Future<bool> createMonthList({
    required int year,
    required int month,
    String? sectionKey,
  }) => _delegate.createMonthList(
    year: year,
    month: month,
    sectionKey: sectionKey,
  );

  @override
  Future<List<DutyMonthList>> getMonthLists({int? year}) =>
      _delegate.getMonthLists(year: year);

  @override
  Future<List<DutyAssignment>> getAssignments({
    required int year,
    required int month,
    String? sectionKey,
  }) => _delegate.getAssignments(
    year: year,
    month: month,
    sectionKey: sectionKey,
  );

  @override
  Future<List<DutyAssignment>> getYearAssignments(int year) =>
      _delegate.getYearAssignments(year);

  @override
  Future<void> replaceAssignments({
    required int year,
    required int month,
    String? sectionKey,
    required List<DutyAssignment> assignments,
  }) => _delegate.replaceAssignments(
    year: year,
    month: month,
    sectionKey: sectionKey,
    assignments: assignments,
  );
}

void main() {
  tearDown(AppNotifier.instance.hide);

  late AppDatabase database;
  late SqliteDutyRepository dutyRepository;
  late SqliteRoomRepository roomRepository;
  late SqliteBoardingInfoRepository boardingInfoRepository;

  setUp(() async {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    dutyRepository = SqliteDutyRepository(database);
    roomRepository = SqliteRoomRepository(database);
    boardingInfoRepository = SqliteBoardingInfoRepository(database);
    await boardingInfoRepository.save(_draft);
    await roomRepository.syncRooms(_draft);
    await dutyRepository.createMonthList(year: 2026, month: 9);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Bildirimin otomatik kapanma timer'ını ilerletir.
  ///
  /// İddialar tamamlandıktan sonra çağrılmalı; önce çağrılırsa bildirim
  /// kapanır ve üzerinde yapılan iddialar başarısız olur.
  Future<void> drainNotification(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    DutyRepository? repository,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DutyPage(
            repository: repository ?? dutyRepository,
            roomRepository: roomRepository,
            boardingInfoRepository: boardingInfoRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  testWidgets('ay listesi silinir ve liste ekrandan kalkar', (tester) async {
    await pumpPage(tester);

    final deleteButton = find.byKey(const Key('duty_list_delete_2026_9_all'));
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nöbet listesini sil'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pump();
    await settle(tester);

    expect(await tester.runAsync(dutyRepository.getMonthLists), isEmpty);
    expect(find.text('Nöbet listesi silindi.'), findsOneWidget);
    await drainNotification(tester);
  });

  testWidgets('liste silinemezse hata bildirimi gösterilir', (tester) async {
    // Regresyon: silme çağrısının try/catch'i yoktu; veritabanı hatasında
    // unhandled async error oluşuyor ve kullanıcı hiçbir geri bildirim
    // almıyordu. Dosyadaki yedi kardeş metodun tamamında hata bildirimi var.
    await pumpPage(
      tester,
      repository: _FailingDeleteDutyRepository(dutyRepository),
    );

    await tester.tap(find.byKey(const Key('duty_list_delete_2026_9_all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pump();
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Nöbet listesi silinemedi.'), findsOneWidget);
    // Liste silinemediği için ekranda kalmalı.
    expect(
      find.byKey(const Key('duty_list_delete_2026_9_all')),
      findsOneWidget,
    );
    await drainNotification(tester);
  });

  testWidgets('silme onayı vazgeçilirse liste yerinde kalır', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('duty_list_delete_2026_9_all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();

    expect(await tester.runAsync(dutyRepository.getMonthLists), hasLength(1));
    expect(
      find.byKey(const Key('duty_list_delete_2026_9_all')),
      findsOneWidget,
    );
    await drainNotification(tester);
  });
}
