import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import 'evaluation_screen.dart';
import 'geo_analytics_screen.dart';
import 'live_monitoring_screen.dart';
import 'system_logs_screen.dart';
import 'time_requests_screen.dart';
import 'user_management_screen.dart';
import 'web_login_screen.dart';

class AdminDashboardLayout extends StatefulWidget {
  final String activeRoute;
  final Widget? child;

  const AdminDashboardLayout({
    super.key,
    this.activeRoute = 'User Management',
    this.child,
  });

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  static const Color _navy = Color(0xFF0A2351);
  static const Color _blue = Color(0xFF0D4DB3);
  static const Color _background = Color(0xFFF4F7F9);
  static const Color _sidebarBackground = Color(0xFFF0F4F8);
  static const Color _border = Color(0xFFE0E6EF);

  static const Color _darkPageBackground = Color(0xFF0B1120);
  static const Color _darkSidebarBackground = Color(0xFF111827);
  static const Color _darkCard = Color(0xFF0F172A);
  static const Color _darkBorder = Color(0xFF243244);
  static const Color _darkMutedText = Color(0xFF9CA3AF);

  late String _activeRoute;

  final List<_AdminNavItem> _navItems = const [
    _AdminNavItem(
      title: 'User Management',
      icon: Icons.people_alt_outlined,
    ),
    _AdminNavItem(
      title: 'Company Registry',
      icon: Icons.business_outlined,
    ),
    _AdminNavItem(
      title: 'Live Monitoring',
      icon: Icons.radar_outlined,
    ),
    _AdminNavItem(
      title: 'Time Requests',
      icon: Icons.schedule_outlined,
    ),
    _AdminNavItem(
      title: 'Evaluations',
      icon: Icons.assignment_turned_in_outlined,
    ),
    _AdminNavItem(
      title: 'System Logs',
      icon: Icons.history_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    final isKnownRoute = _navItems.any(
      (item) => item.title == widget.activeRoute,
    );

    _activeRoute = isKnownRoute ? widget.activeRoute : 'User Management';
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppServices.of(context).themeController;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isDarkMode = themeController.isDarkMode;

        return Scaffold(
          backgroundColor: isDarkMode ? _darkPageBackground : _background,
          body: Row(
            children: [
              _buildSidebar(isDarkMode),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      '${_activeRoute}_${isDarkMode ? 'dark' : 'light'}',
                    ),
                    child: _buildCurrentPage(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(bool isDarkMode) {
    return Container(
      width: 270,
      color: isDarkMode ? _darkSidebarBackground : _sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(isDarkMode),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];

                return _buildNavItem(
                  icon: item.icon,
                  title: item.title,
                  isDarkMode: isDarkMode,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDarkModeSwitch(),
                const SizedBox(height: 12),
                _buildUserProfile(isDarkMode),
                const SizedBox(height: 12),
                _buildSignOutButton(isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    if (widget.child != null) {
      return widget.child!;
    }

    switch (_activeRoute) {
      case 'User Management':
        return const UserManagementScreen();
      case 'Company Registry':
        return const GeoAnalyticsScreen();
      case 'Live Monitoring':
        return const LiveMonitoringScreen();
      case 'Time Requests':
        return const TimeRequestsScreen();
      case 'Evaluations':
        return const EvaluationScreen();
      case 'System Logs':
        return const SystemLogsScreen();
      default:
        return const UserManagementScreen();
    }
  }

  Widget _buildSidebarHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GeoAI Portal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : _navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Supervisor Dashboard',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? _darkMutedText : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required bool isDarkMode,
  }) {
    final isActive = _activeRoute == title;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? _blue : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ListTile(
        minLeadingWidth: 24,
        horizontalTitleGap: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: Icon(
          icon,
          size: 21,
          color: isActive
              ? Colors.white
              : isDarkMode
                  ? const Color(0xFFD1D5DB)
                  : _navy,
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive
                ? Colors.white
                : isDarkMode
                    ? const Color(0xFFE5E7EB)
                    : _navy,
          ),
        ),
        onTap: () {
          if (_activeRoute == title) return;
          setState(() => _activeRoute = title);
        },
      ),
    );
  }

  Widget _buildDarkModeSwitch() {
    final themeController = AppServices.of(context).themeController;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isDarkMode = themeController.isDarkMode;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => themeController.setDarkMode(!isDarkMode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? _darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDarkMode ? _darkBorder : _border,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: isDarkMode
                        ? const Color(0xFFFACC15)
                        : const Color(0xFF0D4DB3),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dark Mode',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : _navy,
                    ),
                  ),
                ),
                _DarkModeToggle(isDarkMode: isDarkMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserProfile(bool isDarkMode) {
    final currentUser = AppServices.of(context).authService.currentUser;

    final supervisorName =
        currentUser?.displayName?.trim().isNotEmpty == true
            ? currentUser!.displayName!.trim()
            : 'Supervisor';

    final supervisorEmail = currentUser?.email ?? 'Signed in';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? _darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? _darkBorder : _border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: _blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supervisorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  supervisorEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? _darkMutedText : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _handleSignOut,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.white : const Color(0xFF1C2434),
          side: BorderSide(
            color: isDarkMode ? _darkBorder : _border,
          ),
          backgroundColor: isDarkMode ? _darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final services = AppServices.of(context);
    final authService = services.authService;
    final navigator = Navigator.of(context);
    final isDarkMode = services.themeController.isDarkMode;

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkMode ? _darkSidebarBackground : Colors.white,
          title: Text(
            'Sign out?',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: isDarkMode ? Colors.white : _navy,
            ),
          ),
          content: Text(
            'You will be returned to the supervisor login page.',
            style: GoogleFonts.plusJakartaSans(
              color: isDarkMode ? const Color(0xFFD1D5DB) : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    await authService.signOut();

    if (!mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WebLoginScreen()),
      (route) => false,
    );
  }
}

class _AdminNavItem {
  final String title;
  final IconData icon;

  const _AdminNavItem({
    required this.title,
    required this.icon,
  });
}

class _DarkModeToggle extends StatelessWidget {
  final bool isDarkMode;

  const _DarkModeToggle({
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 58,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF0D4DB3) : const Color(0xFFE5EAF3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
