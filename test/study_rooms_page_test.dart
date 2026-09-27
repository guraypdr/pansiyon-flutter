import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/rooms/data/room_repository.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/data/study_room_repository.dart';
import 'package:pansiyon_yonetim/features/study_rooms/domain/study_room_models.dart';
import 'package:pansiyon_yonetim/features/study_rooms/presentation/study_room_seating_preview.dart';
import 'package:pansiyon_yonetim/features/study_rooms/presentation/study_rooms_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _singleFloorDraft = BoardingInfoDraft(
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
      name: 'A Blok',
      standardRoomCapacity: 4,
      floors: [BoardingFloorDraft(floorNumber: 1, studentRoomCount: 2)],
    ),
  ],
);

const _multiFloorDraft = BoardingInfoDraft(
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
      name: 'A Blok',
      standardRoomCapacity: 4,
      floors: [
        BoardingFloorDraft(floorNumber: 1, studentRoomCount: 2),
        BoardingFloorDraft(floorNumber: 2, studentRoomCount: 1),
      ],
    ),
  ],
);

void main() {
  tearDown(AppNotifier.instance.hide);

  late AppDatabase database;
  late SqliteBoardingInfoRepository boardingInfoRepository;
  late SqliteStudentRepository studentRepository;
  late SqliteRoomRepository roomRepository;
  late SqliteStudyRoomRepository repository;

  setUp(() async {
    database = AppDatabase(databasePath: inMemoryDatabasePath);
    boardingInfoRepository = SqliteBoardingInfoRepository(database);
    studentRepository = SqliteStudentRepository(database);
    roomRepository = SqliteRoomRepository(database);
    repository = SqliteStudyRoomRepository(
      database,
      boardingInfoRepository: boardingInfoRepository,
    );
    await boardingInfoRepository.save(_singleFloorDraft);
    await roomRepository.syncRooms(_singleFloorDraft);
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
    // Bildirimin otomatik kapanma timer'ı test sonunda hâlâ durmasın.
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudyRoomsPage(
            repository: repository,
            studentRepository: studentRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);
  }

  testWidgets('salon yokken boş durum ve ekleme butonu görünür', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Etüt Salonları'), findsOneWidget);
    expect(find.text('0 salon kayıtlı'), findsOneWidget);
    expect(find.text('Henüz etüt salonu eklenmedi'), findsOneWidget);
    expect(find.byKey(const Key('add_study_room_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tek bölüm ve tek kat varken konum sorulmaz', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);

    expect(find.text('Etüt Salonu Ekle'), findsWidgets);
    expect(find.byKey(const Key('study_room_block_dropdown')), findsNothing);
    expect(find.byKey(const Key('study_room_floor_dropdown')), findsNothing);
    expect(find.text('Kız Bölümü • A Blok • Zemin Kat'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();
  });

  testWidgets('birden fazla kat varken kat seçimi sorulur', (tester) async {
    await tester.runAsync(() async {
      await boardingInfoRepository.save(_multiFloorDraft);
      await roomRepository.syncRooms(_multiFloorDraft);
    });
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('study_room_block_dropdown')), findsNothing);
    expect(find.byKey(const Key('study_room_floor_dropdown')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Vazgeç'));
    await tester.pumpAndSettle();
  });

  testWidgets('salon eklenir ve otomatik kapasite ile düzen görünür', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);
    // Kapasite artık sorulmaz; tekli sıra 5 x 4 = 20 kişilik varsayılan.
    expect(find.byKey(const Key('study_room_capacity_field')), findsNothing);
    expect(find.text('20 kişi'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('study_room_name_field')),
      'zemin etüt salonu',
    );
    await tester.tap(find.byKey(const Key('study_room_submit_button')));
    await tester.pump();
    await settle(tester);

    expect(find.text('Zemin Etüt Salonu'), findsOneWidget);
    expect(find.text('0 / 20 kişi'), findsOneWidget);
    expect(find.text('Tekli Sıra'), findsOneWidget);
    final rooms = await tester.runAsync(repository.getStudyRooms);
    expect(rooms!.single.capacity, 20);
    expect(rooms.single.name, 'Zemin Etüt Salonu');
  });

  testWidgets('artı ve eksi düğmeleri sıra sayısını değiştirir', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.createStudyRoom(
        name: 'Zemin Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.single,
      ),
    );
    await pumpPage(tester);
    final roomId = (await tester.runAsync(repository.getStudyRooms))!.single.id;

    expect(find.text('Yana sıra: 5'), findsOneWidget);
    expect(find.text('Arkaya sıra: 4'), findsOneWidget);

    await tester.tap(find.byKey(Key('grow_${roomId}_plus_columns')));
    await tester.pump();
    await settle(tester);
    expect(find.text('Yana sıra: 6'), findsOneWidget);
    expect(find.text('24 kişi'), findsOneWidget);

    await tester.tap(find.byKey(Key('grow_${roomId}_minus_columns')));
    await tester.pump();
    await settle(tester);
    expect(find.text('Yana sıra: 5'), findsOneWidget);

    await tester.tap(find.byKey(Key('grow_${roomId}_minus_rows')));
    await tester.pump();
    await settle(tester);
    expect(find.text('Arkaya sıra: 3'), findsOneWidget);
    expect(find.text('15 kişi'), findsOneWidget);
  });

  testWidgets('U düzeninde sol, sağ ve taban sayaçları bulunur', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.createStudyRoom(
        name: 'U Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.horseshoe,
      ),
    );
    await pumpPage(tester);

    expect(find.text('Sol bacak: 5'), findsOneWidget);
    expect(find.text('Taban: 10'), findsOneWidget);
    expect(find.text('Sağ bacak: 5'), findsOneWidget);
    expect(find.text('20 kişi'), findsOneWidget);
  });

  testWidgets('grup düzeninde yatay ve dikey masa sayaçları bulunur', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.createStudyRoom(
        name: 'Grup Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.groupTables,
        tableSize: 4,
      ),
    );
    await pumpPage(tester);

    expect(find.text('Yatay masa: 2'), findsOneWidget);
    expect(find.text('Dikey masa: 2'), findsOneWidget);
    expect(find.text('16 kişi'), findsOneWidget);
  });

  testWidgets('grup düzeninde masa soruları açılır', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);
    expect(find.byKey(const Key('study_room_table_size_field')), findsNothing);

    await tester.tap(find.byKey(const Key('study_room_seating_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grup Çalışma Masası').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('study_room_table_size_field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('study_room_tables_have_students')),
      findsOneWidget,
    );
    expect(find.text('Masa başlarında oturan var mı?'), findsOneWidget);
  });

  testWidgets('otomatik yerleştirme kattaki öğrencileri salona alır', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final girl = await studentRepository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
      final room = (await roomRepository.getRooms()).first;
      await roomRepository.assignStudent(roomId: room.id, studentId: girl);
    });
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);
    await tester.tap(find.byKey(const Key('study_room_submit_button')));
    await tester.pump();
    await settle(tester);
    final roomId = (await tester.runAsync(repository.getStudyRooms))!.single.id;

    await tester.tap(find.byKey(Key('study_room_auto_place_$roomId')));
    await tester.pump();
    await settle(tester);

    expect(find.text('1 / 20 kişi'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsOneWidget);
  });

  testWidgets('yerleşen öğrenci havuza alınabilir', (tester) async {
    await tester.runAsync(() async {
      final girl = await studentRepository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
      final room = (await roomRepository.getRooms()).first;
      await roomRepository.assignStudent(roomId: room.id, studentId: girl);
    });
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);
    await tester.tap(find.byKey(const Key('study_room_submit_button')));
    await tester.pump();
    await settle(tester);
    final roomId = (await tester.runAsync(repository.getStudyRooms))!.single.id;
    final studentId = (await tester.runAsync(
      studentRepository.getStudents,
    ))!.single.id;

    await tester.tap(find.byKey(Key('study_room_auto_place_$roomId')));
    await tester.pump();
    await settle(tester);
    expect(find.text('1 / 20 kişi'), findsOneWidget);

    await tester.tap(find.byKey(Key('release_student_$studentId')));
    await tester.pump();
    await settle(tester);

    expect(find.text('0 / 20 kişi'), findsOneWidget);
    // Öğrenci havuza döner ve havuz panelinde görünür.
    expect(find.text('Henüz öğrenci yerleştirilmedi.'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(await tester.runAsync(repository.getAssignments), isEmpty);
  });

  testWidgets('salon düzenlenir ve silinir', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);
    await tester.tap(find.byKey(const Key('study_room_submit_button')));
    await tester.pump();
    await settle(tester);
    final roomId = (await tester.runAsync(repository.getStudyRooms))!.single.id;

    await tester.tap(find.byKey(Key('study_room_edit_$roomId')));
    await tester.pump();
    await settle(tester);
    expect(find.text('Etüt Salonu Düzenle'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('study_room_name_field')),
      'Yeni Salon Adı',
    );
    // Kapasite alanı yok; düzen sayaçları ile değiştirilir.
    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byKey(const Key('dialog_minus_columns')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('study_room_submit_button')));
    await tester.pump();
    await settle(tester);

    expect(find.text('Yeni Salon Adı'), findsOneWidget);
    // 1 sütun x 4 satır = 4 kişi.
    expect(find.text('0 / 4 kişi'), findsOneWidget);

    await tester.tap(find.byKey(Key('study_room_delete_$roomId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Etüt salonu silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pump();
    await settle(tester);

    expect(await tester.runAsync(repository.getStudyRooms), isEmpty);
    expect(find.text('0 salon kayıtlı'), findsOneWidget);
    expect(find.text('Henüz etüt salonu eklenmedi'), findsOneWidget);
  });

  testWidgets('havuzda yerleştirilmemiş öğrenciler listelenir', (tester) async {
    await tester.runAsync(() async {
      final first = await studentRepository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
      await studentRepository.saveStudent(
        const Student(fullName: 'Elif Şahin', gender: StudentGender.female),
      );
      final room = (await roomRepository.getRooms()).first;
      await roomRepository.assignStudent(roomId: room.id, studentId: first);
    });
    await pumpPage(tester);

    expect(find.text('Öğrenci Havuzu'), findsOneWidget);
    expect(find.text('1 öğrenci'), findsOneWidget);
    expect(find.text('Kız Bölümü • A Blok • Zemin Kat'), findsWidgets);
    // Havuz yalnızca o katta uyuyan, salona yerleştirilmemiş öğrencileri listeler.
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Elif Şahin'), findsNothing);
  });

  testWidgets('havuzdaki öğrenci salona yerleştirilir', (tester) async {
    await tester.runAsync(() async {
      final studentId = await studentRepository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
      final room = (await roomRepository.getRooms()).first;
      await roomRepository.assignStudent(roomId: room.id, studentId: studentId);
      await repository.createStudyRoom(
        name: 'Zemin Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.single,
      );
    });
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('place_student_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Zemin Salonu').last);
    await tester.pump();
    await settle(tester);

    final assignments = await tester.runAsync(repository.getAssignments);
    expect(assignments, hasLength(1));
    expect(assignments!.single.studentId, 1);
    expect(find.text('Havuzda öğrenci yok'), findsNothing);
    expect(find.text('1 / 20 kişi'), findsOneWidget);
  });

  testWidgets('oturma düzeni diyalogda görsel olarak gösterilir', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('add_study_room_button')));
    await tester.pump();
    await settle(tester);
    expect(find.byKey(const Key('study_room_seating_preview')), findsOneWidget);
    expect(find.textContaining('Boş sandalyeler gösteriliyor'), findsOneWidget);
    // Tekli sıra düzeninde yana ve arkaya sıra sayaçları bulunur.
    expect(find.text('Yana sıra: 5'), findsOneWidget);
    expect(find.text('Arkaya sıra: 4'), findsOneWidget);

    // Düzen değiştikçe sayaçlar ve görünüm değişir.
    await tester.tap(find.byKey(const Key('study_room_seating_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U Tipi').last);
    await tester.pumpAndSettle();
    expect(find.text('Sol bacak: 5'), findsOneWidget);
    expect(find.text('Taban: 10'), findsOneWidget);
    expect(find.text('Sağ bacak: 5'), findsOneWidget);

    // Çiftli düzende iki sandalye yapışık kutu içinde gösterilir.
    await tester.tap(find.byKey(const Key('study_room_seating_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çiftli Sıra').last);
    await tester.pumpAndSettle();
    expect(find.text('Yana sıra: 5'), findsOneWidget);
    expect(find.text('Arkaya sıra: 2'), findsOneWidget);

    // Grup düzeninde masa soruları açılır.
    await tester.tap(find.byKey(const Key('study_room_seating_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grup Çalışma Masası').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('study_room_table_size_field')), findsOneWidget);
    expect(find.text('Yatay masa: 2'), findsOneWidget);
    expect(find.text('Dikey masa: 2'), findsOneWidget);
  });

  testWidgets('salon kartında oturma haritası görünür', (tester) async {
    await tester.runAsync(
      () => repository.createStudyRoom(
        name: 'Zemin Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.single,
      ),
    );
    await pumpPage(tester);

    expect(find.textContaining('1 salon • 0 / 20 kişi'), findsOneWidget);
    expect(find.byType(StudyRoomSeatingMap), findsOneWidget);
    expect(find.textContaining('Boş sandalyeler gösteriliyor'), findsOneWidget);
  });

  testWidgets('yerleşen öğrenciler haritada adlarıyla görünür', (tester) async {
    await tester.runAsync(() async {
      final first = await studentRepository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
      final second = await studentRepository.saveStudent(
        const Student(fullName: 'Elif Şahin', gender: StudentGender.female),
      );
      final room = (await roomRepository.getRooms()).first;
      await roomRepository.assignStudent(roomId: room.id, studentId: first);
      await roomRepository.assignStudent(roomId: room.id, studentId: second);
      await repository.createStudyRoom(
        name: 'Zemin Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.single,
      );
    });
    await pumpPage(tester);
    final roomId = (await tester.runAsync(repository.getStudyRooms))!.single.id;

    await tester.tap(find.byKey(Key('study_room_auto_place_$roomId')));
    await tester.pump();
    await settle(tester);

    // Harita, iki öğrenciyi sandalyelere yerleştirir.
    expect(
      find.descendant(
        of: find.byKey(Key('study_room_map_$roomId')),
        matching: find.text('Zeynep K.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('study_room_map_$roomId')),
        matching: find.text('Elif Ş.'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('2 öğrenci yerleştirildi'), findsOneWidget);
  });

  testWidgets('blok ve kat filtreleri listeyi daraltır', (tester) async {
    await tester.runAsync(() async {
      await boardingInfoRepository.save(_multiFloorDraft);
      await repository.createStudyRoom(
        name: 'Zemin Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.single,
      );
      await repository.createStudyRoom(
        name: 'Birinci Kat Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: '1. Kat',
        floorNumber: 2,
        seating: StudyRoomSeating.single,
      );
    });
    await pumpPage(tester);

    expect(find.textContaining('2 salon • 0 / 40 kişi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('study_floor_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Kat').last);
    await tester.pumpAndSettle();

    expect(find.text('Zemin Salonu'), findsNothing);
    expect(find.text('Birinci Kat Salonu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('study_floor_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tümü').last);
    await tester.pumpAndSettle();
    expect(find.text('Zemin Salonu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar pencerede taşma olmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudyRoomsPage(
            repository: repository,
            studentRepository: studentRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('kartta otomatik yerleştirme butonu görünür', (tester) async {
    await tester.runAsync(
      () => repository.createStudyRoom(
        name: 'Zemin Salonu',
        section: BoardingSection.girls,
        blockName: 'A Blok',
        floorLabel: 'Zemin Kat',
        floorNumber: 1,
        seating: StudyRoomSeating.single,
      ),
    );
    await pumpPage(tester);

    expect(find.text('Otomatik Yerleştir'), findsOneWidget);
    expect(find.textContaining('1 salon • 0 / 20 kişi'), findsOneWidget);
    expect(find.text('Kız Bölümü • A Blok • Zemin Kat'), findsOneWidget);
  });
}
