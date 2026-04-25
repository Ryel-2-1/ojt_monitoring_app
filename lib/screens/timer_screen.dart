import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../services/location_service.dart' as app_location;

import 'timesheet_screen.dart';
import 'profile_screen.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isClockedIn = false;
  String? _statusMessage;
  String? _errorMessage;

  app_location.LocationService? _locationService;
  bool _didInit = false;

  double? _targetLat;
  double? _targetLng;
  double? _allowedRadius;

  Timer? _liveTimer;
  Duration _elapsedDuration = Duration.zero;
  DateTime? _clockInTime;

  late AnimationController _ringController;
  late Animation<double> _ringAnimation;

  StreamSubscription<Position>? _positionStreamSub;

  bool _isAutoStopping = false;
  bool _hasExitedGeofence = false;

  int? _requiredOjtHours;
  double _completedOjtHours = 0;

  int _selectedNavIndex = 1;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _ringAnimation =
        CurvedAnimation(parent: _ringController, curve: Curves.linear);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final attendanceRepo = AppServices.of(context).attendanceRepository;
    _locationService =
        app_location.LocationService(attendanceRepository: attendanceRepo);
    _initializeFlow();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _ringController.dispose();
    _positionStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeFlow() async {
    try {
      final services = AppServices.of(context);
      final uid = services.authService.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated.');

      final geofence = await services.userRepository.getGeofenceSettings(uid);
      _targetLat = geofence.latitude;
      _targetLng = geofence.longitude;
      _allowedRadius = geofence.radiusInMeters;

      final user = await services.userRepository.getUserByUid(uid);
      final allLogs =
          await services.attendanceRepository.getAttendanceByStudent(uid);

      _requiredOjtHours = user?.requiredOjtHours ?? 0;
      _completedOjtHours = _calculateCompletedHours(allLogs);

      final logs = await services.attendanceRepository.getTodayAttendance(uid);
      bool alreadyClockedIn = false;

      if (logs.isNotEmpty && logs.first.status == AttendanceStatus.clockIn) {
        alreadyClockedIn = true;
        _clockInTime = logs.first.timestamp;
        _startTimer(_clockInTime!);
        await _startLiveTracking();
      }

      if (mounted) {
        setState(() {
          _isClockedIn = alreadyClockedIn;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _showError('Failed to load. Please go back and try again.');
      }
    }
  }

  double _calculateCompletedHours(List<AttendanceModel> logs) {
    final sorted = [...logs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalHours = 0;
    DateTime? lastClockIn;

    for (final log in sorted) {
      if (log.status == AttendanceStatus.clockIn) {
        lastClockIn = log.timestamp;
      } else if (log.status == AttendanceStatus.clockOut &&
          lastClockIn != null) {
        totalHours += log.timestamp.difference(lastClockIn).inMinutes / 60.0;
        lastClockIn = null;
      }
    }

    return totalHours;
  }

  Future<void> _refreshCompletedHours() async {
    final services = AppServices.of(context);
    final uid = services.authService.currentUser?.uid;
    if (uid == null) return;

    final allLogs =
        await services.attendanceRepository.getAttendanceByStudent(uid);

    if (!mounted) return;
    setState(() {
      _completedOjtHours = _calculateCompletedHours(allLogs);
    });
  }

  void _startTimer(DateTime startTime) {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedDuration = DateTime.now().difference(startTime);
      });
    });
  }

  void _stopTimer() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _clockInTime = null;
    if (mounted) {
      setState(() {
        _elapsedDuration = Duration.zero;
      });
    }
  }

  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  Future<void> _startLiveTracking() async {
    final services = AppServices.of(context);
    final currentUser = services.authService.currentUser;
    if (currentUser == null) return;

    _hasExitedGeofence = false;
    await _positionStreamSub?.cancel();

    try {
      final firstPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await services.liveLocationRepository.upsertLiveLocation(
        uid: currentUser.uid,
        fullName: currentUser.displayName ?? 'Intern',
        email: currentUser.email ?? '',
        latitude: firstPosition.latitude,
        longitude: firstPosition.longitude,
        accuracy: firstPosition.accuracy,
        isClockedIn: true,
        lastStatus: 'Clock-In',
      );
    } catch (e) {
  debugPrint('Initial live location write failed: $e');
  if (mounted) {
    _showError('Could not start live location tracking. Please try again.');
  }
}

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      try {
        await services.liveLocationRepository.upsertLiveLocation(
          uid: currentUser.uid,
          fullName: currentUser.displayName ?? 'Intern',
          email: currentUser.email ?? '',
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          isClockedIn: true,
          lastStatus: 'Clock-In',
        );

        if (_isClockedIn &&
            !_isAutoStopping &&
            _targetLat != null &&
            _targetLng != null &&
            _allowedRadius != null) {
          final distance = _distanceMeters(
            position.latitude,
            position.longitude,
            _targetLat!,
            _targetLng!,
          );

          if (distance > _allowedRadius! && !_hasExitedGeofence) {
            _hasExitedGeofence = true;
            await _handleAutoStop(position);
          }
        }
      } catch (e) {
        debugPrint('Live tracking update failed: $e');
      }
    });
  }

  Future<void> _stopLiveTracking() async {
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }

  String _formatDuration(Duration d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(d.inHours)}:${pad(d.inMinutes.remainder(60))}:${pad(d.inSeconds.remainder(60))}';
  }

  Future<void> _handleStart() async {
    if (_isClockedIn || _targetLat == null) return;
    await _handleClockInOut(AttendanceStatus.clockIn);
  }

  Future<void> _handleStop() async {
    if (!_isClockedIn) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = 'Logging clock-out...';
    });

    try {
      final services = AppServices.of(context);
      final currentUser = services.authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated.');
      }

      await _locationService?.ensurePermissions();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await services.attendanceRepository.logAttendance(
        uid: currentUser.uid,
        status: AttendanceStatus.clockOut,
        locationCoords: GeoPoint(position.latitude, position.longitude),
      );

      await services.liveLocationRepository.upsertLiveLocation(
        uid: currentUser.uid,
        fullName: currentUser.displayName ?? 'Intern',
        email: currentUser.email ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isClockedIn: false,
        lastStatus: 'Clock-Out',
      );

      await _stopLiveTracking();
      await _refreshCompletedHours();

      if (!mounted) return;

      setState(() {
        _isClockedIn = false;
        _statusMessage = 'Clock-Out logged successfully.';
        _isLoading = false;
      });

      _stopTimer();
    } catch (e) {
      if (!mounted) return;
      _showError('Clock-out failed: $e');
    }
  }

  Future<void> _handleAutoStop(Position position) async {
    if (!_isClockedIn || _isAutoStopping) return;

    _isAutoStopping = true;

    try {
      final services = AppServices.of(context);
      final currentUser = services.authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated.');
      }

      await services.attendanceRepository.logAttendance(
        uid: currentUser.uid,
        status: AttendanceStatus.clockOut,
        locationCoords: GeoPoint(position.latitude, position.longitude),
      );

      await services.liveLocationRepository.upsertLiveLocation(
        uid: currentUser.uid,
        fullName: currentUser.displayName ?? 'Intern',
        email: currentUser.email ?? '',
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isClockedIn: false,
        lastStatus: 'Auto Clock-Out',
      );

      await _stopLiveTracking();
      await _refreshCompletedHours();

      if (!mounted) return;

      setState(() {
        _isClockedIn = false;
        _isLoading = false;
        _errorMessage = null;
        _statusMessage =
            'You exited the allowed geofence. Timer stopped automatically.';
      });

      _stopTimer();
    } catch (e) {
      if (!mounted) return;
      _showError('Automatic clock-out failed: $e');
    } finally {
      _isAutoStopping = false;
    }
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
        await _startLiveTracking();
      } else {
        _stopTimer();
      }
    } on app_location.OutsideGeofenceException catch (e) {
      if (mounted) _showError(e.toString());
    } on app_location.LocationServiceDisabledException catch (e) {
      if (mounted) _showError(e.toString());
    } on app_location.LocationPermissionDeniedException catch (e) {
      if (mounted) _showError(e.toString());
    } catch (e) {
      if (mounted) _showError('Clock action failed: $e');
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

  void _handleBottomNavTap(int index) {
  if (index == 1) return;

  switch (index) {
    case 0:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
      break;

    case 2:
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TimesheetScreen()),
        (route) => route.isFirst,
      );
      break;

    case 3:
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      break;
  }
}

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
                    _buildAssignmentCard(),
                    const SizedBox(height: 16),
                    _buildOjtHoursCard(),
                    const SizedBox(height: 20),
                    _buildTimerRing(),
                    const SizedBox(height: 24),
                    _buildActionButtons(geofenceReady),
                    const SizedBox(height: 20),
                    if (_errorMessage != null || _statusMessage != null)
                      _buildStatusBanner(),
                    _buildSpatialAwarenessCard(geofenceReady),
                    const SizedBox(height: 16),
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

  Widget _buildTopBar() {
    final services = AppServices.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF5F7FA),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF1A3A6B),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (services.authService.currentUser?.displayName ?? 'I')[0]
                    .toUpperCase(),
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
        ],
      ),
    );
  }

  Widget _buildAssignmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Color(0xFF1A3A6B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Geofence',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _targetLat != null && _targetLng != null
                      ? 'Lat ${_targetLat!.toStringAsFixed(5)}, Lng ${_targetLng!.toStringAsFixed(5)}'
                      : 'No assigned location yet',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A3A6B),
                  ),
                ),
              ],
            ),
          ),
          if (_allowedRadius != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_allowedRadius!.toStringAsFixed(0)}m radius',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOjtHoursCard() {
    final required = _requiredOjtHours ?? 0;
    final completed = _completedOjtHours;
    final remaining = math.max(0, required.toDouble() - completed);
    final progress =
        required <= 0 ? 0.0 : (completed / required).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OJT Progress',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A3A6B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  label: 'Required',
                  value: '$required hrs',
                  color: const Color(0xFF1A3A6B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  label: 'Completed',
                  value: '${completed.toStringAsFixed(1)} hrs',
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  label: 'Remaining',
                  value: '${remaining.toStringAsFixed(1)} hrs',
                  color: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: const Color(0xFFE8EDF5),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1A3A6B)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% completed',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerRing() {
    return Center(
      child: AnimatedBuilder(
        animation: _ringAnimation,
        builder: (context, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: _ringAnimation.value,
              active: _isClockedIn,
            ),
            child: SizedBox(
              width: 240,
              height: 240,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isClockedIn ? 'ON SESSION' : 'READY',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: _isClockedIn
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1A3A6B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDuration(_elapsedDuration),
                      style: GoogleFonts.dmSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons(bool geofenceReady) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_isLoading || !geofenceReady || _isClockedIn)
                  ? null
                  : _handleStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3A6B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading && !_isClockedIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Start',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: (_isLoading || !_isClockedIn) ? null : _handleStop,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: BorderSide(color: Colors.red.shade200),
                disabledForegroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isLoading && _isClockedIn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Stop',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final bool isError = _errorMessage != null;
    final Color bg =
        isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
    final Color fg =
        isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    final IconData icon =
        isError ? Icons.error_outline_rounded : Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? _statusMessage ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpatialAwarenessCard(bool geofenceReady) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF1A3A6B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spatial Awareness',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A3A6B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  geofenceReady
                      ? 'Your live device position will be compared against the assigned geofence during attendance actions.'
                      : 'A supervisor must assign a geofence before attendance actions can proceed.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
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
          final active = i == _selectedNavIndex;

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

class _RingPainter extends CustomPainter {
  final double progress;
  final bool active;

  _RingPainter({
    required this.progress,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;

    final basePaint = Paint()
      ..color = const Color(0xFFE8EDF5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = active ? const Color(0xFF2E7D32) : const Color(0xFF0D4DB3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 14, basePaint);

    final sweep = active ? (2 * math.pi * progress) : (2 * math.pi * 0.18);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 14),
      -math.pi / 2,
      sweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.active != active;
  }
}