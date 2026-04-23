import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_model.dart';
import 'admin_dashboard_layout.dart';
import 'edit_geofence_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRepo = AppServices.of(context).userRepository;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: userRepo.streamInternUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading users: ${snapshot.error}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.red[700],
                        fontSize: 13,
                      ),
                    ),
                  );
                }

                final users = snapshot.data ?? [];
                final filteredUsers = users.where((user) {
                  final q = _searchQuery.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return user.fullName.toLowerCase().contains(q) ||
                      user.email.toLowerCase().contains(q);
                }).toList();

                return Column(
                  children: [
                    Expanded(
                      child: _buildTableCard(filteredUsers),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryCard(filteredUsers.length),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 420,
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
          decoration: InputDecoration(
            hintText: 'Search across records...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.grey[500],
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE6EBF2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE6EBF2)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A2351),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage institutional roles, student progress, and partnership access.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF0D4DB3), width: 2),
            ),
          ),
          child: Text(
            'Students',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D4DB3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCard(List<UserModel> users) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
      child: Column(
        children: [
          _buildTableHeader(),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8EDF4)),
          const SizedBox(height: 10),
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Text(
                      'No intern users found.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 20, color: Color(0xFFF0F3F8)),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildUserRow(user);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Showing 1 to ${users.length} entries',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    TextStyle headerStyle = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.grey[600],
      letterSpacing: 0.5,
    );

    return Row(
      children: [
        Expanded(flex: 4, child: Text('NAME & IDENTITY', style: headerStyle)),
        Expanded(flex: 2, child: Text('ROLE', style: headerStyle)),
        Expanded(flex: 3, child: Text('INSTITUTION/COMPANY', style: headerStyle)),
        Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
        Expanded(flex: 2, child: Text('LAST LOGIN', style: headerStyle)),
        Expanded(flex: 2, child: Text('', style: headerStyle)),
      ],
    );
  }

  Widget _buildUserRow(UserModel user) {
    final initials = _initialsOf(user.fullName);
    final bool hasGeofence = user.assignedLatitude != null &&
        user.assignedLongitude != null &&
        user.allowedRadius != null;

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  initials,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D4DB3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C2434),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildRoleBadge('INTERN'),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            hasGeofence ? 'Geofence Configured' : 'Not Assigned',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildStatusBadge(
            hasGeofence ? 'Active' : 'Pending',
            hasGeofence ? const Color(0xFF14A44D) : const Color(0xFFF5A623),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            hasGeofence ? 'Configured' : 'Never',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              SizedBox(
                width: 84,
                height: 30,
                child: ElevatedButton(
                  onPressed: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AdminDashboardLayout(
        activeRoute: 'User Management',
        child: EditGeofenceScreen(user: user),
      ),
    ),
  );
},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D4DB3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'EDIT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 84,
                height: 30,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2351),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'EVALUATE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(int totalStudents) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(18),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.groups_2_outlined,
                  color: Color(0xFF0D4DB3), size: 18),
            ),
            const SizedBox(height: 14),
            Text(
              'TOTAL ACTIVE STUDENTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalStudents',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C2434),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0D4DB3),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}