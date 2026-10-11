import 'package:flutter/material.dart';

import 'package:pansiyon_yonetim/core/theme/app_theme.dart';

/// Uygulamanın üst menü çubuğu.
///
/// Menüler yatay olarak sıralanır; etkin olan dolu renkli hap olarak
/// vurgulanır. Menü kimlikleri (`sidebar_item_<id>`) eski yan menüyle aynı
/// tutulur, böylece gezinme mantığı değişmez.
class AppTopNav extends StatelessWidget {
  const AppTopNav({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;

  /// Üst çubuğun toplam yüksekliği.
  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('top_nav_surface'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // ── Sol: Marka ──
          _buildBrand(),
          const SizedBox(width: 28),

          // ── Orta: Pill menüler ──
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in _primaryItems)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _NavPill(
                          key: Key('sidebar_item_${item.id}'),
                          label: item.label,
                          selected: item.id == selectedId,
                          onTap: () => onSelected(item.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),
          // ── Sağ: Ayarlar ikon + Bildirim + Profil avatarı ──
          _NavIconButton(
            key: const Key('sidebar_item_settings'),
            icon: Icons.settings_outlined,
            tooltip: 'Ayarlar',
            selected: selectedId == 'settings',
            onTap: () => onSelected('settings'),
          ),
          const SizedBox(width: 6),
          _NavIconButton(
            key: const Key('nav_notification_button'),
            icon: Icons.notifications_none_rounded,
            tooltip: 'Bildirimler',
            selected: false,
            onTap: () {},
          ),
          const SizedBox(width: 12),
          // Profil avatarı
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 2,
              ),
              color: AppColors.softPurple,
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.home_work_rounded,
            size: 18,
            color: AppColors.surface,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'PansiyonPro',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const List<_NavItemData> _primaryItems = [
  _NavItemData(
    id: 'dashboard',
    label: 'Ana Sayfa',
    icon: Icons.grid_view_rounded,
  ),
  _NavItemData(id: 'courses', label: 'Öğrenciler', icon: Icons.people_outline),
  _NavItemData(
    id: 'friends',
    label: 'Nöbetler',
    icon: Icons.event_available_outlined,
  ),
  _NavItemData(
    id: 'schedule',
    label: 'Odalar',
    icon: Icons.meeting_room_outlined,
  ),
  _NavItemData(
    id: 'study',
    label: 'Etüt Salonları',
    icon: Icons.menu_book_outlined,
  ),
  _NavItemData(
    id: 'attendance',
    label: 'Yoklama',
    icon: Icons.fact_check_outlined,
  ),
  _NavItemData(id: 'discipline', label: 'Disiplin', icon: Icons.gavel_outlined),
];

/// Üst menüde tek bir menü düğmesi (ikon olmadan hap biçiminde metin).
class _NavPill extends StatefulWidget {
  const _NavPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavPill> createState() => _NavPillState();
}

class _NavPillState extends State<_NavPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? AppColors.primary
        : _hovered
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent;
    final foreground = widget.selected ? AppColors.surface : AppColors.darkText;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: background,
        // Tam yuvarlak hap şekli.
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: widget.selected
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Üst çubuğun sağ tarafındaki ikon butonları (ayarlar, bildirim).
class _NavIconButton extends StatefulWidget {
  const _NavIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? AppColors.primary.withValues(alpha: 0.12)
        : _hovered
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent;
    final foreground = widget.selected
        ? AppColors.primary
        : AppColors.secondaryText;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(widget.icon, size: 20, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
