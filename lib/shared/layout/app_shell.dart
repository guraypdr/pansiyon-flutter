import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/core/database/app_database.dart';
import 'package:pansiyon_yonetim/core/theme/app_theme.dart';
import 'package:pansiyon_yonetim/features/boarding_info/data/boarding_info_repository.dart';
import 'package:pansiyon_yonetim/features/boarding_info/presentation/boarding_info_page.dart';
import 'package:pansiyon_yonetim/features/home/presentation/home_page.dart';
import 'package:pansiyon_yonetim/shared/layout/app_sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedMenuId = 'dashboard';
  late final BoardingInfoRepository _boardingInfoRepository;

  @override
  void initState() {
    super.initState();
    _boardingInfoRepository = BoardingInfoRepository(AppDatabase());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerMargin = constraints.maxWidth < 900 ? 6.0 : 16.0;
        final sidebarWidth = constraints.maxWidth < 900 ? 174.0 : 216.0;
        final sidebar = AppSidebar(
          width: sidebarWidth,
          selectedId: _selectedMenuId,
          onSelected: _selectMenu,
        );

        return Scaffold(
          backgroundColor: AppColors.appBackground,
          body: Stack(
            children: [
              const Positioned(
                left: 44,
                top: -56,
                child: _BackdropCircle(size: 132),
              ),
              const Positioned(
                right: 52,
                top: 18,
                child: _BackdropCircle(size: 38),
              ),
              const Positioned(
                left: 72,
                bottom: -62,
                child: _BackdropCircle(size: 118),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(outerMargin),
                  child: DecoratedBox(
                    key: const Key('app_frame'),
                    decoration: BoxDecoration(
                      color: AppColors.sidebar,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.sidebar, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sidebar.withValues(alpha: 0.22),
                          blurRadius: 34,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          sidebar,
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: ClipRRect(
                                key: const Key('content_area'),
                                borderRadius: BorderRadius.circular(20),
                                child: ColoredBox(
                                  color: AppColors.surface,
                                  child: _buildContentArea(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectMenu(String menuId) {
    if (_selectedMenuId == menuId) {
      return;
    }

    setState(() => _selectedMenuId = menuId);
  }

  Widget _buildContentArea() {
    return Column(
      children: [
        _PageTopBar(
          key: const Key('top_bar'),
          title: _currentPageTitle,
          icon: _currentPageIcon,
        ),
        Expanded(child: _buildMainPage()),
      ],
    );
  }

  String get _currentPageTitle {
    switch (_selectedMenuId) {
      case 'boarding-info':
        return 'Pansiyon Bilgileri';
      case 'courses':
        return 'Öğrenciler';
      case 'messages':
        return 'Belltmenler';
      case 'friends':
        return 'Nöbetler';
      case 'schedule':
        return 'Odalar';
      case 'study':
        return 'Etüt Salonları';
      case 'attendance':
        return 'Yoklama';
      case 'permissions':
        return 'İzinler';
      case 'reports':
        return 'Raporlar';
      case 'settings':
        return 'Ayarlar';
      default:
        return 'Ana Sayfa';
    }
  }

  IconData get _currentPageIcon {
    switch (_selectedMenuId) {
      case 'boarding-info':
        return Icons.apartment_rounded;
      case 'courses':
        return Icons.school_outlined;
      case 'messages':
        return Icons.badge_outlined;
      case 'friends':
        return Icons.event_available_outlined;
      case 'schedule':
        return Icons.meeting_room_outlined;
      case 'study':
        return Icons.menu_book_outlined;
      case 'attendance':
        return Icons.fact_check_outlined;
      case 'permissions':
        return Icons.how_to_reg_outlined;
      case 'reports':
        return Icons.bar_chart_outlined;
      case 'settings':
        return Icons.settings_outlined;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Widget _buildMainPage() {
    switch (_selectedMenuId) {
      case 'boarding-info':
        return PansiyonBilgileriPage(repository: _boardingInfoRepository);
      case 'courses':
        return const _ModulePlaceholder(
          title: 'Öğrenciler',
          icon: Icons.school_outlined,
        );
      case 'schedule':
        return const _ModulePlaceholder(
          title: 'Odalar',
          icon: Icons.meeting_room_outlined,
        );
      default:
        return const HomePage();
    }
  }
}

class _PageTopBar extends StatelessWidget {
  const _PageTopBar({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('top_bar_surface'),
      height: 50,
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.softPurple.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.softPurple, AppColors.softMagenta],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bu modül henüz geliştirilmemiştir.',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bu alan yalnızca navigasyon düzenini göstermektedir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
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

class _BackdropCircle extends StatelessWidget {
  const _BackdropCircle({required this.size});

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
