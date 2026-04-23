import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/time_request_model.dart';
import '../services/firestore_service.dart';

class TimeRequestRepository {
  final FirestoreService _firestoreService;

  TimeRequestRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'time_requests';

  Future<String> submitRequest({
    required String internUid,
    required String internName,
    required String internEmail,
    required DateTime requestDate,
    required String requestedStartTime,
    required String requestedEndTime,
    required String reason,
    required String proofNote,
  }) async {
    final model = TimeRequestModel(
      internUid: internUid,
      internName: internName,
      internEmail: internEmail,
      requestDate: requestDate,
      requestedStartTime: requestedStartTime,
      requestedEndTime: requestedEndTime,
      reason: reason,
      proofNote: proofNote,
      status: TimeRequestStatus.pending,
      submittedAt: DateTime.now(),
    );

    return _firestoreService.addDocument(
      path: _collection,
      data: model.toMap(),
    );
  }

  Stream<List<TimeRequestModel>> streamAllRequests() {
    return _firestoreService
        .collection(_collection)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TimeRequestModel.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  Stream<List<TimeRequestModel>> streamRequestsByIntern(String internUid) {
    return _firestoreService
        .collection(_collection)
        .where('internUid', isEqualTo: internUid)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TimeRequestModel.fromMap(doc.data(), id: doc.id))
          .toList();
    });
  }

  Future<void> reviewRequest({
    required String requestId,
    required TimeRequestStatus status,
    required String reviewedBy,
    String? reviewRemarks,
    String? approvedStartTime,
    String? approvedEndTime,
  }) async {
    await _firestoreService.updateDocument(
      path: _collection,
      docId: requestId,
      data: {
        'status': status.name,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewedBy': reviewedBy,
        'reviewRemarks': reviewRemarks ?? '',
        'approvedStartTime':
            status == TimeRequestStatus.approved ? approvedStartTime : null,
        'approvedEndTime':
            status == TimeRequestStatus.approved ? approvedEndTime : null,
      },
    );
  }
}