import 'package:cloud_firestore/cloud_firestore.dart';

enum EnrollmentStatus { active, completed, withdrawn }

extension EnrollmentStatusX on EnrollmentStatus {
  String get value {
    switch (this) {
      case EnrollmentStatus.active:
        return 'active';
      case EnrollmentStatus.completed:
        return 'completed';
      case EnrollmentStatus.withdrawn:
        return 'withdrawn';
    }
  }

  String get label {
    switch (this) {
      case EnrollmentStatus.active:
        return 'Active';
      case EnrollmentStatus.completed:
        return 'Completed';
      case EnrollmentStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  static EnrollmentStatus fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'completed':
        return EnrollmentStatus.completed;
      case 'withdrawn':
        return EnrollmentStatus.withdrawn;
      case 'active':
      default:
        return EnrollmentStatus.active;
    }
  }
}

class EnrollmentModel {
  final String? id;

  final String internUid;
  final String internName;
  final String internEmail;

  final String supervisorUid;
  final String supervisorName;
  final String supervisorEmail;

  final String companyId;
  final String companyName;
  final String companyAddress;
  final double assignedLatitude;
  final double assignedLongitude;
  final double allowedRadius;

  final int requiredOjtHours;
  final DateTime? internshipStartDate;
  final DateTime? internshipEndDate;

  final EnrollmentStatus status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EnrollmentModel({
    this.id,
    required this.internUid,
    required this.internName,
    required this.internEmail,
    required this.supervisorUid,
    required this.supervisorName,
    required this.supervisorEmail,
    required this.companyId,
    required this.companyName,
    required this.companyAddress,
    required this.assignedLatitude,
    required this.assignedLongitude,
    required this.allowedRadius,
    required this.requiredOjtHours,
    this.internshipStartDate,
    this.internshipEndDate,
    this.status = EnrollmentStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  factory EnrollmentModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return EnrollmentModel(
      id: id,
      internUid: map['internUid']?.toString() ?? '',
      internName: map['internName']?.toString() ?? '',
      internEmail: map['internEmail']?.toString() ?? '',
      supervisorUid: map['supervisorUid']?.toString() ?? '',
      supervisorName: map['supervisorName']?.toString() ?? '',
      supervisorEmail: map['supervisorEmail']?.toString() ?? '',
      companyId: map['companyId']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      companyAddress: map['companyAddress']?.toString() ?? '',
      assignedLatitude: _toDouble(map['assignedLatitude']),
      assignedLongitude: _toDouble(map['assignedLongitude']),
      allowedRadius: _toDouble(map['allowedRadius'], fallback: 50),
      requiredOjtHours: _toInt(map['requiredOjtHours'], fallback: 480),
      internshipStartDate: _toDateTime(map['internshipStartDate']),
      internshipEndDate: _toDateTime(map['internshipEndDate']),
      status: EnrollmentStatusX.fromValue(map['status']?.toString()),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'internUid': internUid,
      'internName': internName.trim(),
      'internEmail': internEmail.trim(),

      'supervisorUid': supervisorUid,
      'supervisorName': supervisorName.trim(),
      'supervisorEmail': supervisorEmail.trim(),

      'companyId': companyId,
      'companyName': companyName.trim(),
      'companyAddress': companyAddress.trim(),
      'assignedLatitude': assignedLatitude,
      'assignedLongitude': assignedLongitude,
      'allowedRadius': allowedRadius,

      'requiredOjtHours': requiredOjtHours,
      'internshipStartDate': internshipStartDate == null
          ? null
          : Timestamp.fromDate(internshipStartDate!),
      'internshipEndDate': internshipEndDate == null
          ? null
          : Timestamp.fromDate(internshipEndDate!),

      'status': status.value,

      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'internUid': internUid,
      'internName': internName.trim(),
      'internEmail': internEmail.trim(),

      'supervisorUid': supervisorUid,
      'supervisorName': supervisorName.trim(),
      'supervisorEmail': supervisorEmail.trim(),

      'companyId': companyId,
      'companyName': companyName.trim(),
      'companyAddress': companyAddress.trim(),
      'assignedLatitude': assignedLatitude,
      'assignedLongitude': assignedLongitude,
      'allowedRadius': allowedRadius,

      'requiredOjtHours': requiredOjtHours,
      'internshipStartDate': internshipStartDate == null
          ? null
          : Timestamp.fromDate(internshipStartDate!),
      'internshipEndDate': internshipEndDate == null
          ? null
          : Timestamp.fromDate(internshipEndDate!),

      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  EnrollmentModel copyWith({
    String? id,
    String? internUid,
    String? internName,
    String? internEmail,
    String? supervisorUid,
    String? supervisorName,
    String? supervisorEmail,
    String? companyId,
    String? companyName,
    String? companyAddress,
    double? assignedLatitude,
    double? assignedLongitude,
    double? allowedRadius,
    int? requiredOjtHours,
    DateTime? internshipStartDate,
    DateTime? internshipEndDate,
    EnrollmentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnrollmentModel(
      id: id ?? this.id,
      internUid: internUid ?? this.internUid,
      internName: internName ?? this.internName,
      internEmail: internEmail ?? this.internEmail,
      supervisorUid: supervisorUid ?? this.supervisorUid,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorEmail: supervisorEmail ?? this.supervisorEmail,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      assignedLatitude: assignedLatitude ?? this.assignedLatitude,
      assignedLongitude: assignedLongitude ?? this.assignedLongitude,
      allowedRadius: allowedRadius ?? this.allowedRadius,
      requiredOjtHours: requiredOjtHours ?? this.requiredOjtHours,
      internshipStartDate: internshipStartDate ?? this.internshipStartDate,
      internshipEndDate: internshipEndDate ?? this.internshipEndDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == EnrollmentStatus.active;

  bool get hasValidCompanyGeofence {
    return companyId.trim().isNotEmpty &&
        assignedLatitude != 0 &&
        assignedLongitude != 0 &&
        allowedRadius > 0;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString().trim()) ?? fallback;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}
