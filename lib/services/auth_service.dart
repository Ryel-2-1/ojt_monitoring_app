// lib/services/auth_service.dart
//
// PURPOSE: Handles all authentication logic with platform-aware
// role enforcement.
//
// ARCHITECTURE RULE (Phase 3):
//   Mobile (Android)  → Interns ONLY
//   Web (Chrome)      → Supervisors ONLY
//
// This rule is enforced in two places:
//   1. signInWithEmail() — checks the user's Firestore role after login
//      and throws a platform mismatch error if it doesn't belong.
//   2. registerIntern() / registerSupervisor() — hardcodes the role so
//      the registration form can never forge a role by passing a parameter.
//
// WHY ENFORCE IN THE SERVICE AND NOT JUST THE UI:
// UI checks can be bypassed. Enforcing in the service layer means
// even if the login form is called programmatically or the platform
// check in the UI is skipped, the wrong role can never log in.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

// ─────────────────────────────────────────────────────────────
// AuthException
// ─────────────────────────────────────────────────────────────
// Custom exception with a `code` field so the UI can branch on
// specific cases without parsing raw strings.
// New code added: 'wrong-platform' — raised when a role tries
// to log into the wrong app.
class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException({required this.code, required this.message});

  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────
class AuthService {
  // Singleton — one instance shared across the entire app.
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UserRepository is injected here so AuthService can fetch the
  // role from Firestore immediately after login — without the UI
  // needing to do a second async call before routing.
  //
  // WHY INJECT HERE AND NOT CALL FROM UI:
  // The role check must happen atomically with the sign-in. If the
  // UI fetches role separately, there's a window where an auth state
  // change fires before the role check completes, causing AuthGate
  // to route to the wrong screen momentarily.
  final UserRepository _userRepository = UserRepository();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '373017801855-YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  // ─────────────────────────────────────────────
  // STREAMS & GETTERS
  // ─────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─────────────────────────────────────────────
  // SIGN IN — with platform-aware role enforcement
  // ─────────────────────────────────────────────

  // signInWithEmail():
  // Updated in Phase 3 to enforce the Mobile=Intern / Web=Supervisor rule.
  //
  // FLOW:
  //   1. Sign in with Firebase Auth (email + password).
  //   2. Fetch the user's role from Firestore via UserRepository.getUserRole().
  //   3. Check: does the role match the platform?
  //      - Mobile + supervisor role  → sign out + throw 'wrong-platform'
  //      - Web    + intern role      → sign out + throw 'wrong-platform'
  //      - Match                     → return the User normally
  //
  // WHY WE SIGN OUT BEFORE THROWING:
  // Firebase Auth has already created a session by the time we check the role.
  // If we throw without signing out, the AuthGate stream fires with a valid
  // User, and the app routes to home before the UI can show the error.
  // Signing out first keeps the auth state clean.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Authenticate with Firebase
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User user = credential.user!;

      // Step 2: Fetch role from Firestore
      // getUserRole() does a lightweight single-field read — faster than
      // fetching the full UserModel just for an access check.
      final UserRole? role = await _userRepository.getUserRole(user.uid);

      // Step 3: Handle missing profile
      // A null role means the user has a Firebase Auth account but no
      // Firestore profile — this shouldn't happen in normal flow but
      // can occur if registration was interrupted after Auth creation
      // but before the Firestore write completed.
      if (role == null) {
        await _auth.signOut();
        throw const AuthException(
          code: 'profile-not-found',
          message:
              'Your account profile is incomplete. Please contact support or re-register.',
        );
      }

      // Step 4: Platform enforcement
      // kIsWeb is a compile-time constant from Flutter — true on Chrome/Web,
      // false on Android/iOS. We use this instead of runtime device detection
      // because it's reliable and cannot be spoofed by the user.
      _enforcePlatformRole(role);

