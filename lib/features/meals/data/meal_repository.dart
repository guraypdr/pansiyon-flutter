import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/features/meals/domain/meal_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Menü içeren bir ay.
class MealMonthRef {
  const MealMonthRef({
    required this.year,
    required this.month,
    required this.dayCount,
  });

  final int year;
  final int month;

  /// Menüsü kayıtlı gün sayısı.
  final int dayCount;

  String get title => mealMonthTitle(year, month);
}

/// Toplu içe aktarım sonucu.
///
/// Aynı tarihe ikinci kez aktarıldığında mevcut gün **üzerine yazılır**:
/// Excel'i düzeltip tekrar aktarmak güncel veriyi getirir, eskisi kalıcı
/// olarak eklenmez.
class MealImportResult {
  const MealImportResult({required this.added, required this.updated});

  final int added;
  final int updated;

  int get total => added + updated;

  String get summary => '$added gün eklendi, $updated gün güncellendi.';
}

abstract interface class MealRepository {
  /// Verilen ayın menülerini tarih sırasıyla döner.
  Future<List<MealDay>> getMonth(int year, int month);

  /// Menüsü kayıtlı ayları en yeniden eskiye doğru döner.
  Future<List<MealMonthRef>> getMonths();

  /// Toplu kayıt. Var olan günlerin menüsü değiştirilir.
  Future<MealImportResult> importDays(List<MealDay> days);

  /// Tek günü kaydeder (menüyü tamamen değiştirir).
  Future<void> saveDay(MealDay day);

  Future<void> deleteDay(DateTime date);

  /// Ayın tüm menülerini siler.
  Future<void> clearMonth(int year, int month);

  /// Tutanak imza bloklarının okul geneli bilgilerini okur.
  ///
  /// Hiç kayıt girilmemişse [MealReceiptSignatures.empty] döner.
  Future<MealReceiptSignatures> loadReceiptSignatures();

  /// Tutanak imza bloklarının okul geneli bilgilerini tek satır olarak yazar.
  Future<void> saveReceiptSignatures(MealReceiptSignatures signatures);

  /// [start] ve [end] arasında menüsü kayıtlı gün sayısını döner.
  ///
  /// Tutanak numarası bu sayımla hesaplanır: eğitim öğretim yılının eylül
  /// ayındaki ilk yemek günü `1` numaralı tutanaktır.
  Future<int> countMealDaysBetween(DateTime start, DateTime end);
}

class SqliteMealRepository implements MealRepository {
  SqliteMealRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<List<MealDay>> getMonth(int year, int month) async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery(
      '''
      SELECT d.id AS day_id, d.menu_date, i.meal_type, i.name
      FROM meal_days d
      LEFT JOIN meal_items i ON i.day_id = d.id
      WHERE d.menu_date >= ? AND d.menu_date <= ?
      ORDER BY d.menu_date ASC, i.meal_type ASC, i.position ASC, i.id ASC
      ''',
      [_monthStartKey(year, month), _monthEndKey(year, month)],
    );
    if (rows.isEmpty) {
      return const [];
    }

    final byDay = <String, _MutableMealDay>{};
    final order = <String>[];
    for (final row in rows) {
      final key = row['menu_date'] as String;
      final entry = byDay.putIfAbsent(key, () {
        order.add(key);
        return _MutableMealDay(parseMealDateKey(key)!);
      });
      entry.id = (row['day_id'] as num?)?.toInt() ?? entry.id;
      final type = MealType.fromValue((row['meal_type'] as String?) ?? '');
      final name = (row['name'] as String?)?.trim() ?? '';
      if (type == null || name.isEmpty) {
        continue;
      }
      entry.items.putIfAbsent(type, () => <String>[]).add(name);
    }

