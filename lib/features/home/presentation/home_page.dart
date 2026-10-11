import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/core/theme/app_tokens.dart';
import 'package:pansiyon_yonetim/features/boarding_info/domain/boarding_info_models.dart';
import 'package:pansiyon_yonetim/features/home/data/dashboard_repository.dart';
import 'package:pansiyon_yonetim/shared/widgets/app_buttons.dart';

/// Ana sayfa (pano).
///
/// Kullanıcının selamlanmaması, uygulamanın verilerinden üretilen kart
/// ızgarası gösterilir. Her kart bir modüle götürür.
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
    return Container(
      color: AppColors.appBackground,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.pageGutter),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sayfa adı ve karşılama metni gösterilmez; doğrudan
                  // filtre çubuğu ve veri kartları yer alır.
                  _FilterToolbar(
                    isLoading: _isLoading,
                    onRefresh: _load,
                  ),
                  const SizedBox(height: 16),
                  // ── Dashboard İçeriği ──
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    _ErrorCard(message: _errorMessage!, onRetry: _load)
                  else if (_summary != null)
                    _DashboardGrid(
                      summary: _summary!,
                      onOpenPage: widget.onOpenPage,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({required this.isLoading, required this.onRefresh});

  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Sol grup
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarChip(
              icon: Icons.tune_rounded,
              label: 'Filtre',
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _ToolbarChip(
              icon: Icons.calendar_today_rounded,
              label: 'Bu Ay',
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _ToolbarChip(
              icon: Icons.download_rounded,
              label: 'Dışa Aktar',
              onTap: () {},
            ),
          ],
        ),
        // Sağ grup
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarChip(
              icon: Icons.search_rounded,
              label: 'Ara',
              onTap: () {},
            ),
            const SizedBox(width: 8),
            AppIconAction(
              key: const Key('home_refresh_button'),
              icon: Icons.refresh,
              tooltip: 'Yenile',
              isLoading: isLoading,
              onPressed: onRefresh,
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolbarChip extends StatefulWidget {
  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ToolbarChip> createState() => _ToolbarChipState();
}

class _ToolbarChipState extends State<_ToolbarChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: AppColors.secondaryText),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Grid — Referans görseldeki gibi çeşitli kart tipleri
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.summary, required this.onOpenPage});

  final DashboardSummary summary;
  final ValueChanged<String>? onOpenPage;

  @override
  Widget build(BuildContext context) {
    final occupancy = (summary.occupancyRate * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        final isMedium = constraints.maxWidth >= 820;

        if (!isMedium) {
          // Dar ekran: tek sütun
          return Column(
            children: [
              _buildStudentCard(),
              const SizedBox(height: AppTokens.cardGap),
              _buildHighlightCard(),
              const SizedBox(height: AppTokens.cardGap),
              _buildOccupancyCard(occupancy),
              const SizedBox(height: AppTokens.cardGap),
              _buildCapacityCard(),
              const SizedBox(height: AppTokens.cardGap),
              _buildSchoolInfoCard(),
              const SizedBox(height: AppTokens.cardGap),
              _buildQuickLinksCard(),
              const SizedBox(height: AppTokens.cardGap),
              _buildBlockCard(),
            ],
          );
        }

        // Geniş veya orta ekran
        return Column(
          children: [
            // ── Üst satır: 4 eşit kart ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildStudentCard()),
                  const SizedBox(width: AppTokens.cardGap),
                  Expanded(
                    flex: isWide ? 1 : 1,
                    child: _buildHighlightCard(),
                  ),
                  const SizedBox(width: AppTokens.cardGap),
                  Expanded(child: _buildOccupancyCard(occupancy)),
                  if (isWide) ...[
                    const SizedBox(width: AppTokens.cardGap),
                    Expanded(child: _buildCapacityCard()),
                  ],
                ],
              ),
            ),
            if (!isWide) ...[
              const SizedBox(height: AppTokens.cardGap),
              _buildCapacityCard(),
            ],
            const SizedBox(height: AppTokens.cardGap),
            // ── Alt satır: 3 kart ──
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildSchoolInfoCard()),
                  const SizedBox(width: AppTokens.cardGap),
                  Expanded(child: _buildQuickLinksCard()),
                  const SizedBox(width: AppTokens.cardGap),
                  Expanded(child: _buildBlockCard()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Kayıtlı Öğrenci (Referanstaki "Health Report Pending" benzeri) ──
  Widget _buildStudentCard() {
    return _DashCard(
      onTap: () => _open('courses'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Öğrenci',
                  style: AppTypography.title.copyWith(fontSize: 14.5),
                ),
              ),
              _CardBadge(label: 'Rapor', onTap: () => _open('courses')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${summary.studentCount}',
                style: AppTypography.display.copyWith(fontSize: 36),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Aktif kayıt',
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mini bar grafik gösterimi
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MiniIndicator(
                color: AppColors.primary,
                label: '${summary.studentCount} Kayıtlı',
              ),
              _MiniIndicator(
                color: AppColors.lavender,
                label: '${summary.emptyBeds} Boş Yatak',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Öne Çıkan Bilgi Kartı (Referanstaki "News From The Doctor" benzeri) ──
  Widget _buildHighlightCard() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.cardPadding + 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Güncel Bilgi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Pansiyon Yönetimi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Öğrenci kayıtları, oda atamaları, yoklama ve nöbet planları '
            'tek merkezden kolayca yönetilir.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          // Dekoratif çizgi
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Doluluk Oranı (Referanstaki "Health Trend Chart" benzeri) ──
  Widget _buildOccupancyCard(int occupancy) {
    return _DashCard(
      onTap: () => _open('schedule'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Doluluk Oranı',
                  style: AppTypography.title.copyWith(fontSize: 14.5),
                ),
              ),
              Icon(
                Icons.more_horiz,
                size: 20,
                color: AppColors.secondaryText,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '%$occupancy',
                  style: AppTypography.display.copyWith(fontSize: 40),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successFeedback.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${summary.occupiedBeds}',
                      style: const TextStyle(
                        color: AppColors.successFeedback,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Mini çubuk grafiği (günler simülasyonu)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final label in ['Pzt', 'Sal', 'Çar', 'Per'])
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: (20 + (label.hashCode.abs() % 20)).toDouble(),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Kapasite Kartı (Referanstaki "Checkup Progress" benzeri) ──
  Widget _buildCapacityCard() {
    return _DashCard(
      onTap: () => _open('schedule'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Oda Kapasitesi',
                  style: AppTypography.title.copyWith(fontSize: 14.5),
                ),
              ),
              Icon(
                Icons.more_horiz,
                size: 20,
                color: AppColors.secondaryText,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressRow(
            icon: Icons.bed_outlined,
            label: 'Dolu Yatak',
            value: '${summary.occupiedBeds}',
            progress: summary.occupancyRate,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            icon: Icons.event_available_outlined,
            label: 'Boş Yatak',
            value: '${summary.emptyBeds}',
            progress: summary.totalCapacity == 0
                ? 0
                : summary.emptyBeds / summary.totalCapacity,
            color: AppColors.successFeedback,
          ),
        ],
      ),
    );
  }

  // ── Pansiyon Bilgisi Kartı (Referanstaki "Medical Information" benzeri) ──
  Widget _buildSchoolInfoCard() {
    return _DashCard(
      onTap: () => _open('settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pansiyon Bilgisi',
                  style: AppTypography.title.copyWith(fontSize: 14.5),
                ),
              ),
              _CardBadge(label: 'Detaylar', onTap: () => _open('settings')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.schoolName ?? 'Belirtilmedi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      summary.boardingType?.label ?? 'Tür seçilmedi',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InfoCell(
                  label: 'Pansiyon Türü',
                  value: summary.boardingType?.label ?? 'Belirtilmedi',
                ),
              ),
              Expanded(
                child: _InfoCell(
                  label: 'Kademe',
                  value: summary.educationLevel?.label ?? 'Belirtilmedi',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hızlı Erişim (Referanstaki "My Doctor" benzeri) ──
  Widget _buildQuickLinksCard() {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hızlı Erişim',
                  style: AppTypography.title.copyWith(fontSize: 14.5),
                ),
              ),
              _CardBadge(label: 'Tümünü Gör', onTap: () {}),
            ],
          ),
          const SizedBox(height: 16),
          _QuickLinkRow(
            icon: Icons.people_outline,
            title: 'Öğrenciler',
            subtitle: 'Öğrenci kayıtları',
            onTap: () => _open('courses'),
          ),
          const Divider(height: 16),
          _QuickLinkRow(
            icon: Icons.meeting_room_outlined,
            title: 'Odalar',
            subtitle: 'Oda ve yatak yönetimi',
            onTap: () => _open('schedule'),
          ),
          const Divider(height: 16),
          _QuickLinkRow(
            icon: Icons.fact_check_outlined,
            title: 'Yoklama',
            subtitle: 'Yoklama işlemleri',
            onTap: () => _open('attendance'),
          ),
        ],
      ),
    );
  }

  // ── Blok Bilgisi (Referanstaki "Patient Health Report" benzeri) ──
  Widget _buildBlockCard() {
    return _DashCard(
      onTap: () => _open('schedule'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Blok ve Kat',
                  style: AppTypography.title.copyWith(fontSize: 14.5),
                ),
              ),
              _CardBadge(label: 'Detaylar', onTap: () => _open('schedule')),
            ],
          ),
          const SizedBox(height: 16),
          // Mini bar grafik
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) {
              final heights = [45.0, 60.0, 35.0, 70.0, 50.0, 40.0];
              final h = heights[i];
              final isHighlighted = i == 3;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHighlighted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${summary.roomCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Container(
                    width: 28,
                    height: h,
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          // Etiketler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final l in ['Blk1', 'Blk2', 'Blk3', 'Blk4', 'Blk5', 'Blk6'])
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _open(String menuId) {
    final callback = onOpenPage;
    if (callback != null) {
      callback(menuId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yardımcı Widget'lar
// ─────────────────────────────────────────────────────────────────────────────

/// Genel dashboard kartı çerçevesi.
class _DashCard extends StatelessWidget {
  const _DashCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(color: AppColors.inputBorder),
            boxShadow: AppTokens.shadowCard,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.cardPadding + 2),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Kart üzerindeki küçük etiket butonu (Referanstaki "Report", "See Details").
class _CardBadge extends StatefulWidget {
  const _CardBadge({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CardBadge> createState() => _CardBadgeState();
}

class _CardBadgeState extends State<_CardBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini renk göstergesi (legend item).
class _MiniIndicator extends StatelessWidget {
  const _MiniIndicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Progress satırı (ikon + etiket + değer + çubuk).
class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1).toDouble(),
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Bilgi hücresi (etiket + değer).
class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
      ],
    );
  }
}

/// Hızlı erişim bağlantı satırı.
class _QuickLinkRow extends StatefulWidget {
  const _QuickLinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_QuickLinkRow> createState() => _QuickLinkRowState();
}

class _QuickLinkRowState extends State<_QuickLinkRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.softPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.secondaryText,
            ),
          ],
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.errorFeedback.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: AppColors.errorFeedback.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorFeedback),
          const SizedBox(width: AppTokens.gapSm),
          Expanded(child: Text(message)),
          AppGhostButton(label: 'Tekrar dene', onPressed: onRetry),
        ],
      ),
    );
  }
}

