import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_completeness.dart';
import 'package:pansiyon_yonetim/features/students/domain/student_models.dart';

/// Doğum tarihi `DateTime` olduğu için `const` olamaz.
final _completeStudent = Student(
  fullName: 'Zeynep Kaya',
  gender: StudentGender.female,
  nationalId: '12345678901',
  schoolName: 'Atatürk Lisesi',
  className: '9',
  birthDate: DateTime(2010, 5, 12),
  phone: '05551112233',
  address: 'Atatürk Mah. 1. Sok.',
  motherName: 'Ayşe Kaya',
  motherPhone: '05551112233',
  fatherName: 'Mehmet Kaya',
  fatherPhone: '05554445566',
  emergencyContactName: 'Ayşe Kaya',
  emergencyContactPhone: '05551112233',
);

void main() {
  group('studentMissingFields', () {
    test('temiz kayıtta eksik alan bulunmaz', () {
      final missing = studentMissingFields(_completeStudent);

      expect(missing, isEmpty);
      expect(studentMissingSummary(missing), 'Eksik bilgi yok.');
    });

    test('kimlik ve okul bilgileri eksikse listelenir', () {
      final missing = studentMissingFields(const Student(fullName: 'Ali Veli'));
      final labels = missing.map((field) => field.label).toList();

      expect(labels, contains('Cinsiyet'));
      expect(labels, contains('T.C. Kimlik No'));
      expect(labels, contains('Okul'));
      expect(labels, contains('Sınıf'));
      expect(labels, contains('Telefon'));
      expect(labels, contains('Adres'));
    });

    test('cinsiyet eksikse kritik olarak işaretlenir', () {
      final missing = studentMissingFields(
        const Student(fullName: 'Ali Veli', gender: null),
      );
      final gender = missing.firstWhere((field) => field.label == 'Cinsiyet');

      expect(gender.isCritical, isTrue);
    });

    test('hayatta olmayan ebeveynin alanları aranmaz', () {
      final missing = studentMissingFields(
        const Student(
          fullName: 'Ali Veli',
          gender: StudentGender.male,
          motherAlive: false,
          motherName: null,
          motherPhone: null,
          fatherName: 'Mehmet Veli',
          fatherPhone: '05554445566',
          emergencyContactName: 'Mehmet Veli',
          emergencyContactPhone: '05554445566',
        ),
      );
      final labels = missing.map((field) => field.label).toList();

      expect(labels, isNot(contains('Anne Adı')));
      expect(labels, isNot(contains('Anne Telefonu')));
      expect(labels, isNot(contains('Baba Adı')));
    });

    test('veli anne baba dışındaysa veli alanları aranır', () {
      final missing = studentMissingFields(
        _completeStudent.copyWith(guardianIsOther: true),
      );
      final labels = missing.map((field) => field.label).toList();

      expect(labels, contains('Veli Adı'));
      expect(labels, contains('Veli Telefonu'));
    });

    test('veli anne baba ise veli alanları aranmaz', () {
      final missing = studentMissingFields(
        _completeStudent.copyWith(guardianIsOther: false),
      );
      final labels = missing.map((field) => field.label).toList();

      expect(labels, isNot(contains('Veli Adı')));
    });

    test('acil iletişim yoksa kritik eksik bildirilir', () {
      final missing = studentMissingFields(
        const Student(
          fullName: 'Zeynep Kaya',
          gender: StudentGender.female,
          nationalId: '12345678901',
          schoolName: 'Atatürk Lisesi',
          className: '9',
          phone: '05551112233',
          address: 'Atatürk Mah. 1. Sok.',
          motherName: 'Ayşe Kaya',
          motherPhone: '05551112233',
          fatherName: 'Mehmet Kaya',
          fatherPhone: '05554445566',
        ),
      );
      final emergency = missing.firstWhere(
        (field) => field.label == 'Acil İletişim',
      );

      expect(emergency.isCritical, isTrue);
    });

    test('özet metni kritik alanları ayrı listeler', () {
      final missing = studentMissingFields(const Student(fullName: 'Ali Veli'));
      final summary = studentMissingSummary(missing);

      expect(summary, contains('Kritik eksik: Cinsiyet'));
      expect(summary, contains('Acil İletişim'));
      expect(summary, contains('Eksik bilgiler: '));
    });

    test(
      'yalnızca kritik olmayan alanlar varsa özette uyarı satırı çıkmaz',
      () {
        // Cinsiyet ve acil iletişim dolu; kalan eksikler kritik sayılmaz.
        const student = Student(
          fullName: 'Ali Veli',
          gender: StudentGender.male,
          emergencyContactName: 'Mehmet Veli',
          emergencyContactPhone: '05554445566',
          motherAlive: false,
          fatherAlive: false,
        );
        final summary = studentMissingSummary(studentMissingFields(student));

        expect(summary, isNot(contains('Kritik eksik')));
        expect(summary, startsWith('Eksik bilgiler: '));
      },
    );
  });
}
