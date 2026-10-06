/// Veri katmanının kullanıcıya göstermesi amaçlanan hata mesajını döndürür.
///
/// Repository'ler alan ve iş kuralı doğrulaması için [StateError] (kayıt
/// bulunamadı, kural ihlali) ve [ArgumentError] (alan boş olamaz) fırlatır.
/// İkisi de Türkçe ve kullanıcıya dönük bir mesaj taşır.
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
  return fallback;
}
