// lib/repositories/attendance_repository.dart
//
// PURPOSE: All Firestore operations for the `attendance` collection.
// Attendance logs are append-only (never edited, rarely deleted),
// so this repository focuses on: add, query by UID, and stream today's log.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

// Enum for attendance status — prevents magic strings like "clock-in" vs "Clock In"
enum AttendanceStatus { clockIn, clockOut }

extension AttendanceStatusExtension on AttendanceStatus {
  // What gets stored in Firestore
  String get value {
    switch (this) {
      case AttendanceStatus.clockIn:
        return 'Clock-In';
      case AttendanceStatus.clockOut:
        return 'Clock-Out';
    }
  }

  // Parse from Firestore string back to enum
  static AttendanceStatus fromString(String value) {
    switch (value) {
      case 'Clock-In':
        return AttendanceStatus.clockIn;
      case 'Clock-Out':
        return AttendanceStatus.clockOut;
      default:
        return AttendanceStatus.clockIn;
    }
  }
}

// --- AttendanceModel ---
// Mirrors one document in the `attendance` collection.
class AttendanceModel {
  final String? id;              // Firestore auto-generated doc ID (null before save)
  final String uid;              // The student's Firebase Auth UID
  final DateTime timestamp;      // When the log was created
  final AttendanceStatus status; // Clock-In or Clock-Out
  final GeoPoint? locationCoords; // Firestore's native lat/lng type (nullable)

  const AttendanceModel({
    this.id,
    required this.uid,
    required this.timestamp,
    required this.status,
    this.locationCoords,
  });

  // toMap(): used when writing to Firestore.
  // We use FieldValue.serverTimestamp() instead of DateTime.now() so
  // the timestamp is set by Firestore's servers — not the device clock,
  // which could be wrong or spoofed.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        // FieldValue.serverTimestamp() tells Firestore: "set this when you
        // receive the write request." This is more reliable than client time.
        'timestamp': FieldValue.serverTimestamp(),
        'status': status.value,
        if (locationCoords != null) 'location_coords': locationCoords,
      };

  // fromMap(): used when reading from Firestore.
  factory AttendanceModel.fromMap(Map<String, dynamic> map, {String? id}) {
    // Firestore Timestamps must be converted to Dart DateTime.
    final rawTimestamp = map['timestamp'];
    final DateTime parsedTimestamp = rawTimestamp is Timestamp
        ? rawTimestamp.toDate()
        : DateTime.now(); // fallback if timestamp is somehow null

    return AttendanceModel(
      id: id,
      uid: map['uid'] ?? '',
      timestamp: parsedTimestamp,
      status: AttendanceStatusExtension.fromString(map['status'] ?? 'Clock-In'),
      locationCoords: map['location_coords'] as GeoPoint?,
    );
  }
}

// --- AttendanceRepository ---
class AttendanceRepository {
  final FirestoreService _firestoreService;

  AttendanceRepository({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  static const String _collection = 'attendance';

  // --- Log a Clock-In or Clock-Out ---
  // Returns the new document's auto-generated ID.
  // We don't set a docId — Firestore generates one (addDocument).
  Future<String> logAttendance({
    required String uid,
    required AttendanceStatus status,
    GeoPoint? locationCoords,
  }) async {
    final log = AttendanceModel(
      uid: uid,
      timestamp: DateTime.now(), // local time used in the model, server time in Firestore
      status: status,
      locationCoords: locationCoords,
    );

    return await _firestoreService.addDocument(
      path: _collection,
      data: log.toMap(),
    );
  }

  // --- Get all attendance logs for a student ---
  // Sorted newest-first. Use this for the student's history screen.
  Future<List<AttendanceModel>> getAttendanceByStudent(String uid) async {
    final results = await _firestoreService.queryCollection(
      path: _collection,
      field: 'uid',
      value: uid,
      orderBy: 'timestamp',
      descending: true,
    );

    return results
        .map((data) => AttendanceModel.fromMap(data, id: data['id']))
        .toList();
  }

  // --- Stream attendance logs for a student (real-time) ---
  // Use with StreamBuilder so the log screen updates instantly
  // when a new record is added (e.g., after a QR scan).
  Stream<List<AttendanceModel>> streamAttendanceByStudent(String uid) {
    return _firestoreService.streamCollection(
      path: _collection,
      field: 'uid',
      value: uid,
      orderBy: 'timestamp',
      descending: true,
    ).map((list) =>
        list.map((data) => AttendanceModel.fromMap(data, id: data['id'])).toList());
  }

  // --- Get today's logs for a student ---
  // Useful for checking if a student has already clocked in today.
  // We query all of the student's logs then filter client-side for today,
  // because Firestore doesn't support date-range + UID compound queries
  // without a composite index. For large datasets, add that index instead.
  Future<List<AttendanceModel>> getTodayAttendance(String uid) async {
    final allLogs = await getAttendanceByStudent(uid);
    final now = DateTime.now();

    return allLogs.where((log) {
      return log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day;
    }).toList();
  }

  // --- Check if student is currently "clocked in" ---
  // Returns true if the most recent log today was a Clock-In.
  Future<bool> isCurrentlyClockedIn(String uid) async {
    final todayLogs = await getTodayAttendance(uid);
    if (todayLogs.isEmpty) return false;
    return todayLogs.first.status == AttendanceStatus.clockIn;
  }
}