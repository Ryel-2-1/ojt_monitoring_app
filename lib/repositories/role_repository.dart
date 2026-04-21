// lib/repositories/role_repository.dart
//
// PURPOSE: Manages role-based permissions stored in the `permissions`
// Firestore collection. Used by the Admin Access Control screen.
//
// FIRESTORE SCHEMA:
// Collection: `permissions`
// Document ID: the role name slug (e.g., "security_administrator", "intern")
//
// Example document for "security_administrator":
// {
//   "roleName":      "Security Administrator",   // human-readable display name
//   "liveTracking":  true,
//   "studentRecords": true,
//   "adminLogs":     false,
// }
//
// WHY DOCUMENT ID = ROLE SLUG:
// Using a deterministic ID (the slug) means we can fetch a role's
// permissions with one direct document read instead of a query.
// Direct reads are faster and cheaper (1 read vs N reads for a query).
//
// HOW THE ADMIN SCREEN USES THIS:
//   1. Admin opens Access Control screen.
//   2. Screen calls RoleRepository.getPermissions("security_administrator").
//   3. Screen displays toggles for liveTracking, studentRecords, adminLogs.
//   4. Admin flips a toggle → screen calls RoleRepository.updatePermission(...).
//   5. Firestore updates instantly; other admin sessions update via stream.

import '../services/firestore_service.dart';

// --- RolePermissionModel ---
// Mirrors one document in the `permissions` collection.
// Each boolean field maps directly to a toggle in the Access Control UI.
class RolePermissionModel {
  final String roleSlug;       // Document ID — e.g., "security_administrator"
  final String roleName;       // Display name — e.g., "Security Administrator"
  final bool liveTracking;     // Can view the live student location map
  final bool studentRecords;   // Can view/edit student attendance records
  final bool adminLogs;        // Can view admin activity logs

  const RolePermissionModel({
    required this.roleSlug,
    required this.roleName,
    required this.liveTracking,
    required this.studentRecords,
    required this.adminLogs,
  });

  // toMap(): used when creating a new role document for the first time.
  Map<String, dynamic> toMap() => {
        'roleName': roleName,
        'liveTracking': liveTracking,
        'studentRecords': studentRecords,
        'adminLogs': adminLogs,
      };

  // fromMap(): deserializes a Firestore document into a RolePermissionModel.
  // The `slug` parameter is the document ID passed in separately.
  factory RolePermissionModel.fromMap(
      Map<String, dynamic> map, String slug) =>
      RolePermissionModel(
        roleSlug: slug,
        roleName: map['roleName'] ?? slug,
        // Default to false if a field is missing — safer than defaulting to true.
        liveTracking: map['liveTracking'] ?? false,
        studentRecords: map['studentRecords'] ?? false,
        adminLogs: map['adminLogs'] ?? false,
      );

  // copyWith(): creates a modified copy — used after a toggle update
  // to refresh local state without re-fetching from Firestore.
  RolePermissionModel copyWith({
    String? roleSlug,
    String? roleName,
    bool? liveTracking,
    bool? studentRecords,
    bool? adminLogs,
  }) {
    return RolePermissionModel(
      roleSlug: roleSlug ?? this.roleSlug,
      roleName: roleName ?? this.roleName,
      liveTracking: liveTracking ?? this.liveTracking,
      studentRecords: studentRecords ?? this.studentRecords,
      adminLogs: adminLogs ?? this.adminLogs,
    );
  }

  @override
  String toString() =>
      'RolePermissionModel($roleSlug: liveTracking=$liveTracking, '
      'studentRecords=$studentRecords, adminLogs=$adminLogs)';
}

// --- Permission field name constants ---
// The UI toggles call updatePermission() with one of these constants.
// Using constants instead of raw strings prevents "livetracking" vs
// "liveTracking" typo bugs that are invisible until runtime.
class PermissionField {
  static const String liveTracking = 'liveTracking';
  static const String studentRecords = 'studentRecords';
  static const String adminLogs = 'adminLogs';

  // All permission fields — useful for iterating in the UI to build
  // the toggles list dynamically instead of hardcoding each one.
  static const List<String> all = [liveTracking, studentRecords, adminLogs];

  // Human-readable labels for each field — used by the UI for toggle labels.
  static const Map<String, String> labels = {
    liveTracking: 'Live Tracking',
    studentRecords: 'Student Records',
    adminLogs: 'Admin Logs',
  };
}

// --- RoleRepository ---
class RoleRepository {
  final FirestoreService _firestoreService;

  RoleRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'permissions';

  // --- Pre-defined role slugs ---
  // These are the dropdown options in the Access Control screen.
  // Stored as constants so the UI and the repository stay in sync.
  static const String roleSecurityAdmin = 'security_administrator';
  static const String roleSupervisor = 'supervisor';
  static const String roleIntern = 'intern';
  static const String roleViewer = 'viewer';

