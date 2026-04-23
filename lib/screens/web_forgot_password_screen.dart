import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebForgotPasswordScreen extends StatefulWidget {
  const WebForgotPasswordScreen({super.key});

  @override
  State<WebForgotPasswordScreen> createState() =>
      _WebForgotPasswordScreenState();
}

class _WebForgotPasswordScreenState extends State<WebForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage =
            'A password reset link has been sent to your work email.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _mapResetError(e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send reset email. Please try again.';
      });
    }
  }

  String _mapResetError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'missing-email':
        return 'Email is required.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      default:
        return 'Unable to send reset email right now.';
    }
  }

  void _goBackToSignIn() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Container(
                    width: 420,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D4DB3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lock_reset,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Reset Supervisor Access',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF222222),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter your registered work email and we'll send\na secure link to reset your password.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              height: 1.6,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'WORK EMAIL',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(0xFF666666),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) {
                                _handleSendResetLink();
                              }
                            },
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'supervisor@geocore.com',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF2F2F4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              errorStyle:
                                  GoogleFonts.plusJakartaSans(fontSize: 11),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Work email is required.';
                              }
                              final email = value.trim();
                              if (!email.contains('@') || !email.contains('.')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            _buildErrorBanner(_errorMessage!),
                          ],
                          if (_successMessage != null) ...[
                            const SizedBox(height: 14),
                            _buildSuccessBanner(_successMessage!),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _handleSendResetLink,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D4DB3),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFF0D4DB3).withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 4,
                                shadowColor: Colors.black26,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Send Reset Link',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          InkWell(
                            onTap: _goBackToSignIn,
                            child: Text(
                              '← Back to Sign In',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF0D4DB3),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        children: [
          Text(
            'GeoAI OJT Monitoring',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none, size: 18, color: Colors.black54),
          const SizedBox(width: 14),
          const Icon(Icons.help_outline, size: 18, color: Colors.black54),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF0D4DB3),
            child: Text(
              'S',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFFC62828),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF2E7D32), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Row(
        children: [
          Text(
            '© 2026 GEOAI PRECISION SYSTEMS. ALL RIGHTS RESERVED.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: Colors.grey[500],
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          _buildFooterLink('PRIVACY POLICY'),
          const SizedBox(width: 20),
          _buildFooterLink('TERMS OF SERVICE'),
          const SizedBox(width: 20),
          _buildFooterLink('SUPPORT'),
          const SizedBox(width: 20),
          _buildFooterLink('SECURITY'),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        color: Colors.grey[500],
        letterSpacing: 1,
      ),
    );
  }
}