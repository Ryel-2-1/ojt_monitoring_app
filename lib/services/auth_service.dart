// lib/services/auth_service.dart
//
// RACE CONDITION FIX (Phase 3.1):
//
// WHAT WAS HAPPENING:
//   Registration / Google Sign-In → Firebase Auth account created
//   → AuthGate stream fires immediately
//   → AuthGate calls getUserRole() → null (Firestore write not done yet)
//   → Auto sign-out → back to login
//
// THE FIX:
//   All sign-in and register methods now return UserModel (not just User).
//   This means Firestore profile creation is GUARANTEED COMPLETE before
//   the method returns. AuthGate's FutureBuilder still runs, but by the
//   time it calls getUserRole(), the document already exists in Firestore.
//
//   For the edge case where AuthGate fires before our method returns
//   (possible with Google Sign-In on slow connections), getUserRole()
//   now retries up to 3 times with a short delay before giving up.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException({required this.code, required this.message});
  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '373017801855-YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ─────────────────────────────────────────────
  // SIGN IN WITH EMAIL
  // ─────────────────────────────────────────────

  // Returns UserModel (not just User) to confirm Firestore profile exists.
  // Enforces Mobile = Intern / Web = Supervisor rule.
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User user = credential.user!;

      // Fetch role with retry — guards against slow Firestore writes
      // on first-time users or poor connections.
      final UserRole? role = await _getUserRoleWithRetry(user.uid);

      if (role == null) {
        await _auth.signOut();
        throw const AuthException(
          code: 'profile-not-found',
          message:
              'Your account profile is incomplete. Please re-register or contact support.',
        );
      }

      _enforcePlatformRole(role);

      // Return the full UserModel so the caller has everything it needs.
      return UserModel(
        uid: user.uid,
        email: user.email ?? email,
        fullName: user.displayName ?? '',
        role: role,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: _mapAuthError(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          code: 'unknown', message: 'Sign-in failed. Please try again.');
    }
  }

  // ─────────────────────────────────────────────
  // REGISTER INTERN — Mobile only
  // ─────────────────────────────────────────────

  // Role is HARDCODED to intern — caller cannot override.
  // Returns UserModel only after Firestore write is confirmed complete.
  Future<UserModel> registerIntern({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      role: UserRole.intern,
    );
  }

  // ─────────────────────────────────────────────
  // REGISTER SUPERVISOR — Web only
  // ─────────────────────────────────────────────

  Future<UserModel> registerSupervisor({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      role: UserRole.supervisor,
    );
  }

  // ─────────────────────────────────────────────
  // GOOGLE SIGN-IN
  // ─────────────────────────────────────────────

  // Returns null only if user dismissed the picker (not an error).
  // Returns UserModel on success — Firestore profile guaranteed to exist.
  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User dismissed picker

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final User user = userCredential.user!;

      // Check if Firestore profile already exists (returning user)
      UserRole? role = await _getUserRoleWithRetry(user.uid);

      if (role == null) {
        // First-time Google Sign-In: create Firestore profile now.
        // Role is assigned based on platform — cannot be forged.
        final defaultRole = kIsWeb ? UserRole.supervisor : UserRole.intern;

        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? 'User',
          role: defaultRole,
        );

        // Wait for Firestore write to fully complete before continuing.
        await _userRepository.createUser(userModel);
        role = defaultRole;
      }

      // Enforce platform rule AFTER profile is guaranteed to exist.
      _enforcePlatformRole(role);

      return UserModel(
        uid: user.uid,
        email: user.email ?? '',
        fullName: user.displayName ?? '',
        role: role,
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: _mapAuthError(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          code: 'unknown',
          message: 'Google Sign-In failed. Please try again.');
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
  // Shared registration logic. Role is passed internally only —
  // external callers use registerIntern() or registerSupervisor().
  //
  // KEY CHANGE: awaits createUser() to fully complete, then does a
  // verification read to confirm the document exists before returning.
  // This eliminates the race condition where AuthGate fires before
  // the profile is written.
  Future<UserModel> _registerUser({
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

      final userModel = UserModel(
        uid: user.uid,
        email: user.email!,
        fullName: fullName.trim(),
        role: role,
      );

      try {
        // Step 1: Write to Firestore and wait for confirmation.
        await _userRepository.createUser(userModel);

        // Step 2: Verify the document actually exists before returning.
        // This is the critical guard against the race condition.
        // We retry up to 3 times with increasing delays in case of
        // Firestore propagation lag on slow connections.
        final verifiedRole = await _getUserRoleWithRetry(user.uid);

        if (verifiedRole == null) {
          // Firestore write appeared to succeed but document isn't readable yet.
          // Delete auth account to keep state clean and ask user to retry.
          await user.delete();
          throw const AuthException(
            code: 'firestore-write-failed',
            message:
                'Account setup failed. Please try again.',
          );
        }
      } catch (firestoreError) {
        if (firestoreError is AuthException) rethrow;
        await user.delete();
        throw const AuthException(
          code: 'firestore-write-failed',
          message: 'Account created but profile could not be saved. Please try again.',
        );
      }

      return userModel;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(code: e.code, message: _mapAuthError(e.code));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException(
          code: 'unknown', message: 'Registration failed. Please try again.');
    }
  }

  // _getUserRoleWithRetry():
  // Fetches role from Firestore with up to 3 retries.
  // Delays: 500ms → 1000ms → 2000ms (exponential backoff).
  //
  // WHY THIS IS NEEDED:
  // Firestore writes are eventually consistent. On the first login/register,
  // there's a brief window where the Auth session exists but the Firestore
  // document hasn't fully propagated to the read replica yet.
  // Retrying with backoff bridges this gap without blocking the user
  // for more than ~3 seconds in the worst case.
  Future<UserRole?> _getUserRoleWithRetry(String uid,
      {int maxRetries = 3}) async {
    const delays = [500, 1000, 2000]; // ms

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final role = await _userRepository.getUserRole(uid);
      if (role != null) return role;

      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: delays[attempt]));
      }
    }
    return null;
  }

  // _enforcePlatformRole():
  // The single method enforcing Mobile = Intern / Web = Supervisor.
  // Always signs out before throwing so the session is cleaned up.
  void _enforcePlatformRole(UserRole role) {
    if (kIsWeb && role == UserRole.intern) {
      _auth.signOut();
      throw const AuthException(
        code: 'wrong-platform',
        message:
            'Intern accounts are not permitted on the Supervisor portal. '
            'Please use the mobile app.',
      );
    }
    if (!kIsWeb && role == UserRole.supervisor) {
      _auth.signOut();
      throw const AuthException(
        code: 'wrong-platform',
        message:
            'Supervisor accounts are not permitted on the mobile app. '
            'Please use the web portal.',
      );
    }
  }

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