    return [
      for (final key in order)
        MealDay(
          id: byDay[key]!.id,
          date: byDay[key]!.date,
          items: {
            for (final entry in byDay[key]!.items.entries)
              entry.key: List.unmodifiable(entry.value),
          },
        ),
    ];
  }

  @override
  Future<List<MealMonthRef>> getMonths() async {
    final database = await _appDatabase.database;
    final rows = await database.rawQuery('''
      SELECT substr(menu_date, 1, 4) AS year, substr(menu_date, 6, 2) AS month,
             COUNT(*) AS day_count
      FROM meal_days
      GROUP BY year, month
      ORDER BY year DESC, month DESC
      ''');
    return [
      for (final row in rows)
        MealMonthRef(
          year: int.parse(row['year'] as String),
          month: int.parse(row['month'] as String),
          dayCount: (row['day_count'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<MealImportResult> importDays(List<MealDay> days) async {
    if (days.isEmpty) {
      return const MealImportResult(added: 0, updated: 0);
    }
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();

    return database.transaction((transaction) async {
      final existing = <String>{};
      final existingRows = await transaction.rawQuery(
        'SELECT menu_date FROM meal_days',
      );
      for (final row in existingRows) {
        existing.add(row['menu_date'] as String);
      }

      var added = 0;
      var updated = 0;
      for (final day in days) {
        final key = mealDateKey(day.date);
        final isUpdate = existing.contains(key);
        if (isUpdate) {
          updated++;
        } else {
          added++;
        }
        await _writeDay(transaction, day, key, now, isUpdate: isUpdate);
      }
      return MealImportResult(added: added, updated: updated);
    });
  }

  @override
  Future<void> saveDay(MealDay day) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      final key = mealDateKey(day.date);
      var isUpdate = day.id != null;
      if (!isUpdate) {
        final existing = await transaction.rawQuery(
          'SELECT id FROM meal_days WHERE menu_date = ? LIMIT 1',
          [key],
        );
        isUpdate = existing.isNotEmpty;
      }
      await _writeDay(
        transaction,
        day,
        key,
        now,
        isUpdate: isUpdate,
      );
    });
  }


  Future<void> _writeDay(
    DatabaseExecutor transaction,
    MealDay day,
    String key,
    String now, {
    required bool isUpdate,
  }) async {
    int dayId;
    if (isUpdate) {
      final rows = await transaction.rawQuery(
        'SELECT id FROM meal_days WHERE menu_date = ? LIMIT 1',
        [key],
      );
      if (rows.isEmpty) {
        dayId = await transaction.insert('meal_days', {
          'menu_date': key,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        dayId = rows.first['id'] as int;
        await transaction.update(
          'meal_days',
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [dayId],
        );
        // Menü değişti; eski yemekler kalırsa gün içinde tekrarlar oluşur.
        await transaction.delete(
          'meal_items',
          where: 'day_id = ?',
          whereArgs: [dayId],
        );
      }
    } else {
      dayId = await transaction.insert('meal_days', {
        'menu_date': key,
        'created_at': now,
        'updated_at': now,
      });
    }

    final batch = transaction.batch();
    for (final type in MealType.values) {
      final meals = day.mealsOf(type);
      for (var index = 0; index < meals.length; index++) {
        final name = meals[index].trim();
        if (name.isEmpty) {
          continue;
        }
        batch.insert('meal_items', {
          'day_id': dayId,
          'meal_type': type.value,
          'position': index,
          'name': name,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteDay(DateTime date) async {
    final database = await _appDatabase.database;
    await database.delete(
      'meal_days',
      where: 'menu_date = ?',
      whereArgs: [mealDateKey(date)],
    );
  }

  @override
  Future<void> clearMonth(int year, int month) async {
    final database = await _appDatabase.database;
    await database.delete(
      'meal_days',
      where: 'menu_date >= ? AND menu_date <= ?',
      whereArgs: [_monthStartKey(year, month), _monthEndKey(year, month)],
    );
  }

  @override
  Future<MealReceiptSignatures> loadReceiptSignatures() async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'meal_receipt_signatures',
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      return MealReceiptSignatures.empty;
    }
    final row = rows.first;
    return MealReceiptSignatures(
      delivererJobTitle: (row['deliverer_job_title'] as String?) ?? '',
      delivererName: (row['deliverer_name'] as String?) ?? '',
      receiverJobTitle: (row['receiver_job_title'] as String?) ?? '',
      receiverName: (row['receiver_name'] as String?) ?? '',
    );
  }

  @override
  Future<void> saveReceiptSignatures(MealReceiptSignatures signatures) async {
    final database = await _appDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert('meal_receipt_signatures', {
      'id': 1,
      // Tutanak standart görünümü için her kelimenin ilk harfi büyütülür.
      'deliverer_job_title': mealTitleCase(signatures.delivererJobTitle),
      'deliverer_name': mealTitleCase(signatures.delivererName),
      'receiver_job_title': mealTitleCase(signatures.receiverJobTitle),
      'receiver_name': mealTitleCase(signatures.receiverName),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<int> countMealDaysBetween(DateTime start, DateTime end) async {
    final database = await _appDatabase.database;
    // `menu_date` tek gün başına tek satır olduğu için ayrı gün sayısı
    // doğrudan satır sayısıdır.
    final rows = await database.rawQuery(
      '''
      SELECT COUNT(*) AS day_count
      FROM meal_days
      WHERE menu_date >= ? AND menu_date <= ?
      ''',
      [mealDateKey(start), mealDateKey(end)],
    );
    return (rows.first['day_count'] as num?)?.toInt() ?? 0;
  }
}

/// Gün başına yemekleri toplarken kullanılan geçici taşıyıcı.
class _MutableMealDay {
  _MutableMealDay(this.date);

  final DateTime date;
  int? id;
  final Map<MealType, List<String>> items = {};
}

String _monthStartKey(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';

String _monthEndKey(int year, int month) {
  // Ayın gün sayısı: bir sonraki ayın ilk gününden bir gün geri.
  final next = month == 12
      ? DateTime(year + 1, 1, 1)
      : DateTime(year, month + 1, 1);
  return mealDateKey(next.subtract(const Duration(days: 1)));
}
