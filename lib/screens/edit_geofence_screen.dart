import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_model.dart';

class EditGeofenceScreen extends StatefulWidget {
  final UserModel user;

  const EditGeofenceScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditGeofenceScreen> createState() => _EditGeofenceScreenState();
}

class _EditGeofenceScreenState extends State<EditGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _requiredHoursController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyAddressController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _radiusController;
  late final TextEditingController _internshipStartDateController;
  late final TextEditingController _internshipEndDateController;

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  DateTime? _internshipStartDate;
  DateTime? _internshipEndDate;

  @override
  void initState() {
    super.initState();

    _requiredHoursController = TextEditingController(
      text: (widget.user.requiredOjtHours ?? 480).toString(),
    );

    _companyNameController = TextEditingController(
      text: widget.user.companyName ?? '',
    );
    _companyAddressController = TextEditingController(
      text: widget.user.companyAddress ?? '',
    );
    _longitudeController = TextEditingController(
      text: widget.user.assignedLongitude?.toString() ?? '',
    );
    _latitudeController = TextEditingController(
      text: widget.user.assignedLatitude?.toString() ?? '',
    );
    _radiusController = TextEditingController(
      text: widget.user.allowedRadius?.toStringAsFixed(0) ?? '',
    );

    _internshipStartDate = widget.user.internshipStartDate;
    _internshipEndDate = widget.user.internshipEndDate;

    _internshipStartDateController = TextEditingController(
      text: _internshipStartDate != null ? _formatDate(_internshipStartDate!) : '',
    );
    _internshipEndDateController = TextEditingController(
      text: _internshipEndDate != null ? _formatDate(_internshipEndDate!) : '',
    );
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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text = _formatDate(picked);
      onPicked(picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final userRepo = AppServices.of(context).userRepository;

      await userRepo.updateUser(
        widget.user.uid,
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

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successMessage = 'Placement settings saved successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save placement settings: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                const SizedBox(height: 30),

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
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Company name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _companyAddressController,
                              decoration: _fieldDecoration('Company Address'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Company address is required';
                                }
                                return null;
                              },
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
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: _fieldDecoration('Longitude'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Longitude is required';
                                }
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null) return 'Enter a valid longitude';
                                if (parsed < -180 || parsed > 180) {
                                  return 'Longitude must be between -180 and 180';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration: _fieldDecoration('Latitude'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Latitude is required';
                                }
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null) return 'Enter a valid latitude';
                                if (parsed < -90 || parsed > 90) {
                                  return 'Latitude must be between -90 and 90';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _radiusController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _fieldDecoration('Allowed Radius (meters)'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Radius is required';
                            }
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null) return 'Enter a valid radius';
                            if (parsed <= 0) return 'Radius must be greater than 0';
                            return null;
                          },
                        ),
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
                              return 'Estimated end date is required';
                            }
                            return null;
                          },
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
    );
  }
}