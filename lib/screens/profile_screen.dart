import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_model.dart';
import 'timer_screen.dart';
import 'timesheet_screen.dart';
import '../models/attendance_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedNavIndex = 3;

  double _completedOjtHours = 0;
bool _isLoadingProgress = true;
  void _handleBottomNavTap(int index) {
    if (index == _selectedNavIndex) return;

    switch (index) {
      case 0:
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthGate()),
    (route) => false,
  );
  break;

      case 1:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TimerScreen()),
          (route) => route.isFirst,
        );
        break;

      case 2:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TimesheetScreen()),
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
    final logs = await services.attendanceRepository.getAttendanceByStudent(uid);

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
  final sorted = [...logs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

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

 Future<void> _handleSignOut() async {
  final services = AppServices.of(context);
  final currentUser = services.authService.currentUser;

  if (currentUser == null) return;

  try {
    final isClockedIn =
        await services.attendanceRepository.isCurrentlyClockedIn(
      currentUser.uid,
    );

    if (isClockedIn) {
      if (!mounted) return;

      final goToTimer = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Active session detected',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0D1B2A),
              ),
            ),
            content: Text(
              'You are currently clocked in. Please clock out first before signing out.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.45,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D4DB3),
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

      return;
    }
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not verify your session. Please try again.',
          style: GoogleFonts.dmSans(fontSize: 13),
        ),
      ),
    );

    return;
  }

  final shouldSignOut = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1B2A),
          ),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D4DB3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    },
  );

  if (shouldSignOut != true || !mounted) return;

  try {
    await services.authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to sign out. Please try again.',
          style: GoogleFonts.dmSans(fontSize: 13),
        ),
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: uid == null
            ? _buildProblemState()
            : FutureBuilder<UserModel?>(
                future: services.userRepository.getUserByUid(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D4DB3),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildProblemState();
                  }

                  final user = snapshot.data;

                  final displayName =
                      user?.fullName.trim().isNotEmpty == true
                          ? user!.fullName
                          : firebaseUser?.displayName ?? 'Intern';

                  final email = user?.email.trim().isNotEmpty == true
                      ? user!.email
                      : firebaseUser?.email ?? 'No email';

                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              Text(
                                'STUDENT IDENTITY',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0D4DB3),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                displayName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0D1B2A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildInternshipDetails(user),
                              const SizedBox(height: 18),
                              _buildProgressCard(user),
                              const SizedBox(height: 18),
                              _buildAccountCard(user),
                              const SizedBox(height: 24),
                              _buildLogoutButton(),
                            ],
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
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_outline,
            color: Color(0xFF0D4DB3),
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Profile',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D4DB3),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Account settings coming soon.',
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
              ),
            );
          },
          icon: const Icon(
            Icons.settings_outlined,
            color: Color(0xFF0D4DB3),
          ),
        ),
      ],
    );
  }

  Widget _buildInternshipDetails(UserModel? user) {
    final company = _cleanText(user?.companyName, fallback: 'Not assigned');
    final address = _cleanText(user?.companyAddress, fallback: 'No address yet');
    final radius = user?.allowedRadius == null
        ? 'No geofence radius yet'
        : '${user!.allowedRadius!.toStringAsFixed(0)} meters radius';

    final duration = _formatDuration(
      user?.internshipStartDate,
      user?.internshipEndDate,
    );

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Internship Details',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D1B2A),
            ),
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

  final progressPercent = (progress * 100).toStringAsFixed(1);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF0D4DB3),
      borderRadius: BorderRadius.circular(16),
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
              color: Colors.white.withOpacity(0.35),
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
                : Text(
                    '$progressPercent%',
                    style: GoogleFonts.dmSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          requiredHours <= 0
              ? 'Required OJT hours not set.'
              : '${completedHours.toStringAsFixed(1)} of $requiredHours hours completed',
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
                value: '${completedHours.toStringAsFixed(1)} h',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildProgressMiniStat(
                label: 'Remaining',
                value: '${remainingHours.toStringAsFixed(1)} h',
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
      color: Colors.white.withOpacity(0.12),
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
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}


  Widget _buildAccountCard(UserModel? user) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D1B2A),
            ),
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

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _handleSignOut,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Logout',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF0D4DB3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF0D1B2A),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE9EEF5)),
        ),
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
                    color:
                        active ? const Color(0xFF0D4DB3) : Colors.grey[400],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF0D4DB3)
                          : Colors.grey[400],
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