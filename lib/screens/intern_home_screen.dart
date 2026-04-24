import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../repositories/attendance_repository.dart';
import '../utils/weekly_stats_calculator.dart';
import 'time_request_screen.dart';
import 'timer_screen.dart';
import 'timesheet_screen.dart';

class InternHomeScreen extends StatefulWidget {
  const InternHomeScreen({super.key});

  @override
  State<InternHomeScreen> createState() => _InternHomeScreenState();
}

class _InternHomeScreenState extends State<InternHomeScreen> {
  WeeklyStats? _weeklyStats;
  AttendanceModel? _latestLog;
  bool _isLoadingStats = true;
  String? _errorMessage;

  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  StreamSubscription<AttendanceModel?>? _logStreamSub;
  bool _didInit = false;

  int _selectedNavIndex = 0;

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
      if (mounted) {
        setState(() {
          _errorMessage = 'User not authenticated.';
          _isLoadingStats = false;
        });
      }
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
    if (mounted) {
      setState(() {
        _isLoadingStats = true;
        _errorMessage = null;
      });
    }

    try {
      final logs = await repo.getLogsForCurrentWeek(uid);
      final stats = WeeklyStatsCalculator.calculate(logs);
      if (mounted) {
        setState(() => _weeklyStats = stats);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not load weekly stats.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _reconcileElapsedTimer(AttendanceModel? log) {
    final bool isClockedIn = log?.status == AttendanceStatus.clockIn;

    if (isClockedIn) {
      _elapsed = DateTime.now().difference(log!.timestamp);
      _elapsedTimer?.cancel();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed = DateTime.now().difference(log.timestamp);
        });
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

  String get _formattedElapsed {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(_elapsed.inHours)}:${pad(_elapsed.inMinutes.remainder(60))}:${pad(_elapsed.inSeconds.remainder(60))}';
  }

  void _handleBottomNavTap(int index) {
    if (index == _selectedNavIndex) return;

    setState(() => _selectedNavIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TimerScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TimesheetScreen()),
        );
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile page coming soon.',
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final String name =
        services.authService.currentUser?.displayName ?? 'Alex Chen';
    final String uid = services.authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF0D4DB3),
                onRefresh: () =>
                    _loadWeeklyStats(uid, services.attendanceRepository),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _buildWelcomeHeader(name),
                    const SizedBox(height: 18),
                    if (_errorMessage != null) _buildErrorBanner(),
                    _buildMapCard(),
                    const SizedBox(height: 12),
                    _buildStatsRow(),
                    const SizedBox(height: 18),
                    _buildGoToTimerButton(),
                    const SizedBox(height: 10),
                    _buildRequestTimeAdjustmentButton(),
                    const SizedBox(height: 10),
                    Text(
                      'Timer access requires being within the designated Geofence. Ensure location services are active.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.grey[500],
                        height: 1.45,
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

  Widget _buildTopBar() {
    final services = AppServices.of(context);
    final String letter =
        (services.authService.currentUser?.displayName ?? 'I')[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFE86C3A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                letter,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
              color: const Color(0xFF0D4DB3),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0D4DB3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELCOME BACK',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: const Color(0xFF8A97AB),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C2434),
          ),
        ),
      ],
    );
  }

  Widget _buildMapCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1C7A8B),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(double.infinity, 120),
            painter: _GridPainter(),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ACTIVE ZONE',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'MAIN CAMPUS HUB',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final weeklyValue =
        _isLoadingStats ? '—' : (_weeklyStats?.formattedHours ?? '32.5 hrs');
    final approvalValue = _isLoadingStats
        ? '—'
        : (_weeklyStats?.formattedApprovalRate ?? '98.2%');

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.access_time_rounded,
            label: 'WEEKLY TOTAL',
            value: weeklyValue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.verified_outlined,
            label: 'APPROVAL RATE',
            value: approvalValue,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D4DB3)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 22 > 18 ? 18 : 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C2434),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoToTimerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TimerScreen()),
          );
        },
        icon: const Icon(Icons.timer_outlined, size: 18),
        label: Text(
          'Go to Timer',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D4DB3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTimeAdjustmentButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TimeRequestScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D4DB3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Request Time Adjustment',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

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
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = 0.7;

    const step = 18.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}