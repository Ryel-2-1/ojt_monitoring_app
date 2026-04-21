// lib/models/user_model.dart
//
// PURPOSE: Defines the shape of a user document in Firestore.
// This model is shared between UserRepository (saving/fetching)
// and any UI that needs to display user info (name, role).
//
// WHY A SEPARATE MODELS FOLDER:
// Models are pure data classes — no Firebase imports, no UI imports.
// Any developer on the team can read this file to understand exactly
// what fields a user document contains, without opening Firestore.

// --- UserRole Enum ---
// Using an enum instead of raw strings like "intern" / "supervisor"
// prevents bugs from typos and makes role checks type-safe.
// e.g., if (user.role == UserRole.supervisor) instead of if (user.role == "Supervisor")
enum UserRole { intern, supervisor }

extension UserRoleExtension on UserRole {
  // value: what gets stored as a string in Firestore.
  // Keeping it lowercase makes Firestore queries case-consistent.
  String get value {
    switch (this) {
      case UserRole.intern:
        return 'intern';
      case UserRole.supervisor:
        return 'supervisor';
    }
  }

  // Display label for UI — capitalized for readability.
  String get label {
    switch (this) {
      case UserRole.intern:
        return 'Intern';
      case UserRole.supervisor:
        return 'Supervisor';
    }
  }

  // fromString(): converts the Firestore string back to the enum.
  // Called inside UserModel.fromMap() when reading from Firestore.
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'supervisor':
        return UserRole.supervisor;
      case 'intern':
      default:
        return UserRole.intern;
    }
  }
}

// --- UserModel ---
// Mirrors one document in the `users` Firestore collection.
// Fields:
//   uid       — Firebase Auth UID, used as the Firestore document ID
//   email     — School email used during registration
//   fullName  — Entered on the Create Account screen
//   role      — intern or supervisor (selected on Create Account screen)
//   createdAt — Timestamp of when the account was created (set server-side)
class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final UserRole role;
  final DateTime? createdAt; // nullable — not available until after first fetch

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.createdAt,
  });

  // toMap(): serializes this object for writing to Firestore.
  // We do NOT include createdAt here because it's set by
  // FieldValue.serverTimestamp() in the repository, not client-side.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'role': role.value, // stores "intern" or "supervisor"
      };

  // fromMap(): deserializes a Firestore document back to a UserModel.
  // The `id` parameter is the Firestore document ID (same as uid).
  factory UserModel.fromMap(Map<String, dynamic> map, {String? id}) {
    // Handle Firestore Timestamp → Dart DateTime conversion.
    // Firestore returns timestamps as Timestamp objects, not DateTime.
    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt != null) {
      // Firestore Timestamp has a .toDate() method
      try {
        parsedCreatedAt = (rawCreatedAt as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedCreatedAt = null;
      }
    }

    return UserModel(
      uid: id ?? map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      role: UserRoleExtension.fromString(map['role'] ?? 'intern'),
      createdAt: parsedCreatedAt,
    );
  }

  // copyWith(): creates a modified copy of the model.
  // Used when updating individual fields without re-fetching from Firestore.
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, fullName: $fullName, role: ${role.value})';
}