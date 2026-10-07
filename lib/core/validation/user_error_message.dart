/// Veri katmanının kullanıcıya göstermesi amaçlanan hata mesajını döndürür.
///
/// Repository'ler alan ve iş kuralı doğrulaması için [StateError] (kayıt
/// bulunamadı, kural ihlali) ve [ArgumentError] (alan boş olamaz) fırlatır.
/// Excel içe aktarma da kullanıcıya dönük mesaj taşıyan [FormatException]
/// fırlatır (örneğin kilit dosyası seçildi, sütun eksik).
///
/// Mesaj `toString()` metninden ayrıştırılmaz, tip kontrolüyle alınır.
/// Böylece `DatabaseException` gibi beklenmeyen hatalar arayüze sızmaz;
/// onlar için [fallback] kullanılır.
String userErrorMessage(Object error, {required String fallback}) {
  if (error is StateError) {
    final message = error.message.trim();
    return message.isEmpty ? fallback : message;
  }
  if (error is ArgumentError) {
    final message = error.message?.trim();
    if (message == null || message.isEmpty) {
      return fallback;
    }
    return message;
  }
  if (error is FormatException) {
    // FormatException mesajı doğrudan kullanıcıya gösterilmek üzere
    // yazılır. Burada düşürülürse kullanıcı "dosya okunamadı" gibi
    // sebebi açıklamayan genel bir mesajla kalır.
    final message = error.message.trim();
    return message.isEmpty ? fallback : message;
  }
  return fallback;
}
