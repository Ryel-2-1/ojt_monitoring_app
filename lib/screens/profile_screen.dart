import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import 'intern_home_screen.dart';
import 'timer_screen.dart';
import 'timesheet_screen.dart';
import 'evaluation_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedNavIndex = 3;

  final TextEditingController _supervisorCodeController =
      TextEditingController();

 double _completedOjtHours = 0;
bool _isLoadingProgress = true;
bool _isJoiningSupervisor = false;

Future<UserModel?>? _profileFuture;
String? _profileFutureUid;

Future<DocumentSnapshot<Map<String, dynamic>>>? _evaluationFuture;
String? _evaluationFutureId;

  static const Color _blue = Color(0xFF0D4DB3);
  static const Color _navy = Color(0xFF0A2351);
  static const Color _red = Color(0xFFE53935);
  static const Color _green = Color(0xFF14A44D);
  static const Color _orange = Color(0xFFE86C3A);

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _background =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF5F7FA);

  Color get _cardColor => _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE6EBF2);

  Color get _titleColor => _isDarkMode ? Colors.white : const Color(0xFF0D1B2A);

  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void dispose() {
    _supervisorCodeController.dispose();
    super.dispose();
  }

  Route<T> _noTransitionRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == _selectedNavIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          _noTransitionRoute(const InternHomeScreen()),
          (route) => false,
        );
        break;

      case 1:
        Navigator.of(context).pushAndRemoveUntil(
          _noTransitionRoute(const TimerScreen()),
          (route) => route.isFirst,
        );
        break;

      case 2:
        Navigator.of(context).pushAndRemoveUntil(
          _noTransitionRoute(const TimesheetScreen()),
          (route) => route.isFirst,
        );
        break;

      case 3:
        break;
    }
  }

  Future<void> _loadCompletedHours(String uid) async {
    try {
      final services = AppServices.of(context);
      final logs = await services.attendanceRepository.getAttendanceByStudent(
        uid,
      );

      if (!mounted) return;

      setState(() {
        _completedOjtHours = _calculateCompletedHours(logs);
        _isLoadingProgress = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _completedOjtHours = 0;
        _isLoadingProgress = false;
      });
    }
  }

  double _calculateCompletedHours(List<AttendanceModel> logs) {
    final sorted = [...logs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalHours = 0;
    DateTime? lastClockIn;

    for (final log in sorted) {
      if (log.status == AttendanceStatus.clockIn) {
        lastClockIn = log.timestamp;
      } else if (log.status == AttendanceStatus.clockOut &&
          lastClockIn != null) {
        final duration = log.timestamp.difference(lastClockIn);
        if (!duration.isNegative) {
          totalHours += duration.inMinutes / 60.0;
        }
        lastClockIn = null;
      }
    }

    return totalHours;
  }

  String _formatProgressPercent(double progress) {
    final percent = (progress * 100).clamp(0.0, 100.0);

    if (percent >= 99.95) return '100%';
    if (percent % 1 == 0) return '${percent.toStringAsFixed(0)}%';

    return '${percent.toStringAsFixed(1)}%';
  }

  String _formatHourValue(double hours) {
    if (hours % 1 == 0) return hours.toStringAsFixed(0);
    return hours.toStringAsFixed(1);
  }


  Future<void> _handleJoinSupervisor() async {
    final code = _supervisorCodeController.text.trim();

    if (code.isEmpty) {
      _showSnackBar(
        'Please enter your supervisor enrollment code.',
        isError: true,
      );
      return;
    }

    setState(() => _isJoiningSupervisor = true);

    try {
      final services = AppServices.of(context);
      final uid = services.authService.currentUser?.uid;

      if (uid == null) {
        throw Exception('User not authenticated.');
      }

      await services.userRepository.joinSupervisorByCode(
        internUid: uid,
        code: code,
      );

      if (!mounted) return;

      _supervisorCodeController.clear();

      setState(() => _isJoiningSupervisor = false);

      _showSnackBar(
        'Successfully joined supervisor. Please wait for your OJT assignment.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isJoiningSupervisor = false);

      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<bool> _ensureCanSignOut() async {
    final services = AppServices.of(context);
    final currentUser = services.authService.currentUser;

    if (currentUser == null) return false;

    try {
      final isClockedIn = await services.attendanceRepository
          .isCurrentlyClockedIn(currentUser.uid);

      if (!mounted) return false;

      if (!isClockedIn) return true;

      final goToTimer = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Active session detected',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                color: _titleColor,
              ),
            ),
            content: Text(
              'You are currently clocked in. Please clock out first before signing out.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _mutedColor,
                height: 1.45,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    color: _mutedColor,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Go to Timer',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );
        },
      );

      if (goToTimer == true && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TimerScreen()),
          (route) => route.isFirst,
        );
      }

      return false;
    } catch (_) {
      if (!mounted) return false;

      _showSnackBar(
        'Could not verify your session. Please try again.',
        isError: true,
      );

      return false;
    }
  }

  Future<void> _handleSignOut() async {
    final canSignOut = await _ensureCanSignOut();
    if (!canSignOut || !mounted) return;

    final services = AppServices.of(context);
    final navigator = Navigator.of(context);

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Sign out?',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          content: Text(
            'You will be returned to the login screen.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: _mutedColor,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: _mutedColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Sign Out',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    try {
      await services.authService.signOut();

      if (!mounted) return;

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      _showSnackBar('Failed to sign out. Please try again.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? const Color(0xFFC62828) : _green,
      ),
    );
  }

  Future<void> _refreshProfileData() async {
  final uid = AppServices.of(context).authService.currentUser?.uid;

  if (uid == null || uid.trim().isEmpty) return;

  setState(() {
    _isLoadingProgress = true;
    _profileFutureUid = uid;
    _profileFuture = AppServices.of(context).userRepository.getUserByUid(uid);
    _evaluationFuture = null;
    _evaluationFutureId = null;
  });

  await _profileFuture;
  await _loadCompletedHours(uid);

  if (!mounted) return;

  setState(() {});
}
Future<UserModel?> _getProfileFuture(String uid) {
  if (_profileFutureUid != uid || _profileFuture == null) {
    _profileFutureUid = uid;
    _profileFuture = AppServices.of(context).userRepository.getUserByUid(uid);
  }

  return _profileFuture!;
}

