// lib/screens/login_screen.dart
//
// PURPOSE: Login screen with Intern/Supervisor tab toggle.
// Supports Email+Password and Google Sign-In for both roles.
// Matches the provided GeoAI OJT Monitoring System design.
//
// WHAT THIS FILE DOES:
// 1. Shows a tab toggle between Intern and Supervisor
// 2. Intern tab: Email + Password + Google Sign-In + Create Account
// 3. Supervisor tab: Email + Password + Google Sign-In + Create Account
// 4. Wires Google Sign-In to AuthService (from our service layer)
// 5. Email/Password auth is scaffolded and ready to connect to Firebase Auth
// 6. All navigation targets are placeholders — replace with real routes

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart'; // for AppServices
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';


// Role enum — used to track which tab is selected


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // --- State ---
  UserRole _selectedRole = UserRole.intern;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers capture text field input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    // Always dispose controllers to avoid memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Google Sign-In Handler ---
  // Calls AuthService.signInWithGoogle() from our service layer.
  // AuthGate in main.dart will auto-navigate on success via the auth stream.
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AppServices.of(context).authService;
      final user = await authService.signInWithGoogle();

      if (user == null) {
        // User cancelled — not an error
        setState(() => _isLoading = false);
        return;
      }

      // Check if student profile exists, navigate to setup if not
      if (mounted && _selectedRole == UserRole.intern) {
        final studentRepo = AppServices.of(context).studentRepository;
        final profile = await studentRepo.getStudent(user.uid);
        if (profile == null && mounted) {
          // TODO: Navigate to ProfileSetupScreen
          debugPrint('New intern — navigate to profile setup');
        }
      }
      // AuthGate stream handles navigation to home automatically
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // --- Email/Password Sign-In Handler ---
  // Scaffolded — wire to firebase_auth when ready
  Future<void> _handleEmailSignIn() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final authService = AppServices.of(context).authService;

    await authService.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  } on AuthException catch (e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = e.message;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Light grey background matching the design
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                _buildCard(),
                const SizedBox(height: 16),
                // Footer
                Text(
                  'AUTHORIZED PERSONNEL ONLY\n© 2026 GEOAI OJT MONITORING SYSTEM',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 10,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildTabToggle(),
            const SizedBox(height: 24),
            _buildEmailField(),
            const SizedBox(height: 16),
            _buildPasswordField(),
            const SizedBox(height: 24),
            _buildSignInButton(),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildGoogleButton(),
            const SizedBox(height: 20),
            if (_errorMessage != null) _buildErrorMessage(),
            _buildCreateAccount(),
          ],
        ),
      ),
    );
  }

  // --- Logo + Title + Subtitle ---
  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              // Blue gradient matching the design's icon background
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'GeoAI OJT Monitoring\nSystem',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1565C0),
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Nurturing the next generation of\nprofessional talent',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // --- Intern / Supervisor Tab Toggle ---
  // Uses a segmented-style toggle, not a TabBar, to match the design exactly.
  Widget _buildTabToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTab('Intern', UserRole.intern),
          _buildTab('Supervisor', UserRole.supervisor),
        ],
      ),
    );
  }

  Widget _buildTab(String label, UserRole role) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedRole = role;
          _errorMessage = null; // clear error on tab switch
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : Colors.grey[500],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Work Email Field ---
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORK EMAIL',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: _inputDecoration(
            hint: 'name@company.com',
            icon: Icons.email_outlined,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Email is required';
            if (!value.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
      ],
    );
  }

  // --- Security Key (Password) Field ---
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SECURITY KEY',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Colors.grey[700],
              ),
            ),
            GestureDetector(
              onTap: () {
                // TODO: Navigate to ForgotPasswordScreen
                debugPrint('Forgot password tapped');
              },
              child: Text(
                'Forgot?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1565C0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: _inputDecoration(
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            // Eye icon to toggle password visibility
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey[500],
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            if (value.length < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
      ],
    );
  }

  // --- Sign In Button ---
  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign In',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }

  // --- "or continue with" Divider ---
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  // --- Google Sign-In Button ---
  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[300]!),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google 'G' logo using colored text as a lightweight substitute
            // Replace with an actual SVG asset if needed
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                  TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
                  TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
                  TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
                  TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
                  TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Error Message ---
  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF9A9A)),
        ),
        child: Text(
          _errorMessage!,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFFC62828),
          ),
        ),
      ),
    );
  }

  // --- Create Account Footer ---
  Widget _buildCreateAccount() {
    final roleLabel =
        _selectedRole == UserRole.intern ? 'internship' : 'Company';
    final question = _selectedRole == UserRole.intern
        ? 'New to the internship?'
        : 'New to the Company?';

    return Center(
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: Colors.grey[600]),
          children: [
            TextSpan(text: '$question '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  // TODO: Navigate to RegisterScreen
                  // Pass _selectedRole so the registration form knows
                  // whether it's an intern or supervisor signing up
                  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const RegisterScreen(),
  ),
);
                },
                child: Text(
                  'Create Account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1565C0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reusable Input Decoration ---
  // Centralizes the styling for all text fields so they stay consistent.
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: Colors.grey[400]),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey[500]),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF5350)),
      ),
    );
  }
}