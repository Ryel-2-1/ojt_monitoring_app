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

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.value,
      'location_coords': locationCoords,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawTimestamp = map['timestamp'];

    final DateTime parsedTimestamp = rawTimestamp is Timestamp
        ? rawTimestamp.toDate()
        : rawTimestamp is DateTime
            ? rawTimestamp
            : DateTime.now();

    return AttendanceModel(
      id: id,
      uid: map['uid']?.toString() ?? '',
      timestamp: parsedTimestamp,
      status: AttendanceStatusExtension.fromString(
        map['status']?.toString() ?? 'Clock-In',
      ),
      locationCoords: map['location_coords'] as GeoPoint?,
    );
  }
}