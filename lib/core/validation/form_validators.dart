import 'package:flutter/services.dart';

String? requiredField(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label zorunludur.';
  }
  return null;
}

String? phoneNumberValidator(String? value, {bool isRequired = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return isRequired ? requiredField(value, 'Telefon numarası') : null;
  }
  final digits = normalizePhoneNumber(text);
  final withoutSeparators = text.replaceAll(RegExp(r'[\s().-]'), '');
  if (digits.length != 11 || withoutSeparators != digits) {
    return 'Telefon numarası 11 haneli olmalıdır.';
  }
  return null;
}

String? nationalIdValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (!RegExp(r'^[0-9]{11}$').hasMatch(text)) {
    return 'T.C. kimlik numarası 11 haneli olmalıdır.';
  }
  return null;
}

String? positiveNumberValidator(String? value, String label) {
  final requiredError = requiredField(value, label);
  if (requiredError != null) {
    return requiredError;
  }
  final number = int.tryParse(value!.trim());
  if (number == null || number <= 0) {
    return 'Sıfırdan büyük bir sayı girin.';
  }
  return null;
}

bool isPositiveNumber(String? value) {
  final number = int.tryParse(value?.trim() ?? '');
  return number != null && number > 0;
}

String normalizePhoneNumber(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String formatPhoneNumber(String value) {
  final digits = normalizePhoneNumber(value);
  final truncated = digits.length > 11 ? digits.substring(0, 11) : digits;
  final result = StringBuffer();

  for (var index = 0; index < truncated.length; index++) {
    result.write(truncated[index]);
    if ((index == 3 || index == 6 || index == 8) &&
        index < truncated.length - 1) {
      result.write(' ');
    }
  }

  return result.toString();
}

String capitalizeWords(String value) {
  final result = StringBuffer();
  var capitalizeNext = true;

  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    final lowerCharacter = _turkishLowercase(character);
    if (_isWordSeparator(character)) {
      result.write(character);
      capitalizeNext = true;
    } else if (capitalizeNext) {
      result.write(_turkishUppercase(lowerCharacter));
      capitalizeNext = false;
    } else {
      result.write(lowerCharacter);
    }
  }

  return result.toString();
}

TextInputFormatter get capitalizeWordsFormatter {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    final text = capitalizeWords(newValue.text);
    final baseOffset = _clampTextOffset(newValue.selection.baseOffset, text);
    final extentOffset = _clampTextOffset(
      newValue.selection.extentOffset,
      text,
      fallback: baseOffset,
    );
    return newValue.copyWith(
      text: text,
      selection: TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
    );
  });
}

TextInputFormatter get formattedPhoneNumberFormatter {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    final formatted = formatPhoneNumber(newValue.text);
    final cursorOffset = _phoneCursorOffset(
      formatted,
      newValue.text,
      newValue.selection.baseOffset,
    );
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  });
}

List<TextInputFormatter> get formattedPhoneInputFormatters =>
    <TextInputFormatter>[formattedPhoneNumberFormatter];

List<TextInputFormatter> get phoneDigitsFormatters => <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(11),
];

String _turkishLowercase(String value) {
  if (value == 'İ') {
    return 'i';
  }
  if (value == 'I') {
    return 'ı';
  }
  return value.toLowerCase();
}

String _turkishUppercase(String value) {
  if (value == 'i') {
    return 'İ';
  }
  if (value == 'ı') {
    return 'I';
  }
  return value.toUpperCase();
}

bool _isWordSeparator(String value) {
  return value.trim().isEmpty || value == '-' || value == "'" || value == '’';
}

int _clampTextOffset(int? offset, String text, {int? fallback}) {
  if (offset == null || offset < 0) {
    return fallback ?? text.length;
  }
  return offset > text.length ? text.length : offset;
}

int _phoneCursorOffset(String formatted, String rawValue, int? rawOffset) {
  final safeOffset = rawOffset == null || rawOffset < 0
      ? rawValue.length
      : rawOffset > rawValue.length
      ? rawValue.length
      : rawOffset;
  final digitsBeforeCursor = normalizePhoneNumber(
    rawValue.substring(0, safeOffset),
  );
  if (digitsBeforeCursor.isEmpty) {
    return 0;
  }

  var digitCount = 0;
  for (var index = 0; index < formatted.length; index++) {
    if (_isPhoneDigit(formatted[index])) {
      digitCount++;
      if (digitCount == digitsBeforeCursor.length) {
        return index + 1;
      }
    }
  }
  return formatted.length;
}

bool _isPhoneDigit(String value) {
  final codeUnit = value.codeUnitAt(0);
  return codeUnit >= 48 && codeUnit <= 57;
}
