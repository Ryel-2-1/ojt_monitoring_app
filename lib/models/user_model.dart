import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { intern, supervisor }

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.intern:
        return 'intern';
      case UserRole.supervisor:
        return 'supervisor';
    }
  }

  String get label {
    switch (this) {
      case UserRole.intern:
        return 'Intern';
      case UserRole.supervisor:
        return 'Supervisor';
    }
  }

  static UserRole? fromString(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'intern':
        return UserRole.intern;
      case 'supervisor':
        return UserRole.supervisor;
      default:
        return null;
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;

  final String? enrollmentCode;
  final DateTime? enrollmentCodeUpdatedAt;

  final String? supervisorUid;
  final String? supervisorName;
  final String? supervisorEmail;
  final DateTime? joinedSupervisorAt;

  final String? enrollmentId;
  final String? enrollmentStatus;

  final String? companyId;
  final String? companyName;
  final String? companyAddress;

  final double? assignedLatitude;
  final double? assignedLongitude;
  final double? allowedRadius;

  final int? requiredOjtHours;
  final DateTime? internshipStartDate;
  final DateTime? internshipEndDate;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.enrollmentCode,
    this.enrollmentCodeUpdatedAt,
    this.supervisorUid,
    this.supervisorName,
    this.supervisorEmail,
    this.joinedSupervisorAt,
    this.enrollmentId,
    this.enrollmentStatus,
    this.companyId,
    this.companyName,
    this.companyAddress,
    this.assignedLatitude,
    this.assignedLongitude,
    this.allowedRadius,
    this.requiredOjtHours,
    this.internshipStartDate,
    this.internshipEndDate,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return UserModel(
      uid: id ?? map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      role:
          UserRoleExtension.fromString(map['role']?.toString()) ??
          UserRole.intern,
      enrollmentCode: map['enrollmentCode']?.toString(),
      enrollmentCodeUpdatedAt: _toDateTime(map['enrollmentCodeUpdatedAt']),
      supervisorUid: map['supervisorUid']?.toString(),
      supervisorName: map['supervisorName']?.toString(),
      supervisorEmail: map['supervisorEmail']?.toString(),
      joinedSupervisorAt: _toDateTime(map['joinedSupervisorAt']),
      enrollmentId: map['enrollmentId']?.toString(),
      enrollmentStatus: map['enrollmentStatus']?.toString(),
      companyId: map['companyId']?.toString(),
      companyName: map['companyName']?.toString(),
      companyAddress: map['companyAddress']?.toString(),
      assignedLatitude: _toDouble(map['assignedLatitude']),
      assignedLongitude: _toDouble(map['assignedLongitude']),
      allowedRadius: _toDouble(map['allowedRadius']),
      requiredOjtHours: _toInt(map['requiredOjtHours']),
      internshipStartDate: _toDateTime(map['internshipStartDate']),
      internshipEndDate: _toDateTime(map['internshipEndDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': role.value,
      'enrollmentCode': enrollmentCode,
      'enrollmentCodeUpdatedAt': enrollmentCodeUpdatedAt == null
          ? null
          : Timestamp.fromDate(enrollmentCodeUpdatedAt!),
      'supervisorUid': supervisorUid,
      'supervisorName': supervisorName,
      'supervisorEmail': supervisorEmail,
      'joinedSupervisorAt': joinedSupervisorAt == null
          ? null
          : Timestamp.fromDate(joinedSupervisorAt!),
      'enrollmentId': enrollmentId,
      'enrollmentStatus': enrollmentStatus,
      'companyId': companyId,
      'companyName': companyName,
      'companyAddress': companyAddress,
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
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    UserRole? role,
    String? enrollmentCode,
    DateTime? enrollmentCodeUpdatedAt,
    String? supervisorUid,
    String? supervisorName,
    String? supervisorEmail,
    DateTime? joinedSupervisorAt,
    String? enrollmentId,
    String? enrollmentStatus,
    String? companyId,
    String? companyName,
    String? companyAddress,
    double? assignedLatitude,
    double? assignedLongitude,
    double? allowedRadius,
    int? requiredOjtHours,
    DateTime? internshipStartDate,
    DateTime? internshipEndDate,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      enrollmentCode: enrollmentCode ?? this.enrollmentCode,
      enrollmentCodeUpdatedAt:
          enrollmentCodeUpdatedAt ?? this.enrollmentCodeUpdatedAt,
      supervisorUid: supervisorUid ?? this.supervisorUid,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorEmail: supervisorEmail ?? this.supervisorEmail,
      joinedSupervisorAt: joinedSupervisorAt ?? this.joinedSupervisorAt,
      enrollmentId: enrollmentId ?? this.enrollmentId,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      assignedLatitude: assignedLatitude ?? this.assignedLatitude,
      assignedLongitude: assignedLongitude ?? this.assignedLongitude,
      allowedRadius: allowedRadius ?? this.allowedRadius,
      requiredOjtHours: requiredOjtHours ?? this.requiredOjtHours,
      internshipStartDate: internshipStartDate ?? this.internshipStartDate,
      internshipEndDate: internshipEndDate ?? this.internshipEndDate,
    );
  }

  bool get hasActiveEnrollment {
    return enrollmentStatus?.trim().toLowerCase() == 'active';
  }

  bool get hasJoinedSupervisor {
    return supervisorUid != null && supervisorUid!.trim().isNotEmpty;
  }

  bool get hasValidCompanyAssignment {
    return companyId != null &&
        companyId!.trim().isNotEmpty &&
        assignedLatitude != null &&
        assignedLongitude != null &&
        allowedRadius != null &&
        allowedRadius! > 0;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
