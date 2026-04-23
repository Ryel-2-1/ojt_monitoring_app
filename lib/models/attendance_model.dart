import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { clockIn, clockOut }

extension AttendanceStatusExtension on AttendanceStatus {
  String get value {
    switch (this) {
      case AttendanceStatus.clockIn:
        return 'Clock-In';
      case AttendanceStatus.clockOut:
        return 'Clock-Out';
    }
  }

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

class AttendanceModel {
  final String? id;
  final String uid;
  final DateTime timestamp;
  final AttendanceStatus status;
  final GeoPoint? locationCoords;

  const AttendanceModel({
    this.id,
    required this.uid,
    required this.timestamp,
    required this.status,
    this.locationCoords,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        // Always written as a server timestamp so all clients share the
        // same authoritative time regardless of local clock drift.
        'timestamp': FieldValue.serverTimestamp(),
        'status': status.value,
        if (locationCoords != null) 'location_coords': locationCoords,
      };

  factory AttendanceModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawTimestamp = map['timestamp'];
    // Firestore returns null for serverTimestamp() on the optimistic local
    // snapshot that fires immediately after a write (before the server
    // acknowledges). We fall back to DateTime.now() in that case — the
    // real timestamp arrives on the next snapshot within milliseconds.
    final DateTime parsedTimestamp = rawTimestamp is Timestamp
        ? rawTimestamp.toDate()
        : DateTime.now();

    return AttendanceModel(
      id: id,
      uid: map['uid'] ?? '',
      timestamp: parsedTimestamp,
      status: AttendanceStatusExtension.fromString(
        map['status'] ?? 'Clock-In',
      ),
      locationCoords: map['location_coords'] as GeoPoint?,
    );
  }
}