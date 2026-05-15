import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/time_request_model.dart';
import '../repositories/time_request_repository.dart';

class TimeRequestsScreen extends StatefulWidget {
  const TimeRequestsScreen({super.key});

  @override
  State<TimeRequestsScreen> createState() => _TimeRequestsScreenState();
}

class _TimeRequestsScreenState extends State<TimeRequestsScreen> {
  static const Color _blue = Color(0xFF0D4DB3);
  static const Color _navy = Color(0xFF0A2351);
  static const Color _green = Color(0xFF14A44D);
  static const Color _orange = Color(0xFFF5A623);
  static const Color _red = Color(0xFFC62828);

  String _selectedFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Pending',
    'Approved',
    'Rejected',
  ];

  bool get _isDarkMode => AppServices.of(context).themeController.isDarkMode;

  Color get _pageTextColor =>
      _isDarkMode ? Colors.white : const Color(0xFF0A2351);

  Color get _bodyTextColor =>
      _isDarkMode ? const Color(0xFFE5E7EB) : const Color(0xFF1C2434);

  Color get _mutedTextColor =>
      _isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  Color get _cardColor =>
      _isDarkMode ? const Color(0xFF0F172A) : Colors.white;

  Color get _softCardColor =>
      _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFD);

  Color get _inputColor =>
      _isDarkMode ? const Color(0xFF0B1120) : const Color(0xFFF5F7FA);

  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF243244) : const Color(0xFFE7ECF3);

  @override
  Widget build(BuildContext context) {
    final repo = AppServices.of(context).timeRequestRepository;
    final themeController = AppServices.of(context).themeController;

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildFilterBar(),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<TimeRequestModel>>(
                  stream: repo.streamAllRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _blue),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildStateMessage(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load time requests',
                        message:
                            'Please check your connection or Firestore permissions and try again.',
                      );
                    }

                    final requests = snapshot.data ?? [];
                    final filteredRequests = _filterRequests(requests);

                    if (filteredRequests.isEmpty) {
                      return _buildEmptyLayout(requests);
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildRequestList(filteredRequests),
                        ),
                        const SizedBox(width: 20),
                        _buildSummaryPanel(requests),
                      ],
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: _pageTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Review intern missing-time requests, add supervisor remarks, and approve verified adjustments.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: _mutedTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
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
        Wrap(
          spacing: 8,
          children: _filters.map((filter) {
            final active = _selectedFilter == filter;

            return InkWell(
              onTap: () => setState(() => _selectedFilter = filter),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? _blue : _cardColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? _blue : _borderColor,
                  ),
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : _pageTextColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyLayout(List<TimeRequestModel> allRequests) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildStateMessage(
            icon: Icons.inbox_outlined,
            title: 'No time requests found',
            message: _selectedFilter == 'All'
                ? 'Requests submitted by interns will appear here for review.'
                : 'No ${_selectedFilter.toLowerCase()} requests match the selected filter.',
          ),
        ),
        const SizedBox(width: 20),
        _buildSummaryPanel(allRequests),
      ],
    );
  }

  Widget _buildRequestList(List<TimeRequestModel> requests) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Review Queue',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _pageTextColor,
                ),
              ),
              const Spacer(),
              _buildCountBadge('${requests.length} request(s)'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _buildRequestCard(requests[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(TimeRequestModel request) {
    final statusColor = _statusColor(request.status);
    final isPending = request.status == TimeRequestStatus.pending;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _softCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _isDarkMode
                    ? const Color(0xFF1F2937)
                    : const Color(0xFFE8F0FF),
                child: Text(
                  _initialsOf(request.internName),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.internName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _pageTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.internEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(request.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Request Date',
                  value: _formatDate(request.requestDate),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.schedule_rounded,
                  label: 'Requested Time',
                  value:
                      '${request.requestedStartTime} - ${request.requestedEndTime}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.access_time_rounded,
                  label: 'Submitted',
                  value: _formatDateTime(request.submittedAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextBlock(
            icon: Icons.edit_note_rounded,
            title: 'Reason',
            text: request.reason,
          ),
          if (request.proofNote.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildTextBlock(
              icon: Icons.attachment_outlined,
              title: 'Proof Note',
              text: request.proofNote,
            ),
          ],
          const SizedBox(height: 14),
          if (isPending)
            _buildReviewPanel(request)
          else
            _buildReviewedPanel(request, statusColor),
        ],
      ),
    );
  }

  Widget _buildReviewPanel(TimeRequestModel request) {
    final approvedStartController = TextEditingController(
      text: request.approvedStartTime?.trim().isNotEmpty == true
          ? request.approvedStartTime
          : request.requestedStartTime,
    );

    final approvedEndController = TextEditingController(
      text: request.approvedEndTime?.trim().isNotEmpty == true
          ? request.approvedEndTime
          : request.requestedEndTime,
    );

    final remarksController = TextEditingController();
    bool isProcessing = false;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        Future<void> submitReview(TimeRequestStatus status) async {
          setLocalState(() => isProcessing = true);

          final authService = AppServices.of(context).authService;
          final repository = AppServices.of(context).timeRequestRepository;
          final messenger = ScaffoldMessenger.of(context);

          try {
            final currentUser = authService.currentUser;

            await repository.reviewRequest(
              requestId: request.id!,
              status: status,
              reviewedBy: currentUser?.email ?? currentUser?.uid ?? 'Supervisor',
              reviewRemarks: remarksController.text.trim(),
              approvedStartTime: approvedStartController.text.trim(),
              approvedEndTime: approvedEndController.text.trim(),
            );

            if (!mounted) return;

            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  status == TimeRequestStatus.approved
                      ? 'Time request approved successfully.'
                      : 'Time request rejected.',
                ),
              ),
            );
          } on TimeRequestReviewException catch (e) {
            if (!mounted) return;

            messenger.showSnackBar(
              SnackBar(
                backgroundColor: _orange,
                content: Text(e.message),
              ),
            );
          } catch (_) {
            if (!mounted) return;

            messenger.showSnackBar(
              const SnackBar(
                content: Text('Failed to review request. Please try again.'),
              ),
            );
          } finally {
            if (mounted) {
              setLocalState(() => isProcessing = false);
            }
          }
        }

        Future<void> pickTime(TextEditingController controller) async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _parseTimeOfDay(controller.text) ?? TimeOfDay.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: _blue,
                    brightness: _isDarkMode ? Brightness.dark : Brightness.light,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (picked == null) return;

          setLocalState(() {
            controller.text = _formatPickedTime(picked);
          });
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF0B1120) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor Review',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _pageTextColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: approvedStartController,
                      readOnly: true,
                      style: GoogleFonts.plusJakartaSans(
                        color: _pageTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                      onTap: isProcessing
                          ? null
                          : () => pickTime(approvedStartController),
                      decoration: _inputDecor(
                        'Approved Start',
                        suffixIcon: const Icon(Icons.access_time_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: approvedEndController,
                      readOnly: true,
                      style: GoogleFonts.plusJakartaSans(
                        color: _pageTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                      onTap:
                          isProcessing ? null : () => pickTime(approvedEndController),
                      decoration: _inputDecor(
                        'Approved End',
                        suffixIcon: const Icon(Icons.timer_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksController,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(
                  color: _pageTextColor,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _inputDecor(
                  'Supervisor remarks',
                  suffixIcon: const Icon(Icons.rate_review_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => submitReview(TimeRequestStatus.rejected),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => submitReview(TimeRequestStatus.approved),
                      icon: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        'Approve',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _isDarkMode ? const Color(0xFF1F2937) : Colors.grey[300],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewedPanel(
    TimeRequestModel request,
    Color statusColor,
  ) {
    final hasApprovedTime =
        request.approvedStartTime?.trim().isNotEmpty == true ||
            request.approvedEndTime?.trim().isNotEmpty == true;

    final hasRemarks = request.reviewRemarks?.trim().isNotEmpty == true;
    final hasReviewedBy = request.reviewedBy?.trim().isNotEmpty == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: _isDarkMode ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: _isDarkMode ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Result',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          if (hasApprovedTime)
            _buildResultLine(
              icon: Icons.schedule_rounded,
              label: 'Approved Time',
              value:
                  '${request.approvedStartTime ?? '-'} - ${request.approvedEndTime ?? '-'}',
              color: statusColor,
            ),
          if (hasRemarks) ...[
            const SizedBox(height: 6),
            _buildResultLine(
              icon: Icons.rate_review_outlined,
              label: 'Remarks',
              value: request.reviewRemarks!,
              color: statusColor,
            ),
          ],
          if (hasReviewedBy || request.reviewedAt != null) ...[
            const SizedBox(height: 6),
            _buildResultLine(
              icon: Icons.verified_user_outlined,
              label: 'Reviewed',
              value: [
                if (hasReviewedBy) 'by ${request.reviewedBy}',
                if (request.reviewedAt != null)
                  'on ${_formatDateTime(request.reviewedAt!)}',
              ].join(' '),
              color: statusColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultLine({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _bodyTextColor,
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
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _mutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _bodyTextColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextBlock({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF0B1120) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _blue),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _mutedTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _bodyTextColor,
                    fontWeight: FontWeight.w600,
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

  Widget _buildStatusBadge(TimeRequestStatus status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _statusText(status),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(List<TimeRequestModel> requests) {
    final pending = requests
        .where((item) => item.status == TimeRequestStatus.pending)
        .length;
    final approved = requests
        .where((item) => item.status == TimeRequestStatus.approved)
        .length;
    final rejected = requests
        .where((item) => item.status == TimeRequestStatus.rejected)
        .length;

    return SizedBox(
      width: 260,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildSummaryCard(
            icon: Icons.inbox_outlined,
            label: 'TOTAL REQUESTS',
            value: '${requests.length}',
            color: _blue,
          ),
          const SizedBox(height: 14),
          _buildSummaryCard(
            icon: Icons.pending_actions_outlined,
            label: 'PENDING',
            value: '$pending',
            color: _orange,
          ),
          const SizedBox(height: 14),
          _buildSummaryCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'APPROVED',
            value: '$approved',
            color: _green,
          ),
          const SizedBox(height: 14),
          _buildSummaryCard(
            icon: Icons.cancel_outlined,
            label: 'REJECTED',
            value: '$rejected',
            color: _red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: _isDarkMode ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _mutedTextColor,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _pageTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: _blue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _pageTextColor,
              ),
            ),
            const SizedBox(height: 6),
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

  Widget _buildCountBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _isDarkMode ? const Color(0xFF243244) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _isDarkMode ? const Color(0xFF93C5FD) : _blue,
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: _mutedTextColor,
      ),
      filled: true,
      fillColor: _inputColor,
      suffixIcon: suffixIcon == null
          ? null
          : IconTheme(
              data: IconThemeData(color: _mutedTextColor, size: 19),
              child: suffixIcon,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
    );
  }

  List<TimeRequestModel> _filterRequests(List<TimeRequestModel> requests) {
    switch (_selectedFilter) {
      case 'Pending':
        return requests
            .where((item) => item.status == TimeRequestStatus.pending)
            .toList();
      case 'Approved':
        return requests
            .where((item) => item.status == TimeRequestStatus.approved)
            .toList();
      case 'Rejected':
        return requests
            .where((item) => item.status == TimeRequestStatus.rejected)
            .toList();
      case 'All':
      default:
        return requests;
    }
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

  String _formatPickedTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $suffix';
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm/$dd/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final date = _formatDate(dateTime);
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';

    return '$date • $hour12:$minute $suffix';
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

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
