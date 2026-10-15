import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/students/data/student_duty_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_duty_models.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_duty_tab.dart';

/// Bellek içi depo; diyalogun kaydettiği kapalı günleri tutar.
class _MemoryDutyRepository implements StudentDutyRepository {
  Set<String> blackouts = {};

  /// Araç çubuğu yalnızca liste varken göründüğü için testlerde bir tur
  /// döndürülür.
  StudentDutyList? currentList = StudentDutyList(
    id: 1,
    startDate: DateTime(2026, 10, 1),
    entries: const [
      StudentDutyEntry(listId: 1, sequence: 1, studentId: 1),
      StudentDutyEntry(listId: 1, sequence: 1, studentId: 2),
    ],
  );

  @override
  Future<StudentDutyList?> getCurrentList() async => currentList;

  @override
  Future<StudentDutyList> createList({required DateTime startDate}) async =>
      StudentDutyList(startDate: startDate, entries: const []);

  @override
  Future<void> replaceEntries({
    required int listId,
    required List<StudentDutyDay> days,
  }) async {}

  @override
  Future<void> deleteList(int listId) async {}

  @override
  Future<Set<String>> getBlackouts() async => {...blackouts};

  @override
  Future<void> saveBlackouts(Set<String> blackoutKeys) async {
    blackouts = {...blackoutKeys};
  }

  @override
  Future<void> removeArchivedStudents(Set<int> allArchivedStudentIds) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpTab(WidgetTester tester, _MemoryDutyRepository repository) {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentDutyTab(
            repository: repository,
            students: [
              Student(id: 1, fullName: 'Ali Veli'),
              Student(id: 2, fullName: 'Zeynep Kaya'),
            ],
            roomOf: (_) => null,
          ),
        ),
      ),
    );
  }

  group('Kapalı gün penceresi', () {
    testWidgets('açılır ve aylar arasında gezinilebilir', (tester) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackouts_button')));
      await tester.pumpAndSettle();

      expect(find.text('Nöbete kapalı günler'), findsOneWidget);
      expect(find.byKey(const Key('student_duty_blackout_previous')), findsOneWidget);
      expect(find.byKey(const Key('student_duty_blackout_next')), findsOneWidget);
    });

    testWidgets('gün başlığı tıklanınca ayın o günleri topluca kapanır', (
      tester,
    ) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackouts_button')));
      await tester.pumpAndSettle();

      // Cuma = 5. gün sütunu.
      await tester.tap(find.byKey(const Key('student_duty_blackout_weekday_5')));
      await tester.pumpAndSettle();

      // Ekim 2026'da 2 cuma var (2, 9, 16, 23, 30 -> 5 cuma).
      expect(repository.blackouts.length, 0);

      await tester.tap(find.byKey(const Key('student_duty_blackout_save')));
      await tester.pumpAndSettle();

      // Cuma günleri kapanmış olmalı.
      expect(
        repository.blackouts.contains(studentDutyDateKey(DateTime(2026, 10, 2))),
        isTrue,
      );
      expect(
        repository.blackouts.contains(studentDutyDateKey(DateTime(2026, 10, 30))),
        isTrue,
      );
      expect(repository.blackouts.length, 5);
    });

    testWidgets('kapalı gün üzerindeki "kapalı" yazısı görünür', (
      tester,
    ) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackouts_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackout_day_2')));
      await tester.pumpAndSettle();

      expect(find.text('kapalı'), findsOneWidget);
    });

    testWidgets('aynı gün başlığı ikinci kez tıklanınca günler açılır', (
      tester,
    ) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackouts_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackout_weekday_5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('student_duty_blackout_weekday_5')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackout_save')));
      await tester.pumpAndSettle();

      expect(repository.blackouts, isEmpty);
    });

    testWidgets('ay gezinmesi liste ayına döner', (tester) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackouts_button')));
      await tester.pumpAndSettle();

      // Takvim listenin başlangıç ayıyla (Ekim 2026) açılır.
      expect(find.text('Ekim 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('student_duty_blackout_next')));
      await tester.pumpAndSettle();
      expect(find.text('Kasım 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('student_duty_blackout_previous')));
      await tester.pumpAndSettle();
      expect(find.text('Ekim 2026'), findsOneWidget);
    });

    testWidgets('yıl sınırında gezinme sarmalanır', (tester) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('student_duty_blackouts_button')));
      await tester.pumpAndSettle();

      // Aralık'a ilerle: Ekim -> Kasım -> Aralık.
      await tester.tap(find.byKey(const Key('student_duty_blackout_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('student_duty_blackout_next')));
      await tester.pumpAndSettle();
      expect(find.text('Aralık 2026'), findsOneWidget);

      // Aralık'tan ileri Ocak 2027'ye döner.
      await tester.tap(find.byKey(const Key('student_duty_blackout_next')));
      await tester.pumpAndSettle();
      expect(find.text('Ocak 2027'), findsOneWidget);

      // Ocak'tan geri Aralık 2026'ya döner.
      await tester.tap(find.byKey(const Key('student_duty_blackout_previous')));
      await tester.pumpAndSettle();
      expect(find.text('Aralık 2026'), findsOneWidget);
    });
  });

  group('Nöbet sekmesi', () {
    testWidgets('öğrenci yokken liste oluşturma düğmesi devre dışıdır', (
      tester,
    ) async {
      final repository = _MemoryDutyRepository()..currentList = null;
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentDutyTab(
              // Liste var ama nöbete girebilecek öğrenci yok.
              repository: repository,
              students: const [],
              roomOf: (_) => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nöbete girecek öğrenci yok. Önce öğrenci ekleyin.'),
          findsOneWidget);
    });

    testWidgets('yazdırma düğmesi listedeyken görünür', (tester) async {
      final repository = _MemoryDutyRepository();
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('student_duty_print_button')), findsOneWidget);
      expect(find.byKey(const Key('student_duty_blackouts_button')),
          findsOneWidget);
      expect(find.byKey(const Key('student_duty_new_list_button')), findsOneWidget);
    });

    testWidgets('liste yokken araç çubuğu gösterilmez', (tester) async {
      final repository = _MemoryDutyRepository()..currentList = null;
      await pumpTab(tester, repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('student_duty_print_button')), findsNothing);
    });
  });

  }