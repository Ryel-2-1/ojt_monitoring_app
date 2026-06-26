import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/time_request_model.dart';
import '../models/user_model.dart';

import '../utils/weekly_stats_calculator.dart';
import 'profile_screen.dart';
import 'time_request_screen.dart';
import 'timer_screen.dart';
import 'timesheet_screen.dart';

class InternHomeScreen extends StatefulWidget {
  const InternHomeScreen({super.key});

  @override
  State<InternHomeScreen> createState() => _InternHomeScreenState();
}

class _InternHomeScreenState extends State<InternHomeScreen> {
  static const String _notificationDismissalsBox =
      'intern_home_notification_dismissals';

  static const Color _blue = Color(0xFF0D4DB3);

  static const Color _orange = Color(0xFFE86C3A);
  static const Color _green = Color(0xFF14A44D);
  static const Color _background = Color(0xFFF5F7FA);
  static const Color _border = Color(0xFFE5EAF3);

  WeeklyStats? _weeklyStats;
  UserModel? _profile;

  bool _isLoadingStats = true;
  String? _errorMessage;

  Duration _liveElapsed = Duration.zero;
  Duration _totalCompleted = Duration.zero;

  Timer? _elapsedTimer;
  StreamSubscription<AttendanceModel?>? _latestLogSub;
  StreamSubscription<UserModel?>? _profileSub;
  StreamSubscription<List<TimeRequestModel>>? _timeRequestsSub;

  List<TimeRequestModel> _timeRequests = [];

  Box<dynamic>? _dismissalsBox;
  Set<String> _dismissedNotificationIds = {};
  String? _currentUid;

  bool _didInit = false;
  final int _selectedNavIndex = 0;

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _pageBackground =>
      _isDarkMode ? const Color(0xFF0B1120) : _background;

  Color get _cardColor => _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

  Color get _borderColor => _isDarkMode ? const Color(0xFF243244) : _border;

  Color get _titleColor => _isDarkMode ? Colors.white : const Color(0xFF1C2434);

  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  List<_HomeNotification> get _notifications {
    final notifications = <_HomeNotification>[];

    for (final request in _timeRequests) {
      if (request.id == null || request.status == TimeRequestStatus.pending) {
        continue;
      }

      final isApproved = request.status == TimeRequestStatus.approved;
      final date = _formatDate(request.requestDate);
      final id = 'time_request_${request.id}_${request.status.name}';

      notifications.add(
        _HomeNotification(
          id: id,
          icon: isApproved
              ? Icons.check_circle_outline_rounded
              : Icons.cancel_outlined,
          color: isApproved ? _green : const Color(0xFFC62828),
          title: isApproved
              ? 'Time adjustment approved'
              : 'Time adjustment rejected',
          message: isApproved
              ? 'Your request for $date was approved and may now be reflected in your attendance records.'
              : 'Your request for $date was rejected${_remarksSuffix(request.reviewRemarks)}.',
          createdAt: request.reviewedAt ?? request.submittedAt,
        ),
      );
    }

    final requiredHours = _profile?.requiredOjtHours ?? 0;
    final completedHours = _totalCompleted.inMinutes / 60.0;

    if (requiredHours > 0 && completedHours >= requiredHours) {
      notifications.add(
        _HomeNotification(
          id: 'ojt_completed_${_profile?.uid ?? _currentUid}_$requiredHours',
          icon: Icons.emoji_events_outlined,
          color: _orange,
          title: 'OJT hours completed',
          message:
              'You have reached your required $requiredHours OJT hours. Your supervisor can now evaluate your performance.',
          createdAt: DateTime.now(),
        ),
      );
    }

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notifications
        .where((item) => !_dismissedNotificationIds.contains(item.id))
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInit) return;
    _didInit = true;

