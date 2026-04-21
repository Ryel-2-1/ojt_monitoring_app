// lib/repositories/user_repository.dart
//
// PURPOSE: All Firestore operations for the `users` collection.
//
// Phase 3 addition: getUserRole()
// A lightweight helper that reads ONLY the `role` field from a user's
// Firestore document. Used by AuthService during the login flow to
// enforce the Mobile=Intern / Web=Supervisor access rule without
// loading the full UserModel.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'users';

  // ─────────────────────────────────────────────
  // CREATE — Save new user after registration
  // ─────────────────────────────────────────────

  // createUser():
  // Called by AuthService._registerUser() after Firebase Auth account
  // creation succeeds. Saves the full user profile to Firestore.
  //
  // Uses merge: false so this is a clean write on first creation.
  // createdAt is added here via serverTimestamp() — not in UserModel.toMap()
  // — because client-side timestamps can be unreliable.
  Future<void> createUser(UserModel user) async {
    try {
      final data = {
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.setDocument(
        path: _collection,
        docId: user.uid,
        data: data,
        merge: false,
      );
    } catch (e) {
      throw Exception('Failed to save user profile: $e');
    }
  }

  // ─────────────────────────────────────────────
  // READ (LIGHTWEIGHT) — Fetch role only
  // ─────────────────────────────────────────────

  // getUserRole():
  // NEW in Phase 3. Returns ONLY the UserRole enum for a given uid.
  // Called by AuthService.signInWithEmail() and signInWithGoogle()
  // to enforce the platform access rule.
  //
  // WHY A SEPARATE METHOD INSTEAD OF CALLING getUserByUid():
  // getUserByUid() fetches and deserializes the entire UserModel
  // (all fields, including timestamps). During the login flow, we only
  // need one field — the role. A direct document field read is:
  //   - Faster: less data transferred from Firestore.
  //   - Cheaper: still counts as 1 Firestore read, but no wasted
  //     deserialization of fields we don't need.
  //   - Clearer intent: the name makes it obvious this is a quick
  //     access check, not a full profile load.
  //
  // Returns null if:
  //   - The user document doesn't exist (registration was interrupted).
  //   - The `role` field is missing from the document.
  // AuthService treats null as 'profile-not-found' and signs the user out.
  Future<UserRole?> getUserRole(String uid) async {
    try {
      // We use the Firestore SDK directly here via FirestoreService's
      // collection() accessor to do a targeted field read.
      // This avoids loading all fields when only `role` is needed.
      final snapshot = await _firestoreService
          .collection(_collection)
          .doc(uid)
          .get();

      if (!snapshot.exists || snapshot.data() == null) return null;

      final rawRole = snapshot.data()!['role'] as String?;
      if (rawRole == null) return null;

      // Convert the Firestore string ("intern"/"supervisor") back to enum.
      return UserRoleExtension.fromString(rawRole);
    } catch (e) {
      throw Exception('Failed to fetch user role: $e');
    }
  }

  // ─────────────────────────────────────────────
  // READ — Fetch full user profile by UID
  // ─────────────────────────────────────────────

  // getUserByUid():
  // Used by profile screens and AuthGate after login to load the
  // full UserModel. Not used for the access check (see getUserRole above).
  // Returns null if the profile doesn't exist yet.
  Future<UserModel?> getUserByUid(String uid) async {
    try {
      final data = await _firestoreService.getDocument(
        path: _collection,
        docId: uid,
      );

      if (data == null) return null;
      return UserModel.fromMap(data, id: uid);
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  // ─────────────────────────────────────────────
  // READ — Stream user profile (real-time)
  // ─────────────────────────────────────────────

  // streamUser():
  // For screens that need live updates — e.g., if an admin changes
  // a user's role remotely, the profile screen reflects it immediately.
  Stream<UserModel?> streamUser(String uid) {
    return _firestoreService
        .streamDocument(path: _collection, docId: uid)
        .map((data) => data != null ? UserModel.fromMap(data, id: uid) : null);
  }

  // ─────────────────────────────────────────────
  // UPDATE — Modify specific profile fields
  // ─────────────────────────────────────────────

  // updateUser():
  // For partial updates — e.g., user changes their full name.
  // Only provided fields are written; other fields are untouched.
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    try {
      await _firestoreService.updateDocument(
        path: _collection,
        docId: uid,
        data: fields,
      );
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }
}