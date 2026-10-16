import 'boarding_info_models.dart';

/// Dosya oluşturulduktan sonra değiştirilemeyen özellikler.
enum PansiyonLockedField {
  boardingType('Pansiyon türü'),
  educationLevel('Pansiyon kademesi');

  const PansiyonLockedField(this.label);

  /// Kullanıcıya gösterilen alan adı.
  final String label;
}

/// Pansiyon dosyasının değiştirilemez kimlik bilgileri.
///
/// Kural: **pansiyon türü** ve **pansiyon kademesi** dosya oluşturulurken
/// bir kez seçilir ve sonradan değiştirilemez. Bu iki özellik tüm kayıtların
/// (öğrenci, oda, nöbet, yemek) kademeye ve cinsiyete göre yorumlanmasını
/// belirlediği için dosyanın kimliğidir; açık bir dosyanın içinde değişmesi
/// mevcut kayıtları geçersiz kılardı.
///
/// Farklı bir tür veya kademe ile çalışmak için **yeni bir pansiyon dosyası**
/// oluşturulur.
class PansiyonIdentity {
  const PansiyonIdentity({
    required this.boardingType,
    required this.educationLevel,
  });

  final BoardingType boardingType;
  final EducationLevel educationLevel;

  /// Kayıtlı taslaktan kimliği okur.
  factory PansiyonIdentity.fromDraft(BoardingInfoDraft draft) {
    return PansiyonIdentity(
      boardingType: draft.boardingType,
      educationLevel: draft.educationLevel,
    );
  }

  String get boardingTypeLabel => boardingType.label;
  String get educationLevelLabel => educationLevel.label;
}

/// Kimlik kilidi kuralları.
///
/// Saf mantık içerir; arayüzden bağımsız ve doğrudan test edilebilir.
class PansiyonIdentityLock {
  const PansiyonIdentityLock._();

  /// Farklı tür/kademe için izlenecek yol.
  static const changeHint =
      'Farklı tür veya kademe için "Yeni Pansiyon Oluştur" işlemiyle yeni bir '
      'pansiyon dosyası açın; yeni dosya boş olarak başlar ve mevcut '
      'kayıtlar aktarılmaz.';

  /// Tür ve kademe kilitli mi?
  ///
  /// Yeni dosya oluşturma akışında kimlik henüz seçilmediği için kilit kapalı
  /// olmalıdır. Kayıtlı bir dosyada ise kimlik seçilmiş ve değiştirilemez.
  static bool isLocked({
    required bool isCreatingFile,
    required PansiyonIdentity? storedIdentity,
  }) {
    return !isCreatingFile && storedIdentity != null;
  }

  /// Alanın kilitli olduğunu anlatan kullanıcı metni.
  static String messageFor(PansiyonLockedField field) {
    return '${field.label} dosya oluşturulurken seçilir ve sonradan '
        'değiştirilemez. $changeHint';
  }

  /// Kilit bildiriminde gösterilen açıklama.
  static String get notice => changeHint;
}