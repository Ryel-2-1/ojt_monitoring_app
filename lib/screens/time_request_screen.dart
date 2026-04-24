import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/time_request_model.dart';
import 'intern_home_screen.dart';
import 'timer_screen.dart';

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
  String? _message;
  int _selectedNavIndex = 2;

  @override
  void dispose() {
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _reasonController.dispose();
    _proofNoteController.dispose();
    super.dispose();
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _requestDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      controller.text = _formatTime(picked);
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
      final currentUser = services.authService.currentUser!;

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
        _dateController.clear();
        _startTimeController.clear();
        _endTimeController.clear();
        _reasonController.clear();
        _proofNoteController.clear();
        _requestDate = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _message = 'Failed to submit request: $e';
      });
    }
  }

  InputDecoration _decor(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
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

  void _handleBottomNavTap(int index) {
    if (index == _selectedNavIndex) return;

    setState(() => _selectedNavIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const InternHomeScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TimerScreen()),
        );
        break;
      case 2:
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      onTap: () => _pickTime(_startTimeController),
                      decoration: _decor(
                        'Requested Start Time',
                        suffixIcon: const Icon(Icons.access_time_outlined),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Start time is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      onTap: () => _pickTime(_endTimeController),
                      decoration: _decor(
                        'Requested End Time',
                        suffixIcon: const Icon(Icons.hourglass_bottom_outlined),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'End time is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      decoration: _decor('Reason for adjustment'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Reason is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _proofNoteController,
                      maxLines: 2,
                      decoration: _decor('Proof note / attachment reference'),
                    ),
                    const SizedBox(height: 16),
                    if (_message != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _message!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: _message!.startsWith('Failed')
                                ? Colors.red[700]
                                : Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D4DB3),
                          foregroundColor: Colors.white,
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
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<TimeRequestModel>>(
                stream: AppServices.of(context)
                    .timeRequestRepository
                    .streamRequestsByIntern(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final requests = snapshot.data ?? [];

                  if (requests.isEmpty) {
                    return Center(
                      child: Text(
                        'No time requests yet.',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = requests[index];
                      final color = _statusColor(item.status);
                      final hasRemarks =
                          (item.reviewRemarks ?? '').trim().isNotEmpty;
                      final hasApprovedTime =
                          (item.approvedStartTime ?? '').trim().isNotEmpty ||
                              (item.approvedEndTime ?? '').trim().isNotEmpty;
                      final hasReviewedBy =
                          (item.reviewedBy ?? '').trim().isNotEmpty;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.requestedStartTime} - ${item.requestedEndTime}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: const Color(0xFF1C2434),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.reason,
                              style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusText(item.status),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            if (hasApprovedTime) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Approved Time: ${item.approvedStartTime ?? '-'} - ${item.approvedEndTime ?? '-'}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                            if (hasRemarks) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Supervisor Remarks:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.reviewRemarks!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  height: 1.45,
                                ),
                              ),
                            ],
                            if (hasReviewedBy) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Reviewed by: ${item.reviewedBy}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            if (item.reviewedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reviewed at: ${_formatDateTime(item.reviewedAt!)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = <(IconData, String)>[
      (Icons.home_rounded, 'Home'),
      (Icons.timer_rounded, 'Timer'),
      (Icons.edit_calendar_rounded, 'Requests'),
      (Icons.person_outline_rounded, 'Profile'),
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
}