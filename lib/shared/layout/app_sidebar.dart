import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.width,
    required this.selectedId,
    required this.onSelected,
  });

  final double width;
  final String selectedId;
  final ValueChanged<String> onSelected;

  static const _primaryItems = [
    _SidebarItemData(
      id: 'dashboard',
      label: 'Ana Sayfa',
      icon: Icons.grid_view_rounded,
      enabled: true,
    ),
    _SidebarItemData(
      id: 'boarding-info',
      label: 'Pansiyon Bilgileri',
      icon: Icons.apartment_rounded,
      enabled: true,
    ),
    _SidebarItemData(
      id: 'courses',
      label: 'Öğrenciler',
      icon: Icons.people_outline,
      enabled: true,
    ),
    _SidebarItemData(
      id: 'messages',
      label: 'Belltmenler',
      icon: Icons.badge_outlined,
    ),
    _SidebarItemData(
      id: 'friends',
      label: 'Nöbetler',
      icon: Icons.event_available_outlined,
    ),
    _SidebarItemData(
      id: 'schedule',
      label: 'Odalar',
      icon: Icons.meeting_room_outlined,
      enabled: true,
    ),
    _SidebarItemData(
      id: 'study',
      label: 'Etüt Salonları',
      icon: Icons.menu_book_outlined,
    ),
    _SidebarItemData(
      id: 'attendance',
      label: 'Yoklama',
      icon: Icons.fact_check_outlined,
    ),
    _SidebarItemData(
      id: 'permissions',
      label: 'İzinler',
      icon: Icons.how_to_reg_outlined,
    ),
  ];

  static const _bottomItems = [
    _SidebarItemData(
      id: 'reports',
      label: 'Raporlar',
      icon: Icons.bar_chart_outlined,
    ),
    _SidebarItemData(
      id: 'settings',
      label: 'Ayarlar',
      icon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sidebar_surface'),
      width: width,
      color: AppColors.sidebar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 28, 14, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Pansiyon Yönetimi',
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in _primaryItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _SidebarItem(
                          key: Key('sidebar_item_${item.id}'),
                          data: item,
                          selected: item.id == selectedId,
                          onSelected: onSelected,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final item in _bottomItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _SidebarItem(
                  key: Key('sidebar_item_${item.id}'),
                  data: item,
                  selected: false,
                  onSelected: onSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    super.key,
    required this.data,
    required this.selected,
    required this.onSelected,
  });

  final _SidebarItemData data;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.selected
        ? AppColors.sidebarActive
        : _hovered
        ? AppColors.sidebarHover
        : AppColors.transparent;
    final foregroundColor = widget.selected
        ? AppColors.surface
        : _hovered
        ? AppColors.darkText
        : AppColors.softPurple;

    return Semantics(
      button: widget.data.enabled,
      selected: widget.selected,
      label: widget.data.label,
      child: MouseRegion(
        cursor: widget.data.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: widget.data.enabled
                ? () => widget.onSelected(widget.data.id)
                : null,
            borderRadius: BorderRadius.circular(14),
            splashColor: AppColors.surface.withValues(alpha: 0.08),
            hoverColor: AppColors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: widget.selected
                    ? const Border(
                        left: BorderSide(color: AppColors.surface, width: 4),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(widget.data.icon, color: foregroundColor, size: 21),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      widget.data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 13.5,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
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

class _SidebarItemData {
  const _SidebarItemData({
    required this.id,
    required this.label,
    required this.icon,
    this.enabled = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool enabled;
}
