import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/attendance_model.dart';
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
  static const String _usersCollection = 'users';

  Future<String> submitRequest({
    required String internUid,
    required String internName,
    required String internEmail,
    required DateTime requestDate,
    required String requestedStartTime,
    required String requestedEndTime,
    required String reason,
    String proofNote = '',
  }) {
    return submitMissingTimeRequest(
      internUid: internUid,
      internName: internName,
      internEmail: internEmail,
      requestDate: requestDate,
      requestedStartTime: requestedStartTime,
      requestedEndTime: requestedEndTime,
      reason: reason,
      proofNote: proofNote,
    );
  }

  Future<String> submitMissingTimeRequest({
    required String internUid,
    required String internName,
    required String internEmail,
    required DateTime requestDate,
    required String requestedStartTime,
    required String requestedEndTime,
    required String reason,
    String proofNote = '',
  }) async {
    final model = TimeRequestModel(
      internUid: internUid,
      internName: internName,
      internEmail: internEmail,
      requestType: TimeRequestType.missingTime,
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

  Future<String> submitCorrectionRequest({
    required String internUid,
    required String internName,
    required String internEmail,
    required DateTime requestDate,
    required String requestedStartTime,
    required String requestedEndTime,
    required String reason,
    String proofNote = '',
    required String originalClockInLogId,
    required String originalClockOutLogId,
    required String originalStartTime,
    required String originalEndTime,
  }) async {
    final model = TimeRequestModel(
      internUid: internUid,
      internName: internName,
      internEmail: internEmail,
      requestType: TimeRequestType.correction,
      requestDate: requestDate,
      requestedStartTime: requestedStartTime,
      requestedEndTime: requestedEndTime,
      reason: reason,
      proofNote: proofNote,
      status: TimeRequestStatus.pending,
      submittedAt: DateTime.now(),
      originalClockInLogId: originalClockInLogId,
      originalClockOutLogId: originalClockOutLogId,
      originalStartTime: originalStartTime,
      originalEndTime: originalEndTime,
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

      await _approveRequest(
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

      final currentRequest = TimeRequestModel.fromMap(
        requestSnapshot.data()!,
        id: requestSnapshot.id,
      );

      if (currentRequest.status != TimeRequestStatus.pending) {
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

  Future<void> _approveRequest({
    required String requestId,
    required String reviewedBy,
    required String reviewRemarks,
    required String approvedStartTime,
    required String approvedEndTime,
  }) async {
    final requestRef = _firestoreService.collection(_collection).doc(requestId);

    final requestSnapshot = await requestRef.get();

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

    await _ensureRequestWithinInternshipDuration(
      internUid: request.internUid,
      requestDate: request.requestDate,
    );

    if (request.isCorrection) {
      await _approveCorrectionRequest(
        request: request,
        reviewedBy: reviewedBy,
        reviewRemarks: reviewRemarks,
        approvedStartTime: approvedStartTime,
        approvedEndTime: approvedEndTime,
        approvedStartDateTime: approvedStartDateTime,
        approvedEndDateTime: approvedEndDateTime,
      );
    } else {
      await _approveMissingTimeRequest(
        request: request,
        reviewedBy: reviewedBy,
        reviewRemarks: reviewRemarks,
        approvedStartTime: approvedStartTime,
        approvedEndTime: approvedEndTime,
        approvedStartDateTime: approvedStartDateTime,
        approvedEndDateTime: approvedEndDateTime,
      );
    }
  }

  Future<void> _ensureRequestWithinInternshipDuration({
    required String internUid,
    required DateTime requestDate,
  }) async {
    final userSnapshot =
        await _firestoreService.collection(_usersCollection).doc(internUid).get();

    if (!userSnapshot.exists) {
      throw const TimeRequestReviewException(
        'Intern profile was not found. This request cannot be approved.',
      );
    }

    final data = userSnapshot.data();

    final internshipStartDate = _toDateTime(data?['internshipStartDate']);
    final internshipEndDate = _toDateTime(data?['internshipEndDate']);

    if (internshipStartDate == null || internshipEndDate == null) {
      throw const TimeRequestReviewException(
        'Internship duration is not set for this intern. Please update the intern assignment before approving this request.',
      );
    }

    final requested = DateTime(
      requestDate.year,
      requestDate.month,
      requestDate.day,
    );

    final start = DateTime(
      internshipStartDate.year,
      internshipStartDate.month,
      internshipStartDate.day,
    );

    final end = DateTime(
      internshipEndDate.year,
      internshipEndDate.month,
      internshipEndDate.day,
    );

    if (requested.isBefore(start) || requested.isAfter(end)) {
      throw TimeRequestReviewException(
        'Requested date is outside the intern\'s internship period (${_formatDate(start)} - ${_formatDate(end)}).',
      );
    }
  }

  Future<void> _approveMissingTimeRequest({
    required TimeRequestModel request,
    required String reviewedBy,
    required String reviewRemarks,
    required String approvedStartTime,
    required String approvedEndTime,
    required DateTime approvedStartDateTime,
    required DateTime approvedEndDateTime,
  }) async {
    final requestId = request.id!;

    await _ensureNoAttendanceOverlap(
      internUid: request.internUid,
      requestId: requestId,
      proposedStart: approvedStartDateTime,
      proposedEnd: approvedEndDateTime,
    );

    final requestRef = _firestoreService.collection(_collection).doc(requestId);

    final clockInRef = _firestoreService
        .collection(_attendanceCollection)
        .doc('${requestId}_manual_clock_in');

    final clockOutRef = _firestoreService
        .collection(_attendanceCollection)
        .doc('${requestId}_manual_clock_out');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final latestRequestSnapshot = await transaction.get(requestRef);
      final existingClockIn = await transaction.get(clockInRef);
      final existingClockOut = await transaction.get(clockOutRef);

      if (!latestRequestSnapshot.exists) {
        throw const TimeRequestReviewException('Time request not found.');
      }

      final latestRequest = TimeRequestModel.fromMap(
        latestRequestSnapshot.data()!,
        id: latestRequestSnapshot.id,
      );

      if (latestRequest.status != TimeRequestStatus.pending) {
        throw const TimeRequestReviewException(
          'This request has already been reviewed.',
        );
      }

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
        'isReplaced': false,
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
        'isReplaced': false,
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

  Future<void> _approveCorrectionRequest({
    required TimeRequestModel request,
    required String reviewedBy,
    required String reviewRemarks,
    required String approvedStartTime,
    required String approvedEndTime,
    required DateTime approvedStartDateTime,
    required DateTime approvedEndDateTime,
  }) async {
    final requestId = request.id!;

    final originalClockInId = request.originalClockInLogId;
    final originalClockOutId = request.originalClockOutLogId;

    if (originalClockInId == null ||
        originalClockInId.trim().isEmpty ||
        originalClockOutId == null ||
        originalClockOutId.trim().isEmpty) {
      throw const TimeRequestReviewException(
        'Original attendance session is missing. This correction request cannot be approved.',
      );
    }

    await _ensureNoAttendanceOverlap(
      internUid: request.internUid,
      requestId: requestId,
      proposedStart: approvedStartDateTime,
      proposedEnd: approvedEndDateTime,
      ignoredClockInLogId: originalClockInId,
      ignoredClockOutLogId: originalClockOutId,
    );

    final requestRef = _firestoreService.collection(_collection).doc(requestId);

    final originalClockInRef =
        _firestoreService.collection(_attendanceCollection).doc(originalClockInId);

    final originalClockOutRef =
        _firestoreService.collection(_attendanceCollection).doc(originalClockOutId);

    final correctedClockInRef = _firestoreService
        .collection(_attendanceCollection)
        .doc('${requestId}_corrected_clock_in');

    final correctedClockOutRef = _firestoreService
        .collection(_attendanceCollection)
        .doc('${requestId}_corrected_clock_out');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final latestRequestSnapshot = await transaction.get(requestRef);
      final originalClockInSnapshot = await transaction.get(originalClockInRef);
      final originalClockOutSnapshot = await transaction.get(originalClockOutRef);
      final existingCorrectedClockIn =
          await transaction.get(correctedClockInRef);
      final existingCorrectedClockOut =
          await transaction.get(correctedClockOutRef);

      if (!latestRequestSnapshot.exists) {
        throw const TimeRequestReviewException('Time request not found.');
      }

      final latestRequest = TimeRequestModel.fromMap(
        latestRequestSnapshot.data()!,
        id: latestRequestSnapshot.id,
      );

      if (latestRequest.status != TimeRequestStatus.pending) {
        throw const TimeRequestReviewException(
          'This request has already been reviewed.',
        );
      }

      if (!originalClockInSnapshot.exists || !originalClockOutSnapshot.exists) {
        throw const TimeRequestReviewException(
          'The original attendance logs no longer exist.',
        );
      }

      final originalClockInData = originalClockInSnapshot.data()!;
      final originalClockOutData = originalClockOutSnapshot.data()!;

      if (originalClockInData['uid'] != request.internUid ||
          originalClockOutData['uid'] != request.internUid) {
        throw const TimeRequestReviewException(
          'The selected attendance session does not belong to this intern.',
        );
      }

      if (originalClockInData['isReplaced'] == true ||
          originalClockOutData['isReplaced'] == true) {
        throw const TimeRequestReviewException(
          'This attendance session has already been replaced by a previous correction.',
        );
      }

      if (existingCorrectedClockIn.exists || existingCorrectedClockOut.exists) {
        throw const TimeRequestReviewException(
          'Corrected attendance logs for this request already exist.',
        );
      }

      final now = DateTime.now();

      transaction.update(originalClockInRef, {
        'isReplaced': true,
        'replacedByTimeRequestId': requestId,
        'replacedAt': Timestamp.fromDate(now),
        'replacedBy': reviewedBy,
      });

      transaction.update(originalClockOutRef, {
        'isReplaced': true,
        'replacedByTimeRequestId': requestId,
        'replacedAt': Timestamp.fromDate(now),
        'replacedBy': reviewedBy,
      });

      transaction.set(correctedClockInRef, {
        'uid': request.internUid,
        'timestamp': Timestamp.fromDate(approvedStartDateTime),
        'status': 'Clock-In',
        'location_coords': originalClockInData['location_coords'],
        'source': 'correction_request',
        'timeRequestId': requestId,
        'isReplaced': false,
        'replacesClockInLogId': originalClockInId,
        'replacesClockOutLogId': originalClockOutId,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': reviewedBy,
      });

      transaction.set(correctedClockOutRef, {
        'uid': request.internUid,
        'timestamp': Timestamp.fromDate(approvedEndDateTime),
        'status': 'Clock-Out',
        'location_coords': originalClockOutData['location_coords'],
        'source': 'correction_request',
        'timeRequestId': requestId,
        'isReplaced': false,
        'replacesClockInLogId': originalClockInId,
        'replacesClockOutLogId': originalClockOutId,
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
        'attendanceClockInLogId': correctedClockInRef.id,
        'attendanceClockOutLogId': correctedClockOutRef.id,
      });
    });
  }

  Future<void> _ensureNoAttendanceOverlap({
    required String internUid,
    required String requestId,
    required DateTime proposedStart,
    required DateTime proposedEnd,
    String? ignoredClockInLogId,
    String? ignoredClockOutLogId,
  }) async {
    final logs = await _getAttendanceLogsForDate(
      internUid: internUid,
      date: proposedStart,
    );

    final sessions = _buildSessionsFromLogs(logs);

    for (final session in sessions) {
      if (session.timeRequestId == requestId) {
        continue;
      }

      if (ignoredClockInLogId != null &&
          ignoredClockOutLogId != null &&
          session.clockInId == ignoredClockInLogId &&
          session.clockOutId == ignoredClockOutLogId) {
        continue;
      }

      final overlaps = _rangesOverlap(
        proposedStart: proposedStart,
        proposedEnd: proposedEnd,
        existingStart: session.start,
        existingEnd: session.end,
      );

      if (overlaps) {
        throw TimeRequestReviewException(
          'This approved time overlaps with an existing attendance session '
          '(${_formatTime(session.start)} - ${_formatTime(session.end)}). '
          'Please review the intern\'s logs before approving.',
        );
      }
    }
  }

  Future<List<_AttendanceLogForReview>> _getAttendanceLogsForDate({
    required String internUid,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final nextDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestoreService
        .collection(_attendanceCollection)
        .where('uid', isEqualTo: internUid)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final model = AttendanceModel.fromMap(data, id: doc.id);

          return _AttendanceLogForReview(
            id: doc.id,
            timestamp: model.timestamp,
            status: model.status,
            timeRequestId: data['timeRequestId']?.toString(),
            isReplaced: data['isReplaced'] == true,
          );
        })
        .where((log) =>
            !log.timestamp.isBefore(startOfDay) &&
            log.timestamp.isBefore(nextDay) &&
            !log.isReplaced)
        .toList();
  }

  List<_AttendanceSessionForReview> _buildSessionsFromLogs(
    List<_AttendanceLogForReview> logs,
  ) {
    final sorted = [...logs]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final sessions = <_AttendanceSessionForReview>[];
    _AttendanceLogForReview? activeClockIn;

    for (final log in sorted) {
      if (log.status == AttendanceStatus.clockIn) {
        activeClockIn = log;
        continue;
      }

      if (log.status == AttendanceStatus.clockOut && activeClockIn != null) {
        if (log.timestamp.isAfter(activeClockIn.timestamp)) {
          sessions.add(
            _AttendanceSessionForReview(
              start: activeClockIn.timestamp,
              end: log.timestamp,
              clockInId: activeClockIn.id,
              clockOutId: log.id,
              timeRequestId: activeClockIn.timeRequestId ?? log.timeRequestId,
            ),
          );
        }

        activeClockIn = null;
      }
    }

    return sessions;
  }

  bool _rangesOverlap({
    required DateTime proposedStart,
    required DateTime proposedEnd,
    required DateTime existingStart,
    required DateTime existingEnd,
  }) {
    return proposedStart.isBefore(existingEnd) &&
        proposedEnd.isAfter(existingStart);
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm/$dd/${date.year}';
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

  String _formatTime(DateTime dateTime) {
    final hour24 = dateTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = hour24 >= 12 ? 'PM' : 'AM';

    return '$hour12:$minute $suffix';
  }
}

class _AttendanceLogForReview {
  final String id;
  final DateTime timestamp;
  final AttendanceStatus status;
  final String? timeRequestId;
  final bool isReplaced;

  const _AttendanceLogForReview({
    required this.id,
    required this.timestamp,
    required this.status,
    required this.timeRequestId,
    required this.isReplaced,
  });
}

class _AttendanceSessionForReview {
  final DateTime start;
  final DateTime end;
  final String clockInId;
  final String clockOutId;
  final String? timeRequestId;

  const _AttendanceSessionForReview({
    required this.start,
    required this.end,
    required this.clockInId,
    required this.clockOutId,
    required this.timeRequestId,
  });
}