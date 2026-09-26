import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';

void main() {
  group('ortak form doğrulamaları', () {
    test('zorunlu alanları doğrular', () {
      expect(requiredField('', 'Ad soyad'), 'Ad soyad zorunludur.');
      expect(requiredField('  ', 'Ad soyad'), 'Ad soyad zorunludur.');
      expect(requiredField('Ali Yılmaz', 'Ad soyad'), isNull);
    });

    test('telefon numaralarını isteğe bağlı veya zorunlu doğrular', () {
      expect(phoneNumberValidator(null), isNull);
      expect(phoneNumberValidator(''), isNull);
      expect(
        phoneNumberValidator(null, isRequired: true),
        'Telefon numarası zorunludur.',
      );
      expect(phoneNumberValidator('0312 555 10 10'), isNull);
      expect(
        phoneNumberValidator('0312 555 10'),
        'Telefon numarası 11 haneli olmalıdır.',
      );
    });

    test('T.C. kimlik numarası uzunluğunu doğrular', () {
      expect(nationalIdValidator(''), isNull);
      expect(nationalIdValidator('12345678901'), isNull);
      expect(
        nationalIdValidator('1234'),
        'T.C. kimlik numarası 11 haneli olmalıdır.',
      );
    });

    test('pozitif sayıları doğrular', () {
      expect(isPositiveNumber('12'), isTrue);
      expect(isPositiveNumber('0'), isFalse);
      expect(isPositiveNumber('sayı'), isFalse);
      expect(
        positiveNumberValidator('0', 'Kapasite'),
        'Sıfırdan büyük bir sayı girin.',
      );
      expect(positiveNumberValidator('2', 'Kapasite'), isNull);
    });

    test('telefon ve metinleri ortak biçimlendirir', () {
      expect(formatPhoneNumber('03125551010'), '0312 555 10 10');
      expect(normalizePhoneNumber('0312 555 10 10'), '03125551010');
      expect(capitalizeWords('ali yılmaz-ayşe'), 'Ali Yılmaz-Ayşe');
      expect(capitalizeWords('ÖMER ATMACA'), 'Ömer Atmaca');
      expect(capitalizeWords('İSTANBUL IĞDIR'), 'İstanbul Iğdır');
    });
  });
}
