import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'All Events';

  final List<String> _filters = const [
    'All Events',
    'Clock-In Only',
    'Clock-Out Only',
  ];

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _pageTextColor =>
      _isDarkMode ? Colors.white : const Color(0xFF0A2351);

  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

  Color get _inputColor =>
      _isDarkMode ? const Color(0xFF0B1120) : Colors.white;

  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE7ECF3);

  Color get _dividerColor =>
      _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFF1F4F8);

  Color get _mutedTextColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  static const Color _blue = Color(0xFF0D4DB3);
  static const Color _green = Color(0xFF14A44D);
  static const Color _red = Color(0xFFC62828);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final attendanceRepo = AppServices.of(context).attendanceRepository;
    final userRepo = AppServices.of(context).userRepository;

    return AnimatedBuilder(
      animation: AppServices.of(context).themeController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 22),
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: userRepo.streamInternUsers(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _blue),
                      );
                    }

                    if (userSnapshot.hasError) {
                      return _buildStateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Failed to load users',
                        message: '${userSnapshot.error}',
                      );
                    }

                    final users = userSnapshot.data ?? [];
                    final userMap = {
                      for (final user in users) user.uid: user,
                    };

                    return StreamBuilder<List<AttendanceModel>>(
                      stream: attendanceRepo.streamAllAttendanceLogs(),
                      builder: (context, logSnapshot) {
                        if (logSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _blue),
                          );
                        }

                        if (logSnapshot.hasError) {
                          return _buildStateCard(
                            icon: Icons.error_outline_rounded,
                            title: 'Failed to load logs',
                            message: '${logSnapshot.error}',
                          );
                        }

                        final allLogs = logSnapshot.data ?? [];
                        final filteredLogs = _applyFilters(allLogs, userMap);

                        final totalLogs = filteredLogs.length;
                        final totalClockIns = filteredLogs
                            .where((log) =>
                                log.status == AttendanceStatus.clockIn)
                            .length;
                        final totalClockOuts = filteredLogs
                            .where((log) =>
                                log.status == AttendanceStatus.clockOut)
                            .length;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'TOTAL EVENTS',
                                    value: '$totalLogs',
                                    icon: Icons.receipt_long_rounded,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'CLOCK-INS',
                                    value: '$totalClockIns',
                                    icon: Icons.login_rounded,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'CLOCK-OUTS',
                                    value: '$totalClockOuts',
                                    icon: Icons.logout_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: _buildLogsTable(filteredLogs, userMap),
                            ),
                          ],
                        );
                      },
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

  List<AttendanceModel> _applyFilters(
    List<AttendanceModel> logs,
    Map<String, UserModel> userMap,
  ) {
    return logs.where((log) {
      if (_selectedFilter == 'Clock-In Only' &&
          log.status != AttendanceStatus.clockIn) {
        return false;
      }

      if (_selectedFilter == 'Clock-Out Only' &&
          log.status != AttendanceStatus.clockOut) {
        return false;
      }

      final user = userMap[log.uid];
      final fullName = user?.fullName.toLowerCase() ?? '';
      final email = user?.email.toLowerCase() ?? '';
      final q = _searchQuery.trim().toLowerCase();

      if (q.isEmpty) return true;

      return fullName.contains(q) ||
          email.contains(q) ||
          log.uid.toLowerCase().contains(q) ||
          _statusText(log.status).toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.plusJakartaSans(
              color: _pageTextColor,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search logs by student, email, uid...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _mutedTextColor,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: _mutedTextColor,
              ),
              filled: true,
              fillColor: _inputColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _blue, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          'FILTER:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _mutedTextColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFilter,
              dropdownColor: _cardColor,
              borderRadius: BorderRadius.circular(12),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _pageTextColor,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _mutedTextColor,
              ),
              items: _filters.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedFilter = value);
                }
              },
            ),
          ),
        ),
        const Spacer(),
        Text(
          'System Logs',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _pageTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              color:
                  _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _blue),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _mutedTextColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _pageTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTable(
    List<AttendanceModel> logs,
    Map<String, UserModel> userMap,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const SizedBox(height: 12),
          Divider(height: 1, color: _dividerColor),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyLogs()
                : ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 18, color: _dividerColor),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final user = userMap[log.uid];

                      return _buildLogRow(log, user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    final style = GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: _mutedTextColor,
      letterSpacing: 0.5,
    );

    return Row(
      children: [
        Expanded(flex: 3, child: Text('STUDENT', style: style)),
        Expanded(flex: 2, child: Text('EVENT', style: style)),
        Expanded(flex: 2, child: Text('TIME', style: style)),
        Expanded(flex: 3, child: Text('LOCATION', style: style)),
        Expanded(flex: 3, child: Text('UID', style: style)),
      ],
    );
  }

  Widget _buildLogRow(AttendanceModel log, UserModel? user) {
    final isClockIn = log.status == AttendanceStatus.clockIn;
    final badgeColor = isClockIn ? _green : _red;

    final locationText = log.locationCoords == null
        ? 'No coordinates'
        : '${log.locationCoords!.latitude.toStringAsFixed(6)}, ${log.locationCoords!.longitude.toStringAsFixed(6)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _isDarkMode
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFE8F0FF),
                child: Text(
                  _initialsOf(user?.fullName ?? 'Unknown User'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Unknown User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _pageTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'No email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusText(log.status),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            _formatDateTime(log.timestamp),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _mutedTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            locationText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _mutedTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            log.uid,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: _mutedTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLogs() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 42,
            color: _mutedTextColor,
          ),
          const SizedBox(height: 10),
          Text(
            'No logs found.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: _mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: _blue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _pageTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _mutedTextColor,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.clockIn:
        return 'Clock-In';
      case AttendanceStatus.clockOut:
        return 'Clock-Out';
    }
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:$minute $suffix';
  }
}
