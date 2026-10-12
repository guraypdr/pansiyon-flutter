import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_excel_importer.dart';
import 'package:pansiyon_yonetim/features/meals/data/meal_repository.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:pansiyon_yonetim/features/meals/presentation/meal_import_dialog.dart';
import 'package:pansiyon_yonetim/features/meals/presentation/meals_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';

/// Testlerde ekranı besleyen bellek içi depo.
class _FakeMealRepository implements MealRepository {
  final Map<String, MealDay> days = {};
  var _nextId = 1;

  void seed(List<MealDay> seed) {
    for (final day in seed) {
      days[mealDateKey(day.date)] = MealDay(
        id: _nextId++,
        date: day.date,
        items: day.items,
      );
    }
  }

  @override
  Future<List<MealDay>> getMonth(int year, int month) async {
    final result =
        days.values
            .where((day) => day.date.year == year && day.date.month == month)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  @override
  Future<List<MealMonthRef>> getMonths() async {
    final grouped = <String, List<MealDay>>{};
    for (final day in days.values) {
      grouped
          .putIfAbsent('${day.date.year}-${day.date.month}', () => [])
          .add(day);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        MealMonthRef(
          year: int.parse(key.split('-')[0]),
          month: int.parse(key.split('-')[1]),
          dayCount: grouped[key]!.length,
        ),
    ];
  }

  @override
  Future<MealImportResult> importDays(List<MealDay> incoming) async {
    var added = 0;
    var updated = 0;
    for (final day in incoming) {
      final key = mealDateKey(day.date);
      if (days.containsKey(key)) {
        updated++;
      } else {
        added++;
      }
      days[key] = MealDay(
        id: days[key]?.id ?? _nextId++,
        date: day.date,
        items: day.items,
      );
    }
    return MealImportResult(added: added, updated: updated);
  }

  @override
  Future<void> saveDay(MealDay day) async {
    final key = mealDateKey(day.date);
    days[key] = MealDay(
      id: days[key]?.id ?? _nextId++,
      date: day.date,
      items: day.items,
    );
  }

  @override
  Future<void> deleteDay(DateTime date) async {
    days.remove(mealDateKey(date));
  }

  @override
  Future<void> clearMonth(int year, int month) async {
    days.removeWhere(
      (key, day) => day.date.year == year && day.date.month == month,
    );
  }
}

Future<void> pumpPage(WidgetTester tester, MealRepository repository) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MealsPage(repository: repository)),
    ),
  );
}

