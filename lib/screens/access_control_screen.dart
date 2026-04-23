import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../repositories/role_repository.dart';

class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  // Default to Security Admin as per the design
  String _selectedRoleSlug = RoleRepository.roleSecurityAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Control Management',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage role-based permissions and granular feature access across the GeoAI Monitor platform.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create Role'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A2351),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const Divider(height: 48, color: Color(0xFFE9ECEF)),
          Expanded(
            child: _buildPermissionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRoleSlug,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _selectedRoleSlug = newValue);
                }
              },
              items: RoleRepository.allRoles.map((roleMap) {
                return DropdownMenuItem<String>(
                  value: roleMap['slug'],
                  child: Text('Role: ${roleMap['label']}'),
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search permissions...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF4F7F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsList() {
    final roleRepo = AppServices.of(context).roleRepository;

    return StreamBuilder<RolePermissionModel?>(
      stream: roleRepo.streamPermissions(_selectedRoleSlug),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading permissions: ${snapshot.error}'));
        }

        final permissions = snapshot.data;

        // If no permissions doc exists yet for this role, show a placeholder
        if (permissions == null) {
          return Center(
            child: Text(
              'No permissions configured for this role yet.',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
          );
        }

        return ListView(
          children: [
            _buildPermissionRow(
              icon: Icons.explore_outlined,
              title: 'Live Tracking',
              description: 'Real-time geospatial coordinate monitoring.',
              badgeText: permissions.liveTracking ? 'Full Access' : 'Restricted',
              badgeColor: permissions.liveTracking ? const Color(0xFFE3F2FD) : const Color(0xFFFFEBEE),
              badgeTextColor: permissions.liveTracking ? const Color(0xFF1565C0) : const Color(0xFFC62828),
              value: permissions.liveTracking,
              field: PermissionField.liveTracking,
            ),
            const SizedBox(height: 24),
            _buildPermissionRow(
              icon: Icons.folder_shared_outlined,
              title: 'Student Records',
              description: 'Access to historical movement data and profiles.',
              badgeText: permissions.studentRecords ? 'Read/Write' : 'Read Only',
              badgeColor: permissions.studentRecords ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
              badgeTextColor: permissions.studentRecords ? const Color(0xFF2E7D32) : Colors.grey[700]!,
              value: permissions.studentRecords,
              field: PermissionField.studentRecords,
            ),
            const SizedBox(height: 24),
            _buildPermissionRow(
              icon: Icons.gavel_outlined,
              title: 'Admin Logs',
              description: 'System-wide audit trails and configuration changes.',
              badgeText: permissions.adminLogs ? 'Full Access' : 'Restricted',
              badgeColor: permissions.adminLogs ? const Color(0xFFE3F2FD) : const Color(0xFFFFEBEE),
              badgeTextColor: permissions.adminLogs ? const Color(0xFF1565C0) : const Color(0xFFC62828),
              value: permissions.adminLogs,
              field: PermissionField.adminLogs,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required String title,
    required String description,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required bool value,
    required String field,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFF4F7F9),
          child: Icon(icon, color: const Color(0xFF0A2351), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'GRANULAR CONTROL',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Switch(
              value: value,
              activeThumbColor: const Color(0xFF0A2351),
              onChanged: (newValue) async {
                final roleRepo = AppServices.of(context).roleRepository;
                try {
                  await roleRepo.updatePermission(
                    roleSlug: _selectedRoleSlug,
                    field: field,
                    value: newValue,
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating permission: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}