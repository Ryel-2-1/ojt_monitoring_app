import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import 'edit_geofence_screen.dart';
import 'evaluate_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isGeneratingCode = false;

  static const Color _blue = Color(0xFF0D4DB3);
  static const Color _navy = Color(0xFF081F5C);
  static const Color _green = Color(0xFF14A44D);
  static const Color _orange = Color(0xFFF5A623);
  static const Color _red = Color(0xFFC62828);

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _pageBackground =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF4F7F9);
  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF111827) : Colors.white;
  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFD);
  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE7ECF3);
  Color get _titleColor => _isDarkMode ? Colors.white : const Color(0xFF0A2351);
  Color get _bodyColor =>
      _isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF7A8494);

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

    return AnimatedBuilder(
      animation: services.themeController,
      builder: (context, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: _pageBackground,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 18),
              _buildEnrollmentCodeCard(supervisorUid),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: userRepo.streamInternUsers(
                    supervisorUid: supervisorUid,
                    includeUnassigned: false,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _blue),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildCenteredMessage(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load students',
                        message:
                            'Please check Firestore permissions and try again.',
                        color: _red,
                      );
                    }

                    final users = snapshot.data ?? [];
                    final filteredUsers = users.where(_matchesSearch).toList();

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildStudentListCard(filteredUsers)),
                        const SizedBox(width: 16),
                        _buildSummaryPanel(
                          totalStudents: filteredUsers.length,
                          assignedCount:
                              filteredUsers.where(_hasGeofence).length,
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

  bool _matchesSearch(UserModel user) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    return user.fullName.toLowerCase().contains(q) ||
        user.email.toLowerCase().contains(q) ||
        user.uid.toLowerCase().contains(q) ||
        (user.companyName ?? '').toLowerCase().contains(q) ||
        (user.companyAddress ?? '').toLowerCase().contains(q);
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 440,
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: _titleColor,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search students by name, email, UID, or company...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: _mutedColor,
            ),
            prefixIcon: Icon(Icons.search, color: _mutedColor, size: 20),
            filled: true,
            fillColor: _cardColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue, width: 1.3),
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
            fontWeight: FontWeight.w900,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manage students who joined your supervisor group, assign their partner company, geofence, OJT hours, and internship dates.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: _mutedColor,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _blue, width: 2),
            ),
          ),
          child: Text(
            'Students',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _blue,
            ),
          ),
        ),
      ],
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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              _buildIconBox(Icons.vpn_key_outlined, _blue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervisor Enrollment Code',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCode
                          ? 'Give this code to interns. Once they enter it on mobile, they will appear in your student list.'
                          : 'Generate a code and give it to interns so they can join your OJT supervisor group.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _mutedColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _softCardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Text(
                    hasCode ? code : 'NO CODE YET',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _blue,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (hasCode)
                  IconButton(
                    tooltip: 'Copy code',
                    color: _isDarkMode ? Colors.white70 : const Color(0xFF1C2434),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enrollment code copied: $code'),
                          backgroundColor: _blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ElevatedButton.icon(
                  onPressed: _isGeneratingCode
                      ? null
                      : () => _handleGenerateEnrollmentCode(supervisorUid),
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
                    backgroundColor: _blue,
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
            ],
          ),
        );
      },
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
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isGeneratingCode = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _red,
        ),
      );
    }
  }

  Widget _buildStudentListCard(List<UserModel> users) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
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
                  color: _titleColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${users.length} record(s)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _isDarkMode ? const Color(0xFF93C5FD) : _blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: users.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildStudentCard(users[index]),
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
        ? 'Hours not set'
        : '$requiredOjtHours hrs required';

    final geofenceText = hasGeofence
        ? '${(user.allowedRadius ?? 0).toStringAsFixed(0)}m radius'
        : 'No geofence';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
                child: Text(
                  initials,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _isDarkMode ? const Color(0xFF93C5FD) : _blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: _titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge('INTERN'),
                        const SizedBox(width: 8),
                        _buildStatusBadge(
                          _assignmentStatusLabel(user),
                          user.hasActiveEnrollment ? _green : _orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: _mutedColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'UID: ${_shortUid(user.uid)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: _mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCompactInfoChip(
                icon: Icons.person_pin_outlined,
                label: 'Supervisor',
                value: supervisor,
              ),
              _buildCompactInfoChip(
                icon: Icons.business_outlined,
                label: 'Company',
                value: company,
              ),
              _buildCompactInfoChip(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: address,
              ),
              _buildCompactInfoChip(
                icon: Icons.radar_outlined,
                label: 'Geofence',
                value: geofenceText,
              ),
              _buildCompactInfoChip(
                icon: Icons.timer_outlined,
                label: 'OJT Hours',
                value: requiredHours,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditGeofenceScreen(userUid: user.uid),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                    label: Text(
                      hasGeofence ? 'Edit Assignment' : 'Assign OJT Details',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isDarkMode ? const Color(0xFF93C5FD) : _blue,
                      side: BorderSide(
                        color: _isDarkMode ? const Color(0xFF60A5FA) : _blue,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildEvaluateButton(user)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluateButton(UserModel user) {
    final requiredHours = user.requiredOjtHours ?? 0;

    return FutureBuilder<List<AttendanceModel>>(
      future: AppServices.of(
        context,
      ).attendanceRepository.getAttendanceByStudent(user.uid),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final completedHours = isLoading
            ? 0.0
            : _calculateCompletedHours(snapshot.data ?? []);

        final canEvaluate = requiredHours > 0 && completedHours >= requiredHours;

        final completedText = isLoading
            ? 'Checking hours...'
            : '${completedHours.toStringAsFixed(1)} / $requiredHours hrs';

        final label = isLoading
            ? 'Checking Hours'
            : canEvaluate
                ? 'Evaluate Student'
                : 'Evaluation Locked';

        return Tooltip(
          message: canEvaluate
              ? 'Student has completed the required OJT hours.'
              : requiredHours <= 0
                  ? 'Required OJT hours are not set.'
                  : 'Evaluation unlocks once total hours reach $requiredHours.',
          child: SizedBox(
            height: 42,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !canEvaluate || isLoading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EvaluateScreen(
                            intern: user,
                            completedHours: completedHours,
                            requiredHours: requiredHours,
                          ),
                        ),
                      );
                    },
              icon: Icon(
                canEvaluate
                    ? Icons.assignment_outlined
                    : Icons.lock_outline_rounded,
                size: 16,
              ),
              label: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    completedText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canEvaluate ? _navy : Colors.grey[300],
                foregroundColor: canEvaluate ? Colors.white : Colors.grey[600],
                disabledBackgroundColor: _isDarkMode
                    ? const Color(0xFF374151)
                    : Colors.grey[300],
                disabledForegroundColor: _isDarkMode
                    ? const Color(0xFF9CA3AF)
                    : Colors.grey[600],
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateCompletedHours(List<AttendanceModel> logs) {
    final sorted = [...logs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalHours = 0;
    DateTime? lastClockIn;

    for (final log in sorted) {
      if (log.status == AttendanceStatus.clockIn) {
        lastClockIn = log.timestamp;
      } else if (log.status == AttendanceStatus.clockOut && lastClockIn != null) {
        totalHours += log.timestamp.difference(lastClockIn).inMinutes / 60.0;
        lastClockIn = null;
      }
    }

    return totalHours;
  }

  Widget _buildCompactInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 164,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _mutedColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _bodyColor,
                    height: 1.25,
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
        color: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: _isDarkMode ? const Color(0xFF93C5FD) : _blue,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
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
    final assignedPercent = totalStudents == 0 ? 0.0 : assignedCount / totalStudents;

    return SizedBox(
      width: 240,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildSummaryCard(
              icon: Icons.groups_2_outlined,
              label: 'TOTAL STUDENTS',
              value: '$totalStudents',
              color: _blue,
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              icon: Icons.location_on_outlined,
              label: 'ASSIGNED',
              value: '$assignedCount',
              color: _green,
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              icon: Icons.pending_actions_outlined,
              label: 'PENDING',
              value: '$pendingCount',
              color: _orange,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASSIGNMENT COVERAGE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(assignedPercent * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: assignedPercent.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFF6E92D8),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: _mutedColor,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _titleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _blue.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _blue),
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
                    color: _isDarkMode ? const Color(0xFF93C5FD) : _blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _bodyColor,
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

  Widget _buildCenteredMessage({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _mutedColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No students have joined your supervisor group yet. Generate your enrollment code and give it to your interns.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: _mutedColor,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
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
