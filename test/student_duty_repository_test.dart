import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/students/data/student_duty_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Öğrenci nöbet repository', () {
    late AppDatabase database;
    late SqliteStudentDutyRepository repository;

    setUp(() async {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      repository = SqliteStudentDutyRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('tur yoksa null döner', () async {
      expect(await repository.getCurrentList(), isNull);
    });

    test('başlangıç tarihiyle tur oluşturulur', () async {
      final list = await repository.createList(
        startDate: DateTime(2026, 10, 5),
      );

      final current = await repository.getCurrentList();
      expect(current, isNotNull);
      expect(current!.id, list.id);
      expect(current.startDate, DateTime(2026, 10, 5));
      expect(current.entries, isEmpty);
    });

    test('girdiler yazılır ve sırayla okunur', () async {
      final list = await repository.createList(
        startDate: DateTime(2026, 10, 5),
      );
      await repository.replaceEntries(
        listId: list.id!,
        days: const [
          StudentDutyDay(sequence: 1, studentIds: [11, 12]),
          StudentDutyDay(sequence: 2, studentIds: [13, 14]),
          StudentDutyDay(sequence: 3, studentIds: [15]),
        ],
      );

      final current = await repository.getCurrentList();
      expect(current!.studentCount, 5);
      expect(current.dayCount, 3);
      expect(current.days.first.studentIds, [11, 12]);
      expect(current.days.last.studentIds, [15]);
    });

    test('girdiler değiştirilince eskiler silinir', () async {
      final list = await repository.createList(
        startDate: DateTime(2026, 10, 5),
      );
      await repository.replaceEntries(
        listId: list.id!,
        days: const [
          StudentDutyDay(sequence: 1, studentIds: [11, 12]),
        ],
      );
      await repository.replaceEntries(
        listId: list.id!,
        days: const [
          StudentDutyDay(sequence: 1, studentIds: [21, 22]),
        ],
      );

      final current = await repository.getCurrentList();
      final ids = [
        for (final day in current!.days) ...day.studentIds,
      ];
      expect(ids, [21, 22]);
    });

    test('tur silinir', () async {
      final list = await repository.createList(
        startDate: DateTime(2026, 10, 5),
      );
      await repository.replaceEntries(
        listId: list.id!,
        days: const [
          StudentDutyDay(sequence: 1, studentIds: [11, 12]),
        ],
      );

      await repository.deleteList(list.id!);

      expect(await repository.getCurrentList(), isNull);
    });

    group('Kapalı günler', () {
      test('kaydedilip okunur', () async {
        await repository.saveBlackouts({'2026-10-01', '2026-10-02'});

        expect(
          await repository.getBlackouts(),
          {'2026-10-01', '2026-10-02'},
        );
      });

      test('kayıt yenilenince eskiler silinir', () async {
        await repository.saveBlackouts({'2026-10-01', '2026-10-02'});
        await repository.saveBlackouts({'2026-10-03'});

        expect(await repository.getBlackouts(), {'2026-10-03'});
      });
    });

    group('Arşivlenen öğrenci düşer ve liste bir öne kayar', () {
      Future<void> seed() async {
        final list = await repository.createList(
          startDate: DateTime(2026, 10, 5),
        );
        await repository.replaceEntries(
          listId: list.id!,
          days: const [
            StudentDutyDay(sequence: 1, studentIds: [1, 2]),
            StudentDutyDay(sequence: 2, studentIds: [3, 4]),
            StudentDutyDay(sequence: 3, studentIds: [5, 6]),
            StudentDutyDay(sequence: 4, studentIds: [7, 8]),
          ],
        );
      }

      test('arşivlenen öğrenci listeden düşer', () async {
        await seed();

        await repository.removeArchivedStudents(const {3});

        final current = await repository.getCurrentList();
        final ids = [
          for (final day in current!.days) ...day.studentIds,
        ];
        expect(ids, isNot(contains(3)));
      });

      test('kalan öğrenciler bir öne kayar', () async {
        await seed();

        await repository.removeArchivedStudents(const {3});

        final current = await repository.getCurrentList();
        final days = current!.days;
        expect(days.length, 4);
        expect(days[0].studentIds, [1, 2]);
        // 3 gittiği için 4 bir öne geçer.
        expect(days[1].studentIds, [4, 5]);
        expect(days[2].studentIds, [6, 7]);
        expect(days[3].studentIds, [8]);
      });

      test('gün sırası 1 den başlar', () async {
        await seed();

        await repository.removeArchivedStudents(const {5});

        final current = await repository.getCurrentList();
        expect(
          current!.days.map((day) => day.sequence),
          [1, 2, 3, 4],
        );
      });

      test('arşivdeki öğrenci yoksa liste değişmez', () async {
        await seed();

        await repository.removeArchivedStudents(const {});

        final current = await repository.getCurrentList();
        expect(current!.days[1].studentIds, [3, 4]);
        expect(current.dayCount, 4);
      });

      test('iki öğrenci arşive düşerse bir gün eksilir', () async {
        await seed();

        await repository.removeArchivedStudents(const {5, 6});

        final current = await repository.getCurrentList();
        expect(current!.dayCount, 3);
        expect(current.days.last.studentIds, [7, 8]);
      });

      test('tur yoksa arşiv temizliği hata vermez', () async {
        await repository.removeArchivedStudents(const {3});

        expect(await repository.getCurrentList(), isNull);
      });
    });
  });
}
