// lib/repositories/user_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/geofence_settings.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String collectionPath = 'users';

  Future<void> createUser(UserModel user) async {
    try {
      final data = {
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.setDocument(
        path: collectionPath,
        docId: user.uid,
        data: data,
        merge: false,
      );
    } catch (_) {
      throw Exception('Failed to save user profile.');
    }
  }

  Future<void> createUserIfMissing(UserModel user) async {
    final existingUser = await getUserByUid(user.uid);

    if (existingUser != null) return;

    await createUser(user);
  }

  Future<UserRole?> getUserRole(String uid) async {
    try {
      final data = await _firestoreService.getDocument(
        path: collectionPath,
        docId: uid,
      );

      if (data == null) return null;

      return UserRoleExtension.fromString(data['role']?.toString());
    } catch (_) {
      throw Exception('Failed to verify user role.');
    }
  }

  Future<UserRole?> getUserRoleWithRetry(
    String uid, {
    int maxRetries = 4,
  }) async {
    const delays = <int>[600, 1200, 2000, 3000];

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final role = await getUserRole(uid);
        if (role != null) return role;
      } catch (_) {
        // Retry silently. AuthGate will show a clean message if all attempts fail.
      }

      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: delays[attempt]));
      }
    }

    return null;
  }

  Future<UserModel?> getUserByUid(String uid) async {
    try {
      final data = await _firestoreService.getDocument(
        path: collectionPath,
        docId: uid,
      );

      if (data == null) return null;

      return UserModel.fromMap(data, id: uid);
    } catch (_) {
      throw Exception('Failed to fetch user profile.');
    }
  }

  Stream<UserModel?> streamUser(String uid) {
    return _firestoreService
        .streamDocument(path: collectionPath, docId: uid)
        .map((data) => data == null ? null : UserModel.fromMap(data, id: uid));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    try {
      await _firestoreService.updateDocument(
        path: collectionPath,
        docId: uid,
        data: {
          ...fields,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } catch (_) {
      throw Exception('Failed to update user profile.');
    }
  }

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

  Stream<List<UserModel>> streamInternUsers() {
    return _firestoreService
        .streamCollection(
          path: collectionPath,
          field: 'role',
          value: UserRole.intern.value,
          orderBy: 'fullName',
        )
        .map(
          (rows) => rows
              .map((row) => UserModel.fromMap(row, id: row['id']?.toString()))
              .toList(),
        );
  }

  Future<List<UserModel>> getInternUsers() async {
    try {
      final rows = await _firestoreService.queryCollection(
        path: collectionPath,
        field: 'role',
        value: UserRole.intern.value,
        orderBy: 'fullName',
      );

      return rows
          .map((row) => UserModel.fromMap(row, id: row['id']?.toString()))
          .toList();
    } catch (_) {
      throw Exception('Failed to fetch intern users.');
    }
  }
}