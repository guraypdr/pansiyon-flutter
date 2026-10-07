import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Kaydetme diyaloğunun açılacağı güvenli varsayılan klasörü çözer.
///
/// Windows'un "Kaydet" diyaloğu başlangıç klasörü verilmezse kendi
/// seçtiği yere açılır. Bu seçim bazen yazma yetkisi olmayan bir konuma
/// denk gelir ve diyalog "buraya kaydetmeye izin yok, yönetici izni
/// gerekiyor" uyarısı göstererek kullanıcıyı kilitler. Bu yüzden
/// başlangıç klasörünü biz belirliyoruz.
///
/// Sıra: İndirilenler -> Kullanıcı profilindeki Desktop -> Belgeler.
/// Hepsine erişilemezse `null` döner; çağıran bu durumda diyaloğu
/// varsayılan davranışla açabilir.
Future<String?> resolveSaveDirectory() async {
  final candidates = <String?>[
    await _safeDirectory(getDownloadsDirectory),
    _desktopFromEnvironment(),
    await _safeDirectory(getApplicationDocumentsDirectory),
  ];
  for (final candidate in candidates) {
    if (candidate == null) {
      continue;
    }
    if (await Directory(candidate).exists()) {
      return candidate;
    }
  }
  return null;
}

Future<String?> _safeDirectory(Future<Directory?> Function() resolver) async {
  try {
    return (await resolver())?.path;
  } catch (_) {
    // Yol sağlayıcı bu platformda çalışmıyor olabilir.
    return null;
  }
}

/// `USERPROFILE` üzerinden masaüstü yolunu bulur.
///
/// [getDownloadsDirectory] çalışmazsa geriye düşer. Gerçek masaüstü
/// (OneDrive yönlendirmesi olan sistemlerde) kayıt defterinden gelir; bu
/// yol yalnızca yedek çözümdür, bu yüzden varlığı ayrıca doğrulanır.
String? _desktopFromEnvironment() {
  final profile = Platform.environment['USERPROFILE'];
  if (profile == null || profile.isEmpty) {
    return null;
  }
  return '$profile\\Desktop';
}

/// Baytları diske yazar ve yazmanın gerçekten gerçekleştiğini doğrular.
///
/// Shell diyaloğu dosyayı oluşturabildiği hâlde yazma başarısız
/// olabilir; bu durumda kullanıcıya "kaydedildi" demek yanlış olur ve
/// Excel'in açamadığı 0 baytlık bir dosya kalır. Bu yüzden boyut
/// kontrolü yapılır ve başarısızsa dosya silinir.
Future<void> writeFileChecked(String filePath, List<int> bytes) async {
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  if (await file.length() == bytes.length) {
    return;
  }
  if (await file.exists()) {
    await file.delete();
  }
  throw FileSystemException('Dosya tam olarak yazılamadı.', filePath);
}

/// Kaydetme diyaloğunu açar ve kullanıcı iptal etmezse baytları yazar.
///
/// [FilePicker.saveFile] yalnızca yolu döndürür; yazma işi çağırana
/// kalır. Diyalog iptal edilirse `null` döner.
Future<String?> saveBytesWithDialog({
  required String dialogTitle,
  required String fileName,
  required List<int> bytes,
  required String mimeType,
  List<String> allowedExtensions = const ['xlsx'],
}) async {
  final savedUri = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: mimeType,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    initialDirectory: await resolveSaveDirectory(),
  );
  if (savedUri == null) {
    return null;
  }
  final path = savedUri.toFilePath();
  await writeFileChecked(path, bytes);
  return path;
}
