// lib/screens/intern_home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';
import '../utils/weekly_stats_calculator.dart';
import 'timer_screen.dart';
import 'time_request_screen.dart';

class InternHomeScreen extends StatefulWidget {
  const InternHomeScreen({super.key});

  @override
  State<InternHomeScreen> createState() => _InternHomeScreenState();
}

class _InternHomeScreenState extends State<InternHomeScreen> {
  // ── State ──────────────────────────────────────────────────────────
  WeeklyStats? _weeklyStats;
  AttendanceModel? _latestLog;
  bool _isLoadingStats = true;
  String? _errorMessage;

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  StreamSubscription<AttendanceModel?>? _logStreamSub;
  bool _didInit = false;

  int _selectedNavIndex = 0;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _initialize();
  }

  Future<void> _initialize() async {
    final services = AppServices.of(context);
    final String? uid = services.authService.currentUser?.uid;
    final AttendanceRepository repo = services.attendanceRepository;

    if (uid == null) {
      if (mounted) setState(() { _errorMessage = 'User not authenticated.'; _isLoadingStats = false; });
      return;
    }

    await _loadWeeklyStats(uid, repo);

    await _logStreamSub?.cancel();
    _logStreamSub = repo.watchLatestLog(uid).listen(
      (log) {
        if (!mounted) return;
        setState(() => _latestLog = log);
        _reconcileElapsedTimer(log);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _errorMessage = 'Could not load live status.');
      },
    );
  }

  Future<void> _loadWeeklyStats(String uid, AttendanceRepository repo) async {
    if (mounted) setState(() { _isLoadingStats = true; _errorMessage = null; });
    try {
      final logs = await repo.getLogsForCurrentWeek(uid);
      final stats = WeeklyStatsCalculator.calculate(logs);
      if (mounted) setState(() => _weeklyStats = stats);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Could not load weekly stats.');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  void _reconcileElapsedTimer(AttendanceModel? log) {
    final bool isClockedIn = log?.status == AttendanceStatus.clockIn;
    if (isClockedIn) {
      _elapsed = DateTime.now().difference(log!.timestamp);
      _elapsedTimer?.cancel();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed = DateTime.now().difference(log.timestamp));
      });
    } else {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _logStreamSub?.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String get _formattedElapsed {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(_elapsed.inHours)}:${pad(_elapsed.inMinutes.remainder(60))}:${pad(_elapsed.inSeconds.remainder(60))}';
  }

  String _formatTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }

Future<void> _handleSignOut() async {
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
              backgroundColor: const Color(0xFF1A3A6B),
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
    await AppServices.of(context).authService.signOut();
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
  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final String name = services.authService.currentUser?.displayName ?? 'Intern';
    final String uid = services.authService.currentUser?.uid ?? '';
    final bool isClockedIn = _latestLog?.status == AttendanceStatus.clockIn;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(name, services),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF1A3A6B),
                onRefresh: () => _loadWeeklyStats(uid, services.attendanceRepository),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Welcome
                    _buildWelcomeHeader(name),
                    const SizedBox(height: 16),

                    // Error banner
                    if (_errorMessage != null) _buildErrorBanner(),

                    // Current Task Card
                    _buildCurrentTaskCard(isClockedIn),
                    const SizedBox(height: 16),

                    // Map / Zone Preview
                    _buildZonePreview(isClockedIn),
                    const SizedBox(height: 16),

                    // Weekly Stats Row
                    _buildWeeklyStats(),
                    const SizedBox(height: 20),

                    // Go to Timer CTA
                    _buildGoToTimerButton(context),
const SizedBox(height: 12),
_buildTimeRequestButton(context),
const SizedBox(height: 12),

                    // Disclaimer
                    Text(
                      'Timer access requires being within the designated Geofence. Ensure location services are active.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────

  Widget _buildTopBar(String name, AppServices services) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF5F7FA),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A6B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (services.authService.currentUser?.displayName ?? 'I')[0].toUpperCase(),
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Internship Monitor',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A3A6B),
            ),
          ),
          const Spacer(),
IconButton(
  icon: const Icon(Icons.logout_rounded, color: Color(0xFF1A3A6B)),
  onPressed: _handleSignOut,
),
        ],
      ),
    );
  }

  // ── Welcome Header ─────────────────────────────────────────────────

  Widget _buildWelcomeHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELCOME BACK',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: GoogleFonts.dmSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0D1B2A),
          ),
        ),
      ],
    );
  }

  // ── Current Task Card ──────────────────────────────────────────────

  Widget _buildCurrentTaskCard(bool isClockedIn) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tabs row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _buildTabChip('CURRENT TASK', true),
                const SizedBox(width: 8),
                _buildTabChip('LOGGED BY SUPERVISOR', false),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geospatial Data Validation',
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cross-referencing satellite imagery signatures with field metadata for the Central Valley project area. High precision required for AI model refinement.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                // Status chips
                Row(
                  children: [
                    _buildStatusChip(
                      icon: Icons.circle_outlined,
                      label: 'Not Started',
                      color: Colors.grey[600]!,
                      bg: Colors.grey[100]!,
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(
                      icon: Icons.location_off_outlined,
                      label: 'Outside Geofence',
                      color: const Color(0xFFC62828),
                      bg: const Color(0xFFFFEBEE),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8EDF7) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: active ? const Color(0xFF1A3A6B) : Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Zone Preview ───────────────────────────────────────────────────

  Widget _buildZonePreview(bool isClockedIn) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1A3A6B),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Grid pattern background
          CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _GridPainter(),
          ),
          // Active zone pulse
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4FC3F7).withOpacity(0.15),
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4FC3F7),
                  ),
                ),
              ),
            ),
          ),
          // Active Zone badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.5)),
              ),
              child: Text(
                'ACTIVE ZONE',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4FC3F7),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          // Campus label
          Positioned(
            bottom: 12,
            left: 12,
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 13, color: Color(0xFF4FC3F7)),
                const SizedBox(width: 4),
                Text(
                  'MAIN CAMPUS HUB',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Stats ───────────────────────────────────────────────────

  Widget _buildWeeklyStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time_rounded,
            label: 'WEEKLY TOTAL',
            value: _isLoadingStats ? '—' : (_weeklyStats?.formattedHours ?? '0h 0m'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline,
            label: 'APPROVAL RATE',
            value: _isLoadingStats ? '—' : (_weeklyStats?.formattedApprovalRate ?? '0.0%'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF1A3A6B)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D1B2A),
            ),
          ),
        ],
      ),
    );
  }

  // ── Go to Timer Button ─────────────────────────────────────────────

  Widget _buildGoToTimerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TimerScreen()),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          'Go to Timer',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3A6B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

Widget _buildTimeRequestButton(BuildContext context) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TimeRequestScreen()),
      ),
      icon: const Icon(Icons.edit_calendar_outlined, size: 20),
      label: Text(
        'Request Time Adjustment',
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1A3A6B),
        side: const BorderSide(color: Color(0xFF1A3A6B), width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}
  // ── Error Banner ───────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          _errorMessage!,
          style: GoogleFonts.dmSans(
            color: Colors.red.shade800,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_rounded, 'HOME'),
      (Icons.timer_outlined, 'TIMER'),
      (Icons.table_chart_outlined, 'TIMESHEETS'),
      (Icons.history_rounded, 'HISTORY'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _selectedNavIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedNavIndex = i);
                  if (i == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TimerScreen()),
                    );
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 22,
                        color: active ? const Color(0xFF1A3A6B) : Colors.grey[400],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? const Color(0xFF1A3A6B) : Colors.grey[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Grid Painter for zone preview ─────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 0.8;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}