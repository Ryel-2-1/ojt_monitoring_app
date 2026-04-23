import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/auth_service.dart';

class WebRegisterScreen extends StatefulWidget {
  const WebRegisterScreen({super.key});

  @override
  State<WebRegisterScreen> createState() => _WebRegisterScreenState();
}

class _WebRegisterScreenState extends State<WebRegisterScreen> {
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'You must agree to the Terms and Privacy Policy.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AppServices.of(context).authService;

      await authService.registerSupervisor(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (!mounted) return;

      // AuthGate will handle the post-register route automatically.
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Registration failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _goToSignIn() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildLeftPanel(),
                        ),
                        const SizedBox(width: 52),
                        Expanded(
                          child: Form(
                            key: _formKey,
                            child: _buildRightPanel(),
                          ),
                        ),
                      ],
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
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
    child: Row(
      children: [
        Text(
          'GeoAI Monitor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A3D91),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildLeftPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 680,
          decoration: BoxDecoration(
            color: const Color(0xFF001A66),
            borderRadius: BorderRadius.circular(0),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.18,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.3, 0.0),
                        radius: 0.9,
                        colors: [
                          Color(0xFF1A4ED8),
                          Color(0xFF001A66),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(42, 36, 42, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '◌ SUPERVISOR PORTAL',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Precision\nMonitoring\nfor Professional\nExcellence.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'GeoAI Monitor',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '© 2026 GeoAI OJT Systems. Precision Monitoring & Analytics.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Supervisor Account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your credentials to access the precision\nmonitoring suite.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 28),

          _buildLabel('Full Name'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hintText: 'John Doe',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              if (value.trim().length < 2) {
                return 'Enter your full name';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),
          _buildLabel('Work Email'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailController,
            hintText: 'john.doe@geosystems.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              final email = value.trim();
              if (!email.contains('@') || !email.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _passwordController,
                      hintText: '••••••••',
                      obscureText: _obscurePassword,
                      toggle: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      hintText: '••••••••',
                      obscureText: _obscureConfirmPassword,
                      toggle: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) {
                          _handleRegister();
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm your password';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() => _agreedToTerms = value ?? false);
                      },
                activeColor: const Color(0xFF0D4DB3),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: Color(0xFF0D4DB3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Color(0xFF0D4DB3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' regarding data monitoring and GeoAI processing.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorBanner(),
          ],

          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D4DB3),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF0D4DB3).withOpacity(0.6),
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
                      'Create Account',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 48),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 22),

          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have a supervisor account? ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                InkWell(
                  onTap: _goToSignIn,
                  child: Text(
                    'Sign In',
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
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF444444),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
        filled: true,
        fillColor: const Color(0xFFF2F2F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback toggle,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey[600]),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: Colors.grey[600],
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF2F2F4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 11),
      ),
      validator: validator,
    );
  }

  Widget _buildErrorBanner() {
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
              _errorMessage!,
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

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
      child: Wrap(
        spacing: 22,
        alignment: WrapAlignment.center,
        children: [
          _buildFooterLink('Privacy Policy'),
          _buildFooterLink('Terms of Service'),
          _buildFooterLink('Security'),
          _buildFooterLink('Contact'),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: const Color(0xFF7C8AA5),
      ),
    );
  }
}