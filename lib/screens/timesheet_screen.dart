import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import 'timer_screen.dart';
import 'profile_screen.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  int _selectedNavIndex = 2;

 void _handleBottomNavTap(int index) {
  if (index == 2) return;

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

    case 3:
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      break;
  }
}

  @override
  Widget build(BuildContext context) {
    return _TimesheetOverviewScreen(
      onGeneratePressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const GenerateTimesheetScreen(),
          ),
        );
      },
      bottomNav: _buildBottomNav(),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE9EEF5)),
        ),
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
                    color:
                        active ? const Color(0xFF0D4DB3) : Colors.grey[400],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? const Color(0xFF0D4DB3)
                          : Colors.grey[400],
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
}

class _TimesheetOverviewScreen extends StatelessWidget {
  final VoidCallback onGeneratePressed;
  final Widget bottomNav;

  const _TimesheetOverviewScreen({
    required this.onGeneratePressed,
    required this.bottomNav,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildCurrentObjectiveCard(),
                  const SizedBox(height: 16),
                  _buildLastSessionCard(),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 128,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: onGeneratePressed,
                        icon: const Icon(Icons.description_outlined, size: 15),
                        label: Text(
                          'Generate\nTimesheet',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D4DB3),
                          foregroundColor: Colors.white,
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
              ),
            ),
            bottomNav,
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFE86C3A),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'I',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Internship Monitor',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D4DB3),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF0D4DB3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentObjectiveCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'CURRENT OBJECTIVE',
              style: GoogleFonts.dmSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: const Color(0xFF1A3A6B),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Spatial Data\nIntegrity Audit',
            style: GoogleFonts.dmSans(
              fontSize: 17,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Execute comprehensive validation of GeoAI classification models across designated urban sectors.\nSupervisor: Dr. Elena Vance.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'TOTAL\nPROGRESS',
                  '84%',
                  const Color(0xFF0D4DB3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _metric(
                  'TARGET HOURS',
                  '320/400',
                  const Color(0xFF1C2434),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D4DB3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
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
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: Colors.grey[500],
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLastSessionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: Color(0xFF0D4DB3),
            ),
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
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '04:12:00',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yesterday, 14:30 — 18:42',
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
}

class GenerateTimesheetScreen extends StatefulWidget {
  const GenerateTimesheetScreen({super.key});

  @override
  State<GenerateTimesheetScreen> createState() => _GenerateTimesheetScreenState();
}

class _GenerateTimesheetScreenState extends State<GenerateTimesheetScreen> {
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  String _selectedAgeGroup = 'Not Specified';
  String _selectedGender = 'Male';
  String _selectedFormat = 'PDF';

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final mm = picked.month.toString().padLeft(2, '0');
      final dd = picked.day.toString().padLeft(2, '0');
      controller.text = '$mm/$dd/${picked.year}';
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        fontSize: 12,
        color: Colors.grey[500],
      ),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                    _buildHeroCard(),
                    const SizedBox(height: 18),
                    _buildSectionLabel(
                      Icons.calendar_today_outlined,
                      'PERIOD SELECTION',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startDateController,
                            readOnly: true,
                            onTap: () => _pickDate(_startDateController),
                            decoration: _fieldDecoration('mm/dd/yyyy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _endDateController,
                            readOnly: true,
                            onTap: () => _pickDate(_endDateController),
                            decoration: _fieldDecoration('mm/dd/yyyy'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSectionLabel(
                      Icons.settings_outlined,
                      'OPTIONAL METADATA',
                    ),
                    const SizedBox(height: 10),
                    _buildMetadataCard(),
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
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Generate report coming soon.',
                                style: GoogleFonts.dmSans(fontSize: 13),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          'GENERATE REPORT',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          const Icon(
            Icons.account_circle_outlined,
            color: Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
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
            'Official Report Builder',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These reports are formatted specifically for institutional submission to your school coordinators. Please ensure all data entered is accurate for validation.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withOpacity(0.88),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Age Group',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAgeGroup,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'Not Specified',
                    child: Text('Not Specified'),
                  ),
                  DropdownMenuItem(
                    value: '18-24',
                    child: Text('18-24'),
                  ),
                  DropdownMenuItem(
                    value: '25-34',
                    child: Text('25-34'),
                  ),
                  DropdownMenuItem(
                    value: '35+',
                    child: Text('35+'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedAgeGroup = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gender Identification',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildGenderChip('Male')),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderChip('Female')),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderChip('Other')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    final selected = _selectedGender == label;

    return GestureDetector(
      onTap: () => setState(() => _selectedGender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FF) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: const Color(0xFF0D4DB3), width: 1.2)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? const Color(0xFF0D4DB3) : Colors.grey[700],
            ),
          ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF0D4DB3)
                : const Color(0xFFE6EBF2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color:
                  selected ? const Color(0xFF0D4DB3) : Colors.grey[500],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C2434),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}