void main() {
  // Bildirim katmanı 4 saniyelik bir zamanlayıcı bırakır; test ağacı
  // dağıtıldıktan sonra da sarkıyor.
  tearDown(AppNotifier.instance.hide);

  MealDay day(int date, {String breakfast = 'Domates-Peynir'}) {
    return MealDay(
      date: DateTime(2026, 10, date),
      items: {
        MealType.breakfast: splitMealItems(breakfast),
        MealType.lunch: splitMealItems('Yayla çorbası-Soslu makarna-Elma'),
        MealType.dinner: splitMealItems('Ekşili köfte-Pirinç pilavı'),
        MealType.snack: splitMealItems('Sütlaç-Kuruyemiş'),
      },
    );
  }

  testWidgets('menu yokken bos durum ve iceri aktarma dugmesi gorunur', (
    tester,
  ) async {
    final repository = _FakeMealRepository();
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meals_empty_import_button')), findsOneWidget);
    expect(find.text('Bu ay için menü yok'), findsOneWidget);
    expect(find.byKey(const Key('meals_list')), findsNothing);
  });

  testWidgets('yuklenen menuler gun kartlari olarak listelenir', (
    tester,
  ) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1), day(2), day(5)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meals_list')), findsOneWidget);
    // Her günde 2 kahvaltı + 3 öğle + 2 akşam + 2 ara öğün = 9 yemek.
    expect(find.text('3 gün • 27 yemek • Ekim 2026'), findsOneWidget);
  });

  testWidgets('dort ogun basligi her kartta gorunur', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Kahvaltı'), findsOneWidget);
    expect(find.text('Öğle'), findsOneWidget);
    expect(find.text('Akşam'), findsOneWidget);
    expect(find.text('Ara Öğün'), findsOneWidget);
  });

  testWidgets('yemekler ayri satirlarda gosterilir', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Domates'), findsOneWidget);
    expect(find.text('Peynir'), findsOneWidget);
    expect(find.text('Yayla çorbası'), findsOneWidget);
    expect(find.text('Soslu makarna'), findsOneWidget);
    // "Domates, Peynir" olarak birleşik gösterilmemeli.
    expect(find.text('Domates, Peynir'), findsNothing);
  });

  testWidgets('gun adi ve tarih kartta yazilir', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('1.10.2026'), findsOneWidget);
    expect(find.text('Perşembe'), findsOneWidget);
  });

  testWidgets('menu olmayan ogun tire ile gosterilir', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([
      MealDay(
        date: DateTime(2026, 10, 1),
        items: {
          MealType.breakfast: ['Domates'],
        },
      ),
    ]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('onceki ve sonraki ay dugmeleri ay degistirir', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('1.10.2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('meals_next_month')));
    await tester.pumpAndSettle();

    // Kasımda menü yoktur.
    expect(find.text('Bu ay için menü yok'), findsOneWidget);
    expect(find.text('1.10.2026'), findsNothing);
  });

  testWidgets('menu olmayan aydan one ay geri donulurse menu bulunur', (
    tester,
  ) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meals_next_month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meals_previous_month')));
    await tester.pumpAndSettle();

    expect(find.text('1.10.2026'), findsOneWidget);
  });

  testWidgets('gun silme onayi sonrasi kayit silinir', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1), day(2)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_day_delete_2026-10-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    // Başarı bildirimi 4 saniyelik zamanlayıcı bırakır.
    await tester.pump(const Duration(seconds: 5));

    expect(repository.days.containsKey('2026-10-01'), isFalse);
    expect(find.text('1.10.2026'), findsNothing);
    expect(find.text('2.10.2026'), findsOneWidget);
  });

  testWidgets('silme vazgecilirse kayit kalir', (tester) async {
    final repository = _FakeMealRepository();
    repository.seed([day(1)]);
    await pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_day_delete_2026-10-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.days.containsKey('2026-10-01'), isTrue);
  });

  group('İçe aktarma penceresi', () {
    Future<void> pumpDialog(
      WidgetTester tester,
      MealImportPreview preview,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MealImportDialog(preview: preview),
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
    }

    testWidgets('gun ve yemek sayisi yazilir', (tester) async {
      await pumpDialog(
        tester,
        MealImportPreview(
          days: [
            MealDay(
              date: DateTime(2026, 10, 1),
              items: {
                MealType.breakfast: ['Domates'],
                MealType.lunch: ['Çorba'],
              },
            ),
          ],
          warnings: [],
        ),
      );

      expect(find.textContaining('1 gün'), findsOneWidget);
      expect(find.textContaining('2 yemek'), findsOneWidget);
    });

    testWidgets('uyarilar gosterilir', (tester) async {
      await pumpDialog(
        tester,
        MealImportPreview(
          days: [MealDay(date: DateTime(2026, 10, 1))],
          warnings: ['EKİM: 4 satır tarih içermediği için atlandı.'],
        ),
      );

      expect(
        find.text('EKİM: 4 satır tarih içermediği için atlandı.'),
        findsOneWidget,
      );
    });

    testWidgets('menu bulunamazsa onay dugmesi etkisizdir', (tester) async {
      await pumpDialog(
        tester,
        MealImportPreview(days: [], warnings: ['Excel dosyası okunamadı.']),
      );

      final button = tester.widget<AppPrimaryButton>(
        find.byKey(const Key('meal_import_confirm')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('ilk gunler onizlenir', (tester) async {
      await pumpDialog(
        tester,
        MealImportPreview(
          days: [for (var index = 1; index <= 5; index++) day(index)],
          warnings: const [],
        ),
      );

      expect(find.text('... ve 1 gün daha'), findsOneWidget);
    });
  });
}
