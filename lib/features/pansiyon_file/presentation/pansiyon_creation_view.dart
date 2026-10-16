import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_dropdown.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_labelled_field.dart';

/// Yeni pansiyon dosyası oluşturma akışı.
///
/// Bu ekran yalnızca **dosyanın kimliğini** sorar: dosya adı, pansiyon türü
/// ve pansiyon kademesi. Okul adı, yönetici bilgileri ve bina bilgileri
/// dosya oluşturulduktan sonra Ayarlar > Pansiyon Bilgileri ekranından girilir.
class PansiyonCreationView extends StatefulWidget {
  const PansiyonCreationView({
    super.key,
    required this.directory,
    required this.controller,
    this.onPansiyonActivated,
    this.onDirtyChanged,
    this.onCancel,
  });

  final Directory directory;
  final PansiyonFileActions controller;
  final ValueChanged<PansiyonActivationResult>? onPansiyonActivated;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onCancel;

  @override
  State<PansiyonCreationView> createState() => _PansiyonCreationViewState();
}

class _PansiyonCreationViewState extends State<PansiyonCreationView> {
  late final TextEditingController _fileNameController;
  BoardingType? _boardingType;
  EducationLevel? _educationLevel;
  String? _errorText;
  bool _isWorking = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(
      text: widget.controller.fileNameForPansiyon(''),
    );
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  void _setDirty(bool value) {
    if (_isDirty == value) {
      return;
    }
    _isDirty = value;
    widget.onDirtyChanged?.call(value);
  }

  /// Dosya adı alanına göre hedef dosya adını türetir.
  String get _resolvedFileName {
    final typed = _fileNameController.text.trim();
    if (typed.isEmpty) {
      return widget.controller.fileNameForPansiyon('');
    }
    return widget.controller.fileNameForPansiyon(
      typed.replaceAll(RegExp(r'\.pansiyon$', caseSensitive: false), ''),
    );
  }

  Future<void> _createPansiyon() async {
    if (_isWorking) {
      return;
    }
    if (_boardingType == null || _educationLevel == null) {
      setState(() {
        _errorText = 'Pansiyon türü ve kademesi seçilmelidir.';
      });
      return;
    }
    if (_fileNameController.text.trim().isEmpty) {
      setState(() {
        _errorText = 'Dosya adı boş olamaz.';
      });
      return;
    }

    final fileName = _resolvedFileName;
    // Bu adımda yalnızca kimlik bilgileri yazılır; okul ve bina bilgileri
    // dosya oluşturulduktan sonra Ayarlar ekranından girilir.
    final draft = BoardingInfoDraft(
      schoolName: '',
      principalName: '',
      principalPhone: '',
      deputyName: '',
      deputyPhone: '',
      boardingType: _boardingType!,
      educationLevel: _educationLevel!,
      blocks: const [],
    );

    setState(() {
      _isWorking = true;
      _errorText = null;
    });
    try {
      final result = await widget.controller.createPansiyonFile(
        draft: draft,
        directory: widget.directory,
        fileName: fileName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isWorking = false;
        _setDirty(false);
      });
      _notify(
        '${result.fileName} oluşturuldu ve açıldı. '
        'Diğer bilgileri Ayarlar > Pansiyon Bilgileri ekranından girebilirsiniz.',
        AppNotificationTone.success,
      );
      widget.onPansiyonActivated?.call(result);
    } on PansiyonActivationException catch (error) {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _errorText = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _errorText = 'Pansiyon dosyası oluşturulamadı. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  void _notify(String message, [AppNotificationTone tone = AppNotificationTone.error]) {
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
          fileName: _resolvedFileName,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _IdentityForm(
                fileNameController: _fileNameController,
                fileNameHint: widget.controller.fileNameForPansiyon(''),
                onFileNameChanged: () {
                  setState(() => _errorText = null);
                  _setDirty(true);
                },
                boardingType: _boardingType,
                educationLevel: _educationLevel,
                errorText: _errorText,
                onBoardingTypeChanged: (value) {
                  setState(() {
                    _boardingType = value;
                    _errorText = null;
                  });
                  _setDirty(true);
                },
                onEducationLevelChanged: (value) {
                  setState(() {
                    _educationLevel = value;
                    _errorText = null;
                  });
                  _setDirty(true);
                },
                isWorking: _isWorking,
                onSubmit: _createPansiyon,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dosya adı, tür ve kademe alanlarından oluşan kimlik formu.
class _IdentityForm extends StatelessWidget {
  const _IdentityForm({
    required this.fileNameController,
    required this.fileNameHint,
    required this.onFileNameChanged,
    required this.boardingType,
    required this.educationLevel,
    required this.onBoardingTypeChanged,
    required this.onEducationLevelChanged,
    required this.isWorking,
    required this.onSubmit,
    this.errorText,
  });

  final TextEditingController fileNameController;
  final String fileNameHint;
  final VoidCallback onFileNameChanged;
  final BoardingType? boardingType;
  final EducationLevel? educationLevel;
  final ValueChanged<BoardingType?> onBoardingTypeChanged;
  final ValueChanged<EducationLevel?> onEducationLevelChanged;
  final bool isWorking;
  final VoidCallback onSubmit;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pansiyon_create_identity_form'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dosyanın kimlik bilgileri',
            style: const TextStyle(
              color: AppColors.darkText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pansiyon türü ve kademesi dosya oluşturulurken seçilir ve sonradan '
            'değiştirilemez. Farklı tür veya kademe için yeni bir pansiyon '
            'dosyası oluşturmanız gerekir.',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          AppLabelledField(
            label: 'Dosya adı',
            child: TextField(
              key: const Key('pansiyon_create_file_name_field'),
              controller: fileNameController,
              enabled: !isWorking,
              style: AppTheme.inputTextStyle,
              decoration: InputDecoration(hintText: fileNameHint),
              onChanged: (_) => onFileNameChanged(),
            ),
          ),
          const SizedBox(height: 14),
          AppDropdown<BoardingType>(
            key: const Key('pansiyon_create_boarding_type'),
            label: 'Pansiyon türü',
            value: boardingType,
            enabled: !isWorking,
            items: [
              for (final type in BoardingType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: onBoardingTypeChanged,
          ),
          const SizedBox(height: 14),
          AppDropdown<EducationLevel>(
            key: const Key('pansiyon_create_education_level'),
            label: 'Pansiyon kademesi',
            value: educationLevel,
            enabled: !isWorking,
            items: [
              for (final level in EducationLevel.values)
                DropdownMenuItem(value: level, child: Text(level.label)),
            ],
            onChanged: onEducationLevelChanged,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              errorText!,
              key: const Key('pansiyon_create_error'),
              style: const TextStyle(
                color: AppColors.errorFeedback,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('pansiyon_create_submit_button'),
            onPressed: isWorking ? null : onSubmit,
            icon: isWorking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_special_outlined),
            label: Text(isWorking ? 'Oluşturuluyor...' : 'Dosyayı Oluştur'),
          ),
          const SizedBox(height: 12),
          Text(
            'Okul adı, yönetici bilgileri ve bina bilgileri dosya oluşturulduktan '
            'sonra Ayarlar > Pansiyon Bilgileri ekranından girilir.',
            key: const Key('pansiyon_create_identity_note'),
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
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
                  style: const TextStyle(
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