import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Kullanıcının en son açtığı/oluşturduğu pansiyon dosyasının yolunu hatırlar.
///
/// Uygulamanın kendi veri klasöründe tek satırlık bir metin dosyası tutulur;
/// `.pansiyon` dosyalarının içeriğine dokunulmaz.
abstract interface class PansiyonFileMemory {
  Future<String?> readLastFilePath();

  Future<void> writeLastFilePath(String? filePath);
}

class FileSystemPansiyonFileMemory implements PansiyonFileMemory {
  FileSystemPansiyonFileMemory({this.fileName = 'son_pansiyon_dosyasi.txt'});

  static const directoryName = 'pansiyon_yonetim';

  final String fileName;

  @override
  Future<String?> readLastFilePath() async {
    try {
      final file = await _memoryFile();
      if (!await file.exists()) {
        return null;
      }
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeLastFilePath(String? filePath) async {
    try {
      final file = await _memoryFile();
      final value = filePath?.trim();
      if (value == null || value.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(value);
    } catch (_) {
      // Hatırlama başarısız olursa uygulama normal şekilde çalışmaya devam eder.
    }
  }

  Future<File> _memoryFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(path.join(supportDirectory.path, directoryName, fileName));
  }
}

/// Testler ve geçici durumlar için bellek içi uygulama.
class InMemoryPansiyonFileMemory implements PansiyonFileMemory {
  InMemoryPansiyonFileMemory([this.lastFilePath]);

  String? lastFilePath;

  @override
  Future<String?> readLastFilePath() async => lastFilePath;

  @override
  Future<void> writeLastFilePath(String? filePath) async {
    lastFilePath = filePath?.trim().isEmpty ?? true ? null : filePath?.trim();
  }
}
