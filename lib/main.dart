import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';

import 'models/user_model.dart';

import 'repositories/attendance_repository.dart';
import 'repositories/company_repository.dart';
import 'repositories/enrollment_repository.dart';
import 'repositories/live_location_repository.dart';
import 'repositories/role_repository.dart';
import 'repositories/student_repository.dart';
import 'repositories/time_request_repository.dart';
import 'repositories/user_repository.dart';

import 'screens/admin_dashboard_layout.dart';
import 'screens/intern_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/web_login_screen.dart';

import 'services/auth_service.dart';
import 'services/offline_attendance_queue_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();

  runApp(const OjtApp());
}

class AppThemeController extends ChangeNotifier {
  static const String _boxName = 'app_settings';
  static const String _darkModeKey = 'dark_mode_enabled';

  Box<dynamic>? _box;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _isDarkMode = _box?.get(_darkModeKey, defaultValue: false) == true;
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    await _box?.put(_darkModeKey, value);
    notifyListeners();
  }
}

class OjtApp extends StatefulWidget {
  const OjtApp({super.key});

  @override
  State<OjtApp> createState() => _OjtAppState();
}

class _OjtAppState extends State<OjtApp> {
  late final AuthService _authService;
  late final StudentRepository _studentRepository;
  late final AttendanceRepository _attendanceRepository;
  late final UserRepository _userRepository;
  late final RoleRepository _roleRepository;
  late final LiveLocationRepository _liveLocationRepository;
  late final TimeRequestRepository _timeRequestRepository;
  late final CompanyRepository _companyRepository;
  late final EnrollmentRepository _enrollmentRepository;
  late final OfflineAttendanceQueueService _offlineAttendanceQueueService;
  late final AppThemeController _themeController;

  late final Future<void> _appInitFuture;
  bool _recoveredUnsyncedDataOnStartup = false;

  @override
  void initState() {
    super.initState();

    _authService = AuthService();
    _studentRepository = StudentRepository();
    _attendanceRepository = AttendanceRepository();
    _userRepository = UserRepository();
    _roleRepository = RoleRepository();
    _liveLocationRepository = LiveLocationRepository();
    _timeRequestRepository = TimeRequestRepository();
    _companyRepository = CompanyRepository();
    _enrollmentRepository = EnrollmentRepository();
    _themeController = AppThemeController();

    _offlineAttendanceQueueService = OfflineAttendanceQueueService(
      attendanceRepository: _attendanceRepository,
      liveLocationRepository: _liveLocationRepository,
    );

    _appInitFuture = _initializeAppServices();
  }

