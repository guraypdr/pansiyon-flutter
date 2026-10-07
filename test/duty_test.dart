import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_repository.dart';
import 'package:pansiyon_yonetim/features/duty/data/duty_teacher_excel_importer.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_distribution.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DutyTeacher teacher(
  int id,
  String name, {
  DutyPreference preference = DutyPreference.balanced,
  List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
  bool isActive = true,
}) {
  return DutyTeacher(
    id: id,
    fullName: name,
    dutyPreference: preference,
    availableWeekdays: weekdays,
    isActive: isActive,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nöbet dağıtım algoritması', () {
    test('herkese birer nöbet yazılır', () {
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [teacher(1, 'Ali'), teacher(2, 'Berna'), teacher(3, 'Cem')],
          dutyDates: [
            DateTime(2026, 9, 7),
            DateTime(2026, 9, 8),
            DateTime(2026, 9, 9),
          ],
        ),
      );

      expect(assignments.length, 3);
      expect(assignments.map((item) => item.teacherId).toSet().length, 3);
    });

    test('nöbet yalnızca müsait günlere yazılır', () {
      // 2026-09-07 Pazartesi, 2026-09-08 Salı.
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [
            teacher(1, 'Ali', weekdays: const [1]),
            teacher(2, 'Berna', weekdays: const [1, 2]),
          ],
          dutyDates: [DateTime(2026, 9, 7), DateTime(2026, 9, 8)],
          dailyCount: 1,
        ),
      );

      expect(assignments.length, 2);
      final monday = assignments.firstWhere((item) => item.date.day == 7);
      final tuesday = assignments.firstWhere((item) => item.date.day == 8);
      expect(monday.teacherId, 1);
      expect(tuesday.teacherId, 2);
    });

    test(
      'dengeli isteyen haftada bir, maksimum isteyen ayda en çok 8 nöbet alır',
      () {
        final dates = dutyMonthDates(2026, 9)
            .where(
              (date) =>
                  date.weekday != DateTime.saturday &&
                  date.weekday != DateTime.sunday,
            )
            .toList();
        final teachers = [
          teacher(1, 'Dengeli', preference: DutyPreference.balanced),
          teacher(2, 'Maksimum', preference: DutyPreference.maximum),
        ];

        final assignments = DutyDistribution.generate(
          DutyDistributionInput(
            year: 2026,
            month: 9,
            teachers: teachers,
            dutyDates: dates,
          ),
        );

        final balanced = assignments
            .where((item) => item.teacherId == 1)
            .length;
        final maximum = assignments.where((item) => item.teacherId == 2).length;
        final weeks = dates
            .map(
              (date) => date.subtract(Duration(days: date.weekday - 1)).month,
            )
            .toSet();

        expect(balanced, weeks.length);
        expect(maximum, lessThanOrEqualTo(8));
        expect(maximum, greaterThan(balanced));
      },
    );

    test('minimum isteyen yalnızca ilk turda görev alır', () {
      final dates = dutyMonthDates(2026, 9)
          .where(
            (date) =>
                date.weekday != DateTime.saturday &&
                date.weekday != DateTime.sunday,
          )
          .toList();
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [
            teacher(1, 'Minimum', preference: DutyPreference.minimum),
            teacher(2, 'Dengeli'),
          ],
          dutyDates: dates,
        ),
      );

      expect(assignments.where((item) => item.teacherId == 1).length, 1);
    });

    test('üst üste nöbet sınırına uyulur', () {
      final dates = dutyMonthDates(2026, 9)
          .where(
            (date) =>
                date.weekday != DateTime.saturday &&
                date.weekday != DateTime.sunday,
          )
          .toList();
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [teacher(1, 'Ali'), teacher(2, 'Berna'), teacher(3, 'Cem')],
          dutyDates: dates,
          maxConsecutive: 1,
        ),
      );

      final datesByTeacher = <int, List<DateTime>>{};
      for (final assignment in assignments) {
        datesByTeacher
            .putIfAbsent(assignment.teacherId, () => [])
            .add(assignment.date);
      }
      for (final items in datesByTeacher.values) {
        items.sort();
        for (var index = 1; index < items.length; index++) {
          expect(
            items[index].difference(items[index - 1]).inDays,
            greaterThan(1),
          );
        }
      }
    });

    test('pasif öğretmenler dağıtıma katılmaz', () {
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [teacher(1, 'Ali'), teacher(2, 'Pasif', isActive: false)],
          dutyDates: [DateTime(2026, 9, 7), DateTime(2026, 9, 8)],
        ),
      );

      expect(assignments.every((item) => item.teacherId == 1), isTrue);
    });

    test('günlük nöbetçi sayısı 2 veya 3 olur', () {
      for (final dailyCount in const [2, 3]) {
        final assignments = DutyDistribution.generate(
          DutyDistributionInput(
            year: 2026,
            month: 9,
            teachers: [
              teacher(1, 'Ali'),
              teacher(2, 'Berna'),
              teacher(3, 'Cem'),
              teacher(4, 'Deniz'),
            ],
            dutyDates: [DateTime(2026, 9, 7)],
            dailyCount: dailyCount,
          ),
        );
        expect(
          assignments.where((item) => item.date.day == 7).length,
          dailyCount,
        );
      }
    });

    test('günlük nöbetçi sayısı kadar öğretmen atanır', () {
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [teacher(1, 'Ali'), teacher(2, 'Berna'), teacher(3, 'Cem')],
          dutyDates: [DateTime(2026, 9, 7)],
          dailyCount: 2,
        ),
      );

      expect(assignments.length, 2);
    });

    test('nöbet yerleri sırayla dağıtılır', () {
      final assignments = DutyDistribution.generate(
        DutyDistributionInput(
          year: 2026,
          month: 9,
          teachers: [teacher(1, 'Ali'), teacher(2, 'Berna')],
          dutyDates: [DateTime(2026, 9, 7)],
          dailyCount: 2,
          locations: const ['A Blok - Zemin Kat', 'A Blok - 1. Kat'],
        ),
      );

      expect(assignments.map((item) => item.location).toSet(), {
        'A Blok - Zemin Kat',
        'A Blok - 1. Kat',
      });
    });
  });

  group('nöbet yardımcıları', () {
    test('ay günleri ve hafta sonu kapanışları', () {
      expect(dutyDaysInMonth(2026, 9), 30);
      expect(dutyMonthTitle(2026, 9), 'Eylül 2026');
      expect(dutyWeekdayLabel(DateTime.monday), 'Pazartesi');
      expect(dutyWeekdayShortLabel(5), 'Cum');
      expect(defaultDutyBlackoutKeys(2026, 9).length, 8);
      expect(dutyMonthCalendar(2026, 9).first.first, isNull);
      expect(dutyMonthCalendar(2026, 9).first.length, 7);
    });

    test(
      'ba\u015f harfler b\u00fcy\u00fck ve T\u00fcrk\u00e7e uygun yaz\u0131l\u0131r',
      () {
        expect(dutyTeacherInitials('zeynep kaya'), 'ZK');
        expect(dutyTeacherInitials('ay\u015fe y\u0131lmaz'), 'AY');
        expect(dutyTeacherInitials('AY\u015eE YILMAZ'), 'AY');
        expect(dutyTeacherInitials('zeynep'), 'Z');
        expect(dutyTeacherInitials(''), '?');
      },
    );

    test(
      'n\u00f6bet yeri yuvalara g\u00f6re da\u011f\u0131t\u0131l\u0131r',
      () {
        const settings = DutySettings(
          sectionKey: null,
          locations: ['Zemin Kat'],
        );
        expect(settings.dailyCount, 2);
        expect(settings.locationsForSlots(2), ['Zemin Kat', '']);
        expect(settings.locationForSlot(0), 'Zemin Kat');
        expect(settings.locationForSlot(1), '');
        expect(settings.withLocation(1, '1. Kat').locations, [
          'Zemin Kat',
          '1. Kat',
        ]);
      },
    );

    test('nöbet puanı nöbet sayısı kadardır', () {
      expect(dutyScore(0), 0);
      expect(dutyScore(7), 7);
    });
  });

  group('excel şablonu', () {
    test('şablon başlıkları beklenen sütunları içerir', () {
      final bytes = const DutyTeacherExcelImporter().buildTemplate();
      expect(bytes.length, greaterThan(500));
      final excel = Excel.decodeBytes(bytes);
      final headers = excel.tables.values.first.rows.first
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .toList();
      expect(headers, contains('Ad Soyad'));
      expect(headers, contains('T.C. Kimlik No'));
      expect(headers, contains('Okul'));
      expect(headers, contains('Branş'));
      expect(headers, contains('Beletmenlik Eğitimi'));
      expect(headers, contains('Nöbet İsteği'));
      expect(headers, contains('Nöbet Müsait Günler'));
    });

    test('Excel kilit dosyası seçilirse uyarı verir', () async {
      // Excel, açık çalışma kitabı için "~$ad.xlsx" adlı geçici kilit
      // dosyası oluşturur; dosya seçme penceresinde .xlsx olarak görünür.
      final directory = await Directory.systemTemp.createTemp(
        'duty_lock_file_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final lockPath =
          '${directory.path}${Platform.pathSeparator}~\$sablon.xlsx';
      File(lockPath).writeAsBytesSync(List<int>.filled(165, 0));

      final preview = await const DutyTeacherExcelImporter().readFile(lockPath);

      expect(preview.rows, isEmpty);
      expect(preview.headerWarnings.single, contains('kilit dosyası'));
    });

    test('okunamayan dosya için sebebi belirtir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'duty_broken_file_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bogusPath =
          '${directory.path}${Platform.pathSeparator}notatablo.xlsx';
      File(bogusPath).writeAsStringSync('bu bir excel dosyasi degil');

      final preview = await const DutyTeacherExcelImporter().readFile(
        bogusPath,
      );

      expect(preview.headerWarnings.single, contains('.xlsx'));
    });
  });

  group('nöbet repository', () {
    late AppDatabase database;
    late SqliteDutyRepository repository;

    setUp(() async {
      database = AppDatabase(databasePath: inMemoryDatabasePath);
      repository = SqliteDutyRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('öğretmen kaydedilir, güncellenir ve silinir', () async {
      final id = await repository.saveTeacher(
        const DutyTeacher(fullName: 'Ali Veli'),
      );
      final teachers = await repository.getTeachers();
      expect(teachers.single.fullName, 'Ali Veli');
      expect(teachers.single.availableWeekdays, [1, 2, 3, 4, 5]);

      await repository.saveTeacher(
        DutyTeacher(
          id: id,
          fullName: 'Ali Veli',
          dutyPreference: DutyPreference.maximum,
          availableWeekdays: const [1, 3, 5],
          phone: '05321234567',
        ),
      );
      final updated = (await repository.getTeachers()).single;
      expect(updated.dutyPreference, DutyPreference.maximum);
      expect(updated.availableWeekdays, [1, 3, 5]);
      expect(updated.phone, '0532 123 45 67');

      await repository.deleteTeacher(id);
      expect(await repository.getTeachers(), isEmpty);
    });

    test('bölüm bazlı ayarlar ve nöbet atamaları kaydedilir', () async {
      final teacherId = await repository.saveTeacher(
        const DutyTeacher(fullName: 'Berna Kaya'),
      );

      final initial = await repository.getSettings(null);
      expect(initial.dailyCount, 2);
      expect(initial.maxConsecutive, 2);
      expect(initial.locations, isEmpty);
      expect(initial.blackouts, isEmpty);

      await repository.saveSettings(
        initial.copyWith(
          dailyCount: 3,
          maxConsecutive: 1,
          locations: const ['A Blok - Zemin Kat'],
          blackouts: {dutyDateKey(DateTime(2026, 9, 7))},
        ),
      );
      final saved = await repository.getSettings(null);
      expect(saved.dailyCount, 3);
      expect(saved.maxConsecutive, 1);
      expect(saved.locations, ['A Blok - Zemin Kat']);
      expect(saved.blackouts, {dutyDateKey(DateTime(2026, 9, 7))});

      // Bölümler birbirinden bağımsızdır.
      final girls = await repository.getSettings('Kız Bölümü');
      expect(girls.dailyCount, 2);
      expect(girls.blackouts, isEmpty);

      await repository.replaceAssignments(
        year: 2026,
        month: 9,
        sectionKey: null,
        assignments: [
          DutyAssignment(
            year: 2026,
            month: 9,
            date: DateTime(2026, 9, 8),
            teacherId: teacherId,
            location: 'A Blok - Zemin Kat',
          ),
          DutyAssignment(
            year: 2026,
            month: 9,
            date: DateTime(2026, 9, 9),
            teacherId: teacherId,
          ),
        ],
      );

      final assignments = await repository.getAssignments(year: 2026, month: 9);
      expect(assignments.length, 2);
      expect(assignments.first.location, 'A Blok - Zemin Kat');
      expect(
        await repository.getAssignments(
          year: 2026,
          month: 9,
          sectionKey: 'Kız Bölümü',
        ),
        isEmpty,
      );

      final lists = await repository.getMonthLists();
      expect(lists.single.year, 2026);
      expect(lists.single.month, 9);
      expect(lists.single.assignmentCount, 2);

      await repository.deleteMonthList(year: 2026, month: 9);
      expect(await repository.getAssignments(year: 2026, month: 9), isEmpty);
    });

    test('ay listesi oluşturma ve mevcut liste uyarısı', () async {
      expect(await repository.createMonthList(year: 2026, month: 10), isFalse);
      expect(await repository.createMonthList(year: 2026, month: 10), isTrue);
      expect(
        await repository.createMonthList(
          year: 2026,
          month: 10,
          sectionKey: 'Kız Bölümü',
        ),
        isFalse,
      );

      final lists = await repository.getMonthLists();
      expect(lists.length, 2);
      expect(lists.every((item) => item.assignmentCount == 0), isTrue);

      final teacherId = await repository.saveTeacher(
        const DutyTeacher(fullName: 'Ali Veli'),
      );
      await repository.replaceAssignments(
        year: 2026,
        month: 10,
        sectionKey: null,
        assignments: [
          DutyAssignment(
            year: 2026,
            month: 10,
            date: DateTime(2026, 10, 5),
            teacherId: teacherId,
          ),
        ],
      );

      final withCounts = await repository.getMonthLists();
      expect(
        withCounts
            .firstWhere((item) => item.sectionKey == null)
            .assignmentCount,
        1,
      );

      await repository.deleteMonthList(year: 2026, month: 10, sectionKey: null);
      expect(
        (await repository.getMonthLists()).where(
          (item) => item.sectionKey == null,
        ),
        isEmpty,
      );
    });

    test('nöbet atamaları liste kaydını da oluşturur', () async {
      final teacherId = await repository.saveTeacher(
        const DutyTeacher(fullName: 'Ali Veli'),
      );
      await repository.replaceAssignments(
        year: 2026,
        month: 10,
        sectionKey: null,
        assignments: [
          DutyAssignment(
            year: 2026,
            month: 10,
            date: DateTime(2026, 10, 5),
            teacherId: teacherId,
          ),
        ],
      );

      final lists = await repository.getMonthLists();
      final list = lists.firstWhere(
        (item) =>
            item.year == 2026 && item.month == 10 && item.sectionKey == null,
      );
      expect(list.assignmentCount, 1);
    });
  });
}
