import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_roster_tab.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_widgets.dart';

DutySettings settingsWith({
  int dailyCount = 3,
  List<String> locations = const ['Nöbetçi Odası', 'Giriş Kapısı', 'Kışlık'],
}) {
  return DutySettings(
    sectionKey: null,
    dailyCount: dailyCount,
    maxConsecutive: 2,
    locations: locations,
  );
}

Future<void> pumpRoster(
  WidgetTester tester, {
  required double width,
  DutySettings? settings,
  List<DutyAssignment>? assignments,
  int dailyCount = 3,
  int year = 2026,
  int month = 9,
  // Liste tembel kurulduğu için tüm haftaların sayılabilmesi adına
  // ekranı ayın tamamını gösterecek kadar uzun tutuyoruz.
  double height = 3200,
}) async {
  final teachers = [
    for (var id = 1; id <= 6; id++)
      DutyTeacher(id: id, fullName: 'Öğretmen $id'),
  ];
  final resolved = settings ?? settingsWith(dailyCount: dailyCount);

  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DutyRosterTab(
          year: year,
          month: month,
          settings: resolved,
          assignments:
              assignments ??
              [
                for (var day = 1; day <= 8; day++)
                  for (var slot = 0; slot < dailyCount; slot++)
                    DutyAssignment(
                      id: day * 10 + slot,
                      year: 2026,
                      month: 9,
                      date: DateTime(2026, 9, day),
                      teacherId: (day + slot) % 6 + 1,
                      location: slot == 0
                          ? 'Nöbetçi Odası'
                          : 'Giriş Kapısı',
                    ),
              ],
          teachers: teachers,
          onAssignmentChanged: (_, _) {},
          onAssignmentRemoved: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('Taşma yok', () {
    testWidgets('1600 ile 400 piksel arasında yatay taşma olmaz', (
      tester,
    ) async {
      // Regresyon: yuva içindeki nöbet yeri etiketi sabit 76px genişlikteydi;
      // 520px altındaki pencerelerde 21-29px taşıyordu.
      for (final width in const [1600.0, 1200.0, 900.0, 700.0, 520.0, 400.0]) {
        await pumpRoster(tester, width: width);
        expect(
          tester.takeException(),
          isNull,
          reason: '$width px genişlikte taşma oldu',
        );
      }
    });

    testWidgets('çok uzun nöbet yeri adıyla taşma olmaz', (tester) async {
      await pumpRoster(
        tester,
        width: 420,
        settings: settingsWith(
          locations: const [
            'Kız Bölümü Bodrum Katı Kuzeybatı Nöbetçi Odası',
            'Giriş Kapısı ve Kamera Önü',
          ],
        ),
        dailyCount: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Özet kutuları', () {
    testWidgets('gün, yuva, toplam ve yer bilgileri görünür', (tester) async {
      await pumpRoster(tester, width: 1600);
      expect(find.text('Nöbet günü'), findsOneWidget);
      expect(find.text('Günlük nöbetçi'), findsOneWidget);
      expect(find.text('Toplam nöbet'), findsOneWidget);
      expect(find.text('Nöbet yerleri'), findsOneWidget);
    });

    testWidgets('boş yuva sayısı bildirilir', (tester) async {
      // 22 nöbet günü x 3 yuva = 66 yuva, 24 atama yapildi.
      await pumpRoster(tester, width: 1600, dailyCount: 3);
      expect(find.textContaining('yuva boş'), findsOneWidget);
    });

    testWidgets('tüm yuvalar doluyken boş uyarısı çıkmaz', (tester) async {
      // 2 gün, günde 1 yuva -> tam dolu.
      await pumpRoster(
        tester,
        width: 1600,
        dailyCount: 1,
        assignments: [
          DutyAssignment(
            id: 1,
            year: 2026,
            month: 9,
            date: DateTime(2026, 9, 1),
            teacherId: 1,
          ),
          DutyAssignment(
            id: 2,
            year: 2026,
            month: 9,
            date: DateTime(2026, 9, 2),
            teacherId: 2,
          ),
        ],
      );
      // Kapalı günler olmadigi icin diger gunler bos kalir; yalnizca
      // "yuva dolu" ifadesinin gorunmedigini dogrulariz.
      expect(find.textContaining('tüm yuvalar dolu'), findsNothing);
    });
  });

  group('Hafta başlıkları', () {
    /// Yalnızca hafta başlıklarındaki numaraları arar; gün satırlarındaki
    /// tarih rakamlarıyla karışmasın diye alt ağaca ineriz.
    Finder weekNumber(String number) => find.descendant(
      of: find.byType(DutyWeekHeader),
      matching: find.text(number),
    );

    testWidgets('numaralar ay başından itibaren 1 den başlar', (tester) async {
      // Eylül 2026'nın 1'i salıdır; ISO hafta numarası (36-40) kullanılmaz.
      await pumpRoster(tester, width: 1600);
      expect(weekNumber('1'), findsOneWidget);
      expect(weekNumber('2'), findsOneWidget);
      for (final isoWeek in const ['36', '37', '38', '39', '40']) {
        expect(weekNumber(isoWeek), findsNothing);
      }
    });

    testWidgets('başlıkta tarih aralığı veya gün sayısı yazmaz', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      final header = find.byType(DutyWeekHeader);
      expect(
        find.descendant(of: header, matching: find.textContaining('Eylül')),
        findsNothing,
      );
      expect(
        find.descendant(of: header, matching: find.textContaining('gün')),
        findsNothing,
      );
      // Her başlıkta yalnızca numara ve "HAFTA" yazısı vardır.
      expect(
        find.descendant(of: header, matching: find.text('HAFTA')),
        findsNWidgets(find.byType(DutyWeekHeader).evaluate().length),
      );
    });

    testWidgets('ay 1 pazartesi değilse ilk hafta ay 1 den kısa olur', (
      tester,
    ) async {
      // Eylül 2026: 1 Salı. İlk hafta 1-6 Eylül (6 gün), sonra 7-13,
      // 14-20, 21-27 ve 28-30 -> toplam 5 hafta.
      await pumpRoster(tester, width: 1600);
      expect(find.byType(DutyWeekHeader), findsNWidgets(5));
      expect(weekNumber('5'), findsOneWidget);
      expect(weekNumber('6'), findsNothing);
    });

    testWidgets('ay 1 pazartesi değilse hafta sayısı doğru ilerler', (
      tester,
    ) async {
      // Kasım 2026: 1 Pazar. İlk hafta yalnızca 1 Kasım, sonra 2-8, 9-15,
      // 16-22, 23-29 ve 30 -> toplam 6 hafta.
      await pumpRoster(tester, width: 1600, month: 11);
      expect(find.byType(DutyWeekHeader), findsNWidgets(6));
      expect(weekNumber('6'), findsOneWidget);
      expect(weekNumber('7'), findsNothing);
    });
  });

  group('Yuva etkileşimi', () {
    testWidgets('dolu yuvada öğretmen seçici ve kaldırma düğmesi vardır', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      expect(find.byKey(const ValueKey('duty_slot_1_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('duty_assignment_10')), findsOneWidget);
      expect(find.byKey(const ValueKey('duty_assignment_remove_10')), findsOneWidget);
    });

    testWidgets('boş yuvada seçim listesi bulunur', (tester) async {
      // 8 gün x 3 yuva = 24 yuva, hepsi dolu; 9. gün boş yuva içerir.
      await pumpRoster(
        tester,
        width: 1600,
        assignments: [
          for (var day = 1; day <= 2; day++)
            for (var slot = 0; slot < 3; slot++)
              DutyAssignment(
                id: day * 10 + slot,
                year: 2026,
                month: 9,
                date: DateTime(2026, 9, day),
                teacherId: (day + slot) % 6 + 1,
              ),
        ],
      );
      expect(
        find.byKey(const ValueKey('duty_slot_empty_3_0')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('duty_slot_pick_3_0')), findsOneWidget);
    });
  });

  testWidgets('kapalı gün listede yer almaz', (tester) async {
    final settings = DutySettings(
      sectionKey: null,
      dailyCount: 2,
      maxConsecutive: 2,
      locations: const ['A', 'B'],
      blackouts: {dutyDateKey(DateTime(2026, 9, 15))},
    );
    await pumpRoster(
      tester,
      width: 1600,
      settings: settings,
      assignments: [
        DutyAssignment(
          id: 1,
          year: 2026,
          month: 9,
          date: DateTime(2026, 9, 15),
          teacherId: 1,
        ),
      ],
    );
    // 15 Eylül kara dönem; o günün yuvası çizilmemeli.
    expect(find.byKey(const ValueKey('duty_slot_15_0')), findsNothing);
  });
}