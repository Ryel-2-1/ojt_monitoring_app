import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';

class EditGeofenceScreen extends StatefulWidget {
  final String userUid;

  const EditGeofenceScreen({
    super.key,
    required this.userUid,
  });

  @override
  State<EditGeofenceScreen> createState() => _EditGeofenceScreenState();
}

class _EditGeofenceScreenState extends State<EditGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _requiredHoursController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyAddressController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  final TextEditingController _internshipStartDateController =
      TextEditingController();
  final TextEditingController _internshipEndDateController =
      TextEditingController();

  bool _isSaving = false;
  bool _isLoadingUser = true;
  bool _didLoadUser = false;

  String? _errorMessage;
  String? _selectedCompanyId;

  UserModel? _loadedUser;
  DateTime? _internshipStartDate;
  DateTime? _internshipEndDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadUser) return;
    _didLoadUser = true;
    _loadUser();
  }

  @override
  void dispose() {
    _requiredHoursController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _longitudeController.dispose();
    _latitudeController.dispose();
    _radiusController.dispose();
    _internshipStartDateController.dispose();
    _internshipEndDateController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoadingUser = true;
      _errorMessage = null;
    });

    try {
      final userRepo = AppServices.of(context).userRepository;
      final user = await userRepo.getUserByUid(widget.userUid);

      if (user == null) {
        throw Exception('User document not found.');
      }

      _loadedUser = user;
      _selectedCompanyId = user.companyId;

      _requiredHoursController.text = (user.requiredOjtHours ?? 0).toString();
      _companyNameController.text = user.companyName ?? '';
      _companyAddressController.text = user.companyAddress ?? '';
      _longitudeController.text = user.assignedLongitude?.toString() ?? '';
      _latitudeController.text = user.assignedLatitude?.toString() ?? '';
      _radiusController.text = user.allowedRadius?.toStringAsFixed(0) ?? '';

      _internshipStartDate = user.internshipStartDate;
      _internshipEndDate = user.internshipEndDate;

      _internshipStartDateController.text =
          _internshipStartDate != null ? _formatDate(_internshipStartDate!) : '';
      _internshipEndDateController.text =
          _internshipEndDate != null ? _formatDate(_internshipEndDate!) : '';

      if (!mounted) return;
      setState(() {
        _isLoadingUser = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingUser = false;
        _errorMessage = 'Failed to load user. Please try again.';
      });
    }
  }

  void _applyCompany(CompanyModel company) {
    setState(() {
      _selectedCompanyId = company.id;
      _companyNameController.text = company.companyName;
      _companyAddressController.text = company.companyAddress;
      _latitudeController.text = company.assignedLatitude.toString();
      _longitudeController.text = company.assignedLongitude.toString();
      _radiusController.text = company.allowedRadius.toStringAsFixed(0);
      _errorMessage = null;
    });
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: Colors.grey[400],
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      errorStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffixIcon,
    );
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$mm/$dd/$yyyy';
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController controller,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = _formatDate(picked);
      onPicked(picked);
    }
  }

  Future<void> _handleSave() async {
    if (_loadedUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final userRepo = AppServices.of(context).userRepository;

      await userRepo.updateUser(
        _loadedUser!.uid,
        {
          'companyId': _selectedCompanyId,
          'companyName': _companyNameController.text.trim(),
          'companyAddress': _companyAddressController.text.trim(),
          'assignedLatitude': double.parse(_latitudeController.text.trim()),
          'assignedLongitude': double.parse(_longitudeController.text.trim()),
          'allowedRadius': double.parse(_radiusController.text.trim()),
          'requiredOjtHours':
              int.tryParse(_requiredHoursController.text.trim()) ?? 480,
          'internshipStartDate': _internshipStartDate,
          'internshipEndDate': _internshipEndDate,
        },
      );

      await _loadUser();

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student assignment updated successfully.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save assignment. Please check the details and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadedUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Text(
            _errorMessage ?? 'User not found.',
            style: GoogleFonts.plusJakartaSans(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7ECF3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student Assignment Setup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0A2351),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Assign this intern to a registered partner company. The company geofence will be applied automatically.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInternHeader(),
                  const SizedBox(height: 24),
                  _buildRequiredHoursSection(),
                  const SizedBox(height: 24),
                  _buildPartnerCompanySection(),
                  const SizedBox(height: 24),
                  _buildInternshipDurationSection(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _buildErrorBox(_errorMessage!),
                  ],
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 190,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Assignment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D4DB3),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInternHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F0FF),
            child: Text(
              _initialsOf(_loadedUser!.fullName),
              style: GoogleFonts.plusJakartaSans(
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
                  _loadedUser!.fullName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _loadedUser!.email,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Required OJT Hours'),
        const SizedBox(height: 10),
        TextFormField(
          controller: _requiredHoursController,
          keyboardType: TextInputType.number,
          decoration: _fieldDecoration('480'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Required OJT hours is required';
            }
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed <= 0) {
              return 'Enter a valid number of hours';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPartnerCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Partner Company'),
        const SizedBox(height: 10),
        StreamBuilder<List<CompanyModel>>(
          stream: AppServices.of(context)
              .companyRepository
              .streamCompanies(activeOnly: true),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorBox(
                'Could not load partner companies. Please check Firestore permissions.',
              );
            }

            final companies = snapshot.data ?? [];

            if (companies.isEmpty) {
              return _buildInfoBox(
                icon: Icons.business_outlined,
                title: 'No partner companies yet',
                message:
                    'Go to Geo-Analytics and register a company first before assigning interns.',
              );
            }

            CompanyModel? selectedCompany;
            for (final company in companies) {
              if (company.id == _selectedCompanyId) {
                selectedCompany = company;
                break;
              }
            }

            return Column(
              children: [
                DropdownButtonFormField<CompanyModel>(
                  value: selectedCompany,
                  isExpanded: true,
                  decoration: _fieldDecoration('Select registered company'),
                  items: companies.map((company) {
                    return DropdownMenuItem<CompanyModel>(
                      value: company,
                      child: Text(
                        company.companyName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (company) {
                    if (company != null) _applyCompany(company);
                  },
                  validator: (_) {
                    if (_selectedCompanyId == null ||
                        _selectedCompanyId!.trim().isEmpty) {
                      return 'Please select a company';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildSelectedCompanyPreview(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedCompanyPreview() {
    final hasCompany = _companyNameController.text.trim().isNotEmpty;

    if (!hasCompany) {
      return _buildInfoBox(
        icon: Icons.info_outline_rounded,
        title: 'Company geofence not selected',
        message:
            'Select a registered company above to auto-fill latitude, longitude, address, and radius.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _companyNameController,
            readOnly: true,
            decoration: _fieldDecoration('Company Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyAddressController,
            readOnly: true,
            decoration: _fieldDecoration('Company Address'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  readOnly: true,
                  decoration: _fieldDecoration('Latitude'),
                  validator: _validateLatitude,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  readOnly: true,
                  decoration: _fieldDecoration('Longitude'),
                  validator: _validateLongitude,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _radiusController,
                  readOnly: true,
                  decoration: _fieldDecoration('Radius'),
                  validator: _validateRadius,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInternshipDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Internship Duration'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7ECF3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _internshipStartDateController,
                  readOnly: true,
                  onTap: () => _pickDate(
                    context,
                    _internshipStartDateController,
                    (value) => _internshipStartDate = value,
                  ),
                  decoration: _fieldDecoration('Start Date'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Start date is required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _internshipEndDateController,
                  readOnly: true,
                  onTap: () => _pickDate(
                    context,
                    _internshipEndDateController,
                    (value) => _internshipEndDate = value,
                  ),
                  decoration: _fieldDecoration('Estimated End Date'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'End date is required';
                    }
                    if (_internshipStartDate != null &&
                        _internshipEndDate != null &&
                        _internshipEndDate!.isBefore(_internshipStartDate!)) {
                      return 'End date must be after start';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF1C2434),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E6FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0D4DB3), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0D4DB3),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF1C2434),
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

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFFC62828),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateLatitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Invalid latitude';
    if (number < -90 || number > 90) return 'Latitude must be -90 to 90';
    return null;
  }

  String? _validateLongitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Invalid longitude';
    if (number < -180 || number > 180) return 'Longitude must be -180 to 180';
    return null;
  }

  String? _validateRadius(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Invalid radius';
    if (number <= 0) return 'Must be greater than 0';
    return null;
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}