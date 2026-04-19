// lib/services/auth_service.dart
//
// PURPOSE: Handles all Authentication logic.
// Separating auth into its own service means any developer can swap
// the sign-in provider (e.g., add email/password later) without touching UI code.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  // --- Singleton Pattern ---
  // We use a private constructor + static instance so the entire app
  // shares one AuthService object. This avoids creating duplicate
  // Firebase/GoogleSignIn instances, which can cause errors.
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // FirebaseAuth.instance is the entry point for all auth operations.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // GoogleSignIn handles the Google account picker popup/sheet.
  // On Web, we must pass the clientId (from your Firebase Web config).
  // On Android, it reads from google-services.json automatically.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '373017801855-YOUR_WEB_CLIENT_ID.apps.googleusercontent.com' // <-- Replace with your actual Web Client ID from Firebase Console
        : null,
    scopes: ['email', 'profile'],
  );

  // --- Stream: Auth State Changes ---
  // Exposes a stream so any widget can listen and rebuild when
  // the user logs in or out. Use this in main.dart with StreamBuilder.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Current User Getter ---
  // A quick way to get the currently logged-in user anywhere in the app.
  // Returns null if no user is signed in.
  User? get currentUser => _auth.currentUser;

  // --- Google Sign-In ---
  // Returns the Firebase User on success, or null if the user cancelled.
  // Throws an exception on actual errors (network issues, config problems).
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // On Web: use a popup window for Google Sign-In.
        // GoogleAuthProvider is Firebase's built-in Web OAuth handler.
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // On Android: trigger the native Google account picker sheet.
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        // User cancelled the sign-in flow.
        if (googleUser == null) return null;

        // Get auth tokens from the chosen Google account.
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create a Firebase credential using those tokens.
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign into Firebase with that credential.
        userCredential = await _auth.signInWithCredential(credential);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // FirebaseAuthException gives us a structured error code.
      // This is better than a generic catch because we can show
      // user-friendly messages based on e.code.
      throw Exception('Auth error [${e.code}]: ${e.message}');
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  // --- Sign Out ---
  // Signs out from both Firebase and Google.
  // Signing out from Google is important on Android so the account
  // picker appears again on the next sign-in instead of auto-selecting.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      if (!kIsWeb) _googleSignIn.signOut(),
    ]);
  }
}