import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import 'intern_home_screen.dart';
import 'profile_screen.dart';
import 'timer_screen.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  final int _selectedNavIndex = 2;

  bool _isLoading = true;
  String? _errorMessage;

  UserModel? _user;
  List<_TimesheetSession> _sessions = [];

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _background =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF5F7FA);

  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFEAF1FF);

  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE9EEF5);

  Color get _titleColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1C2434);

  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTimesheetData();
  }

  Future<void> _loadTimesheetData() async {
    final services = AppServices.of(context);
    final uid = services.authService.currentUser?.uid;

    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated.';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = await services.userRepository.getUserByUid(uid);
      final logs = await services.attendanceRepository.getAttendanceByStudent(
        uid,
      );

      final sessions = _buildSessions(logs);

      if (!mounted) return;

      setState(() {
        _user = user;
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load timesheet data. Please try again.';
      });
    }
  }

  List<_TimesheetSession> _buildSessions(List<AttendanceModel> logs) {
    final sorted = [...logs]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sessions = <_TimesheetSession>[];
    AttendanceModel? activeClockIn;

    for (final log in sorted) {
      if (log.status == AttendanceStatus.clockIn) {
        activeClockIn = log;
      }

      if (log.status == AttendanceStatus.clockOut && activeClockIn != null) {
        if (log.timestamp.isAfter(activeClockIn.timestamp)) {
          sessions.add(
            _TimesheetSession(clockIn: activeClockIn, clockOut: log),
          );
        }

        activeClockIn = null;
      }
    }

    return sessions;
  }

  double get _completedHours {
    return _sessions.fold<double>(
      0,
      (total, session) => total + session.duration.inMinutes / 60.0,
    );
  }

  int get _requiredHours => _user?.requiredOjtHours ?? 0;

  double get _progress {
    if (_requiredHours <= 0) return 0;
    return (_completedHours / _requiredHours).clamp(0.0, 1.0);
  }

  _TimesheetSession? get _lastSession {
    if (_sessions.isEmpty) return null;
    final sorted = [..._sessions]
      ..sort((a, b) => a.clockIn.timestamp.compareTo(b.clockIn.timestamp));
    return sorted.last;
  }


  Route<T> _noTransitionRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == 2) return;

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

      case 3:
        Navigator.of(context).pushAndRemoveUntil(
          _noTransitionRoute(const ProfileScreen()),
          (route) => route.isFirst,
        );
        break;
    }
  }

  void _openGenerateTimesheet() {
    Navigator.push(
      context,
      _noTransitionRoute(
        GenerateTimesheetScreen(
          user: _user,
          sessions: _sessions,
          completedHours: _completedHours,
          requiredHours: _requiredHours,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = AppServices.of(context).themeController;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Column(
              children: [
                
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF0D4DB3),
                    onRefresh: _loadTimesheetData,
                    child: _buildBody(),
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

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator(color: Color(0xFF0D4DB3))),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 160),
          _buildMessageCard(
            icon: Icons.error_outline_rounded,
            title: 'Timesheet unavailable',
            message: _errorMessage!,
          ),
        ],
      );
    }

    final bool canGenerateTimesheet = _sessions.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildCurrentObjectiveCard(),
        const SizedBox(height: 16),
        _buildLastSessionCard(),
        const SizedBox(height: 16),
        _buildRecentSessionsCard(),
        const SizedBox(height: 22),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 150,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: canGenerateTimesheet ? _openGenerateTimesheet : null,
              icon: Icon(
                Icons.description_outlined,
                size: 16,
                color: canGenerateTimesheet ? Colors.white : _mutedColor,
              ),
              label: Text(
  'Generate\nTimesheet',
  textAlign: TextAlign.center,
  style: GoogleFonts.dmSans(
    fontSize: 10,
    height: 1.05,
    fontWeight: FontWeight.w700,
    color: canGenerateTimesheet ? Colors.white : _mutedColor,
  ),
),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D4DB3),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    _isDarkMode ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                disabledForegroundColor: _mutedColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Text(
            'Internship Monitor',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D4DB3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentObjectiveCard() {
    final company = _cleanText(
      _user?.companyName,
      fallback: 'No company assigned',
    );
    final requiredText = _requiredHours <= 0
        ? 'Not set'
        : '$_requiredHours hrs';
    final completedText = '${_completedHours.toStringAsFixed(1)} hrs';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE8EDF7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'OJT TIMESHEET SUMMARY',
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF1A3A6B),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            company,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _cleanText(
              _user?.companyAddress,
              fallback: 'Company address has not been assigned yet.',
            ),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _mutedColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'TOTAL\nPROGRESS',
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  const Color(0xFF0D4DB3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _metric(
                  'COMPLETED\nHOURS',
                  completedText,
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _metric(
                  'TARGET\nHOURS',
                  requiredText,
                  const Color(0xFF1C2434),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 9,
              backgroundColor: _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE8EDF5),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF0D4DB3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: _mutedColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLastSessionCard() {
    final last = _lastSession;

    if (last == null) {
      return _buildMessageCard(
        icon: Icons.timer_outlined,
        title: 'No completed session yet',
        message:
            'Your latest completed clock-in and clock-out pair will appear here.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer_outlined, color: Color(0xFF0D4DB3)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST ACTIVE SESSION',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: _mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(last.duration),
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(last.clockIn.timestamp)} • ${_formatTime(last.clockIn.timestamp)} — ${_formatTime(last.clockOut.timestamp)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D4DB3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard() {
    if (_sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    final recent = [..._sessions]
      ..sort((a, b) => b.clockIn.timestamp.compareTo(a.clockIn.timestamp));

    final limited = recent.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Sessions',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 12),
          ...limited.map((session) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFF0D4DB3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatDate(session.clockIn.timestamp),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatTime(session.clockIn.timestamp)} - ${_formatTime(session.clockOut.timestamp)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: _mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(session.duration.inMinutes / 60).toStringAsFixed(1)}h',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0D4DB3), size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _mutedColor,
              height: 1.4,
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
                    color: active ? const Color(0xFF0D4DB3) : _mutedColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? const Color(0xFF0D4DB3) : _mutedColor,
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

  String _formatDuration(Duration duration) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(duration.inHours)}:${pad(duration.inMinutes.remainder(60))}:${pad(duration.inSeconds.remainder(60))}';
  }

  String _formatDate(DateTime date) {
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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class GenerateTimesheetScreen extends StatefulWidget {
  final UserModel? user;
  final List<_TimesheetSession> sessions;
  final double completedHours;
  final int requiredHours;

  const GenerateTimesheetScreen({
    super.key,
    required this.user,
    required this.sessions,
    required this.completedHours,
    required this.requiredHours,
  });

  @override
  State<GenerateTimesheetScreen> createState() =>
      _GenerateTimesheetScreenState();
}

class _GenerateTimesheetScreenState extends State<GenerateTimesheetScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedFormat = 'PDF';
  List<_TimesheetSession> _filteredSessions = [];
  bool _hasGeneratedPreview = false;

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _background =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF5F7FA);

  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF5F7FA);

  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE6EBF2);

  Color get _titleColor =>
      _isDarkMode ? Colors.white : const Color(0xFF1C2434);

  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    if (widget.sessions.isNotEmpty) {
      final sorted = [...widget.sessions]
        ..sort((a, b) => a.clockIn.timestamp.compareTo(b.clockIn.timestamp));

      _startDate = sorted.first.clockIn.timestamp;
      _endDate = sorted.last.clockOut.timestamp;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate ?? DateTime.now()
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) {
        if (!_isDarkMode) return child ?? const SizedBox.shrink();

        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0D4DB3),
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
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }

      _hasGeneratedPreview = false;
    });
  }

  void _generatePreview() {
    if (_startDate == null || _endDate == null) {
      _showSnackBar('Please select a start and end date.');
      return;
    }

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
    );

    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      23,
      59,
      59,
    );

    if (end.isBefore(start)) {
      _showSnackBar('End date cannot be before start date.');
      return;
    }

    final filtered =
        widget.sessions.where((session) {
            final date = session.clockIn.timestamp;
            return !date.isBefore(start) && !date.isAfter(end);
          }).toList()
          ..sort((a, b) => a.clockIn.timestamp.compareTo(b.clockIn.timestamp));

    setState(() {
      _filteredSessions = filtered;
      _hasGeneratedPreview = true;
    });
  }

  double get _filteredHours {
    return _filteredSessions.fold<double>(
      0,
      (total, session) => total + session.duration.inMinutes / 60.0,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.dmSans(fontSize: 13))),
    );
  }

  Future<void> _handleExport() async {
    if (!_hasGeneratedPreview) {
      _showSnackBar('Please generate a preview first.');
      return;
    }

    if (_filteredSessions.isEmpty) {
      _showSnackBar('There are no sessions to export.');
      return;
    }

    try {
      if (_selectedFormat == 'PDF') {
        await _exportPdf();
      } else {
        await _exportCsv();
      }
    } catch (_) {
      _showSnackBar('Export failed. Please try again.');
    }
  }

  Future<void> _exportPdf() async {
    final bytes = await _buildPdfBytes();
    final fileName = 'ojt_timesheet_${_fileDateStamp()}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<void> _exportCsv() async {
    final csvContent = _buildCsvContent();
    final fileName = 'ojt_timesheet_${_fileDateStamp()}.csv';

    await SharePlus.instance.share(
      ShareParams(
        text: 'OJT Timesheet CSV Export',
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csvContent)),
            mimeType: 'text/csv',
            name: fileName,
          ),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdfBytes() async {
    final pdf = pw.Document();

    final displayName = _cleanText(widget.user?.fullName, fallback: 'Intern');
    final email = _cleanText(widget.user?.email, fallback: 'No email');
    final company = _cleanText(
      widget.user?.companyName,
      fallback: 'No company assigned',
    );
    final address = _cleanText(
      widget.user?.companyAddress,
      fallback: 'No company address assigned',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Text(
              'OJT Timesheet Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Generated: ${_formatDateTime(DateTime.now())}'),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Intern Information',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Name: $displayName'),
                  pw.Text('Email: $email'),
                  pw.Text('Company: $company'),
                  pw.Text('Company Address: $address'),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report Summary',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Date Range: ${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                  ),
                  pw.Text('Completed Sessions: ${_filteredSessions.length}'),
                  pw.Text(
                    'Total Hours in Report: ${_filteredHours.toStringAsFixed(2)} hrs',
                  ),
                  pw.Text(
                    'Required OJT Hours: ${widget.requiredHours <= 0 ? 'Not set' : '${widget.requiredHours} hrs'}',
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              'Attendance Sessions',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              headers: const ['Date', 'Clock In', 'Clock Out', 'Duration'],
              data: _filteredSessions.map((session) {
                return [
                  _formatDate(session.clockIn.timestamp),
                  _formatTime(session.clockIn.timestamp),
                  _formatTime(session.clockOut.timestamp),
                  '${(session.duration.inMinutes / 60).toStringAsFixed(2)} hrs',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
            ),

            pw.SizedBox(height: 24),

            pw.Text(
              'This report was generated from recorded clock-in and clock-out attendance logs.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _buildCsvContent() {
    final displayName = _cleanText(widget.user?.fullName, fallback: 'Intern');
    final email = _cleanText(widget.user?.email, fallback: 'No email');
    final company = _cleanText(
      widget.user?.companyName,
      fallback: 'No company assigned',
    );

    final rows = <List<String>>[
      ['OJT Timesheet Report'],
      ['Generated', _formatDateTime(DateTime.now())],
      ['Intern Name', displayName],
      ['Email', email],
      ['Company', company],
      ['Date Range', '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'],
      ['Total Sessions', _filteredSessions.length.toString()],
      ['Total Hours', _filteredHours.toStringAsFixed(2)],
      [],
      ['Date', 'Clock In', 'Clock Out', 'Duration Hours'],
      ..._filteredSessions.map((session) {
        return [
          _formatDate(session.clockIn.timestamp),
          _formatTime(session.clockIn.timestamp),
          _formatTime(session.clockOut.timestamp),
          (session.duration.inMinutes / 60).toStringAsFixed(2),
        ];
      }),
    ];

    return rows
        .map((row) {
          return row.map(_escapeCsv).join(',');
        })
        .join('\n');
  }

  String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');

    final escaped = value.replaceAll('"', '""');

    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _fileDateStamp() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return '$year$month${day}_$hour$minute';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${_formatTime(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _cleanText(widget.user?.fullName, fallback: 'Intern');
    final company = _cleanText(
      widget.user?.companyName,
      fallback: 'No company assigned',
    );

    final themeController = AppServices.of(context).themeController;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(displayName, company),
                        const SizedBox(height: 18),
                        _buildSectionLabel(
                          Icons.calendar_today_outlined,
                          'PERIOD SELECTION',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDateBox(
                                label: 'Start Date',
                                value: _startDate == null
                                    ? 'Select date'
                                    : _formatDate(_startDate!),
                                onTap: () => _pickDate(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDateBox(
                                label: 'End Date',
                                value: _endDate == null
                                    ? 'Select date'
                                    : _formatDate(_endDate!),
                                onTap: () => _pickDate(isStart: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildSectionLabel(
                          Icons.description_outlined,
                          'OUTPUT FORMAT',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormatCard(
                                title: 'PDF Document',
                                subtitle: 'Official Submission',
                                icon: Icons.picture_as_pdf_outlined,
                                selected: _selectedFormat == 'PDF',
                                onTap: () {
                                  setState(() => _selectedFormat = 'PDF');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormatCard(
                                title: 'CSV Spreadsheet',
                                subtitle: 'Data Analysis',
                                icon: Icons.table_chart_outlined,
                                selected: _selectedFormat == 'CSV',
                                onTap: () {
                                  setState(() => _selectedFormat = 'CSV');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _generatePreview,
                            icon: const Icon(Icons.visibility_outlined),
                            label: Text(
                              'GENERATE PREVIEW',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D4DB3),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_hasGeneratedPreview) _buildPreviewCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF0D4DB3),
            ),
          ),
          Expanded(
            child: Text(
              'Generate Timesheet',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D4DB3),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHeroCard(String displayName, String company) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D4DB3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OJT Timesheet Report',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            company,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _mutedColor),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _mutedColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDateBox({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 11, color: _mutedColor),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF0D4DB3) : _borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF0D4DB3) : _mutedColor,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(fontSize: 11, color: _mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
  if (_filteredSessions.isEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Text(
        'No completed attendance sessions found for the selected date range.',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _mutedColor,
        ),
      ),
    );
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timesheet Preview',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_filteredSessions.length} completed session(s) • ${_filteredHours.toStringAsFixed(1)} total hour(s)',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: _isDarkMode
                ? const Color(0xFF93C5FD)
                : const Color(0xFF0D4DB3),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ..._filteredSessions.map((session) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _softCardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(session.clockIn.timestamp),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _titleColor,
                    ),
                  ),
                ),
                Text(
                  '${_formatTime(session.clockIn.timestamp)} - ${_formatTime(session.clockOut.timestamp)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _mutedColor,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(session.duration.inMinutes / 60).toStringAsFixed(1)}h',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () async {
              await _handleExport();
            },
            icon: Icon(
              _selectedFormat == 'PDF'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.table_chart_outlined,
            ),
            label: Text(
              'EXPORT AS $_selectedFormat',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _isDarkMode
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFF0D4DB3),
              side: BorderSide(
                color: _isDarkMode
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFF0D4DB3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  String _cleanText(String? value, {required String fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  String _formatDate(DateTime date) {
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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _TimesheetSession {
  final AttendanceModel clockIn;
  final AttendanceModel clockOut;

  const _TimesheetSession({required this.clockIn, required this.clockOut});

  Duration get duration => clockOut.timestamp.difference(clockIn.timestamp);
}
