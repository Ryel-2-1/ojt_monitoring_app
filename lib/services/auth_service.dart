// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';

class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException({
    required this.code,
    required this.message,
  });

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
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthException(
          code: 'user-missing',
          message: 'Sign-in failed. Please try again.',
        );
      }

      final userModel = await _loadVerifiedUser(firebaseUser.uid);

      await _enforcePlatformRole(userModel.role);

      return userModel;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (_) {
      throw const AuthException(
        code: 'unknown',
        message: 'Sign-in failed. Please try again.',
      );
    }
  }

  Future<UserModel> registerIntern({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      role: UserRole.intern,
    );
  }

  Future<UserModel> registerSupervisor({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      role: UserRole.supervisor,
    );
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        credential = await _auth.signInWithPopup(provider);
      } else {
        final googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          return null;
        }

        final googleAuth = await googleUser.authentication;

        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        credential = await _auth.signInWithCredential(oauthCredential);
      }

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthException(
          code: 'user-missing',
          message: 'Google sign-in failed. Please try again.',
        );
      }

      final existingUser = await _userRepository.getUserByUid(firebaseUser.uid);

      UserModel userModel;

      if (existingUser == null) {
        userModel = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          fullName: firebaseUser.displayName ?? 'User',
          role: kIsWeb ? UserRole.supervisor : UserRole.intern,
        );

        await _userRepository.createUser(userModel);
      } else {
        userModel = existingUser;
      }

      await _enforcePlatformRole(userModel.role);

      return userModel;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (_) {
      throw const AuthException(
        code: 'unknown',
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
  }

  Future<UserModel> _registerUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthException(
          code: 'user-missing',
          message: 'Account creation failed. Please try again.',
        );
      }

      await firebaseUser.updateDisplayName(fullName.trim());
      await firebaseUser.reload();

      final refreshedUser = _auth.currentUser ?? firebaseUser;

      final userModel = UserModel(
        uid: refreshedUser.uid,
        email: refreshedUser.email ?? email.trim(),
        fullName: fullName.trim(),
        role: role,
      );

      try {
        await _userRepository.createUser(userModel);

        final verifiedRole = await _userRepository.getUserRoleWithRetry(
          refreshedUser.uid,
        );

        if (verifiedRole == null) {
          await refreshedUser.delete();

          throw const AuthException(
            code: 'profile-create-failed',
            message: 'Account setup failed. Please try again.',
          );
        }
      } catch (e) {
        if (e is AuthException) rethrow;

        await refreshedUser.delete();

        throw const AuthException(
          code: 'profile-create-failed',
          message: 'Account profile could not be saved. Please try again.',
        );
      }

      await _enforcePlatformRole(userModel.role);

      return userModel;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        code: e.code,
        message: _mapAuthError(e.code),
      );
    } catch (_) {
      throw const AuthException(
        code: 'unknown',
        message: 'Registration failed. Please try again.',
      );
    }
  }

  Future<UserModel> _loadVerifiedUser(String uid) async {
    final role = await _userRepository.getUserRoleWithRetry(uid);

    if (role == null) {
      await signOut();

      throw const AuthException(
        code: 'profile-not-found',
        message:
            'Your account profile was not found. Please contact your administrator.',
      );
    }

    final user = await _userRepository.getUserByUid(uid);

    if (user == null) {
      await signOut();

      throw const AuthException(
        code: 'profile-not-found',
        message:
            'Your account profile was not found. Please contact your administrator.',
      );
    }

    return user;
  }

  Future<void> _enforcePlatformRole(UserRole role) async {
    final bool wrongPlatform =
        (kIsWeb && role == UserRole.intern) ||
        (!kIsWeb && role == UserRole.supervisor);

    if (!wrongPlatform) return;

    await signOut();

    if (kIsWeb) {
      throw const AuthException(
        code: 'wrong-platform',
        message:
            'Intern accounts are not permitted on the Supervisor portal. Please use the mobile app.',
      );
    }

    throw const AuthException(
      code: 'wrong-platform',
      message:
          'Supervisor accounts are not permitted on the mobile app. Please use the web portal.',
    );
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
      case 'popup-closed-by-user':
        return 'Google sign-in was cancelled.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}