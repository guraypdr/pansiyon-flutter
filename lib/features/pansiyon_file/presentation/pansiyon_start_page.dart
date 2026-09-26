import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/database/pansiyon_file_controller.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/data/pansiyon_file_dialogs.dart';
import 'package:pansiyon_yonetim/features/pansiyon_file/presentation/pansiyon_creation_view.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

/// Kullanılabilir bir pansiyon dosyası olmadığında gösterilen başlangıç ekranı.
///
/// Kullanıcının yalnızca iki işlemi vardır: yeni pansiyon oluşturmak veya
/// daha önce oluşturduğu bir `.pansiyon` dosyasını açmak.
class PansiyonStartPage extends StatefulWidget {
  const PansiyonStartPage({
    super.key,
    required this.controller,
    required this.boardingInfoRepository,
    this.dialogs = const FilePickerPansiyonFileDialogs(),
    this.lastFileMissing = false,
    this.onPansiyonActivated,
  });

  final PansiyonFileActions controller;
  final BoardingInfoRepository boardingInfoRepository;
  final PansiyonFileDialogs dialogs;

  /// Daha önce seçilmiş dosya bulunamadığında bilgilendirme gösterilir.
  final bool lastFileMissing;
  final ValueChanged<PansiyonActivationResult>? onPansiyonActivated;

  @override
  State<PansiyonStartPage> createState() => _PansiyonStartPageState();
}

class _PansiyonStartPageState extends State<PansiyonStartPage> {
  Directory? _saveDirectory;
  bool _isWorking = false;

  Future<void> _startCreateFlow() async {
    if (_isWorking) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      final directory = await widget.dialogs.pickSaveDirectory();
      if (!mounted) {
        return;
      }
      setState(() {
        _isWorking = false;
        if (directory != null) {
          _saveDirectory = directory;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isWorking = false);
        _notify('Kaydedilecek klasör seçilemedi.');
      }
    }
  }

  Future<void> _openExistingFile() async {
    if (_isWorking) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      final filePath = await widget.dialogs.pickPansiyonFile();
      if (!mounted) {
        return;
      }
      if (filePath == null) {
        setState(() => _isWorking = false);
        return;
      }

      final result = await widget.controller.openPansiyonFile(filePath);
      if (!mounted) {
        return;
      }
      if (result != null) {
        setState(() => _isWorking = false);
        _notify('${result.fileName} açıldı.', AppNotificationTone.success);
        widget.onPansiyonActivated?.call(result);
      } else {
        setState(() => _isWorking = false);
      }
    } on PansiyonActivationException catch (error) {
      if (mounted) {
        setState(() => _isWorking = false);
        _notify(error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isWorking = false);
        _notify('Pansiyon dosyası açılamadı. Lütfen tekrar deneyin.');
      }
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
    final directory = _saveDirectory;
    return Scaffold(
      key: const Key('pansiyon_start_page'),
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 40,
              top: -60,
              child: const _StartBackdropCircle(size: 150),
            ),
            const Positioned(
              right: 60,
              top: 40,
              child: _StartBackdropCircle(size: 46),
            ),
            if (directory == null)
              _buildWelcomeView()
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: PansiyonCreationView(
                  directory: directory,
                  controller: widget.controller,
                  boardingInfoRepository: widget.boardingInfoRepository,
                  onPansiyonActivated: widget.onPansiyonActivated,
                  onCancel: () => setState(() => _saveDirectory = null),
                ),
              ),
            if (_isWorking)
              Positioned.fill(
                child: ColoredBox(
                  key: const Key('pansiyon_start_progress'),
                  color: AppColors.appBackground.withValues(alpha: 0.72),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _WelcomeCard(
                      isBusy: _isWorking,
                      lastFileMissing: widget.lastFileMissing,
                      onCreate: _startCreateFlow,
                      onOpen: _openExistingFile,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.isBusy,
    required this.onCreate,
    required this.onOpen,
    this.lastFileMissing = false,
  });

  final bool isBusy;
  final VoidCallback onCreate;
  final VoidCallback onOpen;
  final bool lastFileMissing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardSurface, AppColors.cardSurfaceAccent],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: AppColors.surface,
              size: 30,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pansiyon Yönetimi',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz bir pansiyon oluşturulmadı.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (lastFileMissing) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('last_pansiyon_file_missing_notice'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardSurfaceAccent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Son açtığınız pansiyon dosyası bulunamadı. Dosyayı '
                      'yeniden seçebilir veya yeni bir pansiyon oluşturabilirsiniz.',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Yeni bir pansiyon dosyası oluşturabilir veya daha önce kaydettiğiniz '
            'pansiyon dosyasını açabilirsiniz.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final buttons = [
                FilledButton.icon(
                  key: const Key('new_pansiyon_button'),
                  onPressed: isBusy ? null : onCreate,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Yeni Pansiyon Oluştur'),
                ),
                OutlinedButton.icon(
                  key: const Key('open_pansiyon_file_button'),
                  onPressed: isBusy ? null : onOpen,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Pansiyon Dosyası Aç'),
                ),
              ];
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buttons[0],
                    const SizedBox(height: 12),
                    buttons[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: buttons[1]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StartBackdropCircle extends StatelessWidget {
  const _StartBackdropCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
