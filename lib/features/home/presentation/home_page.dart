import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/backup/database_backup_service.dart';
import 'package:pansiyon_yonetim/features/home/data/dashboard_repository.dart';
import 'package:pansiyon_yonetim/shared/notifications/app_notifier.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.scrollable = true,
    required this.dashboardRepository,
    required this.backupService,
    this.onOpenPage,
  });

  final bool scrollable;
  final DashboardRepository dashboardRepository;
  final DatabaseBackupService backupService;
  final ValueChanged<String>? onOpenPage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DashboardSummary? _summary;
  DatabaseBackup? _latestBackup;
  bool _isLoading = true;
  bool _isWorking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final summary = await widget.dashboardRepository.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
      try {
        final backups = await widget.backupService.listBackups();
        if (!mounted) {
          return;
        }
        setState(() {
          _latestBackup = backups.isEmpty ? null : backups.first;
        });
      } catch (_) {
        if (mounted) {
          setState(() => _latestBackup = null);
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Özet bilgiler yüklenemedi.';
      });
    }
  }

  Future<void> _createBackup() async {
    if (_isWorking) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      await widget.backupService.createBackup();
      await _load();
      _notify('Veritabanı yedeği oluşturuldu.', AppNotificationTone.success);
    } catch (_) {
      _notify('Yedek oluşturulamadı.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isWorking) {
      return;
    }
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Geri yüklenecek yedek dosyası',
      type: FileType.custom,
      allowedExtensions: const ['db', 'sqlite', 'sqlite3'],
    );
    final filePath = files.isEmpty ? null : files.single.path;
    if (filePath == null || !mounted) {
      return;
    }
    setState(() => _isWorking = true);
    try {
      await widget.backupService.restoreBackup(filePath);
      await _load();
      _notify('Yedek geri yüklendi.', AppNotificationTone.success);
    } catch (_) {
      _notify('Yedek geri yüklenemedi.', AppNotificationTone.error);
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  void _notify(String message, AppNotificationTone tone) {
    if (!mounted) {
      return;
    }
    AppNotifier.instance.show(context, message: message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final page = Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(
                summary: _summary,
                isLoading: _isLoading,
                isWorking: _isWorking,
                onRefresh: _load,
                onBackup: _createBackup,
                onRestore: _restoreBackup,
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                _ErrorCard(message: _errorMessage!, onRetry: _load)
              else if (_summary != null)
                _SummaryBody(
                  summary: _summary!,
                  latestBackup: _latestBackup,
                  onOpenPage: widget.onOpenPage,
                ),
            ],
          ),
        ),
      ),
    );

    return widget.scrollable ? SingleChildScrollView(child: page) : page;
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.summary,
    required this.isLoading,
    required this.isWorking,
    required this.onRefresh,
    required this.onBackup,
    required this.onRestore,
  });

  final DashboardSummary? summary;
  final bool isLoading;
  final bool isWorking;
  final VoidCallback onRefresh;
  final VoidCallback onBackup;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final subtitle = summary?.schoolName ?? 'Pansiyon özeti yükleniyor';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ana Sayfa', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: isLoading || isWorking ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: isLoading || isWorking ? null : onBackup,
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Yedekle'),
        ),
        OutlinedButton.icon(
          onPressed: isLoading || isWorking ? null : onRestore,
          icon: const Icon(Icons.restore),
          label: const Text('Geri Yükle'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.summary,
    required this.latestBackup,
    required this.onOpenPage,
  });

  final DashboardSummary summary;
  final DatabaseBackup? latestBackup;
  final ValueChanged<String>? onOpenPage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - ((columns - 1) * 16)) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatCard(
                  width: cardWidth,
                  icon: Icons.people_outline,
                  title: 'Öğrenci',
                  value: '${summary.studentCount}',
                  description: 'Kayıtlı öğrenci sayısı',
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.bed_outlined,
                  title: 'Kapasite',
                  value: '${summary.totalCapacity}',
                  description: '${summary.roomCount} oda',
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.meeting_room_outlined,
                  title: 'Dolu Yatak',
                  value: '${summary.occupiedBeds}',
                  description:
                      'Doluluk %${(summary.occupancyRate * 100).toStringAsFixed(1)}',
                ),
                _StatCard(
                  width: cardWidth,
                  icon: Icons.event_available_outlined,
                  title: 'Boş Yatak',
                  value: '${summary.emptyBeds}',
                  description: 'Yerleştirilebilir yatak',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _BackupCard(latestBackup: latestBackup),
        const SizedBox(height: 16),
        if (!summary.hasBoardingInfo)
          _ActionCard(
            title: 'Pansiyon bilgileri eksik',
            message:
                'Özetin tamamlanması için önce pansiyon bilgilerini kaydedin.',
            actionLabel: 'Pansiyon Bilgilerini Aç',
            onAction: onOpenPage == null
                ? null
                : () => onOpenPage!('boarding-info'),
          )
        else if (summary.studentCount == 0 || summary.roomCount == 0)
          _ActionCard(
            title: 'Kayıtlar eksik',
            message:
                'Öğrenci veya oda kaydı yok. İlgili sayfadan kayıt ekleyin.',
            actionLabel: 'Öğrencileri Aç',
            onAction: onOpenPage == null ? null : () => onOpenPage!('courses'),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 18),
              Text(value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.latestBackup});

  final DatabaseBackup? latestBackup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final backup = latestBackup;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.backup_outlined, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Veri yedeği', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  backup == null
                      ? 'Henüz yedek oluşturulmadı.'
                      : 'Son yedek: ${_formatDateTime(backup.createdAt)} • ${_formatBytes(backup.sizeBytes)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(height: 10),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} $hour:$minute';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
