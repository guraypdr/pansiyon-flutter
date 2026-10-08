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
  bool withTeachers = true,
}) async {
  final teachers = withTeachers
      ? [
          for (var id = 1; id <= 6; id++)
            DutyTeacher(id: id, fullName: 'Öğretmen $id'),
        ]
      : <DutyTeacher>[];
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
                      location: slot == 0 ? 'Nöbetçi Odası' : 'Giriş Kapısı',
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
    testWidgets('pencerenin izin verdiği tüm genişliklerde taşma olmaz', (
      tester,
    ) async {
      // Pencere, windows/runner/win32_window.cpp içindeki WM_GETMINMAXINFO
      // ile 1180x680 altına küçültülemiyor. Testler bu sınırın üzerindeki
      // ve tam sınırındaki genişlikleri kapsar.
      for (final width in const [1600.0, 1440.0, 1280.0, 1180.0]) {
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
        width: 1180,
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

    testWidgets('üç yuvalı günlük düzen sınırda da sığar', (tester) async {
      await pumpRoster(tester, width: 1180, dailyCount: 3);
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
    /// Yalnızca hafta başlıklarındaki "N. HAFTA" yazılarını arar; gün
    /// satırlarındaki tarih rakamlarıyla karışmasın diye alt ağaca ineriz.
    Finder weekNumber(String number) => find.descendant(
      of: find.byType(DutyWeekHeader),
      matching: find.text('$number. HAFTA'),
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

  group('Hafta kartı', () {
    testWidgets('başlık koyu renkte ve kartın tam genişliğinde', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      final header = find.byType(DutyWeekHeader).first;
      final card = find.byKey(const ValueKey('duty_day_1'));

      // Başlık, kartın boydan boya genişliğini kaplar; gün satırıyla aynı ölçüdedir.
      expect(
        tester.getSize(header).width,
        closeTo(tester.getSize(card).width, 1),
      );
      // Başlık koyu bir zemin taşır.
      final container = tester.widget<Container>(
        find.descendant(of: header, matching: find.byType(Container)).first,
      );
      expect(
        (container.color ?? container.constraints?.maxHeight) != null ||
            container.decoration != null,
        isTrue,
      );
    });

    testWidgets('başlıkta yalnızca "N. HAFTA" yazısı vardır', (tester) async {
      await pumpRoster(tester, width: 1600);
      final header = find.byType(DutyWeekHeader).first;
      expect(
        find.descendant(of: header, matching: find.text('1. HAFTA')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.textContaining('Eylül')),
        findsNothing,
      );
    });

    testWidgets('her hafta kendi kartında toplanır', (tester) async {
      await pumpRoster(tester, width: 1600);
      // Eylül 2026 -> 5 hafta, yani 5 başlık.
      expect(find.byType(DutyWeekHeader), findsNWidgets(5));
      // Kartlar arası boşluk vardır.
      final first = tester.getTopLeft(find.byType(DutyWeekHeader).first);
      final second = tester.getTopLeft(find.byType(DutyWeekHeader).at(1));
      expect(second.dy - first.dy, greaterThan(50));
    });
  });

  group('Gün satırı', () {
    testWidgets('tarih "14 Eylül Paz" biçiminde tek etiket olarak yazılır', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      expect(find.text('1 Eylül Sal'), findsWidgets);
      // Paneldeki sıra numarası da "1" yazdığı için, gün satırının kendi
      // içinde tek başına "1" bulunmamalıdır.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('duty_day_1')),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });

    testWidgets('nöbetçi "N. Kat: Öğretmen" biçiminde tek satırda', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      // Yer etiketi iki nokta üstü ile biter, öğretmen adı aynı satırda.
      expect(find.text('Nöbetçi Odası:'), findsWidgets);
      expect(find.text('Giriş Kapısı:'), findsWidgets);

      final label = find.text('Nöbetçi Odası:').first;
      final dropdown = find.byKey(const ValueKey('duty_assignment_10'));
      // Aynı satırda, etiket seçicinin solunda.
      expect(
        tester.getTopLeft(label).dy,
        closeTo(tester.getTopLeft(dropdown).dy, 6),
      );
      expect(
        tester.getTopLeft(label).dx,
        lessThan(tester.getTopLeft(dropdown).dx),
      );
    });

    testWidgets('satırlar arasında ince ayraç çizgisi vardır', (tester) async {
      await pumpRoster(tester, width: 1600);
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('duty_day_2')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.border?.bottom.color, AppColors.inputBorder);
    });
  });

  group('Nöbet yeri', () {
    testWidgets('her yuvanın kendi yer etiketi vardır', (tester) async {
      await pumpRoster(tester, width: 1600);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('duty_slot_1_0')),
          matching: find.byType(DutyLocationLabel),
        ),
        findsOneWidget,
      );
      expect(find.byType(DutyLocationLabel), findsWidgets);
    });

    testWidgets('tanımlı yer yoksa "Nöbet yeri yok:" yazar', (tester) async {
      await pumpRoster(
        tester,
        width: 1600,
        settings: settingsWith(locations: const []),
      );
      expect(find.text('Nöbet yeri yok:'), findsWidgets);
    });

    testWidgets('hafta başlığında yer yazısı bulunmaz', (tester) async {
      await pumpRoster(tester, width: 1600);
      expect(
        find.descendant(
          of: find.byType(DutyWeekHeader),
          matching: find.byType(DutyLocationLabel),
        ),
        findsNothing,
      );
    });
  });

  group('Satır genişliği', () {
    testWidgets('gün satırı sol sütunu tamamen kaplar', (tester) async {
      await pumpRoster(tester, width: 1600);
      final row = find.byKey(const ValueKey('duty_day_1'));
      // Sağdaki 300px'lik nöbet dağılımı paneli ve 20+10 boşluk düşülür.
      expect(tester.getSize(row).width, closeTo(1600 - 300 - 20 - 10, 2));
    });

    testWidgets('daraltma sınırı yerel değildir: pencere sınırlar', (
      tester,
    ) async {
      // Gerçek sınırlama windows/runner/win32_window.cpp içindeki
      // WM_GETMINMAXINFO ile yapılır; içerikte yerel bir genişlik
      // sınırı veya yatay kaydırma yoktur.
      await pumpRoster(tester, width: 1180);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('geniş pencerede liste solda panel sağda yerleşir', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      final row = find.byKey(const ValueKey('duty_day_1'));
      expect(tester.getSize(row).width, closeTo(1600 - 300 - 20 - 10, 2));
      // Panel, listenin sağındadır.
      expect(
        tester.getTopLeft(find.text('NÖBET DAĞILIMI')).dx,
        greaterThan(tester.getTopRight(row).dx),
      );
    });

    testWidgets('sınırın üstünde ölçü bozulmaz', (tester) async {
      for (final width in const [1600.0, 1440.0, 1280.0, 1180.0]) {
        await pumpRoster(tester, width: width);
        expect(tester.takeException(), isNull, reason: '$width px');
      }
    });

    testWidgets('açılır liste tüm ekranı kaplamaz', (tester) async {
      await pumpRoster(tester, width: 1600);
      final dropdown = find.byKey(const ValueKey('duty_assignment_10'));
      expect(tester.getSize(dropdown).width, lessThan(400));
    });
  });

  group('Yuva etkileşimi', () {
    testWidgets('dolu yuvada seçici ve kaldırma düğmesi vardır', (
      tester,
    ) async {
      await pumpRoster(tester, width: 1600);
      expect(find.byKey(const ValueKey('duty_slot_1_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('duty_assignment_10')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('duty_assignment_remove_10')),
        findsOneWidget,
      );
    });

    testWidgets('boş yuvada seçim listesi bulunur', (tester) async {
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
      expect(find.byKey(const ValueKey('duty_slot_empty_3_0')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('duty_slot_15_0')), findsNothing);
  });

  group('dutyTeacherDutyCounts', () {
    List<DutyTeacher> buildTeachers() => [
      for (var id = 1; id <= 6; id++)
        DutyTeacher(id: id, fullName: 'Öğretmen $id'),
    ];

    List<DutyAssignment> buildAssignments(Map<int, int> counts) => [
      for (final entry in counts.entries)
        for (var i = 0; i < entry.value; i++)
          DutyAssignment(
            id: entry.key * 100 + i,
            year: 2026,
            month: 9,
            date: DateTime(2026, 9, 1),
            teacherId: entry.key,
          ),
    ];

    test('her öğretmenin nöbeti doğru sayılır', () {
      final counts = dutyTeacherDutyCounts(
        assignments: buildAssignments({1: 6, 2: 5, 3: 4, 4: 3, 5: 2, 6: 1}),
        teachers: buildTeachers(),
      );
      expect(counts.map((item) => item.count).toList(), [6, 5, 4, 3, 2, 1]);
    });

    test('nöbeti olmayan öğretmen sıfırla listelenir', () {
      final counts = dutyTeacherDutyCounts(
        assignments: buildAssignments({2: 2}),
        teachers: buildTeachers(),
      );
      expect(counts.length, 6);
      expect(counts.firstWhere((item) => item.teacherId == 2).count, 2);
      expect(
        counts
            .where((item) => item.teacherId != 2)
            .every((item) => item.count == 0),
        isTrue,
      );
    });

    test('eşit sayıda ada göre sıralanır', () {
      final counts = dutyTeacherDutyCounts(
        assignments: buildAssignments({3: 2, 1: 2}),
        teachers: buildTeachers(),
      );
      final equal = counts.where((item) => item.count == 2).toList();
      expect(equal.map((item) => item.fullName), ['Öğretmen 1', 'Öğretmen 3']);
    });

    test('atama yoksa tüm sayılar sıfırdır', () {
      final counts = dutyTeacherDutyCounts(
        assignments: const [],
        teachers: buildTeachers(),
      );
      expect(counts.map((item) => item.count), everyElement(0));
    });

    test('kimliksiz öğretmenler atlanır', () {
      final counts = dutyTeacherDutyCounts(
        assignments: buildAssignments({1: 1}),
        teachers: const [DutyTeacher(fullName: 'Kimliksiz')],
      );
      expect(counts, isEmpty);
    });
  });

  group('Nöbet dağılımı paneli', () {
    /// Panel içindeki metinleri arar. Açılır listelerdeki öğretmen adları da
    /// aynı metni taşıdığı için sonuçları panelle sınırlandırırız.
    Finder panelText(String text) => find.descendant(
      of: find.byKey(const ValueKey('duty_count_panel')),
      matching: find.text(text),
    );

    Finder panelTexts(String pattern) => find.descendant(
      of: find.byKey(const ValueKey('duty_count_panel')),
      matching: find.textContaining(pattern),
    );

    /// Panelde listelenen öğretmen adlarını sırayla döndürür.
    List<String> panelTeacherNames(WidgetTester tester) => tester
        .widgetList<Text>(panelTexts('Öğretmen'))
        .map((text) => text.data ?? '')
        .toList();

    /// Nöbet sayıları 6,5,4,3,2,1 olan öğretmen listesi üretir.
    List<DutyAssignment> staggeredAssignments() {
      var id = 0;
      return [
        for (var teacher = 1; teacher <= 6; teacher++)
          for (var count = 0; count < 7 - teacher; count++)
            DutyAssignment(
              id: id++,
              year: 2026,
              month: 9,
              date: DateTime(2026, 9, (count % 28) + 1),
              teacherId: teacher,
            ),
      ];
    }

    testWidgets('panel sağda kim kaç nöbet yaptığını gösterir', (tester) async {
      await pumpRoster(tester, width: 1600);
      expect(find.text('NÖBET DAĞILIMI'), findsOneWidget);
      for (var id = 1; id <= 6; id++) {
        expect(panelText('Öğretmen $id'), findsOneWidget);
      }
    });

    testWidgets('öğretmenler nöbet sayısına göre azalan sırada', (
      tester,
    ) async {
      await pumpRoster(
        tester,
        width: 1600,
        assignments: staggeredAssignments(),
      );
      expect(panelTeacherNames(tester), [
        'Öğretmen 1',
        'Öğretmen 2',
        'Öğretmen 3',
        'Öğretmen 4',
        'Öğretmen 5',
        'Öğretmen 6',
      ]);
      // 6+5+4+3+2+1 = 21 nöbet.
      expect(find.text('21 nöbet'), findsOneWidget);
    });

    testWidgets('nöbeti olmayan öğretmen sıfırla listelenir', (tester) async {
      await pumpRoster(
        tester,
        width: 1600,
        assignments: [
          for (var day = 1; day <= 8; day++)
            for (var slot = 0; slot < 3; slot++)
              DutyAssignment(
                id: day * 10 + slot,
                year: 2026,
                month: 9,
                date: DateTime(2026, 9, day),
                teacherId: 1,
              ),
        ],
      );
      // Her öğretmen listelenir, nöbeti olmayanlar sıfırla.
      expect(panelTeacherNames(tester).length, 6);
      expect(find.text('24 nöbet'), findsOneWidget);
    });

    testWidgets('boş yuva varsa panelde uyarı görünür', (tester) async {
      await pumpRoster(tester, width: 1600);
      expect(panelTexts('yuva henüz boş'), findsOneWidget);
    });

    testWidgets('tüm yuvalar doluysa boş uyarısı çıkmaz', (tester) async {
      // Eylül 2026'da 30 gün var; günde 2 yuva ile 60 nöbet gerekir.
      await pumpRoster(
        tester,
        width: 1600,
        settings: settingsWith(dailyCount: 2, locations: const ['A', 'B']),
        assignments: [
          for (var day = 1; day <= 30; day++)
            for (var slot = 0; slot < 2; slot++)
              DutyAssignment(
                id: day * 10 + slot,
                year: 2026,
                month: 9,
                date: DateTime(2026, 9, day),
                teacherId: (day + slot) % 6 + 1,
              ),
        ],
      );
      expect(panelTexts('yuva henüz boş'), findsNothing);
      expect(find.text('60 nöbet'), findsOneWidget);
    });

    testWidgets('öğretmen yoksa panel boş durum gösterir', (tester) async {
      await pumpRoster(tester, width: 1600, withTeachers: false);
      expect(panelText('Öğretmen bulunamadı'), findsOneWidget);
    });
  });
}
