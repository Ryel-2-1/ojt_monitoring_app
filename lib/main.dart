// lib/main.dart
//
// PURPOSE: App entry point. Handles:
//   1. Manual Firebase initialization (bypassing flutterfire CLI).
//   2. Wiring up services via an InheritedWidget (AppServices).
//   3. A root widget that listens to auth state and routes accordingly.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Fixes the 'User' type error
import 'models/user_model.dart'; // Fixes the 'UserRole' enum error
import 'services/auth_service.dart';
import 'repositories/student_repository.dart';
import 'repositories/attendance_repository.dart';
import 'screens/login_screen.dart';
import 'repositories/user_repository.dart';
import 'screens/admin_dashboard_layout.dart';
import 'repositories/role_repository.dart';
import 'screens/access_control_screen.dart';
import 'screens/web_login_screen.dart';

// -------------------------------------------------------------------
// STEP 1: Firebase Manual Configuration
// We bypass `flutterfire configure` and hardcode the Web config here.
// Android reads from google-services.json automatically.
// -------------------------------------------------------------------

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyByaNJZjhXfedXhs-71GjazPYhegb36bBM",
  authDomain: "ojt-monitoring-system-44070.firebaseapp.com",
  projectId: "ojt-monitoring-system-44070",
  storageBucket: "ojt-monitoring-system-44070.firebasestorage.app",
  messagingSenderId: "910935241512",
  appId: "1:910935241512:web:15533661247267339d561d",
  measurementId: "G-QK59E8TEW8",
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(options: _webFirebaseOptions);
  } else {
    await Firebase.initializeApp();
  }

  runApp(const OjtApp());
}

// -------------------------------------------------------------------
// STEP 2: AppServices — InheritedWidget for Dependency Injection
// -------------------------------------------------------------------
class AppServices extends InheritedWidget {
  final AuthService authService;
  final StudentRepository studentRepository;
  final AttendanceRepository attendanceRepository;
  final UserRepository userRepository; // Add this line
  final RoleRepository roleRepository;
  
  const AppServices({
    super.key,
    required this.authService,
    required this.studentRepository,
    required this.attendanceRepository,
    required this.userRepository, // Add this line
    required this.roleRepository, // Add this line
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

// -------------------------------------------------------------------
// STEP 3: Root App Widget
// -------------------------------------------------------------------
class OjtApp extends StatelessWidget {
  const OjtApp({super.key});



  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final studentRepository = StudentRepository();
    final attendanceRepository = AttendanceRepository();
    final userRepository = UserRepository(); // Instantiate here
    final roleRepository = RoleRepository(); // Instantiate here

    return AppServices(
      authService: authService,
      studentRepository: studentRepository,
      attendanceRepository: attendanceRepository,
     
      userRepository: userRepository,
      roleRepository: roleRepository,
      child: MaterialApp(
        title: 'OJT Monitoring System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B0000)), // PUP Maroon
          useMaterial3: true,
        ),
       home: const AuthGate(),
      ),
    );
  }
}

// -------------------------------------------------------------------
// STEP 4: AuthGate — Listens to auth state and routes the user
// -------------------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AppServices.of(context).authService;
    final userRepo = AppServices.of(context).userRepository;

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. If NOT logged in, show the platform-specific login screen
        if (!snapshot.hasData || snapshot.data == null) {
          return kIsWeb ? const WebLoginScreen() : const LoginScreen();
        }

        // 2. If logged in, we must check the Role to route correctly
        return FutureBuilder<UserRole?>(
          future: userRepo.getUserRole(snapshot.data!.uid), // Uses your new repo helper
          builder: (context, roleSnapshot) {
           if (roleSnapshot.connectionState == ConnectionState.waiting) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

if (roleSnapshot.hasError) {
  return Scaffold(
    body: Center(
      child: Text('Error: ${roleSnapshot.error}'),
    ),
  );
}

final role = roleSnapshot.data;

if (role == null) {
  return const Scaffold(
    body: Center(
      child: Text('No role found for this account'),
    ),
  );
}

            // 3. Routing Logic: Platform + Role Enforcement
            if (kIsWeb && role == UserRole.supervisor) {
              return const AdminDashboardLayout(
                child: AccessControlScreen(),
              );
            } else if (!kIsWeb && role == UserRole.intern) {
              // This is where you will build your Intern Home Screen
              return const Scaffold(
                body: Center(child: Text('Intern Mobile Home')),
              );
            }

            // 4. Emergency Fallback: If role/platform don't match, send back to login
           return Scaffold(
  body: Center(
    child: Text('Access denied or role mismatch'),
  ),
);
          },
        );
      },
    );
  }
}
// -------------------------------------------------------------------
// PLACEHOLDER SCREENS
// -------------------------------------------------------------------
