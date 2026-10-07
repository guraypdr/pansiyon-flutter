import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/education_year/domain/education_year_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/layout/app_sidebar.dart';
import 'package:pansiyon_yonetim/features/education_year/presentation/education_year_selector.dart';

void main() {
  tearDown(AppNotifier.instance.hide);

  group('EducationYearSelector', () {
    testWidgets('etkin yılı gösterir ve seçim yapar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: EducationYearSelector(
              years: const [
                EducationYear(startYear: 2025),
                EducationYear(startYear: 2026, isActive: true),
              ],
              activeYear: 2026,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('2026-2027'), findsOneWidget);
      expect(find.text('2025-2026'), findsNothing);

      await tester.tap(find.byKey(const Key('education_year_selector')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('education_year_option_2025')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('education_year_option_2026')),
        findsOneWidget,
      );
    });

    testWidgets('seçim geri çağrılır', (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: EducationYearSelector(
              years: const [
                EducationYear(startYear: 2025),
                EducationYear(startYear: 2026, isActive: true),
              ],
              activeYear: 2026,
              onSelected: selected.add,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('education_year_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('education_year_option_2025')));
      await tester.pumpAndSettle();

      expect(selected, [2025]);
    });
  });

  group('Sidebar yıl seçici', () {
    testWidgets('seçici başlığın altında görünür', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Row(
              children: [
                AppSidebar(
                  width: 216,
                  selectedId: 'dashboard',
                  onSelected: (_) {},
                  yearSelector: EducationYearSelector(
                    years: const [EducationYear(startYear: 2025)],
                    activeYear: 2025,
                    onSelected: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Eğitim Öğretim Yılı'), findsOneWidget);
      expect(find.text('2025-2026'), findsOneWidget);
    });

    testWidgets('seçici verilmezse gösterilmez', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppSidebar(
              width: 216,
              selectedId: 'dashboard',
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Eğitim Öğretim Yılı'), findsNothing);
    });
  });
}
