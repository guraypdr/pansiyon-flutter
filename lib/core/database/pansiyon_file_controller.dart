import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:pansiyon_yonetim/core/database/pansiyon_database_session.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_service.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';

/// Kullanıcıya gösterilebilen, teknik ayrıntı içermeyen hata.
class PansiyonActivationException implements Exception {
  const PansiyonActivationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

enum PansiyonActivationKind { created, opened }

class PansiyonActivationResult {
  const PansiyonActivationResult({
    required this.filePath,
    required this.kind,
    this.pansiyonName,
  });

  final String filePath;
  final PansiyonActivationKind kind;
  final String? pansiyonName;

  String get fileName => path.basename(filePath);
}

/// Pansiyon dosyası oluşturma/açma ve aktif veritabanı geçişini yönetir.
///
/// Akış her zaman aynıdır: dosya hazırlanır → yeni dosya doğrulanır →
/// aktif session güvenli şekilde değiştirilir. Geçiş başarısız olursa
/// [PansiyonDatabaseSession.switchToPath] eski bağlantıyı geri açar, bu yüzden
/// mevcut veritabanı hiçbir koşulda kaybolmaz.
abstract interface class PansiyonFileActions {
  String fileNameForPansiyon(String pansiyonName);

  /// Yeni boş bir `.pansiyon` dosyası oluşturur, [draft] bilgilerini bu dosyaya
  /// kaydeder, doğrular ve aktif veritabanı yapar.
  Future<PansiyonActivationResult> createPansiyonFile({
    required BoardingInfoDraft draft,
    required Directory directory,
  });

  /// Doğrulanmış bir `.pansiyon` dosyasını aktif veritabanı yapar.
  ///
  /// Boş yol verilirse `null` döner, yani hiçbir değişiklik yapılmaz.
  Future<PansiyonActivationResult?> openPansiyonFile(String filePath);
}

class PansiyonFileController implements PansiyonFileActions {
  PansiyonFileController({
    required this.session,
    PansiyonFileService? fileService,
  }) : fileService = fileService ?? PansiyonFileService();

  final PansiyonDatabaseSession session;
  final PansiyonFileService fileService;

  Future<String> activeDatabasePath() => session.activePath();

  @override
  String fileNameForPansiyon(String pansiyonName) =>
      fileService.fileNameForPansiyon(pansiyonName);

  /// Yeni boş bir `.pansiyon` dosyası oluşturur, [draft] bilgilerini bu dosyaya
  /// kaydeder, doğrular ve aktif veritabanı yapar.
  @override
  Future<PansiyonActivationResult> createPansiyonFile({
    required BoardingInfoDraft draft,
    required Directory directory,
  }) async {
    final pansiyonName = draft.schoolName.trim();
    if (pansiyonName.isEmpty) {
      throw const PansiyonActivationException('Pansiyon adı boş olamaz.');
    }

    try {
      final created = await fileService.createEmptyPansiyonFile(
        pansiyonName: pansiyonName,
        directory: directory,
      );

      return await _activate(
        created.filePath,
        kind: PansiyonActivationKind.created,
        prepare: (stagingSession) async {
          await SqliteBoardingInfoRepository(
            stagingSession.database,
          ).save(draft);
        },
      );
    } on PansiyonFileExistsException catch (error) {
      throw PansiyonActivationException(
        'Bu adla kayıtlı bir pansiyon dosyası zaten var. '
        'Farklı bir ad veya klasör seçebilirsiniz.',
        cause: error,
      );
    } on PansiyonFileException catch (error) {
      throw PansiyonActivationException(
        'Pansiyon dosyası oluşturulamadı. Farklı bir klasör seçip tekrar deneyin.',
        cause: error,
      );
    } catch (error) {
      throw PansiyonActivationException(
        'Pansiyon dosyası oluşturulamadı. Lütfen tekrar deneyin.',
        cause: error,
      );
    }
  }

  /// Doğrulanmış bir `.pansiyon` dosyasını aktif veritabanı yapar.
  ///
  /// Boş yol verilirse `null` döner, yani hiçbir değişiklik yapılmaz.
  @override
  Future<PansiyonActivationResult?> openPansiyonFile(String filePath) async {
    final selectedPath = filePath.trim();
    if (selectedPath.isEmpty) {
      return null;
    }

    try {
      return await _activate(selectedPath, kind: PansiyonActivationKind.opened);
    } on PansiyonFileValidationException catch (error) {
      throw PansiyonActivationException(
        _validationMessage(error.issue),
        cause: error,
      );
    } on PansiyonFileException catch (error) {
      throw PansiyonActivationException(
        'Seçtiğiniz pansiyon dosyası açılamadı. Lütfen tekrar deneyin.',
        cause: error,
      );
    } catch (error) {
      throw PansiyonActivationException(
        'Seçtiğiniz pansiyon dosyası açılamadı. Lütfen tekrar deneyin.',
        cause: error,
      );
    }
  }

  Future<PansiyonActivationResult> _activate(
    String filePath, {
    required PansiyonActivationKind kind,
    Future<void> Function(PansiyonDatabaseSession session)? prepare,
  }) async {
    PansiyonDatabaseSession? stagingSession;
    try {
      if (prepare != null) {
        // openSession doğrulamayı yapar; bilgiler yazılmadan önce hedef dosya
        // açılır, eski veritabanı bu noktada hiç kapatılmaz.
        stagingSession = await fileService.openSession(filePath);
        await prepare(stagingSession);
        await stagingSession.close();
        stagingSession = null;
      }

      // Bilgiler yazıldıktan sonra dosya yeniden doğrulanır. Eski sürümlü
      // dosyalar da kabul edilir; yükseltme açılışta yapılır.
      final validated = await _validateForActivation(filePath);

      // Aktif bağlantı güvenli şekilde değiştirilir. Hata olursa eski veritabanı
      // geri açılır ve switchToPath hata yeniden fırlatır.
      await session.switchToPath(filePath);

      return PansiyonActivationResult(
        filePath: filePath,
        kind: kind,
        pansiyonName: validated.pansiyonName,
      );
    } finally {
      await stagingSession?.close();
    }
  }

  Future<PansiyonFileInfo> _validateForActivation(String filePath) {
    return fileService.validateFile(filePath, requireCurrentVersion: false);
  }

  String _validationMessage(PansiyonFileIssue issue) {
    switch (issue) {
      case PansiyonFileIssue.missingFile:
        return 'Seçtiğiniz pansiyon dosyası bulunamadı.';
      case PansiyonFileIssue.unsupportedVersion:
        return 'Bu pansiyon dosyası uygulamadan daha yeni bir sürümde '
            'oluşturulmuş. Uygulamayı güncelleyin.';
      case PansiyonFileIssue.missingTables:
      case PansiyonFileIssue.integrityCheckFailed:
      case PansiyonFileIssue.invalidHeader:
      case PansiyonFileIssue.unknown:
        return 'Seçtiğiniz pansiyon dosyası geçerli değil veya bozulmuş olabilir.';
    }
  }
}
