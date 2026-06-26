import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/time_request_model.dart';
import 'intern_home_screen.dart';
import 'profile_screen.dart';
import 'timer_screen.dart';
import 'timesheet_screen.dart';

class TimeRequestScreen extends StatefulWidget {
  const TimeRequestScreen({super.key});

  @override
  State<TimeRequestScreen> createState() => _TimeRequestScreenState();
}

class _TimeRequestScreenState extends State<TimeRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _reasonController = TextEditingController();

  DateTime? _requestDate;
  bool _isSubmitting = false;
  bool _isFormExpanded = true;
  String? _message;

  TimeRequestType _requestType = TimeRequestType.missingTime;

  bool _isLoadingSessions = false;
  List<_AttendanceSession> _sessionsForSelectedDate = [];
  _AttendanceSession? _selectedCorrectionSession;

  final int _selectedNavIndex = -1;

  static const Color _blue = Color(0xFF0D4DB3);
  static const Color _navy = Color(0xFF0A2351);
  static const Color _green = Color(0xFF14A44D);
  static const Color _red = Color(0xFFC62828);
  static const Color _orange = Color(0xFFF5A623);

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _background =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF5F7FA);

  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFD);

  Color get _inputColor =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF5F7FA);

  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE9EEF5);

  Color get _titleColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1C2434);

  Color get _headingColor => _isDarkMode ? Colors.white : _navy;

  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requestDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        if (!_isDarkMode) return child ?? const SizedBox.shrink();

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _blue,
              surface: Color(0xFF111827),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF111827),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _requestDate = picked;
      _dateController.text = _formatDate(picked);
      _selectedCorrectionSession = null;
      _sessionsForSelectedDate = [];
      _message = null;
    });

    await _loadSessionsForSelectedDate();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(controller.text) ?? TimeOfDay.now(),
      builder: (context, child) {
        if (!_isDarkMode) return child ?? const SizedBox.shrink();

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _blue,
              surface: Color(0xFF111827),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF111827),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null) return;

    controller.text = _formatTime(picked);
  }

  Future<void> _loadSessionsForSelectedDate() async {
    if (_requestDate == null) return;

    final currentUser = AppServices.of(context).authService.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoadingSessions = true;
    });

    try {
      final logs = await AppServices.of(context)
          .attendanceRepository
          .getAttendanceByStudent(currentUser.uid);

      final sessions = _buildSessionsForDate(
        logs: logs,
        date: _requestDate!,
      );

      if (!mounted) return;

      setState(() {
        _sessionsForSelectedDate = sessions;
        _isLoadingSessions = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sessionsForSelectedDate = [];
        _isLoadingSessions = false;
        _message = 'Could not load attendance sessions for this date.';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _requestDate == null) return;

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final services = AppServices.of(context);
      final currentUser = services.authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated.');
      }

      final user = await services.userRepository.getUserByUid(currentUser.uid);
      final durationError = _validateRequestDateWithinInternship(
        requestDate: _requestDate!,
        internshipStartDate: user?.internshipStartDate,
        internshipEndDate: user?.internshipEndDate,
      );

      if (durationError != null) {
        _setSubmitMessage(durationError);
        return;
      }

      final requestedStart = _combineDateAndTime(
        _requestDate!,
        _startTimeController.text.trim(),
      );

      final requestedEnd = _combineDateAndTime(
        _requestDate!,
        _endTimeController.text.trim(),
      );

      if (!requestedEnd.isAfter(requestedStart)) {
        _setSubmitMessage('End time must be after start time.');
        return;
      }

      final now = DateTime.now();

if (requestedEnd.isAfter(now)) {
  _setSubmitMessage(
    'You cannot request a time that has not happened yet.',
  );
  return;
}

      final attendanceLogs =
          await services.attendanceRepository.getAttendanceByStudent(
        currentUser.uid,
      );

      if (_requestType == TimeRequestType.correction) {
        if (_selectedCorrectionSession == null) {
          _setSubmitMessage(
            'Please select the attendance session you want to correct.',
          );
          return;
        }

        final overlappingSession = _findOverlappingAttendanceSession(
          logs: attendanceLogs,
          requestedStart: requestedStart,
          requestedEnd: requestedEnd,
          ignoredClockInLogId: _selectedCorrectionSession!.clockInLogId,
          ignoredClockOutLogId: _selectedCorrectionSession!.clockOutLogId,
        );

        if (overlappingSession != null) {
          _setSubmitMessage(
            'You already have another attendance session from '
            '${_formatTimeRange(overlappingSession.start, overlappingSession.end)}. '
            'Please choose a corrected time that does not conflict with other logs.',
          );
          return;
        }

        await services.timeRequestRepository.submitCorrectionRequest(
          internUid: currentUser.uid,
          internName: currentUser.displayName ?? 'Intern',
          internEmail: currentUser.email ?? '',
          requestDate: _requestDate!,
          requestedStartTime: _startTimeController.text.trim(),
          requestedEndTime: _endTimeController.text.trim(),
          reason: _reasonController.text.trim(),
          originalClockInLogId: _selectedCorrectionSession!.clockInLogId,
          originalClockOutLogId: _selectedCorrectionSession!.clockOutLogId,
          originalStartTime: _formatTimeOnly(_selectedCorrectionSession!.start),
          originalEndTime: _formatTimeOnly(_selectedCorrectionSession!.end),
        );
      } else {
        final overlappingSession = _findOverlappingAttendanceSession(
          logs: attendanceLogs,
          requestedStart: requestedStart,
          requestedEnd: requestedEnd,
        );

        if (overlappingSession != null) {
          _setSubmitMessage(
            'You already have an attendance session from '
            '${_formatTimeRange(overlappingSession.start, overlappingSession.end)}. '
            'Please choose a time outside your existing logs.',
          );
          return;
        }

        await services.timeRequestRepository.submitMissingTimeRequest(
          internUid: currentUser.uid,
          internName: currentUser.displayName ?? 'Intern',
          internEmail: currentUser.email ?? '',
          requestDate: _requestDate!,
          requestedStartTime: _startTimeController.text.trim(),
          requestedEndTime: _endTimeController.text.trim(),
          reason: _reasonController.text.trim(),
        );
      }

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _message = _requestType == TimeRequestType.correction
            ? 'Correction request submitted successfully.'
            : 'Time adjustment request submitted successfully.';
        _isFormExpanded = false;

        _dateController.clear();
        _startTimeController.clear();
        _endTimeController.clear();
        _reasonController.clear();
        _requestDate = null;
        _selectedCorrectionSession = null;
        _sessionsForSelectedDate = [];
        _requestType = TimeRequestType.missingTime;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _message = 'Failed to submit request. Please try again.';
      });
    }
  }

  void _setSubmitMessage(String message) {
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _message = message;
    });
  }

  List<_AttendanceSession> _buildSessionsForDate({
    required List<AttendanceModel> logs,
    required DateTime date,
  }) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = startOfDay.add(const Duration(days: 1));

    final sameDayLogs = logs
        .where(
          (log) =>
              !log.timestamp.isBefore(startOfDay) &&
              log.timestamp.isBefore(nextDay),
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sessions = <_AttendanceSession>[];
    AttendanceModel? activeClockIn;

    for (final log in sameDayLogs) {
      if (log.status == AttendanceStatus.clockIn) {
        activeClockIn = log;
        continue;
      }

      if (log.status == AttendanceStatus.clockOut && activeClockIn != null) {
        if (log.timestamp.isAfter(activeClockIn.timestamp) &&
            activeClockIn.id != null &&
            log.id != null) {
          sessions.add(
            _AttendanceSession(
              clockInLogId: activeClockIn.id!,
              clockOutLogId: log.id!,
              start: activeClockIn.timestamp,
              end: log.timestamp,
            ),
          );
        }

        activeClockIn = null;
      }
    }

    return sessions;
  }

  _AttendanceSession? _findOverlappingAttendanceSession({
    required List<AttendanceModel> logs,
    required DateTime requestedStart,
    required DateTime requestedEnd,
    String? ignoredClockInLogId,
    String? ignoredClockOutLogId,
  }) {
    final sessions = _buildSessionsForDate(
      logs: logs,
      date: requestedStart,
    );

    for (final session in sessions) {
      final isIgnoredSession = ignoredClockInLogId != null &&
          ignoredClockOutLogId != null &&
          session.clockInLogId == ignoredClockInLogId &&
          session.clockOutLogId == ignoredClockOutLogId;

      if (isIgnoredSession) continue;

      final overlaps =
          requestedStart.isBefore(session.end) &&
          requestedEnd.isAfter(session.start);

      if (overlaps) {
        return session;
      }
    }

    return null;
  }

  String? _validateRequestDateWithinInternship({
    required DateTime requestDate,
    required DateTime? internshipStartDate,
    required DateTime? internshipEndDate,
  }) {
    if (internshipStartDate == null || internshipEndDate == null) {
      return 'Your internship duration is not set yet. Please contact your supervisor before submitting a time request.';
    }

    final requested = DateTime(
      requestDate.year,
      requestDate.month,
      requestDate.day,
    );

    final start = DateTime(
      internshipStartDate.year,
      internshipStartDate.month,
      internshipStartDate.day,
    );

    final end = DateTime(
      internshipEndDate.year,
      internshipEndDate.month,
      internshipEndDate.day,
    );

    if (requested.isBefore(start) || requested.isAfter(end)) {
      return 'Requested date is outside your assigned internship period (${_formatDate(start)} - ${_formatDate(end)}).';
    }

    return null;
  }

  DateTime _combineDateAndTime(DateTime date, String timeText) {
    final normalized = timeText.trim().toUpperCase();

    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(
      normalized,
    );

    if (match == null) {
      throw Exception('Invalid time format.');
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$')
        .firstMatch(value.trim().toUpperCase());

    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = match.group(3);

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return null;
    }

    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    return '${_formatTimeOnly(start)} - ${_formatTimeOnly(end)}';
  }

  String _formatTimeOnly(DateTime dateTime) {
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';

    return '$hour12:$minute $suffix';
  }


  Route<T> _noTransitionRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _handleBottomNavTap(int index) {
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
        Navigator.of(context).push(
          _noTransitionRoute(const ProfileScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final uid = services.authService.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('No authenticated user found.')),
      );
    }

    return AnimatedBuilder(
      animation: services.themeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            backgroundColor: _background,
            elevation: 0,
            centerTitle: false,
            title: Text(
              'Time Requests',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                color: _headingColor,
              ),
            ),
            iconTheme: IconThemeData(color: _headingColor),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      _buildRequestFormCard(),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 430,
                        child: _buildRequestHistory(uid),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildRequestFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _isFormExpanded = !_isFormExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_calendar_outlined,
                      color: _blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Time Adjustment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: _headingColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isFormExpanded
                              ? 'Submit missing time or request correction for an existing log.'
                              : 'Tap to submit a new adjustment request.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isFormExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _blue,
                  ),
                ],
              ),
            ),
          ),
          if (_message != null && !_isFormExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _buildMessageText(),
            ),
          if (_isFormExpanded) ...[
            Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildRequestTypeSelector(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      style: _inputTextStyle(),
                      decoration: _decor(
                        'Request Date',
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (_) =>
                          _requestDate == null ? 'Date is required' : null,
                    ),
                    if (_requestType == TimeRequestType.correction) ...[
                      const SizedBox(height: 12),
                      _buildCorrectionSessionSelector(),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startTimeController,
                            readOnly: true,
                            onTap: () => _pickTime(_startTimeController),
                            style: _inputTextStyle(),
                            decoration: _decor(
                              _requestType == TimeRequestType.correction
                                  ? 'Corrected Start'
                                  : 'Start Time',
                              suffixIcon:
                                  const Icon(Icons.access_time_outlined),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _endTimeController,
                            readOnly: true,
                            onTap: () => _pickTime(_endTimeController),
                            style: _inputTextStyle(),
                            decoration: _decor(
                              _requestType == TimeRequestType.correction
                                  ? 'Corrected End'
                                  : 'End Time',
                              suffixIcon:
                                  const Icon(Icons.hourglass_bottom_outlined),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 2,
                      style: _inputTextStyle(),
                      decoration: _decor(
                        _requestType == TimeRequestType.correction
                            ? 'Reason for correction'
                            : 'Reason for missing time',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Reason is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    if (_message != null) _buildMessageText(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _requestType == TimeRequestType.correction
                                    ? 'Submit Correction Request'
                                    : 'Submit Missing Time Request',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _inputColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeOption(
              type: TimeRequestType.missingTime,
              label: 'Missing Time',
              icon: Icons.add_alarm_outlined,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTypeOption(
              type: TimeRequestType.correction,
              label: 'Correct Log',
              icon: Icons.edit_calendar_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required TimeRequestType type,
    required String label,
    required IconData icon,
  }) {
    final active = _requestType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () async {
        setState(() {
          _requestType = type;
          _message = null;
          _selectedCorrectionSession = null;
        });

        if (type == TimeRequestType.correction && _requestDate != null) {
          await _loadSessionsForSelectedDate();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? _cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? _blue : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? _blue : _mutedColor,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: active ? _blue : _mutedColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorrectionSessionSelector() {
    if (_requestDate == null) {
      return _buildInlineNotice(
        icon: Icons.info_outline_rounded,
        title: 'Select a date first',
        message:
            'Existing attendance sessions will appear after selecting a date.',
        color: _blue,
      );
    }

    if (_isLoadingSessions) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _inputColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Loading existing attendance sessions...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _mutedColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_sessionsForSelectedDate.isEmpty) {
      return _buildInlineNotice(
        icon: Icons.event_busy_outlined,
        title: 'No sessions found',
        message:
            'There are no completed attendance sessions on this date to correct.',
        color: _orange,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Existing Session to Correct',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _headingColor,
            ),
          ),
          const SizedBox(height: 10),
          ..._sessionsForSelectedDate.map((session) {
            final selected = _selectedCorrectionSession?.clockInLogId ==
                    session.clockInLogId &&
                _selectedCorrectionSession?.clockOutLogId ==
                    session.clockOutLogId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedCorrectionSession = session;
                    _startTimeController.text = _formatTimeOnly(session.start);
                    _endTimeController.text = _formatTimeOnly(session.end);
                    _message = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10)
                        : _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _blue : _borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selected ? _blue : _mutedColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatTimeRange(session.start, session.end),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _titleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInlineNotice({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: color.withValues(alpha: _isDarkMode ? 0.34 : 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
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

  Widget _buildRequestHistory(String uid) {
    return StreamBuilder<List<TimeRequestModel>>(
      stream: AppServices.of(context)
          .timeRequestRepository
          .streamRequestsByIntern(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _blue),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyMessage(
            icon: Icons.error_outline_rounded,
            title: 'Could not load requests',
            message: 'Please check your connection and try again.',
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildEmptyMessage(
            icon: Icons.history_rounded,
            title: 'No time requests yet',
            message: 'Submitted adjustment requests will appear here.',
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Text(
                  'Request History',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _headingColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${requests.length} total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildRequestCard(requests[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(TimeRequestModel item) {
    final hasRemarks = (item.reviewRemarks ?? '').trim().isNotEmpty;
    final hasApprovedTime = (item.approvedStartTime ?? '').trim().isNotEmpty ||
        (item.approvedEndTime ?? '').trim().isNotEmpty;
    final hasReviewedBy = (item.reviewedBy ?? '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeBadge(item.requestType),
              const SizedBox(width: 8),
              _buildStatusBadge(item.status),
              const Spacer(),
              Text(
                _formatDate(item.requestDate),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _mutedColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (item.isCorrection &&
              item.originalStartTime != null &&
              item.originalEndTime != null) ...[
            _buildInfoBox(
              icon: Icons.history_rounded,
              label: 'Original Time',
              value: '${item.originalStartTime} - ${item.originalEndTime}',
              color: _orange,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: _blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.isCorrection
                      ? 'Corrected: ${item.requestedStartTime} - ${item.requestedEndTime}'
                      : '${item.requestedStartTime} - ${item.requestedEndTime}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.reason,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _mutedColor,
              height: 1.35,
            ),
          ),
          if (hasApprovedTime) ...[
            const SizedBox(height: 10),
            _buildInfoBox(
              icon: Icons.check_circle_outline_rounded,
              label: 'Approved Time',
              value:
                  '${item.approvedStartTime ?? '-'} - ${item.approvedEndTime ?? '-'}',
              color: _green,
            ),
          ],
          if (hasRemarks) ...[
            const SizedBox(height: 10),
            _buildInfoBox(
              icon: Icons.rate_review_outlined,
              label: 'Supervisor Remarks',
              value: item.reviewRemarks!,
              color: _blue,
            ),
          ],
          if (hasReviewedBy || item.reviewedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (hasReviewedBy) 'Reviewed by ${item.reviewedBy}',
                if (item.reviewedAt != null)
                  'at ${_formatDateTime(item.reviewedAt!)}',
              ].join(' '),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: _mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBadge(TimeRequestType type) {
    final isCorrection = type == TimeRequestType.correction;
    final color = isCorrection ? _orange : _blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isCorrection ? 'CORRECTION' : 'MISSING TIME',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: _isDarkMode ? 0.26 : 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _titleColor,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TimeRequestStatus status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(status),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageText() {
    final message = _message ?? '';

    final isSuccess =
        message.startsWith('Time adjustment request submitted') ||
            message.startsWith('Correction request submitted');

    final isOverlap = message.startsWith('You already have') ||
        message.startsWith('Please select') ||
        message.startsWith('End time') ||
        message.startsWith('Could not load');

    final Color borderColor = isSuccess
        ? _green
        : isOverlap
            ? _orange
            : _red;

    final Color bgColor = borderColor.withValues(
      alpha: _isDarkMode ? 0.17 : 0.09,
    );

    final IconData icon = isSuccess
        ? Icons.check_circle_outline_rounded
        : isOverlap
            ? Icons.warning_amber_rounded
            : Icons.error_outline_rounded;

    final String title = isSuccess
        ? 'Request submitted'
        : isOverlap
            ? 'Review required'
            : 'Request failed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: borderColor.withValues(alpha: _isDarkMode ? 0.40 : 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: borderColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: borderColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _titleColor,
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

  Widget _buildEmptyMessage({
  required IconData icon,
  required String title,
  required String message,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _blue, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _mutedColor,
              height: 1.4,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(color: _borderColor),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i].$1,
                    size: 22,
                    color: active ? _blue : _mutedColor,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? _blue : _mutedColor,
                      letterSpacing: 0.5,
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

  InputDecoration _decor(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: _mutedColor,
      ),
      filled: true,
      fillColor: _inputColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.4),
      ),
      suffixIcon: suffixIcon,
      suffixIconColor: _mutedColor,
    );
  }

  TextStyle _inputTextStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _titleColor,
    );
  }

  Color _statusColor(TimeRequestStatus status) {
    switch (status) {
      case TimeRequestStatus.pending:
        return _orange;
      case TimeRequestStatus.approved:
        return _green;
      case TimeRequestStatus.rejected:
        return _red;
    }
  }

  String _statusText(TimeRequestStatus status) {
    switch (status) {
      case TimeRequestStatus.pending:
        return 'PENDING';
      case TimeRequestStatus.approved:
        return 'APPROVED';
      case TimeRequestStatus.rejected:
        return 'REJECTED';
    }
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm/$dd/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  String _formatDateTime(DateTime dateTime) {
    final date = _formatDate(dateTime);
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    return '$date • $hour12:$minute $suffix';
  }
}

class _AttendanceSession {
  final String clockInLogId;
  final String clockOutLogId;
  final DateTime start;
  final DateTime end;

  const _AttendanceSession({
    required this.clockInLogId,
    required this.clockOutLogId,
    required this.start,
    required this.end,
  });
}
