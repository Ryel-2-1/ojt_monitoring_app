// lib/repositories/user_repository.dart

import 'dart:math';

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
        data: {...fields, 'updatedAt': FieldValue.serverTimestamp()},
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

  Stream<List<UserModel>> streamInternUsers({
    String? supervisorUid,
    bool includeUnassigned = false,
  }) {
    return _firestoreService
        .streamCollection(
          path: collectionPath,
          field: 'role',
          value: UserRole.intern.value,
          orderBy: 'fullName',
        )
        .map((rows) {
          final users = rows
              .map((row) => UserModel.fromMap(row, id: row['id']?.toString()))
              .where((user) {
                if (supervisorUid == null || supervisorUid.trim().isEmpty) {
                  return true;
                }

                final assignedSupervisorUid = user.supervisorUid?.trim();
                final assignedToCurrentSupervisor =
                    assignedSupervisorUid == supervisorUid.trim();

                final unassigned =
                    assignedSupervisorUid == null ||
                    assignedSupervisorUid.isEmpty;

                if (includeUnassigned) {
                  return assignedToCurrentSupervisor || unassigned;
                }

                return assignedToCurrentSupervisor;
              })
              .toList();

          users.sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );

          return users;
        });
  }

  Future<List<UserModel>> getInternUsers({
    String? supervisorUid,
    bool includeUnassigned = false,
  }) async {
    try {
      final rows = await _firestoreService.queryCollection(
        path: collectionPath,
        field: 'role',
        value: UserRole.intern.value,
        orderBy: 'fullName',
      );

      final users = rows
          .map((row) => UserModel.fromMap(row, id: row['id']?.toString()))
          .where((user) {
            if (supervisorUid == null || supervisorUid.trim().isEmpty) {
              return true;
            }

            final assignedSupervisorUid = user.supervisorUid?.trim();
            final assignedToCurrentSupervisor =
                assignedSupervisorUid == supervisorUid.trim();

            final unassigned =
                assignedSupervisorUid == null || assignedSupervisorUid.isEmpty;

            if (includeUnassigned) {
              return assignedToCurrentSupervisor || unassigned;
            }

            return assignedToCurrentSupervisor;
          })
          .toList();

      users.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

      return users;
    } catch (_) {
      throw Exception('Failed to fetch intern users.');
    }
  }

  Future<String> generateSupervisorEnrollmentCode(String supervisorUid) async {
    final supervisor = await getUserByUid(supervisorUid);

    if (supervisor == null) {
      throw Exception('Supervisor profile not found.');
    }

    if (supervisor.role != UserRole.supervisor) {
      throw Exception('Only supervisors can generate enrollment codes.');
    }

    String code = '';
    bool isUnique = false;

    for (int attempt = 0; attempt < 10; attempt++) {
      code = _generateCode();

      final existing = await getSupervisorByEnrollmentCode(code);

      if (existing == null) {
        isUnique = true;
        break;
      }
    }

    if (!isUnique) {
      throw Exception('Could not generate a unique enrollment code.');
    }

    await updateUser(supervisorUid, {
      'enrollmentCode': code,
      'enrollmentCodeUpdatedAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  Future<UserModel?> getSupervisorByEnrollmentCode(String code) async {
    final cleanedCode = _normalizeEnrollmentCode(code);

    if (cleanedCode.isEmpty) return null;

    final snapshot = await _firestoreService
        .collection(collectionPath)
        .where('role', isEqualTo: UserRole.supervisor.value)
        .where('enrollmentCode', isEqualTo: cleanedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return UserModel.fromMap(doc.data(), id: doc.id);
  }

  Future<void> joinSupervisorByCode({
    required String internUid,
    required String code,
  }) async {
    final intern = await getUserByUid(internUid);

    if (intern == null) {
      throw Exception('Intern profile not found.');
    }

    if (intern.role != UserRole.intern) {
      throw Exception('Only interns can join a supervisor.');
    }

    final supervisor = await getSupervisorByEnrollmentCode(code);

    if (supervisor == null) {
      throw Exception(
        'Invalid enrollment code. Please check the code and try again.',
      );
    }

    await updateUser(internUid, {
      'supervisorUid': supervisor.uid,
      'supervisorName': supervisor.fullName,
      'supervisorEmail': supervisor.email,
      'joinedSupervisorAt': FieldValue.serverTimestamp(),

      // Joining a supervisor is not yet the final OJT enrollment.
      // The supervisor still needs to assign company/geofence/OJT details.
      'enrollmentStatus': intern.enrollmentStatus,
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    final suffix = List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return 'SUP-$suffix';
  }

  String _normalizeEnrollmentCode(String code) {
    return code.trim().toUpperCase().replaceAll(' ', '');
  }
}
