// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'models/user_model.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/live_location_repository.dart';
import 'repositories/role_repository.dart';
import 'repositories/student_repository.dart';
import 'repositories/time_request_repository.dart';
import 'repositories/user_repository.dart';
import 'screens/admin_dashboard_layout.dart';
import 'screens/intern_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/web_login_screen.dart';
import 'screens/web_unauthorized_screen.dart';
import 'services/auth_service.dart';

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyByaNJZjhXfedXhs-71GjazPYhegb36bBM',
  authDomain: 'ojt-monitoring-system-44070.firebaseapp.com',
  projectId: 'ojt-monitoring-system-44070',
  storageBucket: 'ojt-monitoring-system-44070.firebasestorage.app',
  messagingSenderId: '910935241512',
  appId: '1:910935241512:web:15533661247267339d561d',
  measurementId: 'G-QK59E8TEW8',
);

Future<void> main() async {
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
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
          ),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AppServices.of(context).authService;
    final userRepository = AppServices.of(context).userRepository;

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final firebaseUser = authSnapshot.data;

        if (firebaseUser == null) {
          return kIsWeb ? const WebLoginScreen() : const LoginScreen();
        }

        return FutureBuilder<UserRole?>(
          future: userRepository.getUserRoleWithRetry(firebaseUser.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(
                message: 'Verifying your account...',
              );
            }

            if (roleSnapshot.hasError) {
              return _AccessProblemScreen(
                title: 'Account Check Failed',
                message:
                    'We could not verify your account right now. Please sign in again.',
                buttonText: 'Sign Out',
                onPressed: authService.signOut,
              );
            }

            final role = roleSnapshot.data;

            if (role == null) {
              return _AccessProblemScreen(
                title: 'Profile Not Found',
                message:
                    'Your login is valid, but your user profile was not found. Please contact your administrator.',
                buttonText: 'Sign Out',
                onPressed: authService.signOut,
              );
            }

            if (!kIsWeb && role == UserRole.intern) {
              return const InternHomeScreen();
            }

            if (kIsWeb && role == UserRole.supervisor) {
              return const AdminDashboardLayout(
                activeRoute: 'Live Monitoring',
              );
            }

            if (kIsWeb) {
              return const WebUnauthorizedScreen();
            }

            return _AccessProblemScreen(
              title: 'Access Denied',
              message:
                  'This app is for Intern accounts only. Please use the web portal for Supervisor accounts.',
              buttonText: 'Sign Out',
              onPressed: authService.signOut,
            );
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String? message;

  const _LoadingScreen({
    this.message,
  });

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
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccessProblemScreen extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final Future<void> Function() onPressed;

  const _AccessProblemScreen({
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

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
                child: const Icon(
                  Icons.block_rounded,
                  color: Color(0xFFC62828),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(
                    buttonText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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