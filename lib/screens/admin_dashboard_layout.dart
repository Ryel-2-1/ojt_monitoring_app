import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'access_control_screen.dart';
import 'user_management_screen.dart';
import 'live_monitoring_screen.dart';
import 'system_logs_screen.dart';
import 'time_requests_screen.dart';
import '../main.dart';
import 'web_login_screen.dart';

class AdminDashboardLayout extends StatefulWidget {
  final String activeRoute;
  final Widget? child;

  const AdminDashboardLayout({
    super.key,
    this.activeRoute = 'Access Control',
    this.child,
  });

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  late String _activeRoute;

  @override
  void initState() {
    super.initState();
    _activeRoute = widget.activeRoute;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: Row(
        children: [
          Container(
            width: 260,
            color: const Color(0xFFF0F4F8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebarHeader(),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildNavItem(Icons.radar_outlined, 'Live Monitoring'),
                      _buildNavItem(Icons.people_alt_outlined, 'User Management'),
                      _buildNavItem(Icons.schedule_outlined, 'Time Requests'),
                      _buildNavItem(Icons.admin_panel_settings, 'Access Control'),
                      _buildNavItem(Icons.analytics_outlined, 'Geo-Analytics'),
                      _buildNavItem(Icons.history, 'System Logs'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildFooterItem(
                          Icons.description_outlined, 'Documentation'),
                      _buildFooterItem(Icons.help_outline, 'Support'),
                      const SizedBox(height: 16),
                      _buildUserProfile(),
                      const SizedBox(height: 12),
                      _buildSignOutButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildCurrentPage(),
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
      case 'Live Monitoring':
        return const LiveMonitoringScreen();
      case 'User Management':
        return const UserManagementScreen();
      case 'Time Requests':
        return const TimeRequestsScreen();
      case 'Access Control':
        return const AccessControlScreen();
      case 'Geo-Analytics':
        return _buildPlaceholderPage(
          title: 'Geo-Analytics',
          subtitle: 'This page will display geospatial analysis and insights.',
        );
      case 'System Logs':
        return const SystemLogsScreen();
      default:
        return const AccessControlScreen();
    }
  }

  Widget _buildPlaceholderPage({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize_outlined,
                  size: 42, color: Colors.grey[500]),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0A2351),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Portal',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0A2351),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GeoAI Management',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title) {
    final isActive = _activeRoute == title;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0D4DB3) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF0A2351),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF0A2351),
          ),
        ),
        onTap: () {
          setState(() => _activeRoute = title);
        },
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String title) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18, color: Colors.grey[700]),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: Colors.grey[700],
        ),
      ),
      onTap: () {},
    );
  }

  Widget _buildUserProfile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            child: Icon(Icons.person),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Supervisor',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: () async {
          await AppServices.of(context).authService.signOut();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WebLoginScreen()),
            (route) => false,
          );
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1C2434),
          side: const BorderSide(color: Color(0xFFE0E6EF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}