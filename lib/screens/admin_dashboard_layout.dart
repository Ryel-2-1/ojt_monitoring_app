import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'access_control_screen.dart';

class AdminDashboardLayout extends StatefulWidget {
  final Widget child; 
  final String activeRoute; 

  const AdminDashboardLayout({
    super.key,
    required this.child,
    this.activeRoute = 'Access Control',
  });

  @override
  State<AdminDashboardLayout> createState() => _AdminDashboardLayoutState();
}

class _AdminDashboardLayoutState extends State<AdminDashboardLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: Row(
        children: [
          // LEFT SIDEBAR
          Container(
            width: 260,
            color: const Color(0xFFF0F4F8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebarHeader(),
                const SizedBox(height: 24),
                // Navigation Links
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildNavItem(Icons.radar_outlined, 'Live Monitoring'),
                      _buildNavItem(Icons.people_alt_outlined, 'Student Directory'),
                      _buildNavItem(Icons.admin_panel_settings, 'Access Control'),
                      _buildNavItem(Icons.analytics_outlined, 'Geo-Analytics'),
                      _buildNavItem(Icons.history, 'System Logs'),
                    ],
                  ),
                ),
                // Footer Links
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildFooterItem(Icons.description_outlined, 'Documentation'),
                      _buildFooterItem(Icons.help_outline, 'Support'),
                      const SizedBox(height: 16),
                      _buildUserProfile(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // MAIN CONTENT AREA (Right Side)
         Expanded(
  child: widget.child,

),
        ],
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
    final isActive = widget.activeRoute == title;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          size: 20,
          color: isActive ? const Color(0xFF0A2351) : Colors.grey[600],
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? const Color(0xFF0A2351) : Colors.grey[600],
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, size: 18, color: Colors.grey[600]),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () {},
    );
  }

  Widget _buildUserProfile() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xFF0A2351),
          child: Icon(Icons.person, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          'Admin User',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A2351),
          ),
        ),
      ],
    );
  }
}