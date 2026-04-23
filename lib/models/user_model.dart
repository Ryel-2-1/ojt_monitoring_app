// lib/models/user_model.dart

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
  
  // Geolocation Fields (Nullable because new users won't have them yet)
  final double? assignedLatitude;
  final double? assignedLongitude;
  final double? allowedRadius;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.assignedLatitude,
    this.assignedLongitude,
    this.allowedRadius,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return UserModel(
      uid: id ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: UserRoleExtension.fromString(map['role']) ?? UserRole.intern,
      assignedLatitude: map['assignedLatitude']?.toDouble(),
      assignedLongitude: map['assignedLongitude']?.toDouble(),
      allowedRadius: map['allowedRadius']?.toDouble(),
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
    };
  }
}