  // All roles for building the dropdown list.
  static const List<Map<String, String>> allRoles = [
    {'slug': roleSecurityAdmin, 'label': 'Security Administrator'},
    {'slug': roleSupervisor, 'label': 'Supervisor'},
    {'slug': roleIntern, 'label': 'Intern'},
    {'slug': roleViewer, 'label': 'Viewer'},
  ];

  // ─────────────────────────────────────────────
  // READ — Fetch all permissions for a role (one-time)
  // ─────────────────────────────────────────────

  // getPermissions():
  // Called when the admin opens the Access Control screen and selects
  // a role from the dropdown.
  // Returns null if no permissions document exists for this role yet.
  Future<RolePermissionModel?> getPermissions(String roleSlug) async {
    try {
      final data = await _firestoreService.getDocument(
        path: _collection,
        docId: roleSlug,
      );

      if (data == null) return null;
      return RolePermissionModel.fromMap(data, roleSlug);
    } catch (e) {
      throw Exception('Failed to fetch permissions for $roleSlug: $e');
    }
  }

  // ─────────────────────────────────────────────
  // READ — Stream permissions for a role (real-time)
  // ─────────────────────────────────────────────

  // streamPermissions():
  // Use this in the Access Control screen so the toggles update live
  // if another admin changes permissions simultaneously (multi-admin scenario).
  Stream<RolePermissionModel?> streamPermissions(String roleSlug) {
    return _firestoreService
        .streamDocument(path: _collection, docId: roleSlug)
        .map((data) =>
            data != null ? RolePermissionModel.fromMap(data, roleSlug) : null);
  }

  // ─────────────────────────────────────────────
  // UPDATE — Toggle a single permission boolean
  // ─────────────────────────────────────────────

  // updatePermission():
  // Called when the admin flips a toggle in the UI.
  // Only updates the ONE field that changed — the rest are untouched.
  //
  // Parameters:
  //   roleSlug  — which role's document to update (e.g., "security_administrator")
  //   field     — which permission to flip (use PermissionField constants)
  //   value     — the new boolean value (true = enabled, false = disabled)
  //
  // Example usage:
  //   await roleRepo.updatePermission(
  //     roleSlug: RoleRepository.roleSecurityAdmin,
  //     field: PermissionField.liveTracking,
  //     value: true,
  //   );
  Future<void> updatePermission({
    required String roleSlug,
    required String field,
    required bool value,
  }) async {
    // Guard: only allow known permission fields to prevent
    // accidental writes to arbitrary Firestore fields.
    if (!PermissionField.all.contains(field)) {
      throw ArgumentError(
          'Unknown permission field: "$field". Use PermissionField constants.');
    }

    try {
      await _firestoreService.updateDocument(
        path: _collection,
        docId: roleSlug,
        data: {field: value},
      );
    } catch (e) {
      throw Exception('Failed to update $field for $roleSlug: $e');
    }
  }

  // ─────────────────────────────────────────────
  // CREATE — Initialize a role's permissions document
  // ─────────────────────────────────────────────

  // initializeRole():
  // Called once (e.g., by an admin setup script or on first app launch)
  // to create the permissions document for a role with safe defaults.
  // All permissions default to false — admin must explicitly enable them.
  //
  // Uses merge: true so calling this on an existing role is safe
  // (won't overwrite manually configured permissions).
  Future<void> initializeRole(RolePermissionModel role) async {
    try {
      await _firestoreService.setDocument(
        path: _collection,
        docId: role.roleSlug,
        data: role.toMap(),
        merge: true,
      );
    } catch (e) {
      throw Exception('Failed to initialize role ${role.roleSlug}: $e');
    }
  }

  // ─────────────────────────────────────────────
  // HELPER — Seed default permissions for all roles
  // ─────────────────────────────────────────────

  // seedDefaultPermissions():
  // Run this once from an admin screen or a setup utility to populate
  // the `permissions` collection with sensible defaults.
  // Safe to run multiple times — merge: true won't overwrite existing settings.
  Future<void> seedDefaultPermissions() async {
    final defaults = [
      RolePermissionModel(
        roleSlug: roleSecurityAdmin,
        roleName: 'Security Administrator',
        liveTracking: true,
        studentRecords: true,
        adminLogs: true,
      ),
      RolePermissionModel(
        roleSlug: roleSupervisor,
        roleName: 'Supervisor',
        liveTracking: true,
        studentRecords: true,
        adminLogs: false,
      ),
      RolePermissionModel(
        roleSlug: roleIntern,
        roleName: 'Intern',
        liveTracking: false,
        studentRecords: false,
        adminLogs: false,
      ),
      RolePermissionModel(
        roleSlug: roleViewer,
        roleName: 'Viewer',
        liveTracking: true,
        studentRecords: false,
        adminLogs: false,
      ),
    ];

    for (final role in defaults) {
      await initializeRole(role);
    }
  }
}