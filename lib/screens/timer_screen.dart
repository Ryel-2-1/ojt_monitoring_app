// lib/screens/timer_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/geofence_settings.dart';
import '../services/location_service.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────

  bool _isLoading = true;
  bool _isClockedIn = false;
  String? _statusMessage;
  String? _errorMessage;

  LocationService? _locationService;
  bool _didInit = false;

  double? _targetLat;
  double? _targetLng;
  double? _allowedRadius;

  Timer? _liveTimer;
  Duration _elapsedDuration = Duration.zero;
  DateTime? _clockInTime;

  // Ring animation
  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  // ── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _ringAnimation = CurvedAnimation(parent: _ringController, curve: Curves.linear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final attendanceRepo = AppServices.of(context).attendanceRepository;
    _locationService = LocationService(attendanceRepository: attendanceRepo);
    _initializeFlow();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> _initializeFlow() async {
    try {
      final services = AppServices.of(context);
      final uid = services.authService.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated.');

      final geofence = await services.userRepository.getGeofenceSettings(uid);
      _targetLat = geofence.latitude;
      _targetLng = geofence.longitude;
      _allowedRadius = geofence.radiusInMeters;

      final logs = await services.attendanceRepository.getTodayAttendance(uid);
      bool alreadyClockedIn = false;

      if (logs.isNotEmpty && logs.first.status == AttendanceStatus.clockIn) {
        alreadyClockedIn = true;
        _clockInTime = logs.first.timestamp;
        _startTimer(_clockInTime!);
      }

      if (mounted) {
        setState(() {
          _isClockedIn = alreadyClockedIn;
          _isLoading = false;
        });
      }
    } on GeofenceNotAssignedException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Failed to load. Please go back and try again.');
    }
  }

  // ── Timer helpers ──────────────────────────────────────────────────

  void _startTimer(DateTime startTime) {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedDuration = DateTime.now().difference(startTime));
    });
  }

  void _stopTimer() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _clockInTime = null;
    if (mounted) setState(() => _elapsedDuration = Duration.zero);
  }

  String _formatDuration(Duration d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.inHours)}:${pad(d.inMinutes.remainder(60))}:${pad(d.inSeconds.remainder(60))}';
  }

  // ── Clock-In / Clock-Out ───────────────────────────────────────────

  Future<void> _handleStart() async {
    if (_isClockedIn || _targetLat == null) return;
    await _handleClockInOut(AttendanceStatus.clockIn);
  }

  Future<void> _handleStop() async {
    if (!_isClockedIn) return;
    await _handleClockInOut(AttendanceStatus.clockOut);
  }

  Future<void> _handleClockInOut(AttendanceStatus status) async {
    if (_targetLat == null || _targetLng == null) {
      _showError('Geofence configuration is missing.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Verifying location...';
    });

    try {
      final uid = AppServices.of(context).authService.currentUser!.uid;

      final DateTime confirmedAt = await _locationService!.verifyAndClockIn(
        uid: uid,
        status: status,
        targetLatitude: _targetLat!,
        targetLongitude: _targetLng!,
        radiusInMeters: _allowedRadius ?? 200.0,
      );

      if (!mounted) return;

      final bool nowClockedIn = status == AttendanceStatus.clockIn;
      final String action = nowClockedIn ? 'Clock-In' : 'Clock-Out';

      setState(() {
        _isClockedIn = nowClockedIn;
        _statusMessage = '$action logged successfully.';
        _isLoading = false;
      });

      if (nowClockedIn) {
        _clockInTime = confirmedAt;
        _startTimer(confirmedAt);
      } else {
        _stopTimer();
      }
    } on OutsideGeofenceException catch (e) {
      if (mounted) _showError(e.toString());
    } on LocationServiceDisabledException catch (e) {
      if (mounted) _showError(e.toString());
    } on LocationPermissionDeniedException catch (e) {
      if (mounted) _showError(e.toString());
    } catch (_) {
      if (mounted) _showError('An unexpected error occurred. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _statusMessage = null;
      _isLoading = false;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool geofenceReady = _targetLat != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Assignment
                    _buildAssignmentCard(),
                    const SizedBox(height: 20),

                    // Timer Ring
                    _buildTimerRing(),
                    const SizedBox(height: 24),

                    // Start / Stop buttons
                    _buildActionButtons(geofenceReady),
                    const SizedBox(height: 20),

                    // Status / Error
                    if (_errorMessage != null || _statusMessage != null)
                      _buildStatusBanner(),

                    // Spatial Awareness Card
                    _buildSpatialAwarenessCard(geofenceReady),
                    const SizedBox(height: 16),

                    // Legal note
                    Text(
                      'Logs and spatial coordinates are securely recorded server-side for institutional compliance. Tampering with session data is prohibited.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.grey[400],
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

  Widget _buildTopBar() {
    final services = AppServices.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF5F7FA),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
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
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1A3A6B)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── Assignment Card ────────────────────────────────────────────────

  Widget _buildAssignmentCard() {
    return Container(
      width: double.infinity,
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
          Text(
            'CURRENT ASSIGNMENT',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A6B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Task Name',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Geospatial Data Validation & Analysis',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D1B2A),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Timer Ring ─────────────────────────────────────────────────────

  Widget _buildTimerRing() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated rotating ring — only when clocked in
            if (_isClockedIn)
              AnimatedBuilder(
                animation: _ringAnimation,
                builder: (_, __) => CustomPaint(
                  size: const Size(200, 200),
                  painter: _RingPainter(progress: _ringAnimation.value),
                ),
              )
            else
              CustomPaint(
                size: const Size(200, 200),
                painter: _StaticRingPainter(),
              ),
            // Time display
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1A3A6B),
                    ),
                  )
                else
                  Text(
                    _formatDuration(_elapsedDuration),
                    style: GoogleFonts.dmMono(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0D1B2A),
                      letterSpacing: 1,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _isClockedIn ? 'SESSION ACTIVE' : 'SESSION INACTIVE',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _isClockedIn
                        ? const Color(0xFF1A3A6B)
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ─────────────────────────────────────────────────

  Widget _buildActionButtons(bool geofenceReady) {
    return Row(
      children: [
        // Start Session
        Expanded(
          child: GestureDetector(
            onTap: (_isLoading || _isClockedIn || !geofenceReady)
                ? null
                : _handleStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: (_isClockedIn || !geofenceReady)
                    ? Colors.grey[200]
                    : const Color(0xFF1A3A6B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: (_isClockedIn || !geofenceReady)
                        ? Colors.grey[400]
                        : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Start\nSession',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: (_isClockedIn || !geofenceReady)
                          ? Colors.grey[400]
                          : Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Stop Session
        Expanded(
          child: GestureDetector(
            onTap: (_isLoading || !_isClockedIn) ? null : _handleStop,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isClockedIn
                      ? const Color(0xFFDDE1E9)
                      : Colors.grey[200]!,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.stop_rounded,
                    size: 20,
                    color: _isClockedIn
                        ? const Color(0xFF0D1B2A)
                        : Colors.grey[300],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Stop\nSession',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isClockedIn
                          ? const Color(0xFF0D1B2A)
                          : Colors.grey[300],
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Status / Error Banner ──────────────────────────────────────────

  Widget _buildStatusBanner() {
    final bool isError = _errorMessage != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 16,
              color: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isError ? _errorMessage! : _statusMessage!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Spatial Awareness Card ─────────────────────────────────────────

  Widget _buildSpatialAwarenessCard(bool geofenceReady) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                '📍 SPATIAL AWARENESS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: geofenceReady
                      ? const Color(0xFFE8F5E9)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  geofenceReady ? 'VERIFIED' : 'PENDING',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: geofenceReady
                        ? const Color(0xFF2E7D32)
                        : Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Map thumbnail
              Container(
                width: 72,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A6B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: CustomPaint(
                  painter: _MiniGridPainter(),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4FC3F7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      geofenceReady
                          ? 'Geofence validation active. Your location is within the Technical Innovation Center designated zone.'
                          : 'No geofence assigned. Contact your supervisor to enable clock-in.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          geofenceReady
                              ? 'GPS High Precision Ready'
                              : 'GPS Ready · Geofence Pending',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
              final active = i == 1; // TIMER is active on this screen
              return GestureDetector(
                onTap: () {
                  if (i == 0) Navigator.pop(context);
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

// ── Custom Painters ────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring
    final bgPaint = Paint()
      ..color = const Color(0xFFE8EDF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, bgPaint);

    // Animated arc
    final fgPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF1A3A6B), Color(0xFF4FC3F7), Color(0xFF1A3A6B)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + (progress * 2 * math.pi),
      math.pi * 1.5,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _StaticRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final paint = Paint()
      ..color = const Color(0xFFE8EDF7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, paint);

    // Dashed accent
    final accentPaint = Paint()
      ..color = const Color(0xFFBDCBE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.4,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.8;
    const step = 10.0;
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