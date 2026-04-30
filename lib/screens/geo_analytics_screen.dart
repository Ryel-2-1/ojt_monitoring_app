import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/company_model.dart';

class GeoAnalyticsScreen extends StatefulWidget {
  const GeoAnalyticsScreen({super.key});

  @override
  State<GeoAnalyticsScreen> createState() => _GeoAnalyticsScreenState();
}

class _GeoAnalyticsScreenState extends State<GeoAnalyticsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController(text: '50');

  bool _isSaving = false;
  bool _isFormExpanded = true;
  String? _editingCompanyId;
  String? _message;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _startEdit(CompanyModel company) {
    setState(() {
      _editingCompanyId = company.id;
      _companyNameController.text = company.companyName;
      _companyAddressController.text = company.companyAddress;
      _latitudeController.text = company.assignedLatitude.toString();
      _longitudeController.text = company.assignedLongitude.toString();
      _radiusController.text = company.allowedRadius.toStringAsFixed(0);
      _isFormExpanded = true;
      _message = null;
    });
  }

  void _clearForm() {
    setState(() {
      _editingCompanyId = null;
      _companyNameController.clear();
      _companyAddressController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _radiusController.text = '50';
      _message = null;
    });
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final repo = AppServices.of(context).companyRepository;
      final currentUser = AppServices.of(context).authService.currentUser;

      final lat = double.parse(_latitudeController.text.trim());
      final lng = double.parse(_longitudeController.text.trim());
      final radius = double.parse(_radiusController.text.trim());

      if (_editingCompanyId == null) {
        await repo.createCompany(
          companyName: _companyNameController.text.trim(),
          companyAddress: _companyAddressController.text.trim(),
          assignedLatitude: lat,
          assignedLongitude: lng,
          allowedRadius: radius,
          createdBySupervisorUid: currentUser?.uid,
        );
      } else {
        await repo.updateCompany(
          companyId: _editingCompanyId!,
          companyName: _companyNameController.text.trim(),
          companyAddress: _companyAddressController.text.trim(),
          assignedLatitude: lat,
          assignedLongitude: lng,
          allowedRadius: radius,
          isActive: true,
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _message = _editingCompanyId == null
            ? 'Company registered successfully.'
            : 'Company updated successfully.';
        _isFormExpanded = false;
      });

      _clearForm();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _message = 'Failed to save company. Please check the details and try again.';
      });
    }
  }

  Future<void> _toggleActive(CompanyModel company) async {
    if (company.id == null) return;

    try {
      await AppServices.of(context).companyRepository.setCompanyActive(
            companyId: company.id!,
            isActive: !company.isActive,
          );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update company status.'),
        ),
      );
    }
  }

  Future<void> _deleteCompany(CompanyModel company) async {
    if (company.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete company?'),
          content: Text(
            'This will remove "${company.companyName}" from the company registry. Existing intern records will not be automatically changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await AppServices.of(context).companyRepository.deleteCompany(company.id!);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete company.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AppServices.of(context).companyRepository;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
                  child: _buildCompanyForm(),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: StreamBuilder<List<CompanyModel>>(
                    stream: repo.streamCompanies(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0D4DB3),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return _buildStateCard(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load companies',
                          message:
                              'Please check your Firestore permissions and try again.',
                        );
                      }

                      final companies = snapshot.data ?? [];

                      if (companies.isEmpty) {
                        return _buildStateCard(
                          icon: Icons.business_outlined,
                          title: 'No companies registered yet',
                          message:
                              'Register partner companies here so interns can be assigned without manually encoding geofence data every time.',
                        );
                      }

                      return _buildCompanyList(companies);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Geo-Analytics',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0A2351),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Register partner companies and their geofence settings once, then assign interns to them later.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyForm() {
    final isEditing = _editingCompanyId != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() => _isFormExpanded = !_isFormExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_business_outlined,
                      color: Color(0xFF0D4DB3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Company Geofence' : 'Register Company',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0A2351),
                      ),
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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _buildMessageCard(),
            ),
          if (_isFormExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE7ECF3)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _companyNameController,
                      decoration: _decor('Company Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Company name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyAddressController,
                      maxLines: 2,
                      decoration: _decor('Company Address'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Company address is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _decor('Latitude'),
                            validator: _validateDouble,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _decor('Longitude'),
                            validator: _validateDouble,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _radiusController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decor('Allowed Radius in meters'),
                      validator: (value) {
                        final number = double.tryParse(value?.trim() ?? '');
                        if (number == null) return 'Required';
                        if (number <= 0) return 'Must be greater than 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_message != null) _buildMessageCard(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : _clearForm,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0D4DB3),
                                side: const BorderSide(
                                  color: Color(0xFF0D4DB3),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveCompany,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(isEditing
                                    ? Icons.save_outlined
                                    : Icons.add_rounded),
                            label: Text(
                              isEditing ? 'Save Changes' : 'Register Company',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D4DB3),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCompanyList(List<CompanyModel> companies) {
    final activeCount = companies.where((item) => item.isActive).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Partner Company Registry',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0A2351),
                ),
              ),
              const Spacer(),
              _buildSmallBadge('$activeCount active'),
              const SizedBox(width: 8),
              _buildSmallBadge('${companies.length} total'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: companies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildCompanyCard(companies[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(CompanyModel company) {
    final statusColor =
        company.isActive ? const Color(0xFF14A44D) : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  _initialsOf(company.companyName),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0D4DB3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1C2434),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      company.companyAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(
                company.isActive ? 'ACTIVE' : 'INACTIVE',
                statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Latitude',
                  value: company.assignedLatitude.toStringAsFixed(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.explore_outlined,
                  label: 'Longitude',
                  value: company.assignedLongitude.toStringAsFixed(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.radar_outlined,
                  label: 'Radius',
                  value: '${company.allowedRadius.toStringAsFixed(0)}m',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startEdit(company),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
                  label: Text(
                    'Edit Geofence',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D4DB3),
                    side: const BorderSide(color: Color(0xFF0D4DB3)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleActive(company),
                  icon: Icon(
                    company.isActive
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 17,
                  ),
                  label: Text(
                    company.isActive ? 'Deactivate' : 'Activate',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        company.isActive ? const Color(0xFFC62828) : const Color(0xFF14A44D),
                    side: BorderSide(
                      color:
                          company.isActive ? const Color(0xFFC62828) : const Color(0xFF14A44D),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _deleteCompany(company),
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFFC62828),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF0D4DB3)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C2434),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF0D4DB3),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageCard() {
    final isSuccess = _message?.contains('successfully') == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isSuccess ? const Color(0xFF14A44D) : const Color(0xFFC62828),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: isSuccess ? const Color(0xFF14A44D) : const Color(0xFFC62828),
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _message ?? '',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isSuccess ? const Color(0xFF1B5E20) : const Color(0xFFC62828),
              ),
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
        width: 440,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7ECF3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: const Color(0xFF0D4DB3)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0A2351),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decor(String hint) {
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
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
    );
  }

  String? _validateDouble(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Invalid number';
    return null;
  }

  String _initialsOf(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'C';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}