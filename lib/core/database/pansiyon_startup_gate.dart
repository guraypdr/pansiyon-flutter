import 'dart:io';

import 'package:pansiyon_yonetim/core/database/pansiyon_file_memory.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';

enum PansiyonStartupMode {
  /// Açılış değerlendirmesi sürüyor.
  checking,

  /// Daha önce seçilmiş bir pansiyon dosyası doğrulandı ve açılabilir.
  rememberedPansiyon,

  /// Kullanılabilir bir pansiyon dosyası yok, başlangıç ekranı gösterilir.
  needsPansiyonFile,
}

class PansiyonStartupDecision {
  const PansiyonStartupDecision({
    required this.mode,
    this.filePath,
    this.lastFileMissing = false,
  });

  const PansiyonStartupDecision.needsPansiyonFile({
    bool lastFileMissing = false,
  }) : this(
         mode: PansiyonStartupMode.needsPansiyonFile,
         lastFileMissing: lastFileMissing,
       );

  final PansiyonStartupMode mode;

  /// Doğrulanan hatırlanmış dosyanın yolu.
  final String? filePath;

  /// Daha önce seçilmiş dosya vardı ama artık mevcut değil.
  final bool lastFileMissing;
}

/// Uygulamanın hangi pansiyon dosyasıyla açılacağına karar verir.
///
/// Kural: yalnızca kullanıcının daha önce **seçtiği** dosya otomatik açılır.
/// Uygulamanın kendi varsayılan veritabanı yoluna gidilmez.
class PansiyonStartupGate {
  const PansiyonStartupGate();

  Future<PansiyonStartupDecision> resolve({
    required PansiyonFileMemory memory,
    PansiyonFileService? fileService,
  }) async {
    final service = fileService ?? PansiyonFileService();
    final rememberedPath = (await memory.readLastFilePath())?.trim();
    if (rememberedPath == null || rememberedPath.isEmpty) {
      return const PansiyonStartupDecision.needsPansiyonFile();
    }

    if (!await File(rememberedPath).exists()) {
      return const PansiyonStartupDecision.needsPansiyonFile(
        lastFileMissing: true,
      );
    }

    try {
      // Eski sürümlü dosyalar kabul edilir; yükseltme açılışta yapılır.
      final info = await service.validateFile(
        rememberedPath,
        requireCurrentVersion: false,
      );
      return PansiyonStartupDecision(
        mode: PansiyonStartupMode.rememberedPansiyon,
        filePath: info.filePath,
      );
    } catch (_) {
      return const PansiyonStartupDecision.needsPansiyonFile(
        lastFileMissing: true,
      );
    }
  }
}
