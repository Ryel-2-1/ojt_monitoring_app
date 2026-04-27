import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/time_request_model.dart';
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
  final _proofNoteController = TextEditingController();

  DateTime? _requestDate;
  bool _isSubmitting = false;
  bool _isFormExpanded = true;
  String? _message;

  final int _selectedNavIndex = -1;

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _reasonController.dispose();
    _proofNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _requestDate = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked == null) return;

    controller.text = _formatTime(picked);
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

      await services.timeRequestRepository.submitRequest(
        internUid: currentUser.uid,
        internName: currentUser.displayName ?? 'Intern',
        internEmail: currentUser.email ?? '',
        requestDate: _requestDate!,
        requestedStartTime: _startTimeController.text.trim(),
        requestedEndTime: _endTimeController.text.trim(),
        reason: _reasonController.text.trim(),
        proofNote: _proofNoteController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _message = 'Time adjustment request submitted successfully.';
        _isFormExpanded = false;

        _dateController.clear();
        _startTimeController.clear();
        _endTimeController.clear();
        _reasonController.clear();
        _proofNoteController.clear();
        _requestDate = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _message = 'Failed to submit request. Please try again.';
      });
    }
  }

  void _handleBottomNavTap(int index) {
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.of(context).authService.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('No authenticated user found.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        title: Text(
          'Time Requests',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A2351),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0A2351)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _buildRequestFormCard(),
            const SizedBox(height: 14),
            Expanded(
              child: _buildRequestHistory(uid),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildRequestFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF5)),
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
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.edit_calendar_outlined,
                      color: Color(0xFF0D4DB3),
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
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0A2351),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isFormExpanded
                              ? 'Fill out the details below.'
                              : 'Tap to submit a new adjustment request.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isFormExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF0D4DB3),
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
            const Divider(height: 1, color: Color(0xFFE9EEF5)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: _decor(
                        'Request Date',
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (_) =>
                          _requestDate == null ? 'Date is required' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startTimeController,
                            readOnly: true,
                            onTap: () => _pickTime(_startTimeController),
                            decoration: _decor(
                              'Start Time',
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
                            decoration: _decor(
                              'End Time',
                              suffixIcon: const Icon(
                                Icons.hourglass_bottom_outlined,
                              ),
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
                      decoration: _decor('Reason for adjustment'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Reason is required'
                              : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _proofNoteController,
                      maxLines: 2,
                      decoration: _decor('Proof note / attachment reference'),
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
                          backgroundColor: const Color(0xFF0D4DB3),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
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
                                'Submit Request',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
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

  Widget _buildRequestHistory(String uid) {
    return StreamBuilder<List<TimeRequestModel>>(
      stream: AppServices.of(context)
          .timeRequestRepository
          .streamRequestsByIntern(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0D4DB3)),
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
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A2351),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${requests.length} total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D4DB3),
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
    final color = _statusColor(item.status);
    final hasRemarks = (item.reviewRemarks ?? '').trim().isNotEmpty;
    final hasApprovedTime = (item.approvedStartTime ?? '').trim().isNotEmpty ||
        (item.approvedEndTime ?? '').trim().isNotEmpty;
    final hasReviewedBy = (item.reviewedBy ?? '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusBadge(item.status),
              const Spacer(),
              Text(
                _formatDate(item.requestDate),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: Color(0xFF0D4DB3),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.requestedStartTime} - ${item.requestedEndTime}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF1C2434),
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
              color: Colors.grey[700],
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
              color: const Color(0xFF14A44D),
            ),
          ],
          if (hasRemarks) ...[
            const SizedBox(height: 10),
            _buildInfoBox(
              icon: Icons.rate_review_outlined,
              label: 'Supervisor Remarks',
              value: item.reviewRemarks!,
              color: const Color(0xFF0D4DB3),
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
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
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
                  color: const Color(0xFF1C2434),
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(status),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageText() {
    final failed = _message?.startsWith('Failed') == true;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        _message ?? '',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: failed ? Colors.red[700] : Colors.green[700],
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF0D4DB3), size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C2434),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[600],
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i].$1,
                    size: 22,
                    color: active
                        ? const Color(0xFF1A3A6B)
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF1A3A6B)
                          : Colors.grey[400],
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
        color: Colors.grey[500],
      ),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }

  Color _statusColor(TimeRequestStatus status) {
    switch (status) {
      case TimeRequestStatus.pending:
        return const Color(0xFFF5A623);
      case TimeRequestStatus.approved:
        return const Color(0xFF14A44D);
      case TimeRequestStatus.rejected:
        return const Color(0xFFC62828);
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