import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/enrollment_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class EnrollmentRepository {
  final FirestoreService _firestoreService;

  EnrollmentRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  static const String collectionPath = 'enrollments';
  static const String usersCollectionPath = 'users';

  Stream<List<EnrollmentModel>> streamEnrollments({
    String? supervisorUid,
    String? internUid,
    EnrollmentStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _firestoreService.collection(
      collectionPath,
    );

    if (supervisorUid != null && supervisorUid.trim().isNotEmpty) {
      query = query.where('supervisorUid', isEqualTo: supervisorUid.trim());
    }

    if (internUid != null && internUid.trim().isNotEmpty) {
      query = query.where('internUid', isEqualTo: internUid.trim());
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    return query.snapshots().map((snapshot) {
      final enrollments = snapshot.docs
          .map((doc) => EnrollmentModel.fromMap(doc.data(), id: doc.id))
          .toList();

      enrollments.sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return enrollments;
    });
  }

  Future<List<EnrollmentModel>> getEnrollments({
    String? supervisorUid,
    String? internUid,
    EnrollmentStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _firestoreService.collection(
      collectionPath,
    );

    if (supervisorUid != null && supervisorUid.trim().isNotEmpty) {
      query = query.where('supervisorUid', isEqualTo: supervisorUid.trim());
    }

    if (internUid != null && internUid.trim().isNotEmpty) {
      query = query.where('internUid', isEqualTo: internUid.trim());
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }

    final snapshot = await query.get();

    final enrollments = snapshot.docs
        .map((doc) => EnrollmentModel.fromMap(doc.data(), id: doc.id))
        .toList();

    enrollments.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return enrollments;
  }

  Future<EnrollmentModel?> getActiveEnrollmentForIntern(
    String internUid,
  ) async {
    if (internUid.trim().isEmpty) return null;

    final snapshot = await _firestoreService
        .collection(collectionPath)
        .where('internUid', isEqualTo: internUid.trim())
        .where('status', isEqualTo: EnrollmentStatus.active.value)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final enrollments = snapshot.docs
        .map((doc) => EnrollmentModel.fromMap(doc.data(), id: doc.id))
        .toList();

    enrollments.sort((a, b) {
      final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
      final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return enrollments.first;
  }

  Future<String> createOrUpdateActiveEnrollment({
    required UserModel intern,
    required UserModel supervisor,
    required String companyId,
    required String companyName,
    required String companyAddress,
    required double assignedLatitude,
    required double assignedLongitude,
    required double allowedRadius,
    required int requiredOjtHours,
    DateTime? internshipStartDate,
    DateTime? internshipEndDate,
  }) async {
    final existingEnrollment = await getActiveEnrollmentForIntern(intern.uid);

    final model = EnrollmentModel(
      id: existingEnrollment?.id,
      internUid: intern.uid,
      internName: intern.fullName,
      internEmail: intern.email,
      supervisorUid: supervisor.uid,
      supervisorName: supervisor.fullName,
      supervisorEmail: supervisor.email,
      companyId: companyId,
      companyName: companyName,
      companyAddress: companyAddress,
      assignedLatitude: assignedLatitude,
      assignedLongitude: assignedLongitude,
      allowedRadius: allowedRadius,
      requiredOjtHours: requiredOjtHours,
      internshipStartDate: internshipStartDate,
      internshipEndDate: internshipEndDate,
      status: EnrollmentStatus.active,
      createdAt: existingEnrollment?.createdAt,
    );

    if (existingEnrollment?.id != null) {
      await _firestoreService.updateDocument(
        path: collectionPath,
        docId: existingEnrollment!.id!,
        data: model.toUpdateMap(),
      );

      await _syncUserQuickFields(
        internUid: intern.uid,
        enrollmentId: existingEnrollment.id!,
        enrollment: model,
      );

      return existingEnrollment.id!;
    }

    final enrollmentId = await _firestoreService.addDocument(
      path: collectionPath,
      data: model.toMap(),
    );

    await _syncUserQuickFields(
      internUid: intern.uid,
      enrollmentId: enrollmentId,
      enrollment: model.copyWith(id: enrollmentId),
    );

    return enrollmentId;
  }

  Future<void> updateEnrollmentStatus({
    required String enrollmentId,
    required EnrollmentStatus status,
  }) async {
    await _firestoreService.updateDocument(
      path: collectionPath,
      docId: enrollmentId,
      data: {'status': status.value, 'updatedAt': FieldValue.serverTimestamp()},
    );

    final doc = await _firestoreService
        .collection(collectionPath)
        .doc(enrollmentId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final enrollment = EnrollmentModel.fromMap(data, id: doc.id);

    await _firestoreService.updateDocument(
      path: usersCollectionPath,
      docId: enrollment.internUid,
      data: {
        'enrollmentId': enrollmentId,
        'enrollmentStatus': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> withdrawActiveEnrollmentForIntern(String internUid) async {
    final activeEnrollment = await getActiveEnrollmentForIntern(internUid);

    if (activeEnrollment?.id == null) return;

    await updateEnrollmentStatus(
      enrollmentId: activeEnrollment!.id!,
      status: EnrollmentStatus.withdrawn,
    );
  }

  Future<void> _syncUserQuickFields({
    required String internUid,
    required String enrollmentId,
    required EnrollmentModel enrollment,
  }) async {
    await _firestoreService.updateDocument(
      path: usersCollectionPath,
      docId: internUid,
      data: {
        'supervisorUid': enrollment.supervisorUid,
        'supervisorName': enrollment.supervisorName,
        'supervisorEmail': enrollment.supervisorEmail,
        'enrollmentId': enrollmentId,
        'enrollmentStatus': enrollment.status.value,
        'companyId': enrollment.companyId,
        'companyName': enrollment.companyName,
        'companyAddress': enrollment.companyAddress,
        'assignedLatitude': enrollment.assignedLatitude,
        'assignedLongitude': enrollment.assignedLongitude,
        'allowedRadius': enrollment.allowedRadius,
        'requiredOjtHours': enrollment.requiredOjtHours,
        'internshipStartDate': enrollment.internshipStartDate == null
            ? null
            : Timestamp.fromDate(enrollment.internshipStartDate!),
        'internshipEndDate': enrollment.internshipEndDate == null
            ? null
            : Timestamp.fromDate(enrollment.internshipEndDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }
}