      return user;
    } on AuthException {
      // Re-throw our own exceptions without wrapping them again.
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Sign-in failed. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // REGISTER INTERN — Mobile only
  // ─────────────────────────────────────────────

  // registerIntern():
  // Called by the Mobile Create Account screen.
  // Role is HARDCODED to UserRole.intern — the caller cannot override it.
  //
  // WHY HARDCODE AND NOT ACCEPT A ROLE PARAMETER:
  // If we accepted `role` as a parameter, a bad actor could call
  // registerIntern(role: UserRole.supervisor) and gain supervisor access
  // on the web portal. Hardcoding eliminates that attack surface entirely.
  //
  // FLOW:
  //   1. Create Firebase Auth account.
  //   2. Update displayName in Auth profile.
  //   3. Save UserModel to Firestore with role: intern (via UserRepository).
  //   4. Return the created User.
  Future<User> registerIntern({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      role: UserRole.intern, // hardcoded — not a parameter
    );
  }

  // ─────────────────────────────────────────────
  // REGISTER SUPERVISOR — Web only
  // ─────────────────────────────────────────────

  // registerSupervisor():
  // Called by the Web Create Account screen.
  // Role is HARDCODED to UserRole.supervisor.
  //
  // Same reasoning as registerIntern() — role must not be a parameter.
  Future<User> registerSupervisor({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      role: UserRole.supervisor, // hardcoded — not a parameter
    );
  }

  // ─────────────────────────────────────────────
  // GOOGLE SIGN-IN — with platform role enforcement
  // ─────────────────────────────────────────────

  // signInWithGoogle():
  // Updated to enforce the same platform role check as signInWithEmail().
  // Google Sign-In users must have a Firestore profile with the correct
  // role for their platform, or they are denied and signed out.
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final User user = userCredential.user!;

      // Fetch role and enforce platform — same logic as signInWithEmail.
      // New Google Sign-In users won't have a Firestore profile yet,
      // so null role is handled by routing to a profile setup screen
      // (the caller checks for null return vs exception).
    UserRole? role = await _userRepository.getUserRole(user.uid);

if (role == null) {
  // First-time Google user → create profile automatically

  final defaultRole = kIsWeb
      ? UserRole.supervisor
      : UserRole.intern;

  final userModel = UserModel(
    uid: user.uid,
    email: user.email ?? '',
    fullName: user.displayName ?? 'No Name',
    role: defaultRole,
  );

  await _userRepository.createUser(userModel);

  role = defaultRole;
}

// Enforce platform AFTER role is guaranteed
_enforcePlatformRole(role);
      return user;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Google Sign-In failed. Please try again.',
      );
    }
  }

  // ─────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      if (!kIsWeb) _googleSignIn.signOut(),
    ]);
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────

  // _registerUser():
  // Shared internal registration logic used by both registerIntern()
  // and registerSupervisor(). Private so it cannot be called directly
  // from outside the class with a custom role parameter.
  //
  // WHAT IT DOES:
  //   1. Creates Firebase Auth account.
  //   2. Updates displayName in Auth profile.
  //   3. Builds UserModel with the hardcoded role.
  //   4. Saves to Firestore via UserRepository.createUser().
  Future<User> _registerUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user!.updateDisplayName(fullName.trim());
      await credential.user!.reload();

      final User user = _auth.currentUser!;

      // Build the UserModel and save to Firestore.
      // This is done inside _registerUser (not left to the UI) because
      // the Auth account and Firestore profile must be created together.
      // If Firestore save fails, we clean up the Auth account to avoid
      // orphaned Auth users with no profile.
      final userModel = UserModel(
        uid: user.uid,
        email: user.email!,
        fullName: fullName.trim(),
        role: role,
      );

      try {
        await _userRepository.createUser(userModel);
      } catch (firestoreError) {
        // CLEANUP: If Firestore write fails, delete the Auth account.
        // Without this, the user has an Auth account but no profile,
        // and future login attempts would hit the 'profile-not-found' error.
        await user.delete();
        throw AuthException(
          code: 'firestore-write-failed',
          message:
              'Account created but profile could not be saved. Please try again.',
        );
      }

      return user;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (e) {
      throw AuthException(
        code: 'unknown',
        message: 'Registration failed. Please try again.',
      );
    }
  }

  // _enforcePlatformRole():
  // The single method that contains the Mobile=Intern / Web=Supervisor rule.
  // Centralizing this means if the rule ever changes (e.g., supervisors
  // can also use mobile), you update ONE method, not every sign-in path.
  //
  // Signs out before throwing so the Firebase Auth session is cleaned up.
  void _enforcePlatformRole(UserRole role) {
    if (kIsWeb && role == UserRole.intern) {
      // An intern trying to access the Web supervisor portal
      _auth.signOut();
      throw const AuthException(
        code: 'wrong-platform',
        message:
            'Intern accounts are not permitted on the Supervisor portal. '
            'Please use the mobile app.',
      );
    }

    if (!kIsWeb && role == UserRole.supervisor) {
      // A supervisor trying to log into the mobile intern app
      _auth.signOut();
      throw const AuthException(
        code: 'wrong-platform',
        message:
            'Supervisor accounts are not permitted on the mobile app. '
            'Please use the web portal.',
      );
    }
  }

  // _mapAuthError(): converts Firebase error codes to readable messages.
  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found for this email. Please create an account.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Contact support.';
      default:
        return 'An unexpected error occurred [$code]. Please try again.';
    }
  }
}