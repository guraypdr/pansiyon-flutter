import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

void main() {
  tearDown(AppNotifier.instance.hide);

  testWidgets('üst sağ hata ve başarı bildirimi gösterir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => AppNotifier.instance.show(
                  context,
                  message: 'Deneme hatası',
                  tone: AppNotificationTone.error,
                ),
                child: const Text('Bildirimi göster'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Bildirimi göster'));
    await tester.pumpAndSettle();

    final notification = find.byKey(const Key('app_notification'));
    final container = tester.widget<Container>(notification);
    final decoration = container.decoration as BoxDecoration;
    final notificationRect = tester.getRect(notification);
    final screenWidth = tester.getSize(find.byType(Scaffold)).width;

    expect(notification, findsOneWidget);
    expect(find.text('Deneme hatası'), findsOneWidget);
    expect(decoration.color, AppColors.errorFeedback);
    expect(notificationRect.right, closeTo(screenWidth - 20, 1));
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const Key('app_notification_close')));
    await tester.pump();
    expect(notification, findsNothing);
  });

  testWidgets('bildirim süresi dolunca otomatik kapanır', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () => AppNotifier.instance.show(
                  context,
                  message: 'Deneme başarısı',
                  tone: AppNotificationTone.success,
                  duration: const Duration(milliseconds: 600),
                ),
                child: const Text('Bildirimi göster'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Bildirimi göster'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.byKey(const Key('app_notification')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('app_notification')), findsNothing);
  });

  testWidgets('yeni bildirimleri mevcut bildirim kapanana kadar sıraya alır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  FilledButton(
                    onPressed: () => AppNotifier.instance.show(
                      context,
                      message: 'İlk bildirim',
                      tone: AppNotificationTone.success,
                      duration: const Duration(milliseconds: 500),
                    ),
                    child: const Text('İlk'),
                  ),
                  FilledButton(
                    onPressed: () => AppNotifier.instance.show(
                      context,
                      message: 'İkinci bildirim',
                      tone: AppNotificationTone.error,
                    ),
                    child: const Text('İkinci'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('İlk'));
    await tester.pump();
    await tester.tap(find.text('İkinci'));
    await tester.pump();

    expect(find.text('İlk bildirim'), findsOneWidget);
    expect(find.text('İkinci bildirim'), findsNothing);

    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('İlk bildirim'), findsNothing);
    expect(find.text('İkinci bildirim'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app_notification_close')));
    await tester.pump();
    expect(find.text('İkinci bildirim'), findsNothing);
  });
}
