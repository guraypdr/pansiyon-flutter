import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/duty/domain/duty_models.dart';
import 'package:pansiyon_yonetim/features/duty/presentation/duty_stats_tab.dart';

DutyTeacher teacher(int id, String name, DutyPreference preference) {
  return DutyTeacher(
    id: id,
    fullName: name,
    dutyPreference: preference,
  );
}

DutyMonthList monthList(int year, int month, int count, [String key = '']) {
  return DutyMonthList(
    year: year,
    month: month,
    sectionKey: key,
    assignmentCount: count,
  );
}

void main() {
  final teachers = [
    teacher(1, 'Zeynep Kaya', DutyPreference.balanced),
    teacher(2, 'Mert Demir', DutyPreference.maximum),
    teacher(3, 'Elif Şahin', DutyPreference.minimum),
  ];

  final lists = [
    monthList(2026, 9, 30),
    monthList(2026, 10, 20),
    monthList(2026, 11, 10),
  ];

  // Öğretmen 1: 4+3 = 7, Öğretmen 2: 5+4 = 9, Öğretmen 3: 1+0 = 1
  final perTeacherMonth = <int, Map<int, int>>{
    1: {9: 4, 10: 3},
    2: {9: 5, 10: 4},
    3: {9: 1},
  };

  Future<void> pumpStats(
    WidgetTester tester, {
    double width = 1600,
    double height = 1200,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DutyStatsTab(
            teachers: teachers,
            lists: lists,
            assignments: const [],
            year: 2026,
            perTeacherMonth: perTeacherMonth,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('başlık satırı tüm sütunlarda aynı hizada durur', (tester) async {
    // Regresyon: ay başlıkları yükseklik sınırı olmayan bir Center içinde
    // yer alıyordu ve sınırsız yükseklikte ortalanarak "Öğretmen" ve
    // "Toplam" başlıklarının altına kayıyordu.
    await pumpStats(tester);

    // Sütunlar yalnızca nöbet kaydı olan aylardan üretilir; Kasım
    // listesel olarak var ama hiçbir öğretmende nöbeti yok.
    final basliklar = <String>['Öğretmen', 'Eyl', 'Eki', 'Toplam'];
    final merkezler = <String, double>{};
    for (final baslik in basliklar) {
      final bulucu = find.text(baslik);
      expect(bulucu, findsOneWidget, reason: '"$baslik" bulunamadı');
      merkezler[baslik] = tester.getCenter(bulucu).dy;
    }

    final degerler = merkezler.values.toList();
    for (final deger in degerler) {
      expect(
        deger,
        moreOrLessEquals(degerler.first, epsilon: 1),
        reason: 'başlıklar aynı hizada olmalı, ölçülen: $merkezler',
      );
    }
  });

  testWidgets('öğretmen satırları eşit yükseklikte ve toplamlar sıralı', (
    tester,
  ) async {
    await pumpStats(tester);

    // En çok nöbet alan öğretmen en üstte: Mert Demir (9).
    final sirali = tester
        .getTopLeft(find.text('Mert Demir'))
        .dy;
    final alt = tester.getTopLeft(find.text('Zeynep Kaya')).dy;
    final enAlt = tester.getTopLeft(find.text('Elif Şahin')).dy;
    expect(sirali, lessThan(alt));
    expect(alt, lessThan(enAlt));

    // Her satır hücresi aynı yükseklikte.
    final satirYukseklikleri = <double>{
      for (final ad in const ['Mert Demir', 'Zeynep Kaya', 'Elif Şahin'])
        tester.getSize(find.text(ad)).height,
    };
    expect(
      satirYukseklikleri,
      hasLength(1),
      reason: 'ad hücreleri aynı yükseklikte olmalı',
    );
  });

  testWidgets('öğretmen adı, ay ve toplam değerleri görünür', (tester) async {
    await pumpStats(tester);

    // Elif Şahin: Eylül 1, Kasım yok -> toplam 1
    expect(find.text('Elif Şahin'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    // Toplam sütunu 9 / 7 / 1 gösterir.
    expect(find.text('9'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('öğretmen istek tercihi satırda renkli şeritle gösterilir', (
    tester,
  ) async {
    await pumpStats(tester);
    for (final etiket in const ['Dengeli', 'Maksimum', 'Minimum']) {
      expect(find.text(etiket), findsOneWidget, reason: '"$etiket" görünmeli');
    }
  });

  testWidgets('dar pencerede özet kartları taşmaz', (tester) async {
    await pumpStats(tester, width: 700, height: 1600);
    expect(find.text('Eklenen öğretmen'), findsOneWidget);
    expect(find.text('Bu aydaki nöbet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çok dar pencerede de taşma olmaz', (tester) async {
    await pumpStats(tester, width: 420, height: 2000);
    expect(find.text('Eklenen öğretmen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('veri yokken boş durum gösterilir', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DutyStatsTab(
            teachers: const [],
            lists: const [],
            assignments: const [],
            year: 2026,
            perTeacherMonth: const {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gösterilecek veri yok'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nöbet almayan öğretmen tabloda yer almaz', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DutyStatsTab(
            teachers: [teacher(9, 'Hiç Nöbet Almadı', DutyPreference.minimum)],
            lists: lists,
            assignments: const [],
            year: 2026,
            perTeacherMonth: const {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Hiç Nöbet Almadı'), findsNothing);
    expect(find.textContaining('nöbet alan öğretmen yok'), findsOneWidget);
  });
}