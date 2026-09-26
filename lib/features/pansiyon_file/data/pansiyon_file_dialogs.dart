import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';

/// Kullanıcıyla iletişim kuran sistem pencereleri.
///
/// Test edilebilirlik için ayrı bir arayüz olarak tanımlanır; uygulama içinde
/// yalnızca [FilePickerPansiyonFileDialogs] kullanılır.
abstract interface class PansiyonFileDialogs {
  /// Pansiyon dosyasının kaydedileceği klasörü seçtirir.
  ///
  /// Kullanıcı vazgeçerse `null` döner.
  Future<Directory?> pickSaveDirectory({String? suggestedFileName});

  /// Açılacak `.pansiyon` dosyasını seçtirir.
  ///
  /// Kullanıcı vazgeçerse `null` döner.
  Future<String?> pickPansiyonFile();
}

class FilePickerPansiyonFileDialogs implements PansiyonFileDialogs {
  const FilePickerPansiyonFileDialogs();

  static const extension = PansiyonDatabaseSession.pansiyonFileExtension;

  @override
  Future<Directory?> pickSaveDirectory({String? suggestedFileName}) async {
    final selectedPath = await FilePicker.getDirectoryPath(
      dialogTitle: suggestedFileName == null
          ? 'Pansiyon dosyasının kaydedileceği klasörü seçin'
          : '"$suggestedFileName" dosyası nereye kaydedilsin?',
    );
    if (selectedPath == null) {
      return null;
    }
    return Directory(selectedPath);
  }

  @override
  Future<String?> pickPansiyonFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Açılacak pansiyon dosyasını seçin',
      type: FileType.custom,
      allowedExtensions: const ['pansiyon'],
    );
    if (result.isEmpty) {
      return null;
    }
    return result.single.path;
  }
}
