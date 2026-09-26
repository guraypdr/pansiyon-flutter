import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/settings/presentation/pansiyon_ayarlari_page.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

/// Yeni pansiyon dosyası oluşturma akışı.
///
/// Hem başlangıç ekranı hem de Pansiyon Bilgileri ekranı bu görünümü
/// kullanır; dosya oluşturma mantığı yalnızca [PansiyonFileActions] içindedir.
class PansiyonCreationView extends StatefulWidget {
  const PansiyonCreationView({
    super.key,
    required this.directory,
    required this.controller,
    required this.boardingInfoRepository,
    this.onPansiyonActivated,
    this.onDirtyChanged,
    this.onCancel,
  });

  final Directory directory;
  final PansiyonFileActions controller;
  final BoardingInfoRepository boardingInfoRepository;
  final ValueChanged<PansiyonActivationResult>? onPansiyonActivated;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onCancel;

  @override
  State<PansiyonCreationView> createState() => _PansiyonCreationViewState();
}

class _PansiyonCreationViewState extends State<PansiyonCreationView> {
  late String _fileName;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _fileName = widget.controller.fileNameForPansiyon('');
  }

  Future<bool> _createPansiyon(BoardingInfoDraft draft) async {
    if (_isWorking) {
      return false;
    }
    setState(() => _isWorking = true);
    try {
      final result = await widget.controller.createPansiyonFile(
        draft: draft,
        directory: widget.directory,
      );
      if (!mounted) {
        return false;
      }
      setState(() => _isWorking = false);
      _notify(
        '${result.fileName} oluşturuldu ve açıldı.',
        AppNotificationTone.success,
      );
      widget.onPansiyonActivated?.call(result);
      return true;
    } on PansiyonActivationException catch (error) {
      if (mounted) {
        setState(() => _isWorking = false);
        _notify(error.message);
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _isWorking = false);
        _notify('Pansiyon dosyası oluşturulamadı. Lütfen tekrar deneyin.');
      }
      return false;
    }
  }

  void _notify(
    String message, [
    AppNotificationTone tone = AppNotificationTone.error,
  ]) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('pansiyon_create_back_button'),
              tooltip: 'Geri',
              onPressed: _isWorking ? null : widget.onCancel,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Yeni pansiyon oluştur',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PansiyonTargetLocationCard(
          directoryPath: widget.directory.path,
          fileName: _fileName,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PansiyonAyarlariPage(
            key: const Key('pansiyon_create_form'),
            repository: widget.boardingInfoRepository,
            showPansiyonFileOperations: false,
            startInFormMode: true,
            onSaveDraft: _createPansiyon,
            onDirtyChanged: widget.onDirtyChanged,
            onSchoolNameChanged: (value) {
              final nextName = widget.controller.fileNameForPansiyon(value);
              if (nextName != _fileName && mounted) {
                setState(() => _fileName = nextName);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Hedef klasör ve dosya adı önizlemesi.
class PansiyonTargetLocationCard extends StatelessWidget {
  const PansiyonTargetLocationCard({
    super.key,
    required this.directoryPath,
    required this.fileName,
  });

  final String directoryPath;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.softPurple.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kaydedilecek klasör',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  directoryPath,
                  key: const Key('pansiyon_target_directory'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      fileName,
                      key: const Key('pansiyon_target_file_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
