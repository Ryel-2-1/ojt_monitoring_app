import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
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
  String? _successMessage;

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
      _successMessage = null;
    });

    try {
      final userRepo = AppServices.of(context).userRepository;
      final user = await userRepo.getUserByUid(widget.userUid);

      if (user == null) {
        throw Exception('User document not found.');
      }

      _loadedUser = user;

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
        _errorMessage = 'Failed to load user: $e';
      });
    }
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
        borderRadius: BorderRadius.circular(8),
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
    final initial = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
      _successMessage = null;
    });

    try {
      final userRepo = AppServices.of(context).userRepository;

      await userRepo.updateUser(
        _loadedUser!.uid,
        {
          'companyName': _companyNameController.text.trim(),
          'companyAddress': _companyAddressController.text.trim(),
          'assignedLongitude': double.parse(_longitudeController.text.trim()),
          'assignedLatitude': double.parse(_latitudeController.text.trim()),
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
        _successMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Placement settings updated successfully.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save changes: $e';
        _successMessage = null;
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
              borderRadius: BorderRadius.circular(14),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student Placement Setup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure intern placement, geofence, and internship schedule.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Editing: ${_loadedUser!.fullName} | ${_loadedUser!.email} | UID: ${_loadedUser!.uid}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Required OJT Hours',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C2434),
                    ),
                  ),
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
                  const SizedBox(height: 30),
                  Text(
                    'Partner Company',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _companyNameController,
                                decoration: _fieldDecoration('Company Name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _companyAddressController,
                                decoration: _fieldDecoration('Company Address'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _longitudeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                decoration: _fieldDecoration('Longitude'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _latitudeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                decoration: _fieldDecoration('Latitude'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _radiusController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              _fieldDecoration('Allowed Radius (meters)'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Internship Duration',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(12),
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
                            decoration:
                                _fieldDecoration('Estimated End Date'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      _errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      _successMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 140,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D4DB3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'CONFIRM',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
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
}