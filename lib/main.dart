// lib/main.dart
//
// PURPOSE: App entry point. Handles:
//   1. Manual Firebase initialization (bypassing flutterfire CLI).
//   2. Wiring up services via an InheritedWidget (AppServices).
//   3. A root widget that listens to auth state and routes accordingly.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'services/auth_service.dart';
import 'repositories/student_repository.dart';
import 'repositories/attendance_repository.dart';
import 'screens/login_screen.dart';
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

  const AppServices({
    super.key,
    required this.authService,
    required this.studentRepository,
    required this.attendanceRepository,
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

    return AppServices(
      authService: authService,
      studentRepository: studentRepository,
      attendanceRepository: attendanceRepository,
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

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen(); 
        }

        return const LoginScreen(); 
      },
    );
  }
}

// -------------------------------------------------------------------
// PLACEHOLDER SCREENS
// -------------------------------------------------------------------



class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AppServices.of(context).authService;
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OJT Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: Text('Welcome, ${user?.displayName ?? 'Student'}!'),
      ),
    );
  }
}