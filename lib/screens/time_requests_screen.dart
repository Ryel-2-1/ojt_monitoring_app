import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/time_request_model.dart';

class TimeRequestsScreen extends StatefulWidget {
  const TimeRequestsScreen({super.key});

  @override
  State<TimeRequestsScreen> createState() => _TimeRequestsScreenState();
}

class _TimeRequestsScreenState extends State<TimeRequestsScreen> {
  final Map<String, TextEditingController> _remarksControllers = {};
  final Map<String, TextEditingController> _approvedStartControllers = {};
  final Map<String, TextEditingController> _approvedEndControllers = {};

  TextEditingController _remarksOf(String id, String initialValue) {
    return _remarksControllers.putIfAbsent(
      id,
      () => TextEditingController(text: initialValue),
    );
  }

  TextEditingController _approvedStartOf(String id, String initialValue) {
    return _approvedStartControllers.putIfAbsent(
      id,
      () => TextEditingController(text: initialValue),
    );
  }

  TextEditingController _approvedEndOf(String id, String initialValue) {
    return _approvedEndControllers.putIfAbsent(
      id,
      () => TextEditingController(text: initialValue),
    );
  }

  @override
  void dispose() {
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    for (final c in _approvedStartControllers.values) {
      c.dispose();
    }
    for (final c in _approvedEndControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final suffix = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.text = '$hour:$minute $suffix';
    }
  }

  Future<void> _reviewRequest(
    TimeRequestModel request,
    TimeRequestStatus status,
  ) async {
    final currentUser = AppServices.of(context).authService.currentUser;
    final requestId = request.id!;
    final remarks = _remarksOf(requestId, request.reviewRemarks ?? '').text.trim();
    final approvedStart = _approvedStartOf(
      requestId,
      request.approvedStartTime ?? request.requestedStartTime,
    ).text.trim();
    final approvedEnd = _approvedEndOf(
      requestId,
      request.approvedEndTime ?? request.requestedEndTime,
    ).text.trim();

    if (status == TimeRequestStatus.approved) {
      if (approvedStart.isEmpty || approvedEnd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approved start and end time are required.'),
          ),
        );
        return;
      }
    }

    try {
      await AppServices.of(context).timeRequestRepository.reviewRequest(
        requestId: requestId,
        status: status,
        reviewedBy: currentUser?.email ?? currentUser?.uid ?? 'supervisor',
        reviewRemarks: remarks,
        approvedStartTime:
            status == TimeRequestStatus.approved ? approvedStart : null,
        approvedEndTime:
            status == TimeRequestStatus.approved ? approvedEnd : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == TimeRequestStatus.approved
                ? 'Request approved successfully.'
                : 'Request rejected successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to review request: $e')),
      );
    }
  }

  Color _statusColor(TimeRequestStatus status) {
    switch (status) {
      case TimeRequestStatus.pending:
        return const Color(0xFFF59E0B);
      case TimeRequestStatus.approved:
        return const Color(0xFF16A34A);
      case TimeRequestStatus.rejected:
        return const Color(0xFFDC2626);
    }
  }

  String _statusLabel(TimeRequestStatus status) {
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
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: Colors.grey[500],
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: StreamBuilder<List<TimeRequestModel>>(
        stream: AppServices.of(context).timeRequestRepository.streamAllRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load time requests: ${snapshot.error}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.red[700],
                ),
              ),
            );
          }

          final requests = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Requests',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0A2351),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Review and approve intern time adjustment requests.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: requests.isEmpty
                    ? Center(
                        child: Text(
                          'No time requests found.',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: requests.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = requests[index];
                          final isPending =
                              item.status == TimeRequestStatus.pending;
                          final requestId = item.id!;

                          final remarksController = _remarksOf(
                            requestId,
                            item.reviewRemarks ?? '',
                          );
                          final approvedStartController = _approvedStartOf(
                            requestId,
                            item.approvedStartTime ?? item.requestedStartTime,
                          );
                          final approvedEndController = _approvedEndOf(
                            requestId,
                            item.approvedEndTime ?? item.requestedEndTime,
                          );

                          final badgeColor = _statusColor(item.status);

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE7ECF3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.internName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.internEmail,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Request Date: ${_formatDate(item.requestDate)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Requested Time: ${item.requestedStartTime} - ${item.requestedEndTime}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Reason: ${item.reason}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if ((item.proofNote).trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Proof Note: ${item.proofNote}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: approvedStartController,
                                        readOnly: !isPending,
                                        onTap: isPending
                                            ? () => _pickTime(approvedStartController)
                                            : null,
                                        decoration: _fieldDecoration(
                                          'Approved Start Time',
                                          suffixIcon: const Icon(
                                            Icons.access_time_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: approvedEndController,
                                        readOnly: !isPending,
                                        onTap: isPending
                                            ? () => _pickTime(approvedEndController)
                                            : null,
                                        decoration: _fieldDecoration(
                                          'Approved End Time',
                                          suffixIcon: const Icon(
                                            Icons.hourglass_bottom_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: remarksController,
                                  readOnly: !isPending,
                                  maxLines: 2,
                                  decoration:
                                      _fieldDecoration('Supervisor remarks'),
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(item.status),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isPending) ...[
                                      OutlinedButton(
                                        onPressed: () => _reviewRequest(
                                          item,
                                          TimeRequestStatus.rejected,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF4B5563),
                                          side: const BorderSide(
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                        child: const Text('Reject'),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        onPressed: () => _reviewRequest(
                                          item,
                                          TimeRequestStatus.approved,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1D4ED8),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                        child: const Text('Approve'),
                                      ),
                                    ] else ...[
                                      if (item.reviewedBy != null)
                                        Text(
                                          'Reviewed by: ${item.reviewedBy}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}