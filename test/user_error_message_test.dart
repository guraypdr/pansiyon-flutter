import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pansiyon_yonetim/core/validation/user_error_message.dart';

void main() {
  group('userErrorMessage', () {
    test('StateError mesajını geçirir', () {
      expect(
        userErrorMessage(StateError('Kayıt bulunamadı.'), fallback: 'genel'),
        'Kayıt bulunamadı.',
      );
    });

    test('ArgumentError mesajını geçirir', () {
      expect(
        userErrorMessage(ArgumentError('Alan boş olamaz.'), fallback: 'genel'),
        'Alan boş olamaz.',
      );
    });

    test('FormatException mesajını geçirir', () {
      // Excel içe aktarma kullanıcıya dönük mesajla FormatException
      // fırlatır. Bu mesaj düşürülürse kullanıcı sebebi bilemez.
      expect(
        userErrorMessage(
          const FormatException('Excel kilit dosyası seçildi.'),
          fallback: 'Excel dosyası okunamadı.',
        ),
        'Excel kilit dosyası seçildi.',
      );
    });

    test('FormatException mesajı boşsa genel mesajı kullanır', () {
      expect(
        userErrorMessage(const FormatException(''), fallback: 'genel'),
        'genel',
      );
    });

    test('beklenmeyen hatalarda genel mesajı kullanır', () {
      expect(
        userErrorMessage(FileSystemException('izin yok'), fallback: 'genel'),
        'genel',
      );
    });
  });
}
