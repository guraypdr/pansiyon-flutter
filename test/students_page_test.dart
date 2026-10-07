import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/students/data/student_repository.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_detail_dialog.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_support_dialogs.dart';
import 'package:pansiyon_yonetim/features/students/presentation/student_list_row.dart';
import 'package:pansiyon_yonetim/features/students/presentation/students_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  tearDown(AppNotifier.instance.hide);

  /// Diyalog içindeki gerçek veritabanı erişimini bekler.
  ///
  /// Yükleme göstergesi gerçek zamanlı I/O bitene kadar döndüğü için
  /// `pumpAndSettle` yerine kontrollü bekleme kullanılır.
  Future<void> settle(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('öğrenci listesi ve ekleme formu açılır', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);
    // Etkin eğitim yılı ayrıca okunduğu için ek bir sorgu turu gerekir.
    await settle(tester);

    expect(find.text('Henüz öğrenci eklenmemiş'), findsOneWidget);
    expect(find.byKey(const Key('download_template_button')), findsOneWidget);
    await tester.tap(find.text('Öğrenci Ekle'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Ad Soyad'), findsOneWidget);
    final formDropdowns = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString().startsWith('DropdownButtonFormField'),
    );
    await tester.tap(formDropdowns.at(1));
    await tester.pump();
    await tester.tap(find.text('Kız').last);
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'ali yılmaz');

    await tester.enterText(
      find.byKey(const Key('nationalId_field')),

      '12345678901',
    );
    await tester.tap(find.text('Devam'));
    await tester.pump();
    expect(find.text('Veli Bilgileri'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    });
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    expect(find.text('Ali Yılmaz'), findsOneWidget);
    AppNotifier.instance.hide();
  });

  testWidgets(
    'öğrenci ekleme formu sınıfları pansiyon kademesine göre listeler',
    (tester) async {
      final database = AppDatabase(databasePath: inMemoryDatabasePath);
      final studentRepository = SqliteStudentRepository(database);
      addTearDown(database.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StudentsPage(
              repository: studentRepository,
              boardingInfoRepository: _HighSchoolBoardingRepository(),
            ),
          ),
        ),
      );
      await tester.pump();
      await settle(tester);

      await tester.tap(find.text('Öğrenci Ekle'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Dialog), findsOneWidget);
      // Kız pansiyonunda cinsiyet kilitli olduğu için açılır liste kalmaz.
      expect(find.byKey(const Key('gender_locked_field')), findsOneWidget);
      final classDropdown = find.byKey(const Key('student_class_dropdown'));
      expect(classDropdown, findsOneWidget);
      await tester.ensureVisible(classDropdown);
      await tester.pump();
      await tester.tap(classDropdown);
      await tester.pump();

      expect(find.text('Hazırlık'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('5'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('öğrenci ekranı dar pencerede taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('filtreler listeyi daraltır ve temizlenir', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      final schoolId = await repository.saveSchool(
        const School(name: 'Atatürk Lisesi'),
      );
      await repository.saveStudent(
        const Student(
          fullName: 'Zeynep Kaya',
          gender: StudentGender.female,
          className: '11',
          sectionName: 'A',
        ),
      );
      await repository.saveStudent(
        Student(
          fullName: 'Mert Demir',
          gender: StudentGender.male,
          className: '9',
          sectionName: 'B',
          schoolId: schoolId,
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Mert Demir'), findsOneWidget);
    expect(find.text('2 öğrenci kayıtlı'), findsOneWidget);
    expect(find.text('11/A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('class_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();

    expect(find.text('Mert Demir'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsNothing);
    expect(find.text('1 / 2 öğrenci gösteriliyor'), findsOneWidget);
    expect(find.text('Sınıf: 9'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear_filters_button')));
    await tester.pumpAndSettle();

    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Mert Demir'), findsOneWidget);
    expect(find.text('2 öğrenci kayıtlı'), findsOneWidget);
  });

  testWidgets('cinsiyet ve okul filtreleri listeyi daraltır', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      final schoolId = await repository.saveSchool(
        const School(name: 'Atatürk Lisesi'),
      );
      await repository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
      await repository.saveStudent(
        Student(
          fullName: 'Mert Demir',
          gender: StudentGender.male,
          schoolId: schoolId,
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('gender_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erkek').last);
    await tester.pumpAndSettle();
    expect(find.text('Mert Demir'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsNothing);

    await tester.tap(find.byKey(const Key('clear_filters_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('school_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atatürk Lisesi').last);
    await tester.pumpAndSettle();
    expect(find.text('Mert Demir'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsNothing);
    expect(find.text('Okul: Atatürk Lisesi'), findsOneWidget);
  });

  testWidgets('filtre menüsünde Tümü seçeneği listeyi genişletir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      await repository.saveStudent(
        const Student(
          fullName: 'Zeynep Kaya',
          gender: StudentGender.female,
          className: '9',
        ),
      );
      await repository.saveStudent(
        const Student(
          fullName: 'Mert Demir',
          gender: StudentGender.male,
          className: '10',
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('class_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Mert Demir'), findsNothing);

    // "Tümü" seçilebilir olmalı; önceki hâli null değer döndürdüğü için
    // PopupMenuButton bunu iptal sayıyordu.
    await tester.tap(find.byKey(const Key('class_filter_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sınıf: Tümü').last);
    await tester.pumpAndSettle();

    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Mert Demir'), findsOneWidget);
    expect(find.text('Sınıf'), findsOneWidget);
  });

  testWidgets('öğrenci formunda okul ayarları butonu okul listesini tazeler', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('add_student_button')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('student_school_settings_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('student_school_settings_button')));
    await settle(tester);
    expect(find.byType(SchoolSettingsDialog), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('school_name_field')),
      'atatürk lisesi',
    );
    await tester.tap(find.byKey(const Key('school_submit_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('school_settings_close_button')));
    await settle(tester);

    // Diyalog kapanınca okul, formdaki açılır listede yer alır.
    expect(find.byType(SchoolSettingsDialog), findsNothing);
    final schoolDropdown = find.byKey(const Key('student_school_dropdown'));
    expect(schoolDropdown, findsOneWidget);
    await tester.tap(schoolDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Atatürk Lisesi'), findsOneWidget);
  });

  testWidgets('öğrenci formunda hastalık anahtarı açıklama alanını açar', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('add_student_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).first, 'Zeynep Kaya');
    await tester.enterText(
      find.byKey(const Key('nationalId_field')),
      '12345678901',
    );
    await tester.pump();
    // Sağlık alanları artık ilk adımda.
    expect(find.text('Sağlık'), findsOneWidget);

    expect(find.byKey(const Key('chronic_disease_toggle')), findsOneWidget);
    expect(find.text('Sürekli Hastalık'), findsNothing);
    // Tüm anahtar butonlarda durum yazısı bulunur.
    expect(
      find.descendant(
        of: find.byKey(const Key('chronic_disease_toggle')),
        matching: find.text('Hayır'),
      ),
      findsOneWidget,
    );

    final chronicSwitch = find.descendant(
      of: find.byKey(const Key('chronic_disease_toggle')),
      matching: find.byType(Switch),
    );
    expect(chronicSwitch, findsOneWidget);
    await tester.ensureVisible(chronicSwitch);
    await tester.pump();
    await tester.tap(chronicSwitch);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sürekli Hastalık'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('chronic_disease_toggle')),
        matching: find.text('Evet'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ilaç alanı anahtar butonla açılır', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('add_student_button')));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).first, 'Zeynep Kaya');
    await tester.enterText(
      find.byKey(const Key('nationalId_field')),
      '12345678901',
    );
    await tester.pump();
    // Sağlık alanları artık ilk adımda.

    final medicationToggle = find.byKey(const Key('regular_medication_toggle'));
    expect(medicationToggle, findsOneWidget);
    expect(
      find.descendant(of: medicationToggle, matching: find.text('Hayır')),
      findsOneWidget,
    );
    expect(find.text('Hayır'), findsWidgets);
    expect(find.text('İlaç Bilgisi'), findsNothing);

    final medicationSwitch = find.descendant(
      of: medicationToggle,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(medicationSwitch);
    await tester.pump();
    await tester.tap(medicationSwitch);
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(of: medicationToggle, matching: find.text('Evet')),
      findsOneWidget,
    );
    expect(find.text('İlaç Bilgisi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formdaki tüm anahtarlar kapalıyken Hayır yazar', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('add_student_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).first, 'Zeynep Kaya');
    await tester.enterText(
      find.byKey(const Key('nationalId_field')),
      '12345678901',
    );
    await tester.pump();

    // Sağlık anahtarları ilk adımda.
    const toggleKeys = [
      'chronic_disease_toggle',
      'allergy_toggle',
      'regular_medication_toggle',
      'psychological_toggle',
    ];
    for (final key in toggleKeys) {
      final toggle = find.byKey(Key(key));
      expect(toggle, findsOneWidget, reason: '$key bulunamadı');
      await tester.ensureVisible(toggle);
      await tester.pump();
      expect(
        find.descendant(of: toggle, matching: find.text('Hayır')),
        findsOneWidget,
        reason: '$key kapalıyken Hayır yazmıyor',
      );
      expect(
        find.descendant(of: toggle, matching: find.text('Evet')),
        findsNothing,
        reason: '$key kapalıyken Evet yazıyor',
      );
    }

    // Sürekli kullanılan ilaç anahtarı açılınca aynı yerde Evet yazmalı.
    final medicationToggle = find.byKey(const Key('regular_medication_toggle'));
    await tester.ensureVisible(medicationToggle);
    await settle(tester);
    await tester.tap(
      find.descendant(of: medicationToggle, matching: find.byType(Switch)),
    );
    await settle(tester);

    expect(
      find.descendant(of: medicationToggle, matching: find.text('Evet')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: medicationToggle, matching: find.text('Hayır')),
      findsNothing,
    );

    // Veli adımına geçince anne/baba anahtarları yerine iki veli alanı gelir.
    await tester.tap(find.text('Devam'));
    await settle(tester);
    expect(find.byKey(const Key('guardianName_field')), findsOneWidget);
    expect(find.byKey(const Key('guardian2Name_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('şube yalnızca okulun tanımlı şubelerinden atanır', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      final schoolId = await repository.saveSchool(
        const School(name: 'Atatürk Lisesi'),
      );
      await repository.saveSchoolSections(
        schoolId: schoolId,
        className: '9',
        sections: ['A', 'GD'],
      );
      await repository.saveStudent(
        Student(
          fullName: 'Zeynep Kaya',
          schoolId: schoolId,
          className: '9',
          sectionName: 'GD',
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    // Kayıtlı öğrenci kartı yalnızca "9/GD" gösterir.
    expect(find.text('9/GD'), findsOneWidget);

    await tester.tap(find.byKey(const Key('student_edit_1')));
    await settle(tester);

    // Tanımlı şubeler açılır listede, 9. sınıf düzeyine ait olanlar gelir.
    final sectionDropdown = find.byKey(const Key('student_section_dropdown'));
    expect(sectionDropdown, findsOneWidget);
    await tester.ensureVisible(sectionDropdown);
    await tester.pump();
    await tester.tap(sectionDropdown);
    await tester.pumpAndSettle();
    expect(find.text('9/A'), findsOneWidget);
    expect(find.text('9/GD'), findsWidgets);
    expect(find.text('10/A'), findsNothing);
  });

  testWidgets('okul seçili değilse şube "Şube eklenmedi" olur', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('add_student_button')));
    await settle(tester);

    // Okul seçilmediği için şube atanamaz.
    expect(find.byKey(const Key('student_section_empty')), findsOneWidget);
    expect(find.text('Şube eklenmedi'), findsOneWidget);
    expect(find.byKey(const Key('student_section_dropdown')), findsNothing);
  });

  testWidgets('okulun şubeleri silinince kayıt boş şube ile güncellenir', (
    tester,
  ) async {
    // Değişmez testi: kayıtlı şubesi artık geçersiz olan bir öğrenci
    // düzenlendiğinde geçersiz şube kaydedilmemeli ve form istisna
    // atmamalı. _validSectionName() bu güvenceyi veri katmanında verir.
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      final schoolId = await repository.saveSchool(
        const School(name: 'Atatürk Lisesi'),
      );
      await repository.saveSchoolSections(
        schoolId: schoolId,
        className: '9',
        sections: ['A', 'GD'],
      );
      await repository.saveStudent(
        Student(
          fullName: 'Zeynep Kaya',
          nationalId: '12345678901',
          schoolId: schoolId,
          className: '9',
          sectionName: 'GD',
        ),
      );
      // Kayıtlı şubeler kaldırılır; öğrencinin "GD" ataması geçersiz olur.
      await repository.saveSchoolSections(
        schoolId: schoolId,
        className: '9',
        sections: [],
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('student_edit_1')));
    await settle(tester);

    // Geçersiz şube ataması arayüzde seçili görünmemeli.
    expect(find.byKey(const Key('student_section_empty')), findsOneWidget);

    // Formu kaydetmek istisna atmamalı.
    await tester.tap(find.text('Devam'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    await settle(tester);

    expect(tester.takeException(), isNull);

    final students = await tester.runAsync(repository.getStudents);
    expect(students!.single.sectionName, isNull);
    expect(students.single.fullName, 'Zeynep Kaya');
    AppNotifier.instance.hide();
  });

  testWidgets('form iki adımdan oluşur', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      await repository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', nationalId: '12345678901'),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('student_edit_1')));
    await settle(tester);

    // İlk adımda kimlik, iletişim ve sağlık alanları bir arada.
    expect(find.text('Kimlik ve İletişim'), findsOneWidget);
    expect(find.byKey(const Key('fullName_field')), findsOneWidget);
    expect(find.byKey(const Key('address_field')), findsOneWidget);
    expect(find.byKey(const Key('phone_field')), findsOneWidget);
    expect(find.byKey(const Key('chronic_disease_toggle')), findsOneWidget);
    expect(find.byKey(const Key('allergy_toggle')), findsOneWidget);
    expect(find.byKey(const Key('psychological_toggle')), findsOneWidget);
    expect(find.byKey(const Key('regular_medication_toggle')), findsOneWidget);
    expect(
      find.byKey(const Key('student_blood_group_dropdown')),
      findsOneWidget,
    );
    // Veli alanları ilk adımda yok.
    expect(find.byKey(const Key('guardianName_field')), findsNothing);

    await tester.tap(find.text('Devam'));
    await tester.pump();

    expect(find.text('Veli Bilgileri'), findsOneWidget);
    expect(find.byKey(const Key('guardianName_field')), findsOneWidget);
    expect(find.byKey(const Key('guardianRelation_field')), findsOneWidget);
    expect(find.byKey(const Key('guardianPhone_field')), findsOneWidget);
    expect(find.byKey(const Key('guardianAddress_field')), findsOneWidget);
    expect(find.byKey(const Key('guardian2Name_field')), findsOneWidget);
    expect(find.byKey(const Key('guardian2Relation_field')), findsOneWidget);
    expect(find.byKey(const Key('guardian2Phone_field')), findsOneWidget);
    expect(find.byKey(const Key('guardian2Address_field')), findsOneWidget);
  });

  testWidgets('iki veli bilgisi kaydedilir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      await repository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', nationalId: '12345678901'),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: _HighSchoolBoardingRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('student_edit_1')));
    await settle(tester);
    await tester.tap(find.text('Devam'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('guardianName_field')),
      'Ayşe Kaya',
    );
    await tester.enterText(
      find.byKey(const Key('guardianRelation_field')),
      'Anne',
    );
    await tester.enterText(
      find.byKey(const Key('guardianPhone_field')),
      '05321112233',
    );
    await tester.enterText(
      find.byKey(const Key('guardianAddress_field')),
      'Atatürk Mah. 1. Sok.',
    );
    await tester.enterText(
      find.byKey(const Key('guardian2Name_field')),
      'Mehmet Kaya',
    );
    await tester.enterText(
      find.byKey(const Key('guardian2Relation_field')),
      'Baba',
    );
    await tester.enterText(
      find.byKey(const Key('guardian2Phone_field')),
      '05325556677',
    );
    await tester.enterText(
      find.byKey(const Key('guardian2Address_field')),
      'Cumhuriyet Mah. 2. Cad.',
    );
    await tester.pump();

    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    await settle(tester);

    final students = await tester.runAsync(repository.getStudents);
    final student = students!.single;
    expect(student.guardianName, 'Ayşe Kaya');
    expect(student.guardianRelation, 'Anne');
    expect(student.guardianPhone, '0532 111 22 33');
    expect(student.guardianAddress, 'Atatürk Mah. 1. Sok.');
    expect(student.guardian2Name, 'Mehmet Kaya');
    expect(student.guardian2Relation, 'Baba');
    expect(student.guardian2Phone, '0532 555 66 77');
    expect(student.guardian2Address, 'Cumhuriyet Mah. 2. Cad.');
    // Acil iletişim birincil veliden türetilir.
    expect(student.emergencyContactName, 'Ayşe Kaya');
    expect(student.emergencyContactPhone, '0532 111 22 33');
    AppNotifier.instance.hide();
  });

  testWidgets('kart eksik bilgi varsa uyarı rozeti gösterir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      // Cinsiyet, okul, doğum tarihi ve aile bilgileri eksik bırakılır.
      await repository.saveStudent(const Student(fullName: 'Eksik Öğrenci'));

      final schoolId = await repository.saveSchool(
        const School(name: 'Atatürk Lisesi'),
      );
      // Tam öğrenci: hiçbir alan eksik olmamalı.
      await repository.saveStudent(
        Student(
          fullName: 'Tam Öğrenci',
          gender: StudentGender.female,
          nationalId: '12345678901',
          schoolId: schoolId,
          className: '9',
          birthDate: DateTime(2010, 5, 12),
          phone: '05551112233',
          address: 'Atatürk Mah. 1. Sok.',
          emergencyContactName: 'Ayşe Kaya',
          emergencyContactPhone: '05551112233',
          guardianName: 'Ayşe Kaya',
          guardianPhone: '05551112233',
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

// Eksik bilgi özeti satır yerine kart üzerinde rozet olarak gösterilir.
    expect(find.textContaining('eksik bilgi var'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('student_card_1')),
        matching: find.textContaining('eksik'),
      ),
      findsOneWidget,
      reason: 'eksik bilgisi olan öğrenci kartında uyarı rozeti olmalı',
    );
    // Tam öğrencinin kartında rozet olmamalı.
    expect(
      find.descendant(
        of: find.byKey(const Key('student_card_2')),
        matching: find.textContaining('eksik'),
      ),
      findsNothing,
    );
  });

  testWidgets('okul ayarları diyaloğu okul ekler, düzenler ve siler', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byKey(const Key('school_settings_button')));
    await settle(tester);
    expect(find.text('Okul Ayarları'), findsOneWidget);
    expect(find.text('Henüz okul eklenmedi.'), findsOneWidget);

    // Ekleme: baş harfler büyütülerek kaydedilir.
    await tester.enterText(
      find.byKey(const Key('school_name_field')),
      'atatürk lisesi',
    );
    await tester.tap(find.byKey(const Key('school_submit_button')));
    await settle(tester);

    expect(find.text('Atatürk Lisesi'), findsOneWidget);
    final schools = await tester.runAsync(repository.getSchools);
    final schoolId = schools!.single.id;

    // Düzenleme.
    await tester.tap(find.byKey(Key('school_edit_$schoolId')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('school_name_field')),
      'cumhuriyet lisesi',
    );
    await tester.tap(find.byKey(const Key('school_submit_button')));
    await settle(tester);

    final updated = await tester.runAsync(repository.getSchools);
    expect(updated!.single.name, 'Cumhuriyet Lisesi');
    expect(find.text('Cumhuriyet Lisesi'), findsOneWidget);

    // Silme onayı.
    await tester.tap(find.byKey(Key('school_delete_$schoolId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Okul silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await settle(tester);

    expect(await tester.runAsync(repository.getSchools), isEmpty);
    expect(find.text('Henüz okul eklenmedi.'), findsOneWidget);
  });

  testWidgets('okul ayarlarında hazırlık anahtarı sınıf düzeyini etkiler', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    final boardingInfoRepository = SqliteBoardingInfoRepository(database);
    addTearDown(database.close);

    await tester.runAsync(
      () => boardingInfoRepository.save(
        const BoardingInfoDraft(
          schoolName: 'Test Pansiyonu',
          principalName: 'Ayşe Yılmaz',
          principalPhone: '0312 555 10 10',
          deputyName: 'Mehmet Demir',
          deputyPhone: '0312 555 10 11',
          boardingType: BoardingType.girls,
          educationLevel: EducationLevel.highSchool,
          blocks: [],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsPage(
            repository: repository,
            boardingInfoRepository: boardingInfoRepository,
          ),
        ),
      ),
    );
    await tester.pump();
    await settle(tester);

    // Lise kademesinde "Hazırlık" sınıf düzeyi listesinde yer alır.
    expect(find.text('Hazırlık'), findsNothing);
    await tester.tap(find.byKey(const Key('school_settings_button')));
    await settle(tester);
    expect(find.text('Hazırlık sınıfı var mı?'), findsOneWidget);
    expect(find.text('Pansiyon kademesi: Lise'), findsOneWidget);

    final preparationSwitch = find.descendant(
      of: find.byKey(const Key('preparation_grade_toggle')),
      matching: find.byType(Switch),
    );
    expect(preparationSwitch, findsOneWidget);
    await tester.tap(preparationSwitch);
    await settle(tester);

    final draft = await tester.runAsync(boardingInfoRepository.load);
    expect(draft!.hasPreparationGrade, isFalse);

    await tester.tap(find.byKey(const Key('school_settings_done_button')));
    await settle(tester);

    // Sınıf filtresi artık "Hazırlık" seçeneğini içermez.
    await tester.tap(find.byKey(const Key('class_filter_button')));
    await tester.pumpAndSettle();
    expect(find.text('Hazırlık'), findsNothing);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets('kart detay ikonu öğrenci detay diyaloğunu açar ve kapatır', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      await repository.saveStudent(
        const Student(
          fullName: 'Zeynep Kaya',
          gender: StudentGender.female,
          className: '11',
          sectionName: 'A',
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('student_edit_1')), findsOneWidget);
    expect(find.byKey(const Key('student_delete_1')), findsOneWidget);
    expect(find.text('İzin Ekle'), findsNothing);
    expect(find.text('Rapor Ekle'), findsNothing);
    expect(find.text('Disiplin Kaydı'), findsNothing);

    await tester.tap(find.byKey(const Key('student_detail_1')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    expect(find.byType(StudentDetailDialog), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Öğrenci Detayı'), findsOneWidget);
    expect(find.byKey(const Key('detail_close_button')), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsWidgets);
    expect(find.text('İzin Ekle'), findsOneWidget);
    expect(find.text('Rapor Ekle'), findsOneWidget);
    expect(find.text('Disiplin Kaydı'), findsOneWidget);
    expect(find.byKey(const Key('detail_edit_button')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('detail_close_button')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    for (var index = 0; index < 5; index++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    expect(find.byType(StudentDetailDialog), findsNothing);
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kart üzerine gelince kenar ve gölge değişir', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      await repository.saveStudent(
        const Student(fullName: 'Zeynep Kaya', gender: StudentGender.female),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    BoxDecoration cardDecoration() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const Key('student_card_1')),
                )
                .decoration!
            as BoxDecoration;

    // Dinlenirken gölge yoktur, kenar sıradaki renktedir.
    expect(cardDecoration().boxShadow, isNull);
    final idleBorder = cardDecoration().border!.top.color;
    expect(idleBorder, AppColors.inputBorder);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('student_card_1'))),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Üzerine gelince gölge belirginleşir ve kenar rengi değişir.
    expect(cardDecoration().boxShadow, hasLength(1));
    expect(
      cardDecoration().border!.top.color,
      isNot(idleBorder),
      reason: 'üzerine gelince kenar rengi değişmeli',
    );

    await mouse.moveTo(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cardDecoration().boxShadow, isNull);
    expect(cardDecoration().border!.top.color, idleBorder);
  });

testWidgets('kart ad, sınıf, okul, cinsiyet figürü ve odayı gösterir', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    // Veritabanı çağrıları sahte zaman dilimi dışında yapılmalı; aksi halde
    // test süre aşımına uğrar.
    late int schoolId;
    await tester.runAsync(() async {
      schoolId = await repository.saveSchool(
        const School(name: 'Atatürk Ortaokulu'),
      );
      await repository.saveStudent(
        Student(
          fullName: 'Zeynep Kaya',
          gender: StudentGender.female,
          className: '9',
          sectionName: 'A',
          schoolId: schoolId,
          guardianPhone: '0533 222 33 44',
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    final card = find.byKey(const Key('student_card_1'));
    expect(card, findsOneWidget);

    // Klasik kadın figürü kartın başında.
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.woman)),
      findsOneWidget,
    );
    // Ad, sınıf rozeti ve okul adı görünür.
    expect(
      find.descendant(of: card, matching: find.text('Zeynep Kaya')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('9/A')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Atatürk Ortaokulu • Veli: 0533 222 33 44'),
      ),
      findsOneWidget,
    );
    // T.C. ve öğrenci telefonu kartta yer almıyor.
    for (final value in const ['12345678901', '0532 111 22 33']) {
      expect(
        find.descendant(of: card, matching: find.text(value)),
        findsNothing,
        reason: '"$value" kartta gösterilmemeli',
      );
    }
  });

  testWidgets('kart erkek figürünü gösterir ve atanmamış odada rozet koymaz', (
    tester,
  ) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      await repository.saveStudent(
        const Student(fullName: 'Mert Demir', gender: StudentGender.male),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    final card = find.byKey(const Key('student_card_1'));
    expect(
      find.descendant(of: card, matching: find.byIcon(Icons.man)),
      findsOneWidget,
    );
    // Oda ataması yok, bu yüzden oda rozeti gösterilmez.
    expect(
      find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (widget) => widget is RoomNumberBadge,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('öğrenciler dikey liste halinde sıralanır', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    await tester.runAsync(() async {
      for (final name in const ['Zeynep Kaya', 'Mert Demir', 'Elif Şahin']) {
        await repository.saveStudent(Student(fullName: name));
      }
    });

    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    // Kartlar alt alta dizilir. Konumlar ada göre sıralı olduğu için
    // kimlik sırasına güvenilmez; konumları y'e göre sıralayıp aralık
    // boşluğunu doğrularız.
    final positions = [
      for (var index = 1; index <= 3; index++)
        tester.getTopLeft(find.byKey(Key('student_card_$index'))),
    ]..sort((a, b) => a.dy.compareTo(b.dy));

    // Hepsi aynı x'te: yan yana dizilmiyorlar.
    for (final point in positions) {
      expect(
        point.dx,
        moreOrLessEquals(positions.first.dx, epsilon: 1),
        reason: 'kartlar aynı hizada olmalı',
      );
    }
    // Alt alta dizilmiş ve aralarında boşluk var.
    expect(positions[1].dy, greaterThan(positions[0].dy));
    expect(positions[2].dy, greaterThan(positions[1].dy));

    // Her kartın yüksekliği aynı: hepsi aynı içerik yapısına sahip.
    final heights = {
      tester.getSize(find.byKey(const Key('student_card_1'))).height,
      tester.getSize(find.byKey(const Key('student_card_2'))).height,
      tester.getSize(find.byKey(const Key('student_card_3'))).height,
    };
    expect(heights, hasLength(1), reason: 'kart yükseklikleri eşit olmalı');

    expect(tester.takeException(), isNull);
  });

  testWidgets('çok uzun ad ve okul adında kart taşmaz', (tester) async {
    final database = AppDatabase(databasePath: inMemoryDatabasePath);
    final repository = SqliteStudentRepository(database);
    addTearDown(database.close);

    late int schoolId;
    await tester.runAsync(() async {
      schoolId = await repository.saveSchool(
        const School(
          name: 'Atatürk Anadolu Lisesi İnkılap Tarihi ve Sosyal Bilimler',
        ),
      );
      await repository.saveStudent(
        Student(
          fullName: 'Abdulkadir Mehmet Şahin Karabulutoğulları',
          gender: StudentGender.male,
          className: '12',
          sectionName: 'ABCDEFG',
          schoolId: schoolId,
          guardianPhone: '+90 533 222 33 44',
        ),
      );
    });

    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StudentsPage(repository: repository)),
      ),
    );
    await tester.pump();
    await settle(tester);

    expect(find.byKey(const Key('student_card_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
class _HighSchoolBoardingRepository implements BoardingInfoRepository {
  @override
  Future<BoardingInfoDraft?> load() async => const BoardingInfoDraft(
    schoolName: 'Test Pansiyonu',
    principalName: 'Test',
    principalPhone: '0312 555 10 10',
    deputyName: 'Test',
    deputyPhone: '0312 555 10 11',
    boardingType: BoardingType.girls,
    educationLevel: EducationLevel.highSchool,
    blocks: [],
  );

  @override
  Future<void> save(BoardingInfoDraft draft) async {}

  @override
  Future<void> setPreparationGradeEnabled(bool enabled) async {}
}
