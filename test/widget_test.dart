import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/app/pansiyon_yonetim_app.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('referans sidebar ve mevcut ana ekranı birlikte gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PansiyonYonetimApp());

    final sidebar = find.byKey(const Key('sidebar_surface'));
    final contentArea = find.byKey(const Key('content_area'));
    final topBar = find.byKey(const Key('top_bar'));
    final topBarSurface = tester.widget<Container>(
      find.byKey(const Key('top_bar_surface')),
    );
    final topBarDecoration = topBarSurface.decoration as BoxDecoration;
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appFrame = find.byKey(const Key('app_frame'));
    final appFrameDecoration =
        tester.widget<DecoratedBox>(appFrame).decoration as BoxDecoration;
    final sidebarRect = tester.getRect(sidebar);
    final contentRect = tester.getRect(contentArea);
    final contentClip = tester.widget<ClipRRect>(contentArea);
    final frameRect = tester.getRect(appFrame);
    final sidebarContainer = tester.widget<Container>(sidebar);
    final dashboardItem = find.byKey(const Key('sidebar_item_dashboard'));
    final dashboardBackgroundFinder = find.descendant(
      of: dashboardItem,
      matching: find.byType(AnimatedContainer),
    );
    final dashboardBackground = tester.widget<AnimatedContainer>(
      dashboardBackgroundFinder,
    );
    final dashboardDecoration = dashboardBackground.decoration as BoxDecoration;
    expect(scaffold.backgroundColor, AppColors.appBackground);
    expect(tester.getSize(sidebar).width, 216);
    expect(contentRect.left, closeTo(sidebarRect.right + 8, 0.1));
    expect(contentRect.top, closeTo(sidebarRect.top + 8, 0.1));
    expect(contentRect.right, closeTo(frameRect.right - 8, 0.1));
    expect(contentRect.bottom, closeTo(sidebarRect.bottom - 8, 0.1));
    expect(appFrameDecoration.color, AppColors.sidebar);
    final contentRadius = contentClip.borderRadius as BorderRadius;
    expect(contentRadius.topLeft, const Radius.circular(20));
    expect(contentRadius.topRight, const Radius.circular(20));
    expect(contentRadius.bottomLeft, const Radius.circular(20));
    expect(contentRadius.bottomRight, const Radius.circular(20));
    expect(topBar, findsOneWidget);
    expect(topBarDecoration.gradient, isNull);
    expect(
      topBarDecoration.color,
      AppColors.softPurple.withValues(alpha: 0.55),
    );
    expect(
      tester.getSize(find.byKey(const Key('top_bar_surface'))).height,
      lessThan(80),
    );
    final topBarBorder = topBarDecoration.border! as Border;
    expect(topBarBorder.top.color, AppColors.primary.withValues(alpha: 0.18));
    expect(
      find.descendant(of: topBar, matching: find.text('Ana Sayfa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: topBar, matching: find.text('Pansiyon Yönetimi')),
      findsNothing,
    );
    final topBarIcon = tester.widget<Icon>(
      find.descendant(of: topBar, matching: find.byType(Icon)),
    );
    final menuIcon = tester.widget<Icon>(
      find.descendant(of: dashboardItem, matching: find.byType(Icon)),
    );
    expect(
      tester.getSize(find.byKey(const Key('top_bar_surface'))).height,
      tester.getSize(dashboardBackgroundFinder).height + 8,
    );
    expect(topBarIcon.size, menuIcon.size);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(sidebarContainer.color, AppColors.sidebar);
    expect(find.text('Pansiyon Yönetimi'), findsOneWidget);
    expect(dashboardDecoration.color, AppColors.sidebarActive);
    expect(find.text('Ana Sayfa'), findsNWidgets(3));
    expect(find.text('Uygulama temeli hazır'), findsOneWidget);

    const itemIds = [
      'dashboard',
      'boarding-info',
      'courses',
      'messages',
      'friends',
      'schedule',
      'study',
      'attendance',
      'permissions',
      'reports',
      'settings',
    ];
    var previousY = -1.0;
    for (final itemId in itemIds) {
      final finder = find.byKey(Key('sidebar_item_$itemId'));
      expect(finder, findsOneWidget);
      final currentY = tester.getTopLeft(finder).dy;
      expect(currentY, greaterThan(previousY));
      previousY = currentY;
    }
  });

  testWidgets('sidebar hover rengini macenta paletinden kullanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PansiyonYonetimApp());

    final item = find.byKey(const Key('sidebar_item_courses'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(item));
    await tester.pump(const Duration(milliseconds: 200));

    final background = tester.widget<AnimatedContainer>(
      find.descendant(of: item, matching: find.byType(AnimatedContainer)),
    );
    final decoration = background.decoration as BoxDecoration;

    expect(decoration.color, AppColors.sidebarHover);
    await mouse.removePointer();
  });

  testWidgets('mevcut ekran navigasyonu sidebar üzerinden korunur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PansiyonYonetimApp());

    await tester.tap(find.byKey(const Key('sidebar_item_courses')));
    await tester.pump();
    expect(find.text('Öğrenciler'), findsNWidgets(2));
    expect(find.text('Uygulama temeli hazır'), findsNothing);

    await tester.tap(find.byKey(const Key('sidebar_item_schedule')));
    await tester.pump();
    expect(find.text('Odalar'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('sidebar_item_dashboard')));
    await tester.pump();
    expect(find.text('Uygulama temeli hazır'), findsOneWidget);
  });

  testWidgets('sağ içerik alanı tüm boşluğu kaplar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const PansiyonYonetimApp());

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

    await tester.pumpWidget(const PansiyonYonetimApp());
    await tester.pump(const Duration(milliseconds: 300));

    final sidebar = find.byKey(const Key('sidebar_surface'));

    expect(tester.getSize(sidebar).width, 174);
    expect(find.byKey(const Key('content_area')), findsOneWidget);
    expect(find.byKey(const Key('app_frame')), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsNWidgets(3));
    expect(find.text('Uygulama temeli hazır'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('sidebar_item_boarding-info')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

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
