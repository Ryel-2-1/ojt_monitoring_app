import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeRequestStatus {
  pending,
  approved,
  rejected,
}

class TimeRequestModel {
  final String? id;
  final String internUid;
  final String internName;
  final String internEmail;
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

  // NEW: supervisor-approved corrected times
  final String? approvedStartTime;
  final String? approvedEndTime;

  TimeRequestModel({
    this.id,
    required this.internUid,
    required this.internName,
    required this.internEmail,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'internUid': internUid,
      'internName': internName,
      'internEmail': internEmail,
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
    };
  }

  factory TimeRequestModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return TimeRequestModel(
      id: id,
      internUid: map['internUid'] ?? '',
      internName: map['internName'] ?? '',
      internEmail: map['internEmail'] ?? '',
      requestDate: (map['requestDate'] as Timestamp).toDate(),
      requestedStartTime: map['requestedStartTime'] ?? '',
      requestedEndTime: map['requestedEndTime'] ?? '',
      reason: map['reason'] ?? '',
      proofNote: map['proofNote'] ?? '',
      status: _statusFromString(map['status']),
      submittedAt: (map['submittedAt'] as Timestamp).toDate(),
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: map['reviewedBy'],
      reviewRemarks: map['reviewRemarks'],
      approvedStartTime: map['approvedStartTime'],
      approvedEndTime: map['approvedEndTime'],
    );
  }

  static TimeRequestStatus _statusFromString(String? value) {
    switch (value) {
      case 'approved':
        return TimeRequestStatus.approved;
      case 'rejected':
        return TimeRequestStatus.rejected;
      default:
        return TimeRequestStatus.pending;
    }
  }
}