    _initialize();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _latestLogSub?.cancel();
    _profileSub?.cancel();
    _timeRequestsSub?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final services = AppServices.of(context);
    final uid = services.authService.currentUser?.uid;
    final attendanceRepo = services.attendanceRepository;

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'User not authenticated.';
        _isLoadingStats = false;
      });

      return;
    }

    _currentUid = uid;

    await _loadDismissedNotifications(uid);

    await _profileSub?.cancel();
    _profileSub = services.userRepository
        .streamUser(uid)
        .listen(
          (profile) {
            if (!mounted) return;
            setState(() => _profile = profile);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _errorMessage = 'Could not load profile details.');
          },
        );

    await _timeRequestsSub?.cancel();
    _timeRequestsSub = services.timeRequestRepository
        .streamRequestsByIntern(uid)
        .listen(
          (requests) {
            if (!mounted) return;
            setState(() => _timeRequests = requests);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _errorMessage = 'Could not load notifications.');
          },
        );

    await _refreshHomeData();

    await _latestLogSub?.cancel();
    _latestLogSub = attendanceRepo
        .watchLatestLog(uid)
        .listen(
          (latestLog) async {
            if (!mounted) return;

            _reconcileElapsedTimer(latestLog);
            await _refreshHomeData(silent: true);
          },
          onError: (_) {
            if (!mounted) return;
            setState(
              () => _errorMessage = 'Could not load live attendance status.',
            );
          },
        );
  }

  Future<void> _refreshHomeData({bool silent = false}) async {
    final services = AppServices.of(context);
    final uid = services.authService.currentUser?.uid;

    if (uid == null || uid.isEmpty) return;

    if (!silent && mounted) {
      setState(() {
        _isLoadingStats = true;
        _errorMessage = null;
      });
    }

    try {
      final attendanceRepo = services.attendanceRepository;

      final weeklyLogs = await attendanceRepo.getLogsForCurrentWeek(uid);
      final allLogs = await attendanceRepo.getAttendanceByStudent(uid);

      if (!mounted) return;

      setState(() {
        _weeklyStats = WeeklyStatsCalculator.calculate(weeklyLogs);
        _totalCompleted = _calculateCompletedDuration(allLogs);
        _isLoadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load attendance summary.';
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _loadDismissedNotifications(String uid) async {
    final box = await Hive.openBox<dynamic>(_notificationDismissalsBox);
    final rawIds = box.get(uid);

    final dismissedIds = rawIds is List
        ? rawIds.map((item) => item.toString()).toSet()
        : <String>{};

    if (!mounted) return;

    setState(() {
      _dismissalsBox = box;
      _dismissedNotificationIds = dismissedIds;
    });
  }

  Future<void> _dismissNotification(String notificationId) async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;

    final updated = {..._dismissedNotificationIds, notificationId};
    await _dismissalsBox?.put(uid, updated.toList());

    if (!mounted) return;

    setState(() => _dismissedNotificationIds = updated);
  }

  Future<void> _clearAllNotifications() async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;

    final visibleIds = _notifications
        .map((notification) => notification.id)
        .toSet();

    if (visibleIds.isEmpty) return;

    final updated = {..._dismissedNotificationIds, ...visibleIds};

    await _dismissalsBox?.put(uid, updated.toList());

    if (!mounted) return;

    setState(() => _dismissedNotificationIds = updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'All notifications cleared.',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _blue,
      ),
    );
  }

  void _reconcileElapsedTimer(AttendanceModel? latestLog) {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    if (latestLog?.status != AttendanceStatus.clockIn) {
      setState(() => _liveElapsed = Duration.zero);
      return;
    }

    void updateElapsed() {
      if (!mounted) return;

      final now = DateTime.now();
      final elapsed = now.difference(latestLog!.timestamp);

      setState(
        () => _liveElapsed = elapsed.isNegative ? Duration.zero : elapsed,
      );
    }

    updateElapsed();

    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateElapsed(),
    );
  }

  Duration _calculateCompletedDuration(List<AttendanceModel> logs) {
    final sorted = [...logs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    Duration total = Duration.zero;
    DateTime? lastClockIn;

    for (final log in sorted) {
      if (log.status == AttendanceStatus.clockIn) {
        lastClockIn = log.timestamp;
      } else if (log.status == AttendanceStatus.clockOut &&
          lastClockIn != null) {
        final sessionDuration = log.timestamp.difference(lastClockIn);
        if (!sessionDuration.isNegative) {
          total += sessionDuration;
        }
        lastClockIn = null;
      }
    }

    return total;
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
  Navigator.of(context).pushAndRemoveUntil(
    _noTransitionRoute(const ProfileScreen()),
    (route) => route.isFirst,
  );
  break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);

    return AnimatedBuilder(
      animation: services.themeController,
      builder: (context, _) {
        final currentUser = services.authService.currentUser;
        final authName = currentUser?.displayName?.trim();
        final name = _profile?.fullName.trim().isNotEmpty == true
            ? _profile!.fullName.trim()
            : (authName?.isNotEmpty == true ? authName! : 'Intern');

        return Scaffold(
          backgroundColor: _pageBackground,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: _blue,
                    onRefresh: () => _refreshHomeData(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _buildWelcomeHeader(name),
                        const SizedBox(height: 16),
                        if (_errorMessage != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 12),
                        ],
                        if (_notifications.isNotEmpty) ...[
                          _buildNotificationBanner(),
                          const SizedBox(height: 12),
                        ],
                        _buildOjtProgressCard(),
                        const SizedBox(height: 12),
                        _buildAssignedLocationCard(),
                        const SizedBox(height: 12),
                        _buildStatsRow(),
                        const SizedBox(height: 18),
                        _buildGoToTimerButton(),
                        const SizedBox(height: 10),
                        _buildRequestTimeAdjustmentButton(),
                        const SizedBox(height: 10),
                        Text(
                          'Timer access requires an assigned company geofence and active location services.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: _mutedColor,
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
      },
    );
  }

  Widget _buildTopBar() {
    final count = _notifications.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Text(
            'Internship Monitor',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _blue,
            ),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: _showNotificationSheet,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _blue,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 8,
                  top: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _cardColor, width: 1.5),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
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
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: _mutedColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationBanner() {
    final latest = _notifications.first;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _showNotificationSheet,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: latest.color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: latest.color.withValues(alpha: _isDarkMode ? 0.34 : 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(latest.icon, color: latest.color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                latest.title,
                style: GoogleFonts.dmSans(
                  color: _titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '${_notifications.length} new',
              style: GoogleFonts.dmSans(
                color: latest.color,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOjtProgressCard() {
    final requiredHours = _profile?.requiredOjtHours ?? 0;
    final completedHours = _totalCompleted.inMinutes / 60.0;
    final remainingHours = requiredHours > 0
        ? (requiredHours - completedHours).clamp(0.0, double.infinity)
        : 0.0;
    final progress = requiredHours > 0
        ? (completedHours / requiredHours).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconBox(Icons.timeline_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OJT Progress',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _titleColor,
                  ),
                ),
              ),
              Text(
                requiredHours > 0
                    ? '${(progress * 100).toStringAsFixed(0)}%'
                    : 'Setup needed',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: requiredHours > 0 ? _blue : _orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: _isDarkMode
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFE8EEF8),
              valueColor: const AlwaysStoppedAnimation<Color>(_blue),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  label: 'Completed',
                  value: _formatHours(completedHours),
                ),
              ),
              Expanded(
                child: _buildMiniMetric(
                  label: 'Required',
                  value: requiredHours > 0 ? '${requiredHours}h' : 'Not set',
                ),
              ),
              Expanded(
                child: _buildMiniMetric(
                  label: 'Remaining',
                  value: requiredHours > 0
                      ? _formatHours(remainingHours)
                      : 'Not set',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedLocationCard() {
    final profile = _profile;

    final hasLocation =
        profile != null &&
        profile.assignedLatitude != null &&
        profile.assignedLongitude != null &&
        profile.allowedRadius != null &&
        profile.allowedRadius! > 0;

    if (!hasLocation) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            _buildIconBox(Icons.location_off_outlined, color: _orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No assigned company geofence',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ask your supervisor to assign your partner company before starting your timer.',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: _mutedColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final assignedProfile = profile!;
    final allowedRadius = assignedProfile.allowedRadius!;

    final center = LatLng(
      assignedProfile.assignedLatitude!,
      assignedProfile.assignedLongitude!,
    );

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          if (!_isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 17,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.ojt_monitoring_app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: allowedRadius,
                      useRadiusInMeter: true,
                      color: _blue.withValues(alpha: 0.14),
                      borderColor: _blue.withValues(alpha: 0.62),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'ACTIVE ZONE',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildIconBox(Icons.location_on_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignedProfile.companyName?.trim().isNotEmpty == true
                            ? assignedProfile.companyName!.trim()
                            : 'Assigned OJT Location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        assignedProfile.companyAddress?.trim().isNotEmpty ==
                                true
                            ? assignedProfile.companyAddress!.trim()
                            : '${assignedProfile.assignedLatitude!.toStringAsFixed(6)}, ${assignedProfile.assignedLongitude!.toStringAsFixed(6)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          color: _mutedColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.09),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${allowedRadius.toStringAsFixed(0)}m',
                    style: GoogleFonts.dmSans(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
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
    final weeklyValue = _isLoadingStats
        ? '—'
        : (_weeklyStats?.formattedHours ?? '0 hrs');
    final liveValue = _liveElapsed == Duration.zero
        ? 'Inactive'
        : _formatDuration(_liveElapsed);

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
            icon: Icons.timer_outlined,
            label: 'CURRENT SESSION',
            value: liveValue,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _blue),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: _mutedColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: _mutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _titleColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildIconBox(IconData icon, {Color color = _blue}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildGoToTimerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            _noTransitionRoute(const TimerScreen()),
            (route) => route.isFirst,
          );
        },
        icon: const Icon(Icons.timer_outlined, size: 18),
        label: Text(
          'Go to Timer',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestTimeAdjustmentButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(
            context,
          ).push(_noTransitionRoute(const TimeRequestScreen()));
        },
        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
        label: Text(
          'Request Time Adjustment',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          side: const BorderSide(color: _blue),
          backgroundColor: _cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF3F1111) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode ? const Color(0xFF7F1D1D) : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: _isDarkMode ? const Color(0xFFFCA5A5) : Colors.red.shade800,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.dmSans(
                color: _isDarkMode
                    ? const Color(0xFFFCA5A5)
                    : Colors.red.shade800,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <_BottomNavItem>[
      const _BottomNavItem(Icons.home_outlined, 'HOME'),
      const _BottomNavItem(Icons.timer_outlined, 'TIMER'),
      const _BottomNavItem(Icons.description_outlined, 'TIMESHEETS'),
      const _BottomNavItem(Icons.person_outline, 'PROFILE'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final active = _selectedNavIndex == index;

          return GestureDetector(
            onTap: () => _handleBottomNavTap(index),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[index].icon,
                    size: 20,
                    color: active ? _blue : _mutedColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index].label,
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

  Future<void> _showNotificationSheet() async {
    final notifications = _notifications;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.62,
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF374151)
                          : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.dmSans(
                          color: _titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      if (notifications.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            Navigator.of(sheetContext).pop();
                            await _clearAllNotifications();
                          },
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: notifications.isEmpty
                        ? _buildEmptyNotifications()
                        : ListView.separated(
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final notification = notifications[index];

                              return Dismissible(
                                key: ValueKey(notification.id),
                                direction: DismissDirection.startToEnd,
                                onDismissed: (_) =>
                                    _dismissNotification(notification.id),
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 18),
                                  decoration: BoxDecoration(
                                    color: _green,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.done_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                child: _buildNotificationTile(notification),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(_HomeNotification notification) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(notification.icon, color: notification.color, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: GoogleFonts.dmSans(
                    color: _titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: GoogleFonts.dmSans(
                    color: _mutedColor,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDateTime(notification.createdAt),
                  style: GoogleFonts.dmSans(
                    color: notification.color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: () => _dismissNotification(notification.id),
            icon: Icon(Icons.close_rounded, size: 18, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 42, color: _mutedColor),
          const SizedBox(height: 10),
          Text(
            'No notifications',
            style: GoogleFonts.dmSans(
              color: _titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Approved requests and completion alerts will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: _mutedColor, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatHours(double hours) {
    if (hours <= 0) return '0h';
    if (hours < 1) return '${(hours * 60).round()}m';

    final wholeHours = hours.floor();
    final minutes = ((hours - wholeHours) * 60).round();

    if (minutes == 0) return '${wholeHours}h';
    return '${wholeHours}h ${minutes}m';
  }

  String _formatDate(DateTime date) {
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '${_formatDate(date)} • $hour:$minute $suffix';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  String _remarksSuffix(String? remarks) {
    final value = remarks?.trim();
    if (value == null || value.isEmpty) return '';
    return ': $value';
  }
}

class _HomeNotification {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final DateTime createdAt;

  const _HomeNotification({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.createdAt,
  });
}

class _BottomNavItem {
  final IconData icon;
  final String label;

  const _BottomNavItem(this.icon, this.label);
}
