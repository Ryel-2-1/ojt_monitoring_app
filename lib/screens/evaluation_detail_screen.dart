import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

class EvaluationDetailScreen extends StatelessWidget {
  final String evaluationId;
  final String title;

  const EvaluationDetailScreen({
    super.key,
    required this.evaluationId,
    this.title = 'Final Evaluation',
  });

  static const Color _primary = Color(0xFF0D4DB3);
  static const Color _navy = Color(0xFF0A2351);
  static const Color _success = Color(0xFF14A44D);

  bool _isDarkMode(BuildContext context) =>
      AppServices.of(context).themeController.isDarkMode;

  Color _background(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF0B1120) : const Color(0xFFF4F7FB);

  Color _cardColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF0F172A) : Colors.white;

  Color _softCardColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF111827) : const Color(0xFFF8FAFD);

  Color _borderColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF243244) : const Color(0xFFE7ECF3);

  Color _titleColor(BuildContext context) =>
      _isDarkMode(context) ? Colors.white : _navy;

  Color _bodyColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFFD1D5DB) : const Color(0xFF374151);

  Color _mutedColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppServices.of(context).themeController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background(context),
          body: SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('evaluations')
                  .doc(evaluationId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                if (snapshot.hasError) {
                  return _buildMessage(
                    context,
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load evaluation',
                    message: 'Please check your connection and try again.',
                  );
                }

                final data = snapshot.data?.data();

                if (data == null || data['status']?.toString() != 'submitted') {
                  return _buildMessage(
                    context,
                    icon: Icons.assignment_late_outlined,
                    title: 'No submitted evaluation yet',
                    message:
                        'The final evaluation has not been submitted for this intern.',
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(context),
                          const SizedBox(height: 18),
                          _buildSummaryCards(context, data),
                          const SizedBox(height: 18),
                          _buildRatingsCard(context, data),
                          const SizedBox(height: 18),
                          _buildObservationsCard(context, data),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _titleColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, dynamic> data) {
    final average = _toDouble(data['averageRating']);
    final totalScore = _toInt(data['totalScore']);
    final completedHours = _toDouble(data['completedHours']);
    final requiredHours = _toInt(data['requiredHours']);
    final submittedAt = _formatTimestamp(data['submittedAt']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 850;
        final left = _buildInternCard(context, data, submittedAt);
        final right = _buildScoreCard(
          context,
          average: average,
          totalScore: totalScore,
          completedHours: completedHours,
          requiredHours: requiredHours,
        );

        if (!isWide) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: left),
            const SizedBox(width: 18),
            Expanded(flex: 3, child: right),
          ],
        );
      },
    );
  }

  Widget _buildInternCard(
    BuildContext context,
    Map<String, dynamic> data,
    String submittedAt,
  ) {
    final internName = _clean(data['internName'], 'Intern');
    final internEmail = _clean(data['internEmail'], 'No email');
    final companyName = _clean(data['companyName'], 'No company');
    final supervisorName = _clean(data['supervisorName'], 'Supervisor');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: _isDarkMode(context) ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                _initials(internName),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _isDarkMode(context) ? const Color(0xFF93C5FD) : _primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  internName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _titleColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  internEmail,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _mutedColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _infoChip(context, Icons.business_outlined, companyName),
                    _infoChip(context, Icons.person_pin_outlined, supervisorName),
                    _infoChip(context, Icons.check_circle_outline_rounded,
                        'Submitted: $submittedAt'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(
    BuildContext context, {
    required double average,
    required int totalScore,
    required double completedHours,
    required int requiredHours,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (!_isDarkMode(context))
            BoxShadow(
              color: _primary.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINAL SCORE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${average.toStringAsFixed(1)} / 5',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total Score: $totalScore',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${completedHours.toStringAsFixed(1)} of $requiredHours OJT hours completed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsCard(BuildContext context, Map<String, dynamic> data) {
    final rawRatings = data['ratings'];
    final ratings = rawRatings is Map ? rawRatings : <String, dynamic>{};

    final items = <_RatingItem>[
      _RatingItem('Work Quality', _toInt(ratings['workQuality'])),
      _RatingItem('Productivity', _toInt(ratings['productivity'])),
      _RatingItem('Initiative', _toInt(ratings['initiative'])),
      _RatingItem('Communication Skills', _toInt(ratings['communication'])),
      _RatingItem('Professionalism', _toInt(ratings['professionalism'])),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, Icons.fact_check_outlined, 'Evaluation Ratings'),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _bodyColor(context),
                      ),
                    ),
                  ),
                  _ratingPill(context, item.value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsCard(BuildContext context, Map<String, dynamic> data) {
    final observations = _clean(
      data['finalObservations'],
      'No final observations were provided.',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            context,
            Icons.notes_outlined,
            'Supervisor\'s Final Observations',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _softCardColor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Text(
              observations,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: _bodyColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _titleColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _softCardColor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _bodyColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingPill(BuildContext context, int value) {
    return Container(
      width: 58,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _success.withValues(alpha: _isDarkMode(context) ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$value / 5',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: _success,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: _cardColor(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _borderColor(context)),
      boxShadow: [
        if (!_isDarkMode(context))
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
      ],
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _primary, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _titleColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _mutedColor(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _clean(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatTimestamp(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value != null) {
      date = DateTime.tryParse(value.toString());
    }

    if (date == null) return 'Not available';

    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'IN';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _RatingItem {
  final String label;
  final int value;

  const _RatingItem(this.label, this.value);
}
