import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  intern,
  supervisor,
}

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

  final double? assignedLatitude;
  final double? assignedLongitude;
  final double? allowedRadius;

  final String? companyName;
  final String? companyAddress;
  final int? requiredOjtHours;
  final DateTime? internshipStartDate;
  final DateTime? internshipEndDate;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.assignedLatitude,
    this.assignedLongitude,
    this.allowedRadius,
    this.companyName,
    this.companyAddress,
    this.requiredOjtHours,
    this.internshipStartDate,
    this.internshipEndDate,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return UserModel(
      uid: id ?? map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      role: UserRoleExtension.fromString(map['role']?.toString()) ??
          UserRole.intern,
      assignedLatitude: _toDouble(map['assignedLatitude']),
      assignedLongitude: _toDouble(map['assignedLongitude']),
      allowedRadius: _toDouble(map['allowedRadius']),
      companyName: map['companyName']?.toString(),
      companyAddress: map['companyAddress']?.toString(),
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
      'assignedLatitude': assignedLatitude,
      'assignedLongitude': assignedLongitude,
      'allowedRadius': allowedRadius,
      'companyName': companyName,
      'companyAddress': companyAddress,
      'requiredOjtHours': requiredOjtHours,
      'internshipStartDate': internshipStartDate == null
          ? null
          : Timestamp.fromDate(internshipStartDate!),
      'internshipEndDate':
          internshipEndDate == null ? null : Timestamp.fromDate(internshipEndDate!),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    UserRole? role,
    double? assignedLatitude,
    double? assignedLongitude,
    double? allowedRadius,
    String? companyName,
    String? companyAddress,
    int? requiredOjtHours,
    DateTime? internshipStartDate,
    DateTime? internshipEndDate,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      assignedLatitude: assignedLatitude ?? this.assignedLatitude,
      assignedLongitude: assignedLongitude ?? this.assignedLongitude,
      allowedRadius: allowedRadius ?? this.allowedRadius,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      requiredOjtHours: requiredOjtHours ?? this.requiredOjtHours,
      internshipStartDate: internshipStartDate ?? this.internshipStartDate,
      internshipEndDate: internshipEndDate ?? this.internshipEndDate,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}