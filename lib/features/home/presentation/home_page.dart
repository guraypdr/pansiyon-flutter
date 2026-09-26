import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/features/home/data/dashboard_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.scrollable = true,
    required this.dashboardRepository,
    this.onOpenPage,
  });

  final bool scrollable;
  final DashboardRepository dashboardRepository;
  final ValueChanged<String>? onOpenPage;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DashboardSummary? _summary;
  bool _isLoading = true;
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
                onRefresh: _load,
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                _ErrorCard(message: _errorMessage!, onRetry: _load)
              else if (_summary != null)
                _SummaryBody(summary: _summary!, onOpenPage: widget.onOpenPage),
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
    required this.onRefresh,
  });

  final DashboardSummary? summary;
  final bool isLoading;
  final VoidCallback onRefresh;

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
    final actions = IconButton(
      tooltip: 'Yenile',
      onPressed: isLoading ? null : onRefresh,
      icon: const Icon(Icons.refresh),
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
  const _SummaryBody({required this.summary, required this.onOpenPage});

  final DashboardSummary summary;
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
        if (!summary.hasBoardingInfo)
          _ActionCard(
            title: 'Pansiyon bilgileri eksik',
            message:
                'Özetin tamamlanması için Ayarlar bölümünden pansiyon '
                'bilgilerini kaydedin.',
            actionLabel: 'Ayarları Aç',
            onAction: onOpenPage == null ? null : () => onOpenPage!('settings'),
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
