import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebLoginScreen extends StatelessWidget {
  const WebLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Branding Section (Same as Registration for consistency)
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF002868),
              padding: const EdgeInsets.all(64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUPERVISOR PORTAL', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Text('Welcome Back\nto Professional\nExcellence.', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1.1)),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // Right Login Form
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Supervisor Sign In', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    _buildTextField('Work Email', 'john.doe@geosystems.com', Icons.email_outlined),
                    const SizedBox(height: 16),
                    _buildPasswordField('Password'),
                    const SizedBox(height: 32),
                    _buildSignInButton(),
                    const SizedBox(height: 24),
                    Center(child: _buildRegisterLink(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
            Text('Forgot Password?', style: TextStyle(color: Color(0xFF0046AD), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          obscureText: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            hintText: '••••••••',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0046AD), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: () {},
        child: Text('Sign In', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    return GestureDetector(
      onTap: () { /* Navigate to WebRegisterScreen */ },
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 13),
          children: [
            const TextSpan(text: "Don't have an account? "),
            TextSpan(text: 'Register', style: TextStyle(color: const Color(0xFF0046AD), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}