import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeRequestStatus {
  pending,
  approved,
  rejected,
}

enum TimeRequestType {
  missingTime,
  correction,
}

class TimeRequestModel {
  final String? id;
  final String internUid;
  final String internName;
  final String internEmail;

  final TimeRequestType requestType;

  final DateTime requestDate;
  final String requestedStartTime;
  final String requestedEndTime;
  final String reason;
  final String proofNote;

  final TimeRequestStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewRemarks;

  final String? approvedStartTime;
  final String? approvedEndTime;

  final String? originalClockInLogId;
  final String? originalClockOutLogId;
  final String? originalStartTime;
  final String? originalEndTime;

  final String? attendanceClockInLogId;
  final String? attendanceClockOutLogId;

  TimeRequestModel({
    this.id,
    required this.internUid,
    required this.internName,
    required this.internEmail,
    this.requestType = TimeRequestType.missingTime,
    required this.requestDate,
    required this.requestedStartTime,
    required this.requestedEndTime,
    required this.reason,
    required this.proofNote,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewRemarks,
    this.approvedStartTime,
    this.approvedEndTime,
    this.originalClockInLogId,
    this.originalClockOutLogId,
    this.originalStartTime,
    this.originalEndTime,
    this.attendanceClockInLogId,
    this.attendanceClockOutLogId,
  });

  bool get isMissingTime => requestType == TimeRequestType.missingTime;
  bool get isCorrection => requestType == TimeRequestType.correction;

  Map<String, dynamic> toMap() {
    return {
      'internUid': internUid,
      'internName': internName,
      'internEmail': internEmail,
      'requestType': requestType.name,
      'requestDate': Timestamp.fromDate(requestDate),
      'requestedStartTime': requestedStartTime,
      'requestedEndTime': requestedEndTime,
      'reason': reason,
      'proofNote': proofNote,
      'status': status.name,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
      'reviewRemarks': reviewRemarks,
      'approvedStartTime': approvedStartTime,
      'approvedEndTime': approvedEndTime,
      'originalClockInLogId': originalClockInLogId,
      'originalClockOutLogId': originalClockOutLogId,
      'originalStartTime': originalStartTime,
      'originalEndTime': originalEndTime,
      'attendanceClockInLogId': attendanceClockInLogId,
      'attendanceClockOutLogId': attendanceClockOutLogId,
    };
  }

  factory TimeRequestModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return TimeRequestModel(
      id: id,
      internUid: map['internUid'] ?? '',
      internName: map['internName'] ?? '',
      internEmail: map['internEmail'] ?? '',
      requestType: _typeFromString(map['requestType']),
      requestDate: _dateFromValue(map['requestDate']),
      requestedStartTime: map['requestedStartTime'] ?? '',
      requestedEndTime: map['requestedEndTime'] ?? '',
      reason: map['reason'] ?? '',
      proofNote: map['proofNote'] ?? '',
      status: _statusFromString(map['status']),
      submittedAt: _dateFromValue(map['submittedAt']),
      reviewedAt: map['reviewedAt'] != null
          ? _dateFromValue(map['reviewedAt'])
          : null,
      reviewedBy: map['reviewedBy'],
      reviewRemarks: map['reviewRemarks'],
      approvedStartTime: map['approvedStartTime'],
      approvedEndTime: map['approvedEndTime'],
      originalClockInLogId: map['originalClockInLogId'],
      originalClockOutLogId: map['originalClockOutLogId'],
      originalStartTime: map['originalStartTime'],
      originalEndTime: map['originalEndTime'],
      attendanceClockInLogId: map['attendanceClockInLogId'],
      attendanceClockOutLogId: map['attendanceClockOutLogId'],
    );
  }

  static TimeRequestStatus _statusFromString(String? value) {
    switch (value) {
      case 'approved':
        return TimeRequestStatus.approved;
      case 'rejected':
        return TimeRequestStatus.rejected;
      case 'pending':
      default:
        return TimeRequestStatus.pending;
    }
  }

  static TimeRequestType _typeFromString(String? value) {
    switch (value) {
      case 'correction':
        return TimeRequestType.correction;
      case 'missingTime':
      default:
        return TimeRequestType.missingTime;
    }
  }

  static DateTime _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}