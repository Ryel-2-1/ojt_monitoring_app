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

  static UserRole? fromString(String? roleStr) {
    if (roleStr == 'supervisor') return UserRole.supervisor;
    if (roleStr == 'intern') return UserRole.intern;
    return null;
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

  UserModel({
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
    final rawStartDate = map['internshipStartDate'];
    final rawEndDate = map['internshipEndDate'];

    return UserModel(
      uid: id ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: UserRoleExtension.fromString(map['role']) ?? UserRole.intern,
      assignedLatitude: (map['assignedLatitude'] as num?)?.toDouble(),
      assignedLongitude: (map['assignedLongitude'] as num?)?.toDouble(),
      allowedRadius: (map['allowedRadius'] as num?)?.toDouble(),
      companyName: map['companyName'],
      companyAddress: map['companyAddress'],
      requiredOjtHours: (map['requiredOjtHours'] as num?)?.toInt(),
      internshipStartDate: rawStartDate is Timestamp ? rawStartDate.toDate() : null,
      internshipEndDate: rawEndDate is Timestamp ? rawEndDate.toDate() : null,
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
      'internshipStartDate':
          internshipStartDate != null ? Timestamp.fromDate(internshipStartDate!) : null,
      'internshipEndDate':
          internshipEndDate != null ? Timestamp.fromDate(internshipEndDate!) : null,
    };
  }
}