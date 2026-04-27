import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/time_request_model.dart';
import '../services/firestore_service.dart';

class TimeRequestReviewException implements Exception {
  final String message;

  const TimeRequestReviewException(this.message);

  @override
  String toString() => message;
}

class TimeRequestRepository {
  final FirestoreService _firestoreService;

  TimeRequestRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'time_requests';
  static const String _attendanceCollection = 'attendance';

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
    if (status == TimeRequestStatus.approved) {
      if (approvedStartTime == null ||
          approvedStartTime.trim().isEmpty ||
          approvedEndTime == null ||
          approvedEndTime.trim().isEmpty) {
        throw const TimeRequestReviewException(
          'Approved start and end time are required.',
        );
      }

      await _approveRequestAndCreateAttendancePair(
        requestId: requestId,
        reviewedBy: reviewedBy,
        reviewRemarks: reviewRemarks ?? '',
        approvedStartTime: approvedStartTime.trim(),
        approvedEndTime: approvedEndTime.trim(),
      );

      return;
    }

    await _reviewWithoutAttendanceUpdate(
      requestId: requestId,
      status: status,
      reviewedBy: reviewedBy,
      reviewRemarks: reviewRemarks ?? '',
    );
  }

  Future<void> _reviewWithoutAttendanceUpdate({
    required String requestId,
    required TimeRequestStatus status,
    required String reviewedBy,
    required String reviewRemarks,
  }) async {
    final requestRef = _firestoreService.collection(_collection).doc(requestId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);

      if (!requestSnapshot.exists) {
        throw const TimeRequestReviewException('Time request not found.');
      }

      final currentData = requestSnapshot.data()!;
      final currentStatus = TimeRequestModel.fromMap(
        currentData,
        id: requestSnapshot.id,
      ).status;

      if (currentStatus != TimeRequestStatus.pending) {
        throw const TimeRequestReviewException(
          'This request has already been reviewed.',
        );
      }

      transaction.update(requestRef, {
        'status': status.name,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewedBy': reviewedBy,
        'reviewRemarks': reviewRemarks,
        'approvedStartTime': null,
        'approvedEndTime': null,
      });
    });
  }

  Future<void> _approveRequestAndCreateAttendancePair({
    required String requestId,
    required String reviewedBy,
    required String reviewRemarks,
    required String approvedStartTime,
    required String approvedEndTime,
  }) async {
    final requestRef = _firestoreService.collection(_collection).doc(requestId);

    final clockInRef = _firestoreService
        .collection(_attendanceCollection)
        .doc('${requestId}_manual_clock_in');

    final clockOutRef = _firestoreService
        .collection(_attendanceCollection)
        .doc('${requestId}_manual_clock_out');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);

      if (!requestSnapshot.exists) {
        throw const TimeRequestReviewException('Time request not found.');
      }

      final request = TimeRequestModel.fromMap(
        requestSnapshot.data()!,
        id: requestSnapshot.id,
      );

      if (request.status != TimeRequestStatus.pending) {
        throw const TimeRequestReviewException(
          'This request has already been reviewed.',
        );
      }

      final approvedStartDateTime = _combineDateAndTime(
        request.requestDate,
        approvedStartTime,
      );

      final approvedEndDateTime = _combineDateAndTime(
        request.requestDate,
        approvedEndTime,
      );

      if (!approvedEndDateTime.isAfter(approvedStartDateTime)) {
        throw const TimeRequestReviewException(
          'Approved end time must be after approved start time.',
        );
      }

      final existingClockIn = await transaction.get(clockInRef);
      final existingClockOut = await transaction.get(clockOutRef);

      if (existingClockIn.exists || existingClockOut.exists) {
        throw const TimeRequestReviewException(
          'Attendance logs for this request already exist.',
        );
      }

      final now = DateTime.now();

      transaction.set(clockInRef, {
        'uid': request.internUid,
        'timestamp': Timestamp.fromDate(approvedStartDateTime),
        'status': 'Clock-In',
        'location_coords': null,
        'source': 'manual_adjustment',
        'timeRequestId': requestId,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': reviewedBy,
      });

      transaction.set(clockOutRef, {
        'uid': request.internUid,
        'timestamp': Timestamp.fromDate(approvedEndDateTime),
        'status': 'Clock-Out',
        'location_coords': null,
        'source': 'manual_adjustment',
        'timeRequestId': requestId,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': reviewedBy,
      });

      transaction.update(requestRef, {
        'status': TimeRequestStatus.approved.name,
        'reviewedAt': Timestamp.fromDate(now),
        'reviewedBy': reviewedBy,
        'reviewRemarks': reviewRemarks,
        'approvedStartTime': approvedStartTime,
        'approvedEndTime': approvedEndTime,
        'attendanceClockInLogId': clockInRef.id,
        'attendanceClockOutLogId': clockOutRef.id,
      });
    });
  }

  DateTime _combineDateAndTime(DateTime date, String timeText) {
    final normalized = timeText.trim().toUpperCase();

    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(
      normalized,
    );

    if (match == null) {
      throw const TimeRequestReviewException(
        'Invalid time format. Please use a selected time like 8:00 AM.',
      );
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      throw const TimeRequestReviewException(
        'Invalid approved time. Please select a valid time.',
      );
    }

    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }
}