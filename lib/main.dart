// lib/main.dart
//
// RACE CONDITION FIX (Phase 3.1):
//
// WHAT WAS HAPPENING:
//   Auth state changes → AuthGate's FutureBuilder fires instantly
//   → getUserRole() returns null (Firestore write not committed yet)
//   → auto sign-out → back to login
//
// THE FIX IN AuthGate:
//   1. AuthGate now uses getUserRoleWithRetry() (via UserRepository)
//      instead of getUserRole() directly, so it waits up to ~3s
//      for the Firestore document to become readable.
//   2. The loading screen stays visible during this wait — the user
//      never sees a flash back to the login screen.

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/intern_home_screen.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'repositories/student_repository.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/role_repository.dart';
import 'screens/login_screen.dart';
import 'screens/web_login_screen.dart';
import 'screens/admin_dashboard_layout.dart';

import 'repositories/live_location_repository.dart';
import 'repositories/time_request_repository.dart';

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyByaNJZjhXfedXhs-71GjazPYhegb36bBM',
  authDomain: 'ojt-monitoring-system-44070.firebaseapp.com',
  projectId: 'ojt-monitoring-system-44070',
  storageBucket: 'ojt-monitoring-system-44070.firebasestorage.app',
  messagingSenderId: '910935241512',
  appId: '1:910935241512:web:15533661247267339d561d',
  measurementId: 'G-QK59E8TEW8',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
    await Firebase.initializeApp(options: _webFirebaseOptions);
  } else {
    await Firebase.initializeApp();
  }

  runApp(const OjtApp());
}

class AppServices extends InheritedWidget {
  final AuthService authService;
final StudentRepository studentRepository;
final AttendanceRepository attendanceRepository;
final UserRepository userRepository;
final RoleRepository roleRepository;
final LiveLocationRepository liveLocationRepository;
final TimeRequestRepository timeRequestRepository;
  

 const AppServices({
  super.key,
  required this.authService,
  required this.studentRepository,
  required this.attendanceRepository,
  required this.userRepository,
  required this.roleRepository,
  required this.liveLocationRepository,
  required this.timeRequestRepository,
  required super.child,
});

  static AppServices of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(result != null, 'No AppServices found in widget tree');
    return result!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) => false;
}

class OjtApp extends StatelessWidget {
  const OjtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppServices(
  authService: AuthService(),
  studentRepository: StudentRepository(),
  attendanceRepository: AttendanceRepository(),
  userRepository: UserRepository(),
  roleRepository: RoleRepository(),
  liveLocationRepository: LiveLocationRepository(),
  timeRequestRepository: TimeRequestRepository(),
  child: MaterialApp(
        title: 'GeoAI OJT Monitoring System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// AuthGate
//
// ROUTING TABLE:
//   Not logged in       → LoginScreen (mobile) / WebLoginScreen (web)
//   Logged in, loading  → _LoadingScreen (spinner)
//   intern  + mobile    → InternHomeScreen
//   supervisor + web    → AdminDashboardLayout
//   mismatch            → _RoleMismatchScreen (with Sign Out button)
//   null role           → auto sign-out → back to login
// ─────────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AppServices.of(context).authService;
    final userRepo = AppServices.of(context).userRepository;

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // Still connecting to Firebase
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // Not logged in
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return kIsWeb ? const WebLoginScreen() : const LoginScreen();
        }

        // Logged in — fetch role
        final uid = authSnapshot.data!.uid;

        return FutureBuilder<UserRole?>(
          // Use the retry version so we survive Firestore propagation lag.
          // This is the key fix — getUserRoleWithRetry waits up to ~3.5s
          // before giving up, bridging the gap between Auth and Firestore.
          future: userRepo.getUserRoleWithRetry(uid),
          builder: (context, roleSnapshot) {
            // Fetching role
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(message: 'Verifying your account...');
            }

            // Fetch error
            if (roleSnapshot.hasError) {
              return _RoleMismatchScreen(
                message:
                    'Could not verify your account. Please sign in again.\n\n'
                    'Error: ${roleSnapshot.error}',
                authService: authService,
              );
            }

            final role = roleSnapshot.data;

            // No profile found even after retries
            // → sign out and return to login cleanly
            if (role == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await authService.signOut();
              });
              return const _LoadingScreen(message: 'Signing out...');
            }

            // ── Route correctly ───────────────────────────────────

            if (kIsWeb && role == UserRole.supervisor) {
              return const AdminDashboardLayout(
                activeRoute: 'Live Monitoring',
              );
            }

            if (!kIsWeb && role == UserRole.intern) {
              return const InternHomeScreen();
            }

            // Role / platform mismatch — never a dead end
            final mismatchMessage = kIsWeb
                ? 'This portal is for Supervisors only.\n'
                    'Please use the mobile app to access your Intern account.'
                : 'This app is for Interns only.\n'
                    'Please use the web portal to access your Supervisor account.';

            return _RoleMismatchScreen(
              message: mismatchMessage,
              authService: authService,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _LoadingScreen
// ─────────────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  final String? message;
  const _LoadingScreen({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF1565C0)),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// _RoleMismatchScreen
// Always shows a Sign Out button — user is never stuck.
// ─────────────────────────────────────────────────────────────────────
class _RoleMismatchScreen extends StatelessWidget {
  final String message;
  final AuthService authService;
  const _RoleMismatchScreen(
      {required this.message, required this.authService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.block_rounded,
                    color: Color(0xFFC62828), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => authService.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

