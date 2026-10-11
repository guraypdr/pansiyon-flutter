import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/app/pansiyon_yonetim_app.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _pumpAsync(WidgetTester tester) async {
  // Sabit pompalama sayısı yerine uygulama gerçekten çizilene kadar beklenir.
  // Testler paralel çalıştığında veritabanı açılışı yavaşlayabiliyor ve
  // sabit bir bütçe uygulama çerçevesinin hiç oluşmamasına yol açıyordu.
  const appFrameKey = Key('app_frame');
  const minimumPasses = 5;
  for (var index = 0; index < 30; index++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    final ready = find.byKey(appFrameKey).evaluate().isNotEmpty;
    if (ready && index + 1 >= minimumPasses) {
      return;
    }
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  final database = AppDatabase(databasePath: inMemoryDatabasePath);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
  await tester.pumpWidget(PansiyonYonetimApp(database: database));
  await tester.pump();
  await _pumpAsync(tester);
}

/// Veritabanından gelen özet kartlarının çizilmesini bekler.
Future<void> _pumpUntilHomeCards(WidgetTester tester) async {
  for (var index = 0; index < 30; index++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    if (find.text('Aktif kayıt').evaluate().isNotEmpty) {
      return;
    }
  }
}

void main() {
  testWidgets('üst menü çubuğu menüleri yatay sırada gösterir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);

    expect(find.byKey(const Key('top_nav_surface')), findsOneWidget);
    expect(find.byKey(const Key('top_nav_area')), findsOneWidget);
    expect(find.text('PansiyonPro'), findsOneWidget);
    // Yan menü tamamen kaldırıldı.
    expect(find.byKey(const Key('sidebar_surface')), findsNothing);

    const itemIds = [
      'dashboard',
      'courses',
      'friends',
      'schedule',
      'study',
      'attendance',
      'discipline',
    ];
    var previousX = -1.0;
    for (final itemId in itemIds) {
      final finder = find.byKey(Key('sidebar_item_$itemId'));
      expect(finder, findsOneWidget);
      final currentX = tester.getTopLeft(finder).dx;
      expect(currentX, greaterThan(previousX));
      previousX = currentX;
    }

    // Ayarlar menüsü en sağda durur.
    final settings = find.byKey(const Key('sidebar_item_settings'));
    expect(settings, findsOneWidget);
    expect(
      tester.getTopLeft(settings).dx,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('sidebar_item_dashboard'))).dx,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('üst menü çubuğu içerik alanının üstünde yer alır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);

    final nav = tester.getRect(find.byKey(const Key('top_nav_area')));
    final content = tester.getRect(find.byKey(const Key('content_area')));
    final frame = tester.getRect(find.byKey(const Key('app_frame')));

    // Menü çubuğu ve içerik tek parçadır; aralarında boşluk yoktur.
    expect(content.top, greaterThanOrEqualTo(nav.bottom));
    expect(content.top - nav.bottom, lessThan(12));
    expect(content.left, closeTo(frame.left, 0.1));
    expect(content.right, closeTo(frame.right, 0.1));
    expect(content.bottom, closeTo(frame.bottom, 0.1));
    expect(content.width, greaterThan(frame.width * 0.9));
  });

  testWidgets('üst menüde seçili olan vurgulanır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);

    final dashboard = find.byKey(const Key('sidebar_item_dashboard'));
    final background = tester.widget<Material>(
      find.descendant(of: dashboard, matching: find.byType(Material)).first,
    );
    expect(background.color, AppColors.primary);

    final courses = find.byKey(const Key('sidebar_item_courses'));
    final coursesBackground = tester.widget<Material>(
      find.descendant(of: courses, matching: find.byType(Material)).first,
    );
    expect(coursesBackground.color, AppColors.transparent);
  });

  testWidgets('menüye tıklamak ekranı değiştirir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('sidebar_item_courses')));
    await tester.pump();
    await _pumpAsync(tester);
    expect(find.text('Öğrenciler'), findsWidgets);
    expect(find.byKey(const Key('top_bar')), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar_item_schedule')));
    await tester.pump();
    await _pumpAsync(tester);
    // Odalar sayfası da sayfa adı göstermez; yalnızca özet satırı kalır.
    expect(find.text('Oda Yerleştirme'), findsNothing);
    expect(find.byKey(const Key('rooms_sync_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar_item_dashboard')));
    await tester.pump();
    await _pumpAsync(tester);
    await _pumpUntilHomeCards(tester);
    expect(find.text('Aktif kayıt'), findsOneWidget);
  });

  testWidgets('ana sayfa selamlama ve yeni kontrol düğmesi içermez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);

    expect(find.textContaining('Good Morning'), findsNothing);
    expect(find.textContaining('Selena'), findsNothing);
    expect(find.textContaining('Youcare'), findsNothing);
    expect(find.textContaining('Check new'), findsNothing);
  });

  testWidgets('ana sayfa kartları uygulama verilerinden üretilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);
    await _pumpUntilHomeCards(tester);

    // Kartlar uygulama verisinden üretilir.
    expect(find.text('Aktif kayıt'), findsOneWidget);
    expect(find.textContaining('Kayıtlı'), findsOneWidget);
    expect(find.textContaining('Boş Yatak'), findsWidgets);
    expect(find.text('Dolu Yatak'), findsWidgets);
    expect(find.text('Pansiyon Türü'), findsOneWidget);
    expect(find.text('Kademe'), findsOneWidget);
    // Yedekleme/geri yükleme Ayarlar sayfasında.
    expect(find.text('Veri yedeği'), findsNothing);
    // Sayfa adı ve karşılama metni gösterilmez.
    expect(find.text('Pansiyon Özeti'), findsNothing);
    expect(find.text('Günaydın!'), findsNothing);
    expect(find.text('İyi Günler!'), findsNothing);
    expect(find.text('İyi Akşamlar!'), findsNothing);
    expect(find.text('Yeni Kayıt'), findsNothing);
  });

  testWidgets('sağ içerik alanı tüm boşluğu kaplar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);

    expect(find.text('AI Learning Assistant'), findsNothing);
    expect(find.text('AI Peers Matching'), findsNothing);
    expect(find.text('Online Users'), findsNothing);
    expect(find.text('Nov 2020'), findsNothing);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.byKey(const Key('content_area')), findsOneWidget);
  });

  testWidgets('dar pencerede mevcut düzen taşma olmadan korunur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntilHomeCards(tester);

    final topNav = find.byKey(const Key('top_nav_area'));

    expect(find.byKey(const Key('top_nav_area')), findsOneWidget);
    expect(tester.getSize(topNav).height, greaterThan(0));
    expect(find.byKey(const Key('content_area')), findsOneWidget);
    expect(find.byKey(const Key('app_frame')), findsOneWidget);
    expect(find.text('PansiyonPro'), findsOneWidget);
    expect(find.text('Aktif kayıt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kaydedilmemiş pansiyon bilgilerinde çıkış uyarısı gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    addTearDown(database.close);

    await tester.pumpWidget(PansiyonYonetimApp(database: database));
    await tester.tap(find.byKey(const Key('sidebar_item_settings')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Sayfa özet görünümüyle açılır, form butonu ile açılır.
    expect(find.byKey(const Key('boarding_step_progress')), findsNothing);
    await tester.tap(find.byKey(const Key('add_boarding_info_button')));
    await tester.pump();
    await _pumpAsync(tester);

    expect(find.text('Genel Bilgiler'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Test pansiyonu');
    await tester.pump();

    await tester.tap(find.byKey(const Key('sidebar_item_courses')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Genel Bilgiler'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar_item_courses')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Kaydetmeden çık'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('Henüz öğrenci eklenmemiş'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
