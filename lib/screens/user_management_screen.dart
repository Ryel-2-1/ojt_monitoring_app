import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_model.dart';
import 'edit_geofence_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isGeneratingCode = false;

  static const Color _primary = Color(0xFF0D4DB3);
  static const Color _darkBlue = Color(0xFF0A2351);
  static const Color _navy = Color(0xFF081F5C);
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _border = Color(0xFFE7ECF3);
  static const Color _success = Color(0xFF14A44D);
  static const Color _warning = Color(0xFFF5A623);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final userRepo = services.userRepository;
    final supervisorUid = services.authService.currentUser?.uid;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1050;
        final pagePadding = constraints.maxWidth < 850 ? 18.0 : 28.0;

        return Padding(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isCompact: isCompact),
              const SizedBox(height: 16),
              _buildEnrollmentCodeCard(supervisorUid),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: userRepo.streamInternUsers(
                    supervisorUid: supervisorUid,
                    includeUnassigned: false,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _primary),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildCenteredMessage(
                        'Error loading users. Please check permissions and try again.',
                        color: Colors.red,
                      );
                    }

                    final users = snapshot.data ?? [];
                    final filteredUsers = _filterUsers(users);
                    final assignedCount = filteredUsers
                        .where(_hasGeofence)
                        .length;

                    if (isCompact) {
                      return Column(
                        children: [
                          _buildCompactStatsRow(
                            totalStudents: filteredUsers.length,
                            assignedCount: assignedCount,
                          ),
                          const SizedBox(height: 14),
                          Expanded(child: _buildStudentListCard(filteredUsers)),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildStudentListCard(filteredUsers)),
                        const SizedBox(width: 18),
                        _buildSummaryPanel(
                          totalStudents: filteredUsers.length,
                          assignedCount: assignedCount,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return users;

    return users.where((user) {
      return user.fullName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q) ||
          user.uid.toLowerCase().contains(q) ||
          (user.companyName ?? '').toLowerCase().contains(q) ||
          (user.supervisorName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildHeader({required bool isCompact}) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: GoogleFonts.plusJakartaSans(
            fontSize: isCompact ? 24 : 30,
            fontWeight: FontWeight.w900,
            color: _darkBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage joined interns, assignments, geofence settings, and OJT requirements.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.35,
          ),
        ),
      ],
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [titleBlock, const SizedBox(height: 14), _buildSearchBar()],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: titleBlock),
        const SizedBox(width: 18),
        SizedBox(width: 430, child: _buildSearchBar()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search name, email, UID, company...',
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: Colors.grey[500],
        ),
        prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary),
        ),
      ),
    );
  }

  Widget _buildEnrollmentCodeCard(String? supervisorUid) {
    final userRepo = AppServices.of(context).userRepository;

    if (supervisorUid == null || supervisorUid.trim().isEmpty) {
      return _buildInfoBanner(
        icon: Icons.warning_amber_rounded,
        title: 'Supervisor account not detected',
        message: 'Please sign in again to generate an enrollment code.',
      );
    }

    return FutureBuilder<UserModel?>(
      future: userRepo.getUserByUid(supervisorUid),
      builder: (context, snapshot) {
        final supervisor = snapshot.data;
        final code = supervisor?.enrollmentCode;
        final hasCode = code != null && code.trim().isNotEmpty;

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            final leading = Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.vpn_key_outlined, color: _primary),
            );

            final details = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supervisor Enrollment Code',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasCode
                        ? 'Give this code to interns. Once they enter it on mobile, they will appear in your student list.'
                        : 'Generate a code and give it to interns so they can join your OJT supervisor group.',
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );

            final actions = snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: [
                      _buildEnrollmentCodeChip(hasCode ? code : 'NO CODE YET'),
                      if (hasCode)
                        IconButton.filledTonal(
                          tooltip: 'Copy code',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Enrollment code copied: $code'),
                                backgroundColor: _primary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ElevatedButton.icon(
                        onPressed: _isGeneratingCode
                            ? null
                            : () =>
                                  _handleGenerateEnrollmentCode(supervisorUid),
                        icon: _isGeneratingCode
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          hasCode ? 'Regenerate' : 'Generate Code',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  );

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            leading,
                            const SizedBox(width: 14),
                            details,
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(alignment: Alignment.centerLeft, child: actions),
                      ],
                    )
                  : Row(
                      children: [
                        leading,
                        const SizedBox(width: 14),
                        details,
                        const SizedBox(width: 16),
                        actions,
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildEnrollmentCodeChip(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Text(
        code,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: _primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Future<void> _handleGenerateEnrollmentCode(String supervisorUid) async {
    setState(() => _isGeneratingCode = true);

    try {
      final code = await AppServices.of(
        context,
      ).userRepository.generateSupervisorEnrollmentCode(supervisorUid);

      if (!mounted) return;
      setState(() => _isGeneratingCode = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrollment code generated: $code'),
          backgroundColor: _success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingCode = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  Widget _buildStudentListCard(List<UserModel> users) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Student Records',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _darkBlue,
                ),
              ),
              const Spacer(),
              _buildCountBadge('${users.length} record(s)'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: users.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildStudentCard(users[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(UserModel user) {
    final initials = _initialsOf(user.fullName);
    final hasGeofence = _hasGeofence(user);

    final company = _cleanText(
      user.companyName,
      fallback: 'No company assigned',
    );
    final address = _cleanText(
      user.companyAddress,
      fallback: 'No address assigned',
    );
    final supervisor = _cleanText(
      user.supervisorName,
      fallback: 'No supervisor joined',
    );

    final requiredOjtHours = user.requiredOjtHours ?? 0;
    final requiredHours = requiredOjtHours <= 0
        ? 'Required hours not set'
        : '$requiredOjtHours required hours';

    final geofenceText = hasGeofence
        ? '${(user.allowedRadius ?? 0).toStringAsFixed(0)}m radius'
        : 'Geofence not assigned';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final tileWidth = compact
              ? constraints.maxWidth
              : ((constraints.maxWidth - 20) / 3)
                    .clamp(180.0, 360.0)
                    .toDouble();

          return Column(
            children: [
              compact
                  ? _buildStudentHeaderCompact(user, initials)
                  : _buildStudentHeaderWide(user, initials),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _buildInfoTile(
                      icon: Icons.person_pin_outlined,
                      label: 'Supervisor',
                      value: supervisor,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildInfoTile(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: company,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildInfoTile(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: address,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildInfoTile(
                      icon: Icons.radar_outlined,
                      label: 'Geofence',
                      value: geofenceText,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _buildInfoTile(
                      icon: Icons.timer_outlined,
                      label: 'OJT Hours',
                      value: requiredHours,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              compact
                  ? Column(
                      children: [
                        _buildEditButton(user, hasGeofence),
                        const SizedBox(height: 10),
                        _buildEvaluateButton(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildEditButton(user, hasGeofence)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildEvaluateButton()),
                      ],
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentHeaderWide(UserModel user, String initials) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(initials),
        const SizedBox(width: 14),
        Expanded(child: _buildStudentIdentity(user)),
        const SizedBox(width: 14),
        _buildRoleBadge('INTERN'),
        const SizedBox(width: 10),
        _buildStatusBadge(
          _assignmentStatusLabel(user),
          user.hasActiveEnrollment ? _success : _warning,
        ),
      ],
    );
  }

  Widget _buildStudentHeaderCompact(UserModel user, String initials) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(initials),
            const SizedBox(width: 14),
            Expanded(child: _buildStudentIdentity(user)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildRoleBadge('INTERN'),
            _buildStatusBadge(
              _assignmentStatusLabel(user),
              user.hasActiveEnrollment ? _success : _warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(String initials) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFE8F0FF),
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: _primary,
        ),
      ),
    );
  }

  Widget _buildStudentIdentity(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1C2434),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'UID: ${_shortUid(user.uid)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton(UserModel user, bool hasGeofence) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EditGeofenceScreen(userUid: user.uid),
            ),
          );
        },
        icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
        label: Text(
          hasGeofence ? 'Edit Assignment' : 'Assign OJT Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEvaluateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evaluate flow not wired yet.')),
          );
        },
        icon: const Icon(Icons.assignment_outlined, size: 17),
        label: Text(
          'Evaluate Student',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C2434),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: _primary,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel({
    required int totalStudents,
    required int assignedCount,
  }) {
    final pendingCount = totalStudents - assignedCount;
    final assignedPercent = totalStudents == 0
        ? 0.0
        : assignedCount / totalStudents;

    return SizedBox(
      width: 270,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSummaryCard(
              icon: Icons.groups_2_outlined,
              label: 'TOTAL STUDENTS',
              value: '$totalStudents',
              color: _primary,
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              icon: Icons.location_on_outlined,
              label: 'ASSIGNED',
              value: '$assignedCount',
              color: _success,
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              icon: Icons.pending_actions_outlined,
              label: 'PENDING',
              value: '$pendingCount',
              color: _warning,
            ),
            const SizedBox(height: 12),
            _buildCoverageCard(assignedPercent),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStatsRow({
    required int totalStudents,
    required int assignedCount,
  }) {
    final pendingCount = totalStudents - assignedCount;
    final assignedPercent = totalStudents == 0
        ? 0.0
        : assignedCount / totalStudents;

    return Row(
      children: [
        Expanded(
          child: _buildMiniStatCard(
            label: 'Students',
            value: '$totalStudents',
            icon: Icons.groups_2_outlined,
            color: _primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            label: 'Assigned',
            value: '$assignedCount',
            icon: Icons.location_on_outlined,
            color: _success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            label: 'Pending',
            value: '$pendingCount',
            icon: Icons.pending_actions_outlined,
            color: _warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniStatCard(
            label: 'Coverage',
            value: '${(assignedPercent * 100).toStringAsFixed(0)}%',
            icon: Icons.analytics_outlined,
            color: _navy,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 82,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C2434),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[500],
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C2434),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageCard(double assignedPercent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ASSIGNMENT COVERAGE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(assignedPercent * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: assignedPercent.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFF6E92D8),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: _primary,
        ),
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E6FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF1C2434),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_add_alt_1_outlined,
              color: _primary,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'No students yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: _darkBlue,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Generate your enrollment code and give it to your interns. After they join, they will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredMessage(String message, {Color? color}) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: color ?? Colors.grey[700],
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _assignmentStatusLabel(UserModel user) {
    if (user.hasActiveEnrollment) return 'Enrolled';
    if (_hasGeofence(user)) return 'Assigned';
    if (user.hasJoinedSupervisor) return 'Joined';
    return 'Pending';
  }

  bool _hasGeofence(UserModel user) {
    return user.assignedLatitude != null &&
        user.assignedLongitude != null &&
        user.allowedRadius != null;
  }

  String _cleanText(String? value, {required String fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  String _shortUid(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 6)}...${uid.substring(uid.length - 4)}';
  }

  String _initialsOf(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
