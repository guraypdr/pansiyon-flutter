import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _isInitialized = false;

/// Windows masaüstünde SQLite motorunu hazırlar.
///
/// `databaseFactory` ataması yalnızca bir kez yapılır; her veritabanı
/// açılışında tekrarlanırsa sqflite "changing sqflite default factory"
/// uyarısı yazar.
void ensureSqfliteFfiInitialized() {
  if (_isInitialized) {
    return;
  }
  _isInitialized = true;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
