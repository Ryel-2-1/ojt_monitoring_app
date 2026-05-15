import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import 'evaluate_screen.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  static const Color _primary = Color(0xFF0D4DB3);
  static const Color _navy = Color(0xFF081F5C);
  static const Color _darkBlue = Color(0xFF0A2351);
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _border = Color(0xFFE7ECF3);
  static const Color _success = Color(0xFF14A44D);
  static const Color _warning = Color(0xFFF5A623);
  static const Color _danger = Color(0xFFC62828);

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _pageBg => _isDarkMode ? const Color(0xFF0B1120) : _bg;
  Color get _cardColor => _isDarkMode ? const Color(0xFF0F172A) : Colors.white;
  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : Colors.white;
  Color get _fieldColor =>
      _isDarkMode ? const Color(0xFF111827) : Colors.white;
  Color get _lineColor =>
      _isDarkMode ? const Color(0xFF243244) : _border;
  Color get _titleColor => _isDarkMode ? Colors.white : _darkBlue;
  Color get _bodyColor =>
      _isDarkMode ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> _filterUsers(List<UserModel> users) {
    final q = _searchQuery.trim().toLowerCase();

    if (q.isEmpty) return users;

    return users.where((user) {
      return user.fullName.toLowerCase().contains(q) ||
          user.email.toLowerCase().contains(q) ||
          user.uid.toLowerCase().contains(q) ||
          (user.companyName ?? '').toLowerCase().contains(q);
    }).toList();
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
        totalHours += log.timestamp.difference(lastClockIn).inMinutes / 60.0;
        lastClockIn = null;
      }
    }

    return totalHours;
  }

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final supervisorUid = services.authService.currentUser?.uid;

    return AnimatedBuilder(
      animation: services.themeController,
      builder: (context, _) {
        return Container(
          color: _pageBg,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                Expanded(
                  child: supervisorUid == null
                      ? _buildCenteredMessage(
                          'Supervisor account not detected. Please sign in again.',
                          color: _danger,
                        )
                      : StreamBuilder<List<UserModel>>(
                          stream: services.userRepository.streamInternUsers(
                            supervisorUid: supervisorUid,
                            includeUnassigned: false,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _primary,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return _buildCenteredMessage(
                                'Could not load interns. Please check Firestore permissions.',
                                color: _danger,
                              );
                            }

                            final users = _filterUsers(snapshot.data ?? []);

                            if (users.isEmpty) {
                              return _buildEmptyState();
                            }

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 980;

                                if (!isWide) {
                                  return ListView.separated(
                                    itemCount: users.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, index) {
                                      return _buildEvaluationStudentCard(
                                        user: users[index],
                                        isWide: false,
                                      );
                                    },
                                  );
                                }

                                return GridView.builder(
                                  itemCount: users.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 2.45,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildEvaluationStudentCard(
                                      user: users[index],
                                      isWide: true,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evaluations',
              style: GoogleFonts.plusJakartaSans(
                fontSize: compact ? 24 : 30,
                fontWeight: FontWeight.w900,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Evaluate interns only after they complete their required OJT hours.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _mutedColor,
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), _buildSearchBar()],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            SizedBox(width: 360, child: _buildSearchBar()),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.plusJakartaSans(
        color: _titleColor,
        fontWeight: FontWeight.w600,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search interns or records...',
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: _mutedColor,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: _mutedColor),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: _mutedColor,
                ),
              ),
        filled: true,
        fillColor: _fieldColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _lineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _lineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildEvaluationStudentCard({
    required UserModel user,
    required bool isWide,
  }) {
    final requiredHours = user.requiredOjtHours ?? 0;

    return FutureBuilder<List<AttendanceModel>>(
      future: AppServices.of(context)
          .attendanceRepository
          .getAttendanceByStudent(user.uid),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final completedHours = isLoading
            ? 0.0
            : _calculateCompletedHours(snapshot.data ?? []);

        final progress = requiredHours <= 0
            ? 0.0
            : (completedHours / requiredHours).clamp(0.0, 1.0);

        final canEvaluate =
            requiredHours > 0 && completedHours >= requiredHours;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _lineColor),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode
                    ? Colors.black.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.035),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  children: [
                    _buildAvatar(user),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStudentInfo(
                        user: user,
                        completedHours: completedHours,
                        requiredHours: requiredHours,
                        progress: progress,
                        isLoading: isLoading,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildEvaluationAction(
                      user: user,
                      completedHours: completedHours,
                      requiredHours: requiredHours,
                      canEvaluate: canEvaluate,
                      isLoading: isLoading,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(user),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildStudentInfo(
                            user: user,
                            completedHours: completedHours,
                            requiredHours: requiredHours,
                            progress: progress,
                            isLoading: isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildEvaluationAction(
                      user: user,
                      completedHours: completedHours,
                      requiredHours: requiredHours,
                      canEvaluate: canEvaluate,
                      isLoading: isLoading,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAvatar(UserModel user) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDarkMode ? const Color(0xFF243244) : Colors.transparent,
        ),
      ),
      child: Center(
        child: Text(
          _initialsOf(user.fullName),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _isDarkMode ? const Color(0xFF93C5FD) : _primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfo({
    required UserModel user,
    required double completedHours,
    required int requiredHours,
    required double progress,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: _mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(
              icon: Icons.business_outlined,
              text: _cleanText(user.companyName, fallback: 'No company'),
              color: _primary,
            ),
            _buildChip(
              icon: Icons.timer_outlined,
              text: isLoading
                  ? 'Loading hours...'
                  : '${completedHours.toStringAsFixed(1)} / ${requiredHours <= 0 ? 0 : requiredHours} hrs',
              color: requiredHours > 0 && completedHours >= requiredHours
                  ? _success
                  : _warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor:
                _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE8EDF5),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1 ? _success : _primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationAction({
    required UserModel user,
    required double completedHours,
    required int requiredHours,
    required bool canEvaluate,
    required bool isLoading,
  }) {
    final label = canEvaluate ? 'Evaluate Student' : 'Locked';
    final helper = requiredHours <= 0
        ? 'Target hours not set.'
        : canEvaluate
            ? 'Ready for evaluation.'
            : 'Unlocks at $requiredHours OJT hours.';

    final lockedBg = _isDarkMode ? const Color(0xFF1F2937) : Colors.grey[300];
    final lockedFg = _isDarkMode ? const Color(0xFF9CA3AF) : Colors.grey[600];

    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: isLoading || !canEvaluate
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EvaluateScreen(
                          intern: user,
                          completedHours: completedHours,
                          requiredHours: requiredHours,
                        ),
                      ),
                    );
                  },
            icon: Icon(
              canEvaluate
                  ? Icons.assignment_turned_in_outlined
                  : Icons.lock_outline_rounded,
              size: 17,
            ),
            label: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canEvaluate ? _navy : lockedBg,
              foregroundColor: canEvaluate ? Colors.white : lockedFg,
              disabledBackgroundColor: lockedBg,
              disabledForegroundColor: lockedFg,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: canEvaluate ? _success : _mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _lineColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, color: _primary, size: 34),
            const SizedBox(height: 12),
            Text(
              'No interns found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Interns assigned to you will appear here once they join using your supervisor enrollment code.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _mutedColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredMessage(String message, {Color? color}) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color ?? _bodyColor,
        ),
      ),
    );
  }

  String _cleanText(String? value, {required String fallback}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  String _initialsOf(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) return 'U';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