  Future<void> _initializeAppServices() async {
    await _themeController.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint(
          'Theme settings init timed out. Continuing with default theme.',
        );
      },
    );

    if (!kIsWeb) {
      final recoveredCount = await _offlineAttendanceQueueService.init().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint(
            'Offline attendance storage init timed out. Continuing app startup.',
          );
          return 0;
        },
      );

      _recoveredUnsyncedDataOnStartup = recoveredCount > 0;
    } else {
      debugPrint('Skipping offline attendance queue init on web.');
    }
  }

  @override
  void dispose() {
    _offlineAttendanceQueueService.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppServices(
      authService: _authService,
      studentRepository: _studentRepository,
      attendanceRepository: _attendanceRepository,
      userRepository: _userRepository,
      roleRepository: _roleRepository,
      liveLocationRepository: _liveLocationRepository,
      timeRequestRepository: _timeRequestRepository,
      companyRepository: _companyRepository,
      enrollmentRepository: _enrollmentRepository,
      offlineAttendanceQueueService: _offlineAttendanceQueueService,
      themeController: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'GeoAI OJT Monitoring',
            debugShowCheckedModeBanner: false,
            themeMode: _themeController.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D4DB3),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0F172A),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D4DB3),
                brightness: Brightness.dark,
              ),
            ),
            home: FutureBuilder<void>(
              future: _appInitFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppStartupLoadingScreen();
                }

                if (snapshot.hasError) {
                  return AppStartupErrorScreen(
                    error: snapshot.error.toString(),
                  );
                }

                return StartupResyncNotifier(
                  showRecoveredToast: _recoveredUnsyncedDataOnStartup,
                  child: const AuthGate(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class StartupResyncNotifier extends StatefulWidget {
  final bool showRecoveredToast;
  final Widget child;

  const StartupResyncNotifier({
    super.key,
    required this.showRecoveredToast,
    required this.child,
  });

  @override
  State<StartupResyncNotifier> createState() => _StartupResyncNotifierState();
}

class _StartupResyncNotifierState extends State<StartupResyncNotifier> {
  bool _hasShownToast = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!widget.showRecoveredToast || _hasShownToast) return;

    _hasShownToast = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unsynced data detected and recovered.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF14A44D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppServices extends InheritedWidget {
  final AuthService authService;
  final StudentRepository studentRepository;
  final AttendanceRepository attendanceRepository;
  final UserRepository userRepository;
  final RoleRepository roleRepository;
  final LiveLocationRepository liveLocationRepository;
  final TimeRequestRepository timeRequestRepository;
  final CompanyRepository companyRepository;
  final EnrollmentRepository enrollmentRepository;
  final OfflineAttendanceQueueService offlineAttendanceQueueService;
  final AppThemeController themeController;

  const AppServices({
    super.key,
    required this.authService,
    required this.studentRepository,
    required this.attendanceRepository,
    required this.userRepository,
    required this.roleRepository,
    required this.liveLocationRepository,
    required this.timeRequestRepository,
    required this.companyRepository,
    required this.enrollmentRepository,
    required this.offlineAttendanceQueueService,
    required this.themeController,
    required super.child,
  });

  static AppServices of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<AppServices>();

    if (services == null) {
      throw FlutterError(
        'AppServices.of(context) called with a context that does not contain AppServices.',
      );
    }

    return services;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) {
    return authService != oldWidget.authService ||
        studentRepository != oldWidget.studentRepository ||
        attendanceRepository != oldWidget.attendanceRepository ||
        userRepository != oldWidget.userRepository ||
        roleRepository != oldWidget.roleRepository ||
        liveLocationRepository != oldWidget.liveLocationRepository ||
        timeRequestRepository != oldWidget.timeRequestRepository ||
        companyRepository != oldWidget.companyRepository ||
        enrollmentRepository != oldWidget.enrollmentRepository ||
        offlineAttendanceQueueService !=
            oldWidget.offlineAttendanceQueueService ||
        themeController != oldWidget.themeController;
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<UserRole?>? _roleFuture;
  String? _loadedUid;

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);

    return StreamBuilder(
      stream: services.authService.authStateChanges,
      builder: (context, snapshot) {
        final firebaseUser = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingScreen(message: 'Checking sign-in status...');
        }

        if (firebaseUser == null) {
          _roleFuture = null;
          _loadedUid = null;

          if (kIsWeb) {
            return const WebLoginScreen();
          }

          return const LoginScreen();
        }

        if (_loadedUid != firebaseUser.uid || _roleFuture == null) {
          _loadedUid = firebaseUser.uid;
          _roleFuture = services.userRepository.getUserRoleWithRetry(
            firebaseUser.uid,
          );
        }

        return FutureBuilder<UserRole?>(
          future: _roleFuture,
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingScreen(message: 'Loading account role...');
            }

            if (roleSnapshot.hasError) {
              return AccessProblemScreen(
                title: 'Could not load your account',
                message:
                    'We could not verify your account role. Please try signing in again.',
                onLogout: () async {
                  await services.authService.signOut();
                },
              );
            }

            final role = roleSnapshot.data;

            if (role == null) {
              return AccessProblemScreen(
                title: 'No role found',
                message:
                    'Your account exists, but it does not have an assigned role yet. Please contact your administrator.',
                onLogout: () async {
                  await services.authService.signOut();
                },
              );
            }

            if (role == UserRole.supervisor) {
              if (kIsWeb) {
                return const AdminDashboardLayout();
              }

              return AccessProblemScreen(
                title: 'Web portal required',
                message:
                    'Supervisor accounts must use the web admin portal. Please open this system in a desktop browser.',
                onLogout: () async {
                  await services.authService.signOut();
                },
              );
            }

            if (role == UserRole.intern) {
              if (!kIsWeb) {
                return const InternHomeScreen();
              }

              return AccessProblemScreen(
                title: 'Mobile app required',
                message:
                    'Intern accounts must use the mobile app. Please sign in on your Android device.',
                onLogout: () async {
                  await services.authService.signOut();
                },
              );
            }

            return AccessProblemScreen(
              title: 'Unsupported role',
              message:
                  'Your account role is not supported by this application.',
              onLogout: () async {
                await services.authService.signOut();
              },
            );
          },
        );
      },
    );
  }
}

class AppStartupLoadingScreen extends StatelessWidget {
  const AppStartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppLoadingScreen(
      message: kIsWeb
          ? 'Preparing web portal...'
          : 'Preparing offline attendance storage...',
    );
  }
}

class AppLoadingScreen extends StatelessWidget {
  final String message;

  const AppLoadingScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7ECF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0D4DB3)),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A2351),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppStartupErrorScreen extends StatelessWidget {
  final String error;

  const AppStartupErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7ECF3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFC62828),
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Startup failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A2351),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccessProblemScreen extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function() onLogout;

  const AccessProblemScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7ECF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF0D4DB3),
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A2351),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D4DB3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
