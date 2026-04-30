import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String? id;
  final String companyName;
  final String companyAddress;
  final double assignedLatitude;
  final double assignedLongitude;
  final double allowedRadius;
  final bool isActive;
  final String? createdBySupervisorUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CompanyModel({
    this.id,
    required this.companyName,
    required this.companyAddress,
    required this.assignedLatitude,
    required this.assignedLongitude,
    required this.allowedRadius,
    this.isActive = true,
    this.createdBySupervisorUid,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companyAddress': companyAddress,
      'assignedLatitude': assignedLatitude,
      'assignedLongitude': assignedLongitude,
      'allowedRadius': allowedRadius,
      'isActive': isActive,
      'createdBySupervisorUid': createdBySupervisorUid,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory CompanyModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return CompanyModel(
      id: id,
      companyName: map['companyName']?.toString() ?? '',
      companyAddress: map['companyAddress']?.toString() ?? '',
      assignedLatitude: _toDouble(map['assignedLatitude']),
      assignedLongitude: _toDouble(map['assignedLongitude']),
      allowedRadius: _toDouble(map['allowedRadius'], fallback: 50),
      isActive: map['isActive'] == true,
      createdBySupervisorUid: map['createdBySupervisorUid']?.toString(),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  CompanyModel copyWith({
    String? id,
    String? companyName,
    String? companyAddress,
    double? assignedLatitude,
    double? assignedLongitude,
    double? allowedRadius,
    bool? isActive,
    String? createdBySupervisorUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      assignedLatitude: assignedLatitude ?? this.assignedLatitude,
      assignedLongitude: assignedLongitude ?? this.assignedLongitude,
      allowedRadius: allowedRadius ?? this.allowedRadius,
      isActive: isActive ?? this.isActive,
      createdBySupervisorUid:
          createdBySupervisorUid ?? this.createdBySupervisorUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}