// lib/repositories/user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/geofence_settings.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'users';

  // ─────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────

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
  // READ — Role only (single attempt)
  // ─────────────────────────────────────────────

  Future<UserRole?> getUserRole(String uid) async {
    try {
      final snapshot = await _firestoreService
          .collection(_collection)
          .doc(uid)
          .get();

      if (!snapshot.exists || snapshot.data() == null) return null;

      final rawRole = snapshot.data()!['role'] as String?;
      if (rawRole == null) return null;

      return UserRoleExtension.fromString(rawRole);
    } catch (e) {
      throw Exception('Failed to fetch user role: $e');
    }
  }

  // ─────────────────────────────────────────────
  // READ — Role with retry (for AuthGate)
  // ─────────────────────────────────────────────

  Future<UserRole?> getUserRoleWithRetry(String uid, {int maxRetries = 4}) async {
    const delays = [600, 1200, 2000, 3000]; // ms

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final role = await getUserRole(uid);
        if (role != null) return role;
      } catch (_) {
        // Ignore individual attempt errors — retry will handle it.
      }

      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: delays[attempt]));
      }
    }
    return null; 
  }

  // ─────────────────────────────────────────────
  // READ — Full profile
  // ─────────────────────────────────────────────

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
  // READ — Stream (real-time)
  // ─────────────────────────────────────────────

  Stream<UserModel?> streamUser(String uid) {
    return _firestoreService
        .streamDocument(path: _collection, docId: uid)
        .map((data) => data != null ? UserModel.fromMap(data, id: uid) : null);
  }

  // ─────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────

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

  // ─────────────────────────────────────────────
  // GEOFENCE SETTINGS FETCH
  // ─────────────────────────────────────────────

  Future<GeofenceSettings> getGeofenceSettings(String uid) async {
    final user = await getUserByUid(uid);
    
    if (user == null) {
      throw Exception('User profile not found.');
    }

    if (user.assignedLatitude == null || 
        user.assignedLongitude == null || 
        user.allowedRadius == null) {
      throw GeofenceNotAssignedException();
    }

    return GeofenceSettings(
      uid: uid,
      latitude: user.assignedLatitude!,
      longitude: user.assignedLongitude!,
      radiusInMeters: user.allowedRadius!,
    );
  }
}