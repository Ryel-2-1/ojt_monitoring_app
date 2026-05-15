import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_model.dart';

class EvaluateScreen extends StatefulWidget {
  final UserModel intern;
  final double completedHours;
  final int requiredHours;

  const EvaluateScreen({
    super.key,
    required this.intern,
    required this.completedHours,
    required this.requiredHours,
  });

  @override
  State<EvaluateScreen> createState() => _EvaluateScreenState();
}

class _EvaluateScreenState extends State<EvaluateScreen> {
  final TextEditingController _observationsController =
      TextEditingController();

  bool _isSaving = false;

  static const Color _primary = Color(0xFF0D4DB3);
  static const Color _darkBlue = Color(0xFF0A2351);
  static const Color _bg = Color(0xFFF4F7FB);
  static const Color _border = Color(0xFFE7ECF3);
  static const Color _success = Color(0xFF14A44D);
  static const Color _danger = Color(0xFFC62828);

  final List<_EvaluationCriterion> _criteria = const [
    _EvaluationCriterion(
      key: 'workQuality',
      title: 'Work Quality',
      description: 'Accuracy and thoroughness of assigned work output.',
      icon: Icons.verified_outlined,
    ),
    _EvaluationCriterion(
      key: 'productivity',
      title: 'Productivity',
      description: 'Efficiency in completing assigned tasks.',
      icon: Icons.speed_outlined,
    ),
    _EvaluationCriterion(
      key: 'initiative',
      title: 'Initiative',
      description: 'Seeks new tasks and shows enthusiasm for learning.',
      icon: Icons.lightbulb_outline,
    ),
    _EvaluationCriterion(
      key: 'communicationSkills',
      title: 'Communication Skills',
      description: 'Clarity in verbal and written reporting.',
      icon: Icons.forum_outlined,
    ),
    _EvaluationCriterion(
      key: 'teamwork',
      title: 'Teamwork',
      description: 'Cooperation with peers and supervisors.',
      icon: Icons.groups_2_outlined,
    ),
    _EvaluationCriterion(
      key: 'attendancePunctuality',
      title: 'Attendance & Punctuality',
      description: 'Consistency in work hours and meeting deadlines.',
      icon: Icons.access_time_rounded,
    ),
    _EvaluationCriterion(
      key: 'professionalism',
      title: 'Professionalism',
      description: 'Adherence to workplace ethics and standards.',
      icon: Icons.work_outline_rounded,
    ),
  ];

  late final Map<String, int> _ratings = {
    for (final criterion in _criteria) criterion.key: 0,
  };

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _ratings.values.every((rating) => rating >= 1 && rating <= 5);
  }

  double get _averageRating {
    if (_ratings.isEmpty) return 0;
    final total = _ratings.values.fold<int>(0, (sum, rating) => sum + rating);
    return total / _ratings.length;
  }

  int get _totalScore {
    return _ratings.values.fold<int>(0, (sum, rating) => sum + rating);
  }

  double get _progress {
    if (widget.requiredHours <= 0) return 0;
    return (widget.completedHours / widget.requiredHours).clamp(0.0, 1.0);
  }

  Future<void> _saveEvaluation({required bool submit}) async {
    if (submit && !_canSubmit) {
      _showSnackBar(
        'Please rate all evaluation criteria before submitting.',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final services = AppServices.of(context);
      final currentUser = services.authService.currentUser;

      if (currentUser == null) {
        throw Exception('Supervisor account not detected.');
      }

      final supervisor = await services.userRepository.getUserByUid(
        currentUser.uid,
      );

      final docId = '${widget.intern.uid}_${currentUser.uid}';

      await FirebaseFirestore.instance.collection('evaluations').doc(docId).set(
        {
          'internUid': widget.intern.uid,
          'internName': widget.intern.fullName,
          'internEmail': widget.intern.email,
          'supervisorUid': currentUser.uid,
          'supervisorName': supervisor?.fullName ?? currentUser.displayName,
          'supervisorEmail': supervisor?.email ?? currentUser.email,
          'companyId': widget.intern.companyId,
          'companyName': widget.intern.companyName,
          'completedHours': widget.completedHours,
          'requiredHours': widget.requiredHours,
          'progressPercent': _progress * 100,
          'ratings': _ratings,
          'totalScore': _totalScore,
          'averageRating': _averageRating,
          'finalObservations': _observationsController.text.trim(),
          'status': submit ? 'submitted' : 'draft',
          'updatedAt': FieldValue.serverTimestamp(),
          if (submit) 'submittedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() => _isSaving = false);

      _showSnackBar(
        submit ? 'Evaluation submitted successfully.' : 'Evaluation draft saved.',
      );

      if (submit && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      _showSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isError ? _danger : _success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 820;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStudentSummary(isCompact: isCompact),
                            const SizedBox(height: 18),
                            _buildGuidelinesCard(),
                            const SizedBox(height: 18),
                            _buildCriteriaGrid(isCompact: isCompact),
                            const SizedBox(height: 18),
                            _buildObservationCard(),
                            const SizedBox(height: 28),
                            _buildActionButtons(isCompact: isCompact),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE9EEF5)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _isSaving
                ? null
                : () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Evaluations',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _darkBlue,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF1C2434),
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF1C2434),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSummary({required bool isCompact}) {
    if (isCompact) {
      return Column(
        children: [
          _buildStudentProfileCard(),
          const SizedBox(height: 14),
          _buildProgressCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: _buildStudentProfileCard()),
        const SizedBox(width: 18),
        Expanded(flex: 3, child: _buildProgressCard()),
      ],
    );
  }

  Widget _buildStudentProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      widget.intern.fullName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1C2434),
                      ),
                    ),
                    _buildActiveBadge(),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: ${widget.intern.uid}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoPill(
                      label: 'Company',
                      value: _cleanText(
                        widget.intern.companyName,
                        fallback: 'OJT Company',
                      ),
                    ),
                    _buildInfoPill(
                      label: 'Required Hours',
                      value: '${widget.requiredHours} hrs',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OVERALL PROGRESS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: (_progress * 100).toStringAsFixed(0),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: '%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.completedHours.toStringAsFixed(1)} of ${widget.requiredHours} total OJT hours completed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          _initialsOf(widget.intern.fullName),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _primary,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ACTIVE',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: _primary,
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1C2434),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE5E7EB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: _primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'EVALUATION GUIDELINES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _darkBlue,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Please provide a candid assessment based on the intern’s performance. Use the 1–5 scale where 1 is Unsatisfactory and 5 is Exceptional.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaGrid({required bool isCompact}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _criteria.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 1 : 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        mainAxisExtent: 156,
      ),
      itemBuilder: (context, index) {
        return _buildCriterionCard(_criteria[index]);
      },
    );
  }

  Widget _buildCriterionCard(_EvaluationCriterion criterion) {
    final selected = _ratings[criterion.key] ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  criterion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C2434),
                  ),
                ),
              ),
              Icon(
                criterion.icon,
                size: 18,
                color: _primary.withOpacity(0.55),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            criterion.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              height: 1.25,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final active = selected == rating;

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _ratings[criterion.key] = rating;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? _primary : const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$rating',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Supervisor’s Final Observations',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1C2434),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _observationsController,
            maxLines: 7,
            decoration: InputDecoration(
              hintText:
                  'Provide detailed feedback on strengths, areas for improvement, and overall growth trajectory...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: const Color(0xFFF1F3F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({required bool isCompact}) {
    final buttons = [
      SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _isSaving ? null : () => _saveEvaluation(submit: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBBD7FF),
            foregroundColor: _primary,
            disabledBackgroundColor: Colors.grey[300],
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Save Draft',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
      const SizedBox(width: 14, height: 14),
      SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : () => _saveEvaluation(submit: true),
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: Text(
            'Submit Evaluation',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ];

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons,
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

class _EvaluationCriterion {
  final String key;
  final String title;
  final String description;
  final IconData icon;

  const _EvaluationCriterion({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
  });
}
