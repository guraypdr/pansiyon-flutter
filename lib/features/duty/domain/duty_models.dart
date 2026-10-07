import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/validation/form_validators.dart';

/// Öğretmen adını her kelimenin ilk harfi büyük olacak şekilde düzenler.
/// Altyapıdaki [capitalizeWords] ile aynı davranışı gösterir.
String formatDutyTeacherName(String value) => capitalizeWords(value);

/// Adın baş harflerini büyük harfe çevirir (Türkçe kurallarıyla):
/// "zeynep kaya" -> "ZK", "ayşe yılmaz" -> "AY", "AYŞE YILMAZ" -> "AY".
String dutyTeacherInitials(String fullName) {
  final parts = formatDutyTeacherName(
    fullName,
  ).split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '?';
  }
  final first = parts.first.characters.first.toUpperCase();
  if (parts.length == 1) {
    return first;
  }
  return '$first${parts.last.characters.first.toUpperCase()}';
}

enum DutyPreference { minimum, balanced, maximum }

extension DutyPreferenceLabel on DutyPreference {
  String get label {
    switch (this) {
      case DutyPreference.minimum:
        return 'Minimum';
      case DutyPreference.balanced:
        return 'Dengeli';
      case DutyPreference.maximum:
        return 'Maksimum';
    }
  }

  String get value => name;

  static DutyPreference fromValue(String? value) {
    for (final item in DutyPreference.values) {
      if (item.value == value) {
        return item;
      }
    }
    return DutyPreference.balanced;
  }
}

const _weekdayShortLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _weekdayLongLabels = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

List<String> dutyWeekdayShortLabels() => _weekdayShortLabels;
List<String> dutyWeekdayLabels() => _weekdayLongLabels;

String dutyWeekdayShortLabel(int weekday) => _weekdayShortLabels[weekday - 1];
String dutyWeekdayLabel(int weekday) => _weekdayLongLabels[weekday - 1];

class DutyTeacher {
  const DutyTeacher({
    this.id,
    required this.fullName,
    this.nationalId,
    this.phone,
    this.school,
    this.branch,
    this.hasDutyTraining = false,
    this.dutyPreference = DutyPreference.balanced,
    this.availableWeekdays = const [1, 2, 3, 4, 5],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String fullName;
  final String? nationalId;
  final String? phone;
  final String? school;
  final String? branch;
  final bool hasDutyTraining;
  final DutyPreference dutyPreference;

  /// 1 = Pazartesi ... 7 = Pazar
  final List<int> availableWeekdays;
final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get availableWeekdayLabel => availableWeekdays.isEmpty
      ? 'Müsait gün yok'
      : (availableWeekdays.toList()..sort())
            .map(dutyWeekdayShortLabel)
            .join(', ');

  bool isAvailableOn(DateTime date) => availableWeekdays.contains(date.weekday);
}

/// Bölüm bazında ortak tutulan nöbet ayarları.
class DutySettings {
  const DutySettings({
    required this.sectionKey,
    this.dailyCount = 2,
    this.maxConsecutive = 2,
    this.locations = const [],
    this.blackouts = const {},
  });

  /// Tek bölümlü pansiyon için `null`, karma pansiyonda bölüm etiketi.
  final String? sectionKey;
  final int dailyCount;

  /// 0 = üst üste nöbet yok, 1 = en fazla 1 gün, 2 = en fazla 2 gün ...
  final int maxConsecutive;
  final List<String> locations;

  /// Kapatılmış günler (gg.aa.yyyy).
  final Set<String> blackouts;

  /// Nöbet yeri, günlük nöbetçi sırasına göre tutulur.
  /// Örn. günlük 3 nöbetçi için [ 'Zemin Kat', '', '1. Kat' ].
  List<String> locationsForSlots(int dailyCount) {
    final list = [...locations];
    while (list.length < dailyCount) {
      list.add('');
    }
    return list;
  }

  String locationForSlot(int slot) {
    if (slot < locations.length) {
      return locations[slot];
    }
    return '';
  }

  DutySettings withLocation(int slot, String? value) {
    final updated = [...locations];
    while (updated.length <= slot) {
      updated.add('');
    }
    updated[slot] = (value ?? '').trim();
    return copyWith(
      locations: [for (final item in updated) item.trim().isEmpty ? '' : item],
    );
  }

  DutySettings copyWith({
    int? dailyCount,
    int? maxConsecutive,
    List<String>? locations,
    Set<String>? blackouts,
  }) {
    return DutySettings(
      sectionKey: sectionKey,
      dailyCount: dailyCount ?? this.dailyCount,
      maxConsecutive: maxConsecutive ?? this.maxConsecutive,
      locations: locations ?? this.locations,
      blackouts: blackouts ?? this.blackouts,
    );
  }
}

class DutyAssignment {
  const DutyAssignment({
    this.id,
    required this.year,
    required this.month,
    required this.date,
    required this.teacherId,
    this.location,
  });

  final int? id;
  final int year;
  final int month;
  final DateTime date;
  final int teacherId;
  final String? location;
}

class DutyMonthList {
  const DutyMonthList({
    required this.year,
    required this.month,
    required this.sectionKey,
    required this.assignmentCount,
  });

  final int year;
  final int month;
  final String? sectionKey;
  final int assignmentCount;

  String get sectionLabel => sectionKey ?? 'Tüm Bölümler';
  String get title => dutyMonthTitle(year, month);
}

const _monthNames = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

String dutyMonthName(int month) => _monthNames[month - 1];

String dutyMonthTitle(int year, int month) => '${dutyMonthName(month)} $year';

String dutyShortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// Kapalı gün setinde kullanılan gün anahtarı.
String dutyDateKey(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

int dutyDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

List<DateTime> dutyMonthDates(int year, int month) => [
  for (var day = 1; day <= dutyDaysInMonth(year, month); day++)
    DateTime(year, month, day),
];

/// Takvim ızgarası: Pazartesi ile başlayan haftalar.
List<List<DateTime?>> dutyMonthCalendar(int year, int month) {
  final days = dutyMonthDates(year, month);
  final first = days.first;
  final leading = first.weekday - 1;
  final cells = <DateTime?>[...List<DateTime?>.filled(leading, null), ...days];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [
    for (var index = 0; index < cells.length; index += 7)
      cells.sublist(index, index + 7),
  ];
}

/// Hafta sonlarının nöbet olmayan gün olarak işaretlenmesi için varsayılan kapalı günler.
Set<String> defaultDutyBlackoutKeys(int year, int month) => {
  for (final date in dutyMonthDates(year, month))
    if (date.weekday >= DateTime.saturday) dutyDateKey(date),
};
