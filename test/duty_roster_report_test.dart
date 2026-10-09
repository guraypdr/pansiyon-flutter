import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_report_print.dart';
import 'package:pansiyon_yonetim/shared/pdf/report_pdf_kit.dart';

/// PDF baytlarından sayfa sayısını bulur.
///
/// `pw.Document` sayfaları dışarıya açmaz; sayfa nesneleri sıkıştırılmadan
/// yazıldığı için `/Type /Page` sayımı güvenilirdir. `/Type /Pages` kök
/// düğümü `[^s]` ile elenir.
int countPdfPages(List<int> bytes) {
  final text = latin1.decode(bytes);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReportFonts fonts;

  setUpAll(() async {
    fonts = await ReportFonts.load();
  });

  DutySettings settingsFor({
    int dailyCount = 3,
    Set<String> blackouts = const {},
  }) => DutySettings(
    sectionKey: null,
    dailyCount: dailyCount,
    locations: const ['A Blok - Zemin Kat', 'A Blok - 1. Kat', 'B Blok'],
    blackouts: blackouts,
  );

  DutyReportData reportFor({
    required int year,
    required int month,
    DutySettings? settings,
    int emptyAfter = 1000,
    String principalName = '',
  }) {
    final resolved = settings ?? settingsFor();
    final teachers = [
      for (var index = 1; index <= 7; index++)
        DutyTeacher(id: index, fullName: 'Öğretmen Adı Soyadı $index'),
    ];
    final dates = dutyMonthDates(year, month);
    final assignments = <DutyAssignment>[];
    for (var day = 0; day < dates.length; day++) {
      for (var slot = 0; slot < resolved.dailyCount; slot++) {
        if (day >= emptyAfter) {
          continue;
        }
        assignments.add(
          DutyAssignment(
            year: year,
            month: month,
            date: dates[day],
            teacherId: teachers[(day + slot) % teachers.length].id!,
          ),
        );
      }
    }
    return DutyReportData(
      schoolName: 'Musabeyli Çok Programlı Anadolu Lisesi',
      principalName: principalName,
      teachers: teachers,
      lists: [
        DutyMonthList(
          year: year,
          month: month,
          sectionKey: null,
          assignmentCount: assignments.length,
        ),
      ],
      currentList: DutyMonthList(
        year: year,
        month: month,
        sectionKey: null,
        assignmentCount: assignments.length,
      ),
      currentAssignments: assignments,
      settings: resolved,
    );
  }

  group('rosterWeeks', () {
    test('hafta numarasi 1 den baslar, ISO hafta numarasi kullanilmaz', () {
      // Ekim 2026 ISO olarak 41. haftada; listede 1. hafta olmali.
      final weeks = rosterWeeks(2026, 10, settingsFor());

      expect(weeks, isNotEmpty);
      expect(weeks.first.first.day, 1);
      expect(weeks.length, 5);
    });

    test('ilk hafta ayin 1 inde baslar, sonrakiler pazartesi ile', () {
      for (var month = 1; month <= 12; month++) {
        final weeks = rosterWeeks(2026, month, settingsFor());

        expect(weeks.first.first.day, 1, reason: '$month. ay');
        for (final week in weeks.skip(1)) {
          expect(week.first.weekday, DateTime.monday, reason: '$month. ay');
        }
      }
    });

    test('bir hafta en fazla 7 gun icerir ve gunler ardisiktir', () {
      for (var month = 1; month <= 12; month++) {
        for (final week in rosterWeeks(2026, month, settingsFor())) {
          expect(week.length, lessThanOrEqualTo(7), reason: '$month. ay');
          expect(week.first.day, lessThanOrEqualTo(week.last.day));
          for (var index = 1; index < week.length; index++) {
            expect(
              week[index].difference(week[index - 1]).inDays,
              1,
              reason: '$month. ay: ${week[index - 1]} -> ${week[index]}',
            );
          }
        }
      }
    });

    test('hafta sayisi ayin uzunluguna gore hesaplanir', () {
      // Tanım: ayın 1'inden önceki boş gün sayısı + ayın gün sayısı 7'ye
      // bölünüp yukarı yuvarlanır. 28 günlük ayda 5, 31 günlük ayda pazar
      // başlıyorsa 6 hafta çıkar.
      for (var month = 1; month <= 12; month++) {
        final dates = dutyMonthDates(2026, month);
        final leading = dates.first.weekday - DateTime.monday;
        final expected = ((leading + dates.length) / 7).ceil();

        expect(
          rosterWeeks(2026, month, settingsFor()),
          hasLength(expected),
          reason: '$month. ay (${dates.length} gün, $leading boş gün)',
        );
      }
    });

    test('pazar baslayan ayda ilk hafta tek gun olur', () {
      final month = [
        for (var index = 1; index <= 12; index++)
          if (dutyMonthDates(2026, index).first.weekday == DateTime.sunday)
            index,
      ].first;
      final weeks = rosterWeeks(2026, month, settingsFor());

      expect(dutyMonthDates(2026, month).first.weekday, DateTime.sunday);
      expect(weeks.first, hasLength(1));
      expect(weeks.last.length, lessThanOrEqualTo(7));
    });

    test('kapali gunler listeye girmez', () {
      final dates = dutyMonthDates(2026, 10);
      final closed = dutyDateKey(dates[4]);

      final weeks = rosterWeeks(2026, 10, settingsFor(blackouts: {closed}));

      final allDays = weeks.expand((week) => week).toList();
      expect(allDays, hasLength(dates.length - 1));
      expect(allDays.map(dutyDateKey), isNot(contains(closed)));
    });

    test('tum kapali gune donuldugunde liste bos olur', () {
      final all = {
        for (final date in dutyMonthDates(2026, 3)) dutyDateKey(date),
      };

      expect(rosterWeeks(2026, 3, settingsFor(blackouts: all)), isEmpty);
    });

    test('ayin butun gunleri kapali gunler haric listelenir', () {
      final weeks = rosterWeeks(2026, 10, settingsFor());

      final allDays = weeks.expand((week) => week).toList();
      expect(allDays, dutyMonthDates(2026, 10));
    });
  });

  group('aylik nobet listesi cikti dosyasi', () {
    test('gecerli PDF uretir', () async {
      final document = buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(year: 2026, month: 10),
        fonts,
      );

      final bytes = await document.save();

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('31 gunluk ay uc nöbetci ile tek sayfaya sigar', () async {
      // Regresyon: cok programli okulda 3 nöbetci ve 31 gun bulundugunde
      // liste tek sayfaya sigmalidir. Sigmayan tasarimda kullanici her ay
      // 2 kopya basmak zorunda kaliyordu.
      final document = buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(year: 2026, month: 10),
        fonts,
      );

      expect(countPdfPages(await document.save()), 1);
    });

    test('tum aylar tek sayfaya sigar', () async {
      for (var month = 1; month <= 12; month++) {
        final document = buildMonthlyDutyRosterPdf(
          pw.Document(),
          reportFor(year: 2026, month: month),
          fonts,
        );

        expect(
          countPdfPages(await document.save()),
          1,
          reason: '$month. ay tek sayfaya sigmali',
        );
      }
    });

    test('nöbet yeri tanimlanmamissa da cikti uretilir', () async {
      final document = buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(
          year: 2026,
          month: 10,
          settings: DutySettings(sectionKey: null, dailyCount: 2),
        ),
        fonts,
      );

      expect(countPdfPages(await document.save()), 1);
    });

    test('kapali gun olan ayda da cikti uretilir', () async {
      final dates = dutyMonthDates(2026, 10);
      final blackouts = {for (final date in dates.take(20)) dutyDateKey(date)};

      final document = buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(
          year: 2026,
          month: 10,
          settings: settingsFor(blackouts: blackouts),
        ),
        fonts,
      );

      expect(countPdfPages(await document.save()), 1);
    });
  });

  group('okul muduru imzasi', () {
    test('ad soyad ve unvan ciktiya eklenir', () async {
      // Müdür adı doluyken çıktı, boş olan çıktıdan daha uzun olmalı. Bu,
      // imza bloğunun gerçekten basıldığını kanıtlar.
      final withName = await buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(year: 2026, month: 10, principalName: 'Ahmet Yılmaz'),
        fonts,
      ).save();
      final withoutName = await buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(year: 2026, month: 10),
        fonts,
      ).save();

      expect(withName.length, greaterThan(withoutName.length));
    });

    test('ad bosken cikti yine de uretilir', () async {
      // Boş bir imza çizgisi kalmamalı; çıktı yine de üretilir.
      final document = buildMonthlyDutyRosterPdf(
        pw.Document(),
        reportFor(year: 2026, month: 10, principalName: '   '),
        fonts,
      );

      expect(countPdfPages(await document.save()), 1);
    });

    test('imza blogu sayfa sayisini artirmaz', () async {
      // Regresyon: imza bloğu footer'ı büyüttüğü için 31 günlük ay 2 sayfaya
      // taşıyordu. Alt köşedeki imza tek sayfada kalmalı.
      for (var month = 1; month <= 12; month++) {
        final document = buildMonthlyDutyRosterPdf(
          pw.Document(),
          reportFor(year: 2026, month: month, principalName: 'Ahmet Yılmaz'),
          fonts,
        );

        expect(
          countPdfPages(await document.save()),
          1,
          reason: '$month. ay imza bloğuyla tek sayfada kalmalı',
        );
      }
    });
  });
}
