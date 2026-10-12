/// Günün dört öğünü.
///
/// Excel'deki sütun sırası bu sırayla aynıdır: `SABAH`, `ÖĞLE`, `AKŞAM`,
/// `ARA ÖĞÜN`. Sütun başlıkları eşleştirilirken hem bu kısaltmalar hem de
/// [MealType.aliases] içindeki uzun yazımlar kabul edilir; okul farklı
/// yazdığında ("Kahvaltı", "Ara Öğün") yine bulunur.
enum MealType {
  breakfast(
    value: 'breakfast',
    label: 'Kahvaltı',
    shortLabel: 'Kahvaltı',
    aliases: ['sabah', 'kahvalti', 'kahvaltı', 'breakfast', 'morning'],
  ),
  lunch(
    value: 'lunch',
    label: 'Öğle Yemeği',
    shortLabel: 'Öğle',
    aliases: ['ogle', 'öğle', 'ogleyemegi', 'öğleyemeği', 'lunch'],
  ),
  dinner(
    value: 'dinner',
    label: 'Akşam Yemeği',
    shortLabel: 'Akşam',
    aliases: ['aksam', 'akşam', 'aksamyemegi', 'akşamyemeği', 'dinner'],
  ),
  snack(
    value: 'snack',
    label: 'Ara Öğün',
    shortLabel: 'Ara Öğün',
    aliases: [
      'araogun',
      'ara öğün',
      'araöğün',
      'araogunu',
      'araöğünü',
      'snack',
    ],
  );

  const MealType({
    required this.value,
    required this.label,
    required this.shortLabel,
    required this.aliases,
  });

  /// Veritabanında saklanan kararlı anahtar.
  final String value;

  /// Kart ve tabloda görünen tam ad.
  final String label;

  /// Dar sütunlarda görünen kısa ad.
  final String shortLabel;

  /// Excel başlığı eşleştirmesinde kabul edilen yazımlar.
  final List<String> aliases;

  static MealType? fromValue(String value) {
    final token = value.trim().toLowerCase();
    for (final type in MealType.values) {
      if (type.value == token || type.aliases.contains(token)) {
        return type;
      }
    }
    return null;
  }
}

/// Bir öğünün yemek listesi; sıra menüdeki yazım sırasını korur.
typedef MealItems = List<String>;

/// Bir güne ait menü.
class MealDay {
  const MealDay({required this.date, this.id, this.items = const {}});

  final int? id;
  final DateTime date;

  /// Öğün türü -> o öğündeki yemekler. Anahtarı olmayan öğün boş demektir
  /// (hafta sonu, Cuma akşam yemeği yok vb.).
  final Map<MealType, MealItems> items;

  List<String> mealsOf(MealType type) => items[type] ?? const [];

  /// Bu gün için kayıtlı en az bir yemek var mı.
  bool get hasAnyMeal =>
      MealType.values.any((type) => mealsOf(type).isNotEmpty);

  int get itemCount =>
      MealType.values.fold(0, (sum, type) => sum + mealsOf(type).length);

  /// Menüde geçen yemekler; içe aktarma önizlemesinde ve yazdırmada kullanılır.
  List<String> get allItems => [
    for (final type in MealType.values) ...mealsOf(type),
  ];

  MealDay copyWith({int? id, Map<MealType, MealItems>? items}) {
    return MealDay(id: id ?? this.id, date: date, items: items ?? this.items);
  }

  @override
  bool operator ==(Object other) {
    return other is MealDay &&
        mealDateKey(other.date) == mealDateKey(date) &&
        other.hasAnyMeal == hasAnyMeal &&
        other.itemCount == itemCount;
  }

  @override
  int get hashCode => Object.hash(mealDateKey(date), hasAnyMeal, itemCount);
}

/// Veritabanı anahtarı: yyyy-gg-aa.
String mealDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime? parseMealDateKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(year, month, day);
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

const _weekdayNames = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String mealMonthName(int month) => _monthNames[month - 1];

/// Metni Türkçe kurallarına göre büyütür.
///
/// Dart'ın `toUpperCase()` metodu Türkçe'yi bilmez: noktasız `i` harfini
/// `I` yapar ve başlıkta "EKIM AYI MENÜSÜ" gibi hatalı bir metin üretir.
String mealUpperCase(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(switch (character) {
      'i' => 'İ',
      'ı' => 'I',
      'ş' => 'Ş',
      'ğ' => 'Ğ',
      'ü' => 'Ü',
      'ö' => 'Ö',
      'ç' => 'Ç',
      _ => character.toUpperCase(),
    });
  }
  return buffer.toString();
}

/// `Ekim` -> `EKİM`
String mealMonthUpperName(int month) => mealUpperCase(mealMonthName(month));

String mealWeekdayName(DateTime date) => _weekdayNames[date.weekday - 1];

/// "Ekim 2026" gibi ay etiketi.
String mealMonthTitle(int year, int month) => '${mealMonthName(month)} $year';

/// Seçilen günü içe aktarılmış menüde arar; yoksa null döner.
MealDay? findMealDay(List<MealDay> days, DateTime date) {
  final key = mealDateKey(date);
  for (final day in days) {
    if (mealDateKey(day.date) == key) {
      return day;
    }
  }
  return null;
}

/// Menü hücresini tek tek yemeklere böler.
///
/// Yemekler Excel'de `-` veya satır sonuyla ayrılmıştır; bazı hücrelerde
/// ikisi birlikte kullanılır ("Sütlaç-\nKuruyemiş"), bazılarında yalnızca
/// satır sonu vardır ("Cacık\nMandalina"). Her iki ayraç da birlikte ele
/// alınır, boş parçalar atılır.
List<String> splitMealItems(String raw) {
  final text = raw.replaceAll('\r', '');
  if (text.trim().isEmpty) {
    return const [];
  }
  final items = <String>[];
  for (final part in text.split(RegExp(r'[-–—\n]'))) {
    // Ayraçtan arta kalan nokta, virgül gibi edatlar yemeğe ait değil.
    final cleaned = part
        .trim()
        .replaceAll(RegExp(r'^[\s.,;:]+|[\s.,;:]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      continue;
    }
    items.add(_capitalizeFirst(cleaned));
  }
  return List.unmodifiable(items);
}

/// Yemeğin yalnızca ilk harfini büyütür, gerisini yazan kişinin bıraktığı
/// gibi bırakır.
///
/// Her kelimeyi büyütmek ("Peynirli Tepsi Böreği") yemek adlarını
/// Türkçede alışılmadık bir başlık biçimine sokuyordu. Buna karşılık yazımı
/// olduğu gibi bırakmak "pirinç pilavı" gibi satırları küçük harfle
/// gösteriyordu.
String _capitalizeFirst(String value) {
  if (value.isEmpty) {
    return value;
  }
  final first = value.substring(0, 1);
  // Dart'ın toUpperCase'i Türkçe'yi bilmez: 'i' yerine 'I' verir.
  final upper = switch (first) {
    'i' => 'İ',
    'ı' => 'I',
    _ => first.toUpperCase(),
  };
  return '$upper${value.substring(1)}';
}