Future<DocumentSnapshot<Map<String, dynamic>>> _getEvaluationFuture(
  String evaluationId,
) {
  if (_evaluationFutureId != evaluationId || _evaluationFuture == null) {
    _evaluationFutureId = evaluationId;
    _evaluationFuture = FirebaseFirestore.instance
        .collection('evaluations')
        .doc(evaluationId)
        .get();
  }

  return _evaluationFuture!;
}


  

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);

    return AnimatedBuilder(
      animation: services.themeController,
      builder: (context, _) {
        final firebaseUser = services.authService.currentUser;
        final uid = firebaseUser?.uid;

        if (uid != null && _isLoadingProgress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadCompletedHours(uid);
            }
          });
        }

        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: uid == null
                ? _buildProblemState()
                : FutureBuilder<UserModel?>(
                    future: _getProfileFuture(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: _blue),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildProblemState();
                      }

                      final user = snapshot.data;

                      final displayName =
                          user?.fullName.trim().isNotEmpty == true
                          ? user!.fullName.trim()
                          : firebaseUser?.displayName ?? 'Intern';

                      final email = user?.email.trim().isNotEmpty == true
                          ? user!.email.trim()
                          : firebaseUser?.email ?? 'No email';

                      return Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              color: _blue,
                              onRefresh: _refreshProfileData,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  16,
                                  18,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHeader(),
                                    const SizedBox(height: 24),
                                    _buildIdentityHeader(
                                      displayName: displayName,
                                      email: email,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSupervisorJoinCard(user),
                                    const SizedBox(height: 18),
                                    _buildInternshipDetails(user),
                                    const SizedBox(height: 18),
                                    _buildProgressCard(user),
                                    const SizedBox(height: 18),
                                    _buildFinalEvaluationCard(user),
                                    const SizedBox(height: 18),
                                    _buildAccountCard(user),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _buildBottomNav(),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _isDarkMode
                ? const Color(0xFF1E293B)
                : const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: const Icon(Icons.person_outline, color: _blue, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          'Profile',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _blue,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Settings',
          onPressed: _showSettingsSheet,
          icon: const Icon(Icons.settings_outlined, color: _blue),
        ),
      ],
    );
  }

  Widget _buildIdentityHeader({
    required String displayName,
    required String email,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STUDENT IDENTITY',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: _blue,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: _mutedColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSupervisorJoinCard(UserModel? user) {
    final hasJoinedSupervisor = user?.hasJoinedSupervisor == true;

    final supervisorName = _cleanText(
      user?.supervisorName,
      fallback: 'No supervisor assigned',
    );

    final supervisorEmail = _cleanText(
      user?.supervisorEmail,
      fallback: 'No supervisor email',
    );

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.group_add_outlined,
            title: 'Supervisor Enrollment',
          ),
          const SizedBox(height: 8),
          Text(
            hasJoinedSupervisor
                ? 'You are joined under this supervisor. Your supervisor will assign your company, geofence, required hours, and internship dates.'
                : 'Enter the enrollment code given by your supervisor to join their OJT group.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _mutedColor,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (hasJoinedSupervisor) ...[
            _buildDetailRow(
              icon: Icons.person_pin_outlined,
              label: 'Supervisor',
              value: supervisorName,
            ),
            const SizedBox(height: 14),
            _buildDetailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: supervisorEmail,
            ),
            const SizedBox(height: 14),
            _buildDetailRow(
              icon: Icons.verified_user_outlined,
              label: 'Join Status',
              value: user?.hasActiveEnrollment == true
                  ? 'Active OJT enrollment'
                  : 'Joined supervisor. Waiting for OJT assignment.',
            ),
          ] else ...[
            TextField(
              controller: _supervisorCodeController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.dmSans(
                color: _titleColor,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDecoration(
                hint: 'Example: SUP-A7K9Q2',
                icon: Icons.vpn_key_outlined,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isJoiningSupervisor ? null : _handleJoinSupervisor,
                icon: _isJoiningSupervisor
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  _isJoiningSupervisor ? 'Joining...' : 'Join Supervisor',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInternshipDetails(UserModel? user) {
    final company = _cleanText(user?.companyName, fallback: 'Not assigned');
    final address = _cleanText(
      user?.companyAddress,
      fallback: 'No address yet',
    );
    final radius = user?.allowedRadius == null
        ? 'No geofence radius yet'
        : '${user!.allowedRadius!.toStringAsFixed(0)} meters radius';

    final coordinates =
        user?.assignedLatitude == null || user?.assignedLongitude == null
        ? 'No coordinates yet'
        : '${user!.assignedLatitude!.toStringAsFixed(6)}, ${user.assignedLongitude!.toStringAsFixed(6)}';

    final duration = _formatDuration(
      user?.internshipStartDate,
      user?.internshipEndDate,
    );

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.business_center_outlined,
            title: 'Internship Details',
          ),
          const SizedBox(height: 18),
          _buildDetailRow(
            icon: Icons.business_outlined,
            label: 'Company',
            value: company,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: address,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.my_location_outlined,
            label: 'Coordinates',
            value: coordinates,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.radar_outlined,
            label: 'Geofence',
            value: radius,
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.calendar_month_outlined,
            label: 'Duration',
            value: duration,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(UserModel? user) {
    final requiredHours = user?.requiredOjtHours ?? 0;
    final completedHours = _completedOjtHours;
    final remainingHours = requiredHours <= 0
        ? 0.0
        : (requiredHours - completedHours).clamp(0.0, requiredHours.toDouble());

    final progress = requiredHours <= 0
        ? 0.0
        : (completedHours / requiredHours).clamp(0.0, 1.0);

    final progressPercent = _formatProgressPercent(progress);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: _blue.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'TOTAL PROGRESS',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 8,
              ),
            ),
            child: Center(
              child: _isLoadingProgress
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        progressPercent,
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.dmSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            requiredHours <= 0
                ? 'Required OJT hours not set.'
                : '${_formatHourValue(completedHours)} of $requiredHours hours completed',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildProgressMiniStat(
                  label: 'Required',
                  value: requiredHours <= 0 ? 'Not set' : '$requiredHours h',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProgressMiniStat(
                  label: 'Completed',
                  value: '${_formatHourValue(completedHours)} h',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProgressMiniStat(
                  label: 'Remaining',
                  value: '${_formatHourValue(remainingHours)} h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMiniStat({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalEvaluationCard(UserModel? user) {
    final uid = user?.uid;
    final supervisorUid = user?.supervisorUid;

    if (uid == null || uid.trim().isEmpty) {
      return _buildCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Final Evaluation',
            ),
            const SizedBox(height: 12),
            Text(
              'Evaluation status is not available because your account profile could not be loaded.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: _mutedColor,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (supervisorUid == null || supervisorUid.trim().isEmpty) {
      return _buildEvaluationStatusCard(
        icon: Icons.hourglass_empty_rounded,
        title: 'Final Evaluation',
        status: 'Not available yet',
        message:
            'Join a supervisor and complete your OJT requirements before your final evaluation becomes available.',
        action: null,
      );
    }

    final evaluationId = '${uid}_$supervisorUid';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('evaluations')
          .doc(evaluationId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildEvaluationStatusCard(
            icon: Icons.assignment_turned_in_outlined,
            title: 'Final Evaluation',
            status: 'Checking status...',
            message: 'Please wait while the system checks your evaluation record.',
            action: null,
          );
        }

        final data = snapshot.data?.data();
        final isSubmitted =
            data?['status']?.toString().toLowerCase() == 'submitted';

        if (!isSubmitted) {
          return _buildEvaluationStatusCard(
            icon: Icons.assignment_late_outlined,
            title: 'Final Evaluation',
            status: 'Not submitted yet',
            message:
                'Your supervisor has not submitted your final evaluation yet. It will appear here once submitted.',
            action: null,
          );
        }

        final averageRating = _toDouble(data?['averageRating']);
        final totalScore = _toInt(data?['totalScore']);
        final submittedAt = _formatSubmittedAt(data?['submittedAt']);

        return _buildEvaluationStatusCard(
          icon: Icons.verified_outlined,
          title: 'Final Evaluation',
          status: 'Submitted',
          message:
              'Average Rating: ${averageRating.toStringAsFixed(1)} / 5 • Total Score: $totalScore • Submitted: $submittedAt',
          action: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EvaluationDetailScreen(
                      evaluationId: evaluationId,
                      title: 'My Final Evaluation',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(
                'View Evaluation',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
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

  Widget _buildEvaluationStatusCard({
    required IconData icon,
    required String title,
    required String status,
    required String message,
    Widget? action,
  }) {
    final isSubmitted = status.toLowerCase() == 'submitted';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(icon: icon, title: title),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSubmitted
                  ? _green.withValues(alpha: _isDarkMode ? 0.18 : 0.10)
                  : _softCardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSubmitted
                    ? _green.withValues(alpha: _isDarkMode ? 0.35 : 0.18)
                    : _borderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isSubmitted ? _green : _titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: _mutedColor,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatSubmittedAt(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value != null) {
      date = DateTime.tryParse(value.toString());
    }

    if (date == null) return 'Not available';

    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$mm/$dd/$yyyy';
  }

  Widget _buildAccountCard(UserModel? user) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: user?.role.value ?? 'intern',
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.fingerprint_outlined,
            label: 'Account Status',
            value: 'Active',
          ),
        ],
      ),
    );
  }

  Widget _buildCardTitle({required IconData icon, required String title}) {
    return Row(
      children: [
        _buildSmallIconBox(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _titleColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSmallIconBox(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: _mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: _titleColor,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallIconBox(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Icon(icon, size: 18, color: _blue),
    );
  }

  Widget _buildProblemState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load profile. Please try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _mutedColor,
                ),
              ),
            ),
          ),
        ),
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildBottomNav() {
    final items = <(IconData, String)>[
      (Icons.home_outlined, 'HOME'),
      (Icons.timer_outlined, 'TIMER'),
      (Icons.description_outlined, 'TIMESHEETS'),
      (Icons.person_outline, 'PROFILE'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = _selectedNavIndex == i;

          return GestureDetector(
            onTap: () => _handleBottomNavTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i].$1,
                    size: 20,
                    color: active ? _blue : _mutedColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? _blue : _mutedColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

 Future<void> _showSettingsSheet() async {
  final themeController = AppServices.of(context).themeController;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      return AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          final isDark = themeController.isDarkMode;

          final sheetColor =
              isDark ? const Color(0xFF0F172A) : Colors.white;

          final dragHandleColor =
              isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);

          return SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dragHandleColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          'Settings',
                          style: GoogleFonts.dmSans(
                            color: _titleColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: _mutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildDarkModeTile(themeController),
                    const SizedBox(height: 12),
                    _buildSettingsActionTile(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      subtitle: 'Sign out from this account',
                      color: _red,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _handleSignOut();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _buildDarkModeTile(AppThemeController themeController) {
    final isDark = themeController.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          _buildSmallIconBox(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dark Mode',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _titleColor,
              ),
            ),
          ),
          Switch(
            value: isDark,
            activeColor: _blue,
            onChanged: themeController.setDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _softCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _mutedColor,
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _mutedColor),
      prefixIcon: Icon(icon, color: _blue),
      filled: true,
      fillColor: _softCardColor,
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
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
    );
  }

  String _cleanText(String? value, {required String fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Not set';

    final startText = start == null ? 'Not set' : _formatDate(start);
    final endText = end == null ? 'Not set' : _formatDate(end);

    return '$startText — $endText